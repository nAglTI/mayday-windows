import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

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
    AppTextCatalog? appTextCatalog,
  })  : _runtimePathsService =
            runtimePathsService ?? const RuntimePathsService(),
        _diagnosticsLogger =
            diagnosticsLogger ?? const RuntimeDiagnosticsLogger(),
        _processJob = processJob ?? RuntimeProcessJob(),
        _textCatalog =
            appTextCatalog ?? const AppTextCatalog(AppLanguage.english);

  static const _startupProbeTimeout = Duration(milliseconds: 2500);
  static const _logFlushTimeout = Duration(seconds: 2);

  final RuntimePathsService _runtimePathsService;
  final RuntimeDiagnosticsLogger _diagnosticsLogger;
  final RuntimeProcessJob _processJob;
  AppTextCatalog _textCatalog;
  final _runningStateController = StreamController<bool>.broadcast();
  Process? _activeProcess;
  Future<List<void>>? _activeLogPipes;

  void updateTextCatalog(AppTextCatalog appTextCatalog) {
    _textCatalog = appTextCatalog;
  }

  Stream<bool> get runningChanges => _runningStateController.stream;

  Future<LaunchResult> launch({
    required String configPath,
    bool requiresSplitTunnel = false,
    bool deleteConfigAfterLaunch = false,
  }) async {
    final paths = await _runtimePathsService.getPaths();
    final launcherLogPath = await _launcherLogPath(paths);
    if (_activeProcess != null) {
      await _deleteConfigIfRequested(configPath, deleteConfigAfterLaunch);
      return LaunchResult(
        success: true,
        message: _textCatalog.t('client.running'),
        processId: _activeProcess!.pid,
      );
    }

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

    final missingFiles = await _runtimePathsService.validateRuntime(
      paths,
      includeSplitTunnelFiles: requiresSplitTunnel,
    );
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

  bool get isRunning => _activeProcess != null;

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
      event: 'process.stop.requested',
      fields: {
        'processId': process.pid,
      },
    );

    try {
      final signalled = process.kill();
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 5),
      );
      await _activeLogPipes?.timeout(
        _logFlushTimeout,
        onTimeout: () => <void>[],
      );
      _clearActiveProcess(process);

      await _diagnosticsLogger.writeEvent(
        paths,
        event: 'process.stop.completed',
        fields: {
          'processId': process.pid,
          'killSignalSent': signalled,
          'exitCode': exitCode,
        },
      );
      return StopResult(
        success: true,
        message: _messageWithOptionalLog(
          withLogKey: 'client.stopped',
          withoutLogKey: 'client.stopped_no_log',
          logPath: launcherLogPath,
          values: {'code': exitCode},
        ),
        exitCode: exitCode,
      );
    } on TimeoutException {
      await _diagnosticsLogger.writeEvent(
        paths,
        event: 'process.stop.timeout',
        fields: {
          'processId': process.pid,
        },
      );
      return StopResult(
        success: false,
        message: _messageWithOptionalLog(
          withLogKey: 'client.stop_timeout',
          withoutLogKey: 'client.stop_timeout_no_log',
          logPath: launcherLogPath,
        ),
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
        ['-config', configPath],
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
        _activeProcess = process;
        _activeLogPipes = pipes.done;
        _runningStateController.add(true);
        unawaited(_observeProcessExit(paths, process, pipes.done));
        await _diagnosticsLogger.writeEvent(
          paths,
          event: 'process.launch.started',
          fields: {
            ...configInspection.toLogFields(),
            'processId': process.pid,
            'arguments': '-config $configPath',
            if (stdoutLogPath != null) 'stdoutLogPath': stdoutLogPath,
            if (stderrLogPath != null) 'stderrLogPath': stderrLogPath,
          },
        );
        await _deleteConfigIfRequested(configPath, deleteConfigAfterLaunch);
        return LaunchResult(
          success: true,
          message: _diagnosticsLogger.enabled
              ? _textCatalog.t('client.started', {
                  'launcherLog': launcherLogPath,
                  'stdoutLog': stdoutLogPath,
                  'stderrLog': stderrLogPath,
                })
              : _textCatalog.t('client.started_no_log'),
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
    _runningStateController.add(false);
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
    this.preview,
    this.readError,
  });

  final String configPath;
  final bool exists;
  final bool readOk;
  final int? sizeBytes;
  final DateTime? modified;
  final String? preview;
  final String? readError;

  Map<String, Object?> toLogFields() {
    return {
      'configPath': configPath,
      'configExists': exists,
      'configReadOk': readOk,
      'configSizeBytes': sizeBytes,
      'configModified': modified?.toIso8601String(),
      'configReadError': readError,
      if (preview != null) 'configPreview': '\n$preview',
    };
  }
}
