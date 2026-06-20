abstract final class MaydayAppMetadata {
  static const version = String.fromEnvironment(
    'MAYDAY_APP_VERSION',
    defaultValue: '2.1.1+1',
  );

  static const releasePageUrl =
      'https://github.com/nAglTI/mayday-windows/releases';
}
