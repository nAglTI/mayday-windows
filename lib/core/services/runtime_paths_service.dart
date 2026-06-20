import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/runtime_paths.dart';

enum RuntimePlatform {
  windows,
  macos,
  unsupported;

  static RuntimePlatform current() {
    if (Platform.isWindows) {
      return RuntimePlatform.windows;
    }
    if (Platform.isMacOS) {
      return RuntimePlatform.macos;
    }
    return RuntimePlatform.unsupported;
  }
}

class RuntimePathsService {
  const RuntimePathsService({
    RuntimePlatform? platform,
    Map<String, String>? environment,
    String? resolvedExecutable,
  })  : _platform = platform,
        _environment = environment,
        _resolvedExecutable = resolvedExecutable;

  static const String _buildVariant = String.fromEnvironment(
    'MAYDAY_BUILD_VARIANT',
    defaultValue: 'local',
  );

  final RuntimePlatform? _platform;
  final Map<String, String>? _environment;
  final String? _resolvedExecutable;

  Future<RuntimePaths> getPaths() async {
    final platform = _platform ?? RuntimePlatform.current();
    final spec = _RuntimePlatformSpec.forPlatform(platform);
    final path = p.Context(style: spec.pathStyle);
    final installRoot = _installRoot(
      path,
      platform,
      _resolvedExecutable ?? Platform.resolvedExecutable,
    );
    final runtimeDir = path.join(installRoot, 'runtime');
    final mutableRoot = _mutableRoot(path, platform);
    final configDir = path.join(mutableRoot, 'config');

    return RuntimePaths(
      installRoot: installRoot,
      runtimeDir: runtimeDir,
      clientExePath: path.join(runtimeDir, spec.runtimeExecutableName),
      pipeHelperExePath: path.join(runtimeDir, spec.pipeHelperExecutableName),
      controlPipePath: spec.controlEndpoint.path(path, mutableRoot),
      mutableRoot: mutableRoot,
      configDir: configDir,
      configPath: path.join(configDir, spec.savedConfigFileName),
    );
  }

  String get _mutableRootName {
    final normalized = _buildVariant.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'prod') {
      return 'Mayday';
    }
    return 'Mayday-$normalized';
  }

  String _installRoot(
    p.Context path,
    RuntimePlatform platform,
    String resolvedExecutable,
  ) {
    final executableDir = path.dirname(resolvedExecutable);
    if (platform != RuntimePlatform.macos) {
      return executableDir;
    }

    final contentsDir = path.dirname(executableDir);
    if (path.basename(executableDir) == 'MacOS' &&
        path.basename(contentsDir) == 'Contents') {
      return path.join(contentsDir, 'Resources');
    }

    return executableDir;
  }

  String _mutableRoot(
    p.Context path,
    RuntimePlatform platform,
  ) {
    final environment = _environment ?? Platform.environment;

    switch (platform) {
      case RuntimePlatform.windows:
        final localAppData =
            environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
        return path.join(localAppData, _mutableRootName);
      case RuntimePlatform.macos:
        final home = environment['HOME'] ?? Directory.systemTemp.path;
        return path.join(
          home,
          'Library',
          'Application Support',
          _mutableRootName,
        );
      case RuntimePlatform.unsupported:
        return path.join(Directory.systemTemp.path, _mutableRootName);
    }
  }

  Future<void> ensureMutableDirectories(RuntimePaths paths) async {
    await Directory(paths.configDir).create(recursive: true);
  }

  Future<List<String>> validateRuntime(RuntimePaths paths) async {
    final platform = _platform ?? RuntimePlatform.current();
    final spec = _RuntimePlatformSpec.forPlatform(platform);
    final path = p.Context(style: spec.pathStyle);
    final requiredFiles = <String>[
      paths.clientExePath,
      paths.pipeHelperExePath,
      for (final fileName in spec.additionalRequiredRuntimeFiles)
        path.join(paths.runtimeDir, fileName),
    ];

    final missing = <String>[];
    for (final filePath in requiredFiles) {
      if (!await File(filePath).exists()) {
        missing.add(filePath);
      }
    }
    return missing;
  }
}

class _RuntimePlatformSpec {
  const _RuntimePlatformSpec({
    required this.pathStyle,
    required this.runtimeExecutableName,
    required this.pipeHelperExecutableName,
    required this.savedConfigFileName,
    required this.additionalRequiredRuntimeFiles,
    required this.controlEndpoint,
  });

  factory _RuntimePlatformSpec.forPlatform(RuntimePlatform platform) {
    return switch (platform) {
      RuntimePlatform.windows => _windows,
      RuntimePlatform.macos => _macos,
      RuntimePlatform.unsupported => _unsupported,
    };
  }

  static final _windows = _RuntimePlatformSpec(
    pathStyle: p.Style.windows,
    runtimeExecutableName: 'mdhelper.exe',
    pipeHelperExecutableName: 'mdpipectl.exe',
    savedConfigFileName: 'client.yaml.dpapi',
    additionalRequiredRuntimeFiles: ['wintun.dll'],
    controlEndpoint: _RuntimeControlEndpoint.windowsNamedPipe,
  );

  static final _macos = _RuntimePlatformSpec(
    pathStyle: p.Style.posix,
    runtimeExecutableName: 'mdhelper',
    pipeHelperExecutableName: 'mdpipectl',
    savedConfigFileName: 'client.yaml.keychain',
    additionalRequiredRuntimeFiles: [],
    controlEndpoint: _RuntimeControlEndpoint.unixSocket,
  );

  static final _unsupported = _RuntimePlatformSpec(
    pathStyle: p.Style.posix,
    runtimeExecutableName: 'mdhelper',
    pipeHelperExecutableName: 'mdpipectl',
    savedConfigFileName: 'client.yaml.local',
    additionalRequiredRuntimeFiles: [],
    controlEndpoint: _RuntimeControlEndpoint.unixSocket,
  );

  final p.Style pathStyle;
  final String runtimeExecutableName;
  final String pipeHelperExecutableName;
  final String savedConfigFileName;
  final List<String> additionalRequiredRuntimeFiles;
  final _RuntimeControlEndpoint controlEndpoint;
}

enum _RuntimeControlEndpoint {
  windowsNamedPipe,
  unixSocket;

  String path(p.Context pathContext, String mutableRoot) {
    return switch (this) {
      _RuntimeControlEndpoint.windowsNamedPipe => r'\\.\pipe\mayday-control',
      _RuntimeControlEndpoint.unixSocket => pathContext.join(
          mutableRoot,
          'mayday-control.sock',
        ),
    };
  }
}
