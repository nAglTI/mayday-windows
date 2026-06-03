class RuntimePaths {
  const RuntimePaths({
    required this.installRoot,
    required this.runtimeDir,
    required this.clientExePath,
    required this.mutableRoot,
    required this.configDir,
    required this.configPath,
    this.pipeHelperExePath = '',
    this.controlPipePath = r'\\.\pipe\mayday-control',
  });

  final String installRoot;
  final String runtimeDir;
  final String clientExePath;
  final String pipeHelperExePath;
  final String controlPipePath;
  final String mutableRoot;
  final String configDir;
  final String configPath;
}
