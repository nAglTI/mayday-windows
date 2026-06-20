import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/runtime_status_snapshot.dart';
import '../models/runtime_paths.dart';
import '../l10n/app_texts.dart';
import 'runtime_process_job.dart';
import 'runtime_paths_service.dart';
import 'runtime_diagnostics_logger.dart';

class LaunchResult {
  const LaunchResult({
    required this.success,
    required this.message,
    this.processId,
  });

  final bool success;
  final String message;
  final int? processId;
}

class StopResult {
  const StopResult({
    required this.success,
    required this.message,
    this.exitCode,
  });

  final bool success;
  final String message;
  final int? exitCode;
}

class RuntimeLauncher {
  RuntimeLauncher({
    RuntimePathsService? runtimePathsService,
    RuntimeDiagnosticsLogger? diagnosticsLogger,
    RuntimeProcessJob? processJob,
    RuntimeControlClient? controlClient,
    AppTextCatalog? appTextCatalog,
  })  : _runtimePathsService =
            runtimePathsService ?? const RuntimePathsService(),
        _diagnosticsLogger =
            diagnosticsLogger ?? const RuntimeDiagnosticsLogger(),
        _processJob = processJob ?? RuntimeProcessJob(),
        _controlClient = controlClient ?? RuntimeControlClient(),
        _textCatalog =
            appTextCatalog ?? const AppTextCatalog(AppLanguage.english);

  static const _startupProbeTimeout = Duration(milliseconds: 2500);
  static const _pipeWaitTimeout = Duration(seconds: 30);
  static const _commandWaitTimeout = Duration(seconds: 45);
  static const _logFlushTimeout = Duration(seconds: 2);
  static const _statusPollInterval = Duration(seconds: 2);
  static const _statusPollTimeout = Duration(seconds: 3);

  final RuntimePathsService _runtimePathsService;
  final RuntimeDiagnosticsLogger _diagnosticsLogger;
  final RuntimeProcessJob _processJob;
  final RuntimeControlClient _controlClient;
  AppTextCatalog _textCatalog;
  final _runningStateController = StreamController<bool>.broadcast();
  final _runtimeStatusController =
      StreamController<RuntimeStatusSnapshot>.broadcast();
  Process? _activeProcess;
  Future<List<void>>? _activeLogPipes;
  Timer? _statusPollTimer;
  int? _activeConfigFingerprint;
  bool _vpnActive = false;
  bool _statusPollInFlight = false;

  void updateTextCatalog(AppTextCatalog appTextCatalog) {
    _textCatalog = appTextCatalog;
  }

  Stream<bool> get runningChanges => _runningStateController.stream;

  Stream<RuntimeStatusSnapshot> get runtimeStatusChanges =>
      _runtimeStatusController.stream;

  Future<LaunchResult> launch({
    required String configPath,
    bool requiresSplitTunnel = false,
    bool deleteConfigAfterLaunch = false,
  }) async {
    final paths = await _runtimePathsService.getPaths();
    final launcherLogPath = await _launcherLogPath(paths);
    await _diagnosticsLogger.writeEvent(
      paths,
      event: 'process.launch.requested',
      fields: {
        'launchMode': 'direct Process.start',
        'clientExePath': paths.clientExePath,
        'runtimeDir': paths.runtimeDir,
        'configPath': configPath,
        'requiresSplitTunnel': requiresSplitTunnel,
        'launcherLogPath': launcherLogPath,
      },
    );

    final configInspection = await _inspectConfig(configPath);
    if (configInspection.readError != null) {
      await _diagnosticsLogger.writeEvent(
        paths,
        event: 'process.launch.config_unreadable',
        fields: configInspection.toLogFields(),
      );
      await _deleteConfigIfRequested(configPath, deleteConfigAfterLaunch);
      return LaunchResult(
        success: false,
        message: _messageWithOptionalLog(
          withLogKey: 'client.config_unreadable',
          withoutLogKey: 'client.config_unreadable_no_log',
          logPath: launcherLogPath,
          values: {'error': configInspection.readError},
        ),
      );
    }

    final activeProcess = _activeProcess;
    if (activeProcess != null) {
      if (_activeConfigFingerprint == configInspection.fingerprint) {
        await _deleteConfigIfRequested(configPath, deleteConfigAfterLaunch);
        return _startVpnOnActiveProcess(paths, launcherLogPath);
      }

      await _shutdownActiveProcess(
        paths,
        launcherLogPath,
        reason: 'config_changed',
      );
    }

    final missingFiles = await _runtimePathsService.validateRuntime(paths);
    if (missingFiles.isNotEmpty) {
      await _diagnosticsLogger.writeEvent(
        paths,
        event: 'process.launch.runtime_missing',
        fields: {
          'missingFiles': missingFiles.join('\n'),
        },
      );
      await _deleteConfigIfRequested(configPath, deleteConfigAfterLaunch);
      return LaunchResult(
        success: false,
        message: _messageWithOptionalLog(
          withLogKey: 'client.runtime_missing',
          withoutLogKey: 'client.runtime_missing_no_log',
          logPath: launcherLogPath,
          values: {'files': missingFiles.join('\n')},
        ),
      );
    }

    return _launchDirectWithDiagnostics(
      paths,
      configPath,
      launcherLogPath,
      configInspection,
      deleteConfigAfterLaunch,
    );
  }

  bool get isRunning => _vpnActive;

  Future<StopResult> stop() async {
    final paths = await _runtimePathsService.getPaths();
    final launcherLogPath = await _launcherLogPath(paths);
    final process = _activeProcess;
    if (process == null) {
      return StopResult(
        success: true,
        message: _messageWithOptionalLog(
          withLogKey: 'client.not_running',
          withoutLogKey: 'client.not_running_no_log',
          logPath: launcherLogPath,
        ),
      );
    }

    await _diagnosticsLogger.writeEvent(
      paths,
      event: 'vpn.stop.requested',
      fields: {
        'processId': process.pid,
        'pipe': paths.controlPipePath,
      },
    );

    try {
      final result = await _controlClient.send(
        paths,
        command: 'stop',
        waitTimeout: _commandWaitTimeout,
      );

      if (!result.success) {
        await _diagnosticsLogger.writeEvent(
          paths,
          event: 'vpn.stop.failed',
          fields: {
            'processId': process.pid,
            ...result.toLogFields(),
          },
        );
        return StopResult(
          success: false,
          message: _controlFailureMessage(
            command: 'stop',
            result: result,
            logPath: launcherLogPath,
          ),
          exitCode: result.exitCode,
        );
      }

      _setVpnActive(false);
      await _diagnosticsLogger.writeEvent(
        paths,
        event: 'vpn.stop.completed',
        fields: {
          'processId': process.pid,
          ...result.toLogFields(),
        },
      );
      return StopResult(
        success: true,
        message: _messageWithOptionalLog(
          withLogKey: 'client.vpn_stopped',
          withoutLogKey: 'client.vpn_stopped_no_log',
          logPath: launcherLogPath,
        ),
        exitCode: result.exitCode,
      );
    } catch (error) {
      await _diagnosticsLogger.writeEvent(
        paths,
        event: 'process.stop.failed',
        fields: {
          'processId': process.pid,
          'error': error,
        },
      );
      return StopResult(
        success: false,
        message: _messageWithOptionalLog(
          withLogKey: 'client.stop_failed',
          withoutLogKey: 'client.stop_failed_no_log',
          logPath: launcherLogPath,
          values: {'error': error},
        ),
      );
    }
  }

  Future<StopResult> shutdown() async {
    final paths = await _runtimePathsService.getPaths();
    final launcherLogPath = await _launcherLogPath(paths);
    return _shutdownActiveProcess(
      paths,
      launcherLogPath,
      reason: 'ui_shutdown',
    );
  }

  Future<LaunchResult> _launchDirectWithDiagnostics(
    RuntimePaths paths,
    String configPath,
    String? launcherLogPath,
    _ConfigInspection configInspection,
    bool deleteConfigAfterLaunch,
  ) async {
    String? stdoutLogPath;
    String? stderrLogPath;
    if (_diagnosticsLogger.enabled) {
      final logsDir = p.join(paths.mutableRoot, 'logs');
      await Directory(logsDir).create(recursive: true);

      final stamp =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      stdoutLogPath = p.join(logsDir, 'client-$stamp.out.log');
      stderrLogPath = p.join(logsDir, 'client-$stamp.err.log');
    }

    try {
      final process = await Process.start(
        paths.clientExePath,
        ['-config', configPath, '-control-pipe', paths.controlPipePath],
        workingDirectory: paths.runtimeDir,
        mode: ProcessStartMode.normal,
      );
      await _attachProcessToJob(paths, process);
      final pipes = _pipeProcessOutput(
        process,
        stdoutLogPath: stdoutLogPath,
        stderrLogPath: stderrLogPath,
      );

      final earlyExitCode = await _waitForEarlyExit(process.exitCode);

      if (earlyExitCode == null) {
        final statusProbe = await _controlClient.send(
          paths,
          command: 'status',
          waitTimeout: _pipeWaitTimeout,
        );

        if (!statusProbe.success) {
          process.kill();
          await pipes.done.timeout(
            _logFlushTimeout,
            onTimeout: () => <void>[],
          );
          await _deleteConfigIfRequested(configPath, deleteConfigAfterLaunch);
          await _diagnosticsLogger.writeEvent(
            paths,
            event: 'process.launch.pipe_not_ready',
            fields: {
              ...configInspection.toLogFields(),
              'processId': process.pid,
              ...statusProbe.toLogFields(),
            },
          );
          return LaunchResult(
            success: false,
            message: _controlFailureMessage(
              command: 'status',
              result: statusProbe,
              logPath: launcherLogPath,
            ),
            processId: process.pid,
          );
        }

        _activeProcess = process;
        _activeLogPipes = pipes.done;
        _activeConfigFingerprint = configInspection.fingerprint;
        _setVpnActive(false);
        _startStatusPolling(paths);
        unawaited(_observeProcessExit(paths, process, pipes.done));

        final transports = await _controlClient.send(
          paths,
          command: 'transports',
          waitTimeout: const Duration(seconds: 5),
        );
        await _diagnosticsLogger.writeEvent(
          paths,
          event: 'process.launch.started',
          fields: {
            ...configInspection.toLogFields(),
            'processId': process.pid,
            'arguments':
                '-config $configPath -control-pipe ${paths.controlPipePath}',
            'controlPipe': paths.controlPipePath,
            'statusProbe': statusProbe.toLogFields(),
            'transports': transports.toLogFields(),
            if (stdoutLogPath != null) 'stdoutLogPath': stdoutLogPath,
            if (stderrLogPath != null) 'stderrLogPath': stderrLogPath,
          },
        );
        await _deleteConfigIfRequested(configPath, deleteConfigAfterLaunch);

        return _startVpnOnActiveProcess(
          paths,
          launcherLogPath,
          processId: process.pid,
        );
      }

      await pipes.done.timeout(
        _logFlushTimeout,
        onTimeout: () => <void>[],
      );
      final details = await _collectLaunchDetails(
        stdoutLogPath: stdoutLogPath,
        stderrLogPath: stderrLogPath,
        exitCode: earlyExitCode,
      );

      await _diagnosticsLogger.writeEvent(
        paths,
        event: 'process.launch.exited_immediately',
        fields: {
          ...configInspection.toLogFields(),
          'processId': process.pid,
          'exitCode': earlyExitCode,
          'arguments': '-config $configPath',
          if (stdoutLogPath != null) 'stdoutLogPath': stdoutLogPath,
          if (stderrLogPath != null) 'stderrLogPath': stderrLogPath,
          'details': details,
        },
      );
      await _deleteConfigIfRequested(configPath, deleteConfigAfterLaunch);

      return LaunchResult(
        success: false,
        message: _messageWithOptionalLog(
          withLogKey: 'client.started_failed',
          withoutLogKey: 'client.started_failed_no_log',
          logPath: launcherLogPath,
          values: {'error': details},
        ),
      );
    } catch (error) {
      await _diagnosticsLogger.writeEvent(
        paths,
        event: 'process.launch.exception',
        fields: {
          ...configInspection.toLogFields(),
          'error': error,
        },
      );
      await _deleteConfigIfRequested(configPath, deleteConfigAfterLaunch);
      return LaunchResult(
        success: false,
        message: _messageWithOptionalLog(
          withLogKey: 'client.started_failed',
          withoutLogKey: 'client.started_failed_no_log',
          logPath: launcherLogPath,
          values: {'error': error},
        ),
      );
    }
  }

  Future<LaunchResult> _startVpnOnActiveProcess(
    RuntimePaths paths,
    String? launcherLogPath, {
    int? processId,
  }) async {
    final process = _activeProcess;
    final result = await _controlClient.send(
      paths,
      command: 'start',
      waitTimeout: _commandWaitTimeout,
    );

    await _diagnosticsLogger.writeEvent(
      paths,
      event: result.success ? 'vpn.start.completed' : 'vpn.start.failed',
      fields: {
        if (process != null) 'processId': process.pid,
        ...result.toLogFields(),
      },
    );

    if (!result.success) {
      _setVpnActive(false);
      return LaunchResult(
        success: false,
        message: _controlFailureMessage(
          command: 'start',
          result: result,
          logPath: launcherLogPath,
        ),
        processId: processId ?? process?.pid,
      );
    }

    _setVpnActive(true);
    return LaunchResult(
      success: true,
      message: _messageWithOptionalLog(
        withLogKey: 'client.vpn_started',
        withoutLogKey: 'client.vpn_started_no_log',
        logPath: launcherLogPath,
      ),
      processId: processId ?? process?.pid,
    );
  }

  Future<StopResult> _shutdownActiveProcess(
    RuntimePaths paths,
    String? launcherLogPath, {
    required String reason,
  }) async {
    final process = _activeProcess;
    if (process == null) {
      _setVpnActive(false);
      return StopResult(
        success: true,
        message: _messageWithOptionalLog(
          withLogKey: 'client.not_running',
          withoutLogKey: 'client.not_running_no_log',
          logPath: launcherLogPath,
        ),
      );
    }

    await _diagnosticsLogger.writeEvent(
      paths,
      event: 'process.shutdown.requested',
      fields: {
        'reason': reason,
        'processId': process.pid,
        'pipe': paths.controlPipePath,
      },
    );

    final result = await _controlClient.send(
      paths,
      command: 'shutdown',
      waitTimeout: const Duration(seconds: 5),
    );

    var exitCode = result.exitCode;
    if (result.success) {
      try {
        exitCode = await process.exitCode.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        process.kill();
      }
    } else {
      process.kill();
    }

    await _activeLogPipes?.timeout(
      _logFlushTimeout,
      onTimeout: () => <void>[],
    );
    _clearActiveProcess(process);

    await _diagnosticsLogger.writeEvent(
      paths,
      event: result.success
          ? 'process.shutdown.completed'
          : 'process.shutdown.failed',
      fields: {
        'reason': reason,
        'processId': process.pid,
        'exitCode': exitCode,
        ...result.toLogFields(),
      },
    );

    if (!result.success) {
      return StopResult(
        success: false,
        message: _controlFailureMessage(
          command: 'shutdown',
          result: result,
          logPath: launcherLogPath,
        ),
        exitCode: exitCode,
      );
    }

    return StopResult(
      success: true,
      message: _messageWithOptionalLog(
        withLogKey: 'client.shutdown',
        withoutLogKey: 'client.shutdown_no_log',
        logPath: launcherLogPath,
      ),
      exitCode: exitCode,
    );
  }

  Future<void> _attachProcessToJob(RuntimePaths paths, Process process) async {
    try {
      _processJob.attach(process);
      await _diagnosticsLogger.writeEvent(
        paths,
        event: 'process.job.attached',
        fields: {
          'processId': process.pid,
        },
      );
    } catch (error) {
      await _diagnosticsLogger.writeEvent(
        paths,
        event: 'process.job.attach_failed',
        fields: {
          'processId': process.pid,
          'error': error,
        },
      );
    }
  }

  Future<void> _deleteConfigIfRequested(
    String configPath,
    bool deleteConfigAfterLaunch,
  ) async {
    if (!deleteConfigAfterLaunch) {
      return;
    }

    try {
      final file = File(configPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup of the temporary runtime config.
    }
  }

  Future<void> _observeProcessExit(
    RuntimePaths paths,
    Process process,
    Future<List<void>> pipesDone,
  ) async {
    final exitCode = await process.exitCode;
    await pipesDone.timeout(
      _logFlushTimeout,
      onTimeout: () => <void>[],
    );
    _clearActiveProcess(process);
    await _diagnosticsLogger.writeEvent(
      paths,
      event: 'process.exited',
      fields: {
        'processId': process.pid,
        'exitCode': exitCode,
      },
    );
  }

  void _clearActiveProcess(Process process) {
    if (!identical(_activeProcess, process)) {
      return;
    }
    _activeProcess = null;
    _activeLogPipes = null;
    _activeConfigFingerprint = null;
    _stopStatusPolling(clearStatus: true);
    _setVpnActive(false);
  }

  void _setVpnActive(bool value) {
    if (_vpnActive == value) {
      return;
    }
    _vpnActive = value;
    _runningStateController.add(value);
  }

  void _startStatusPolling(RuntimePaths paths) {
    _statusPollTimer?.cancel();
    _runtimeStatusController.add(RuntimeStatusSnapshot.empty);
    unawaited(_pollRuntimeStatus(paths));
    _statusPollTimer = Timer.periodic(_statusPollInterval, (_) {
      unawaited(_pollRuntimeStatus(paths));
    });
  }

  void _stopStatusPolling({required bool clearStatus}) {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    _statusPollInFlight = false;
    if (clearStatus) {
      _runtimeStatusController.add(RuntimeStatusSnapshot.empty);
    }
  }

  Future<void> _pollRuntimeStatus(RuntimePaths paths) async {
    if (_statusPollInFlight || _activeProcess == null) {
      return;
    }
    _statusPollInFlight = true;
    try {
      final result = await _controlClient.send(
        paths,
        command: 'status',
        waitTimeout: _statusPollTimeout,
      );
      if (!result.success) {
        return;
      }
      final snapshot = RuntimeStatusSnapshot.tryParse(result.stdout);
      if (snapshot != null) {
        _runtimeStatusController.add(snapshot);
      }
    } catch (_) {
      // Status telemetry is best-effort and should not affect the connection.
    } finally {
      _statusPollInFlight = false;
    }
  }

  _ProcessLogPipes _pipeProcessOutput(
    Process process, {
    required String? stdoutLogPath,
    required String? stderrLogPath,
  }) {
    if (stdoutLogPath == null || stderrLogPath == null) {
      return _ProcessLogPipes(
        done: Future.wait<void>([
          process.stdout.drain<void>(),
          process.stderr.drain<void>(),
        ]),
      );
    }

    final stdoutSink = File(stdoutLogPath).openWrite();
    final stderrSink = File(stderrLogPath).openWrite();
    final stdoutDone = process.stdout.pipe(stdoutSink);
    final stderrDone = process.stderr.pipe(stderrSink);

    return _ProcessLogPipes(
      done: Future.wait<void>([
        stdoutDone,
        stderrDone,
      ]),
    );
  }

  Future<int?> _waitForEarlyExit(Future<int> exitCode) async {
    try {
      return await exitCode.timeout(_startupProbeTimeout);
    } on TimeoutException {
      return null;
    }
  }

  Future<String> _collectLaunchDetails({
    required String? stdoutLogPath,
    required String? stderrLogPath,
    required int exitCode,
  }) async {
    final stdoutLog =
        stdoutLogPath == null ? '' : await _readLogSnippet(stdoutLogPath);
    final stderrLog =
        stderrLogPath == null ? '' : await _readLogSnippet(stderrLogPath);
    final details = <String>[
      _textCatalog.t('client.terminated_immediately'),
      _textCatalog.t('client.exit_code', {'code': exitCode}),
      if (stderrLog.isNotEmpty)
        '${_textCatalog.t('client.stderr')}\n$stderrLog',
      if (stdoutLog.isNotEmpty)
        '${_textCatalog.t('client.stdout')}\n$stdoutLog',
      if (stdoutLogPath != null && stderrLogPath != null)
        _textCatalog.t(
          'client.logs',
          {'stdoutLog': stdoutLogPath, 'stderrLog': stderrLogPath},
        ),
    ];

    final joined = details.join('\n\n');
    final lowered = joined.toLowerCase();
    if (lowered.contains('access is denied') ||
        lowered.contains('code 0x00000005')) {
      return '$joined\n\n${_textCatalog.t('client.access_denied')}';
    }

    return joined;
  }

  Future<String> _readLogSnippet(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return '';
    }

    final text = (await file.readAsString()).trim();
    const maxLength = 4000;
    if (text.length <= maxLength) {
      return text;
    }
    return '...\n${text.substring(text.length - maxLength)}';
  }

  Future<_ConfigInspection> _inspectConfig(String configPath) async {
    final file = File(configPath);
    final exists = await file.exists();
    if (!exists) {
      return _ConfigInspection(
        configPath: configPath,
        exists: false,
        readError: _textCatalog.t(
          'client.config_not_found',
          {'configPath': configPath},
        ),
      );
    }

    try {
      final stat = await file.stat();
      final raw = await file.readAsString();
      return _ConfigInspection(
        configPath: configPath,
        exists: true,
        readOk: true,
        sizeBytes: stat.size,
        modified: stat.modified,
        fingerprint: _stableConfigFingerprint(raw),
        preview: _diagnosticsLogger.enabled
            ? _diagnosticsLogger.configPreview(raw)
            : null,
      );
    } catch (error) {
      return _ConfigInspection(
        configPath: configPath,
        exists: exists,
        readError: error.toString(),
      );
    }
  }

  int _stableConfigFingerprint(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  Future<String?> _launcherLogPath(RuntimePaths paths) async {
    if (!_diagnosticsLogger.enabled) {
      return null;
    }
    return _diagnosticsLogger.getLogPath(paths);
  }

  String _messageWithOptionalLog({
    required String withLogKey,
    required String withoutLogKey,
    required String? logPath,
    Map<String, Object?> values = const {},
  }) {
    if (logPath == null || logPath.isEmpty) {
      return _textCatalog.t(withoutLogKey, values);
    }

    return _textCatalog.t(withLogKey, {
      ...values,
      'log': logPath,
    });
  }

  String _controlFailureMessage({
    required String command,
    required RuntimeControlResult result,
    required String? logPath,
  }) {
    return _messageWithOptionalLog(
      withLogKey: 'client.control_failed',
      withoutLogKey: 'client.control_failed_no_log',
      logPath: logPath,
      values: {
        'command': _controlCommandLabel(command),
        'error': _controlErrorLabel(result),
      },
    );
  }

  String _controlCommandLabel(String command) {
    return switch (command) {
      'start' => _textCatalog.t('client.control_command_start'),
      'stop' => _textCatalog.t('client.control_command_stop'),
      'status' => _textCatalog.t('client.control_command_status'),
      'shutdown' => _textCatalog.t('client.control_command_shutdown'),
      'transports' => _textCatalog.t('client.control_command_transports'),
      _ => command,
    };
  }

  String _controlErrorLabel(RuntimeControlResult result) {
    final details = result.details.trim().toLowerCase();
    if (details.contains('access is denied') ||
        details.contains('0x00000005')) {
      return _textCatalog.t('client.control_error_access_denied');
    }
    if (details.contains('timeout') || details.contains('timed out')) {
      return _textCatalog.t('client.control_error_timeout');
    }
    if (result.exitCode != 0) {
      return _textCatalog.t(
        'client.control_error_code',
        {'code': result.exitCode},
      );
    }
    return _textCatalog.t('client.control_error_generic');
  }
}

class _ProcessLogPipes {
  const _ProcessLogPipes({
    required this.done,
  });

  final Future<List<void>> done;
}

class _ConfigInspection {
  const _ConfigInspection({
    required this.configPath,
    required this.exists,
    this.readOk = false,
    this.sizeBytes,
    this.modified,
    this.fingerprint,
    this.preview,
    this.readError,
  });

  final String configPath;
  final bool exists;
  final bool readOk;
  final int? sizeBytes;
  final DateTime? modified;
  final int? fingerprint;
  final String? preview;
  final String? readError;

  Map<String, Object?> toLogFields() {
    return {
      'configPath': configPath,
      'configExists': exists,
      'configReadOk': readOk,
      'configSizeBytes': sizeBytes,
      'configModified': modified?.toIso8601String(),
      'configFingerprint': fingerprint,
      'configReadError': readError,
      if (preview != null) 'configPreview': '\n$preview',
    };
  }
}

class RuntimeControlClient {
  const RuntimeControlClient();

  Future<RuntimeControlResult> send(
    RuntimePaths paths, {
    required String command,
    required Duration waitTimeout,
  }) async {
    final helperPath = paths.pipeHelperExePath.isEmpty
        ? p.join(
            paths.runtimeDir,
            Platform.isWindows ? 'mdpipectl.exe' : 'mdpipectl',
          )
        : paths.pipeHelperExePath;
    final result = await Process.run(
      helperPath,
      [
        '-pipe',
        paths.controlPipePath,
        '-command',
        command,
        '-wait-timeout',
        _goDuration(waitTimeout),
      ],
      workingDirectory: paths.runtimeDir,
    );

    return RuntimeControlResult(
      command: command,
      exitCode: result.exitCode,
      stdout: result.stdout?.toString() ?? '',
      stderr: result.stderr?.toString() ?? '',
    );
  }

  String _goDuration(Duration duration) {
    if (duration.inMilliseconds % 1000 == 0) {
      return '${duration.inSeconds}s';
    }
    return '${duration.inMilliseconds}ms';
  }
}

class RuntimeControlResult {
  const RuntimeControlResult({
    required this.command,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final String command;
  final int exitCode;
  final String stdout;
  final String stderr;

  bool get success => exitCode == 0;

  String get details {
    final lines = <String>[
      if (stderr.trim().isNotEmpty) stderr.trim(),
      if (stdout.trim().isNotEmpty) stdout.trim(),
      if (exitCode != 0) 'exit code $exitCode',
    ];
    return lines.isEmpty ? 'ok' : lines.join('\n');
  }

  Map<String, Object?> toLogFields() {
    return {
      'command': command,
      'exitCode': exitCode,
      if (stdout.trim().isNotEmpty) 'stdout': stdout.trim(),
      if (stderr.trim().isNotEmpty) 'stderr': stderr.trim(),
    };
  }
}
