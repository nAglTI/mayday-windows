import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/bad_app_finding.dart';

class BadAppScannerService {
  BadAppScannerService({
    Duration timeout = const Duration(seconds: 30),
    List<String> blockedKeywords = defaultBlockedKeywords,
  })  : _timeout = timeout,
        _blockedKeywords = blockedKeywords;

  static const defaultBlockedKeywords = [
    'yandex',
    'яндекс',
    'alice',
    'алиса',
    'alisa',
    'vkontakte',
    'вконтакте',
    'vk messenger',
    'vk music',
    'vk video',
    'vkvideo',
    'mail.ru',
    'mailru',
    'mytracker',
    'odnoklassniki',
    'одноклассники',
    'ok.ru',
    'max messenger',
    'max.ru',
    't-bank',
    'tbank',
    'tinkoff',
    'тинькофф',
    'т-банк',
    'sber',
    'сбер',
    'sberbank',
    'сбербанк',
    'vtb',
    'втб',
    'alfa-bank',
    'alfabank',
    'альфа-банк',
    'альфабанк',
    'megamarket',
    'мегамаркет',
    'samokat',
    'самокат',
    'avito',
    'авито',
    'ozon',
    'озон',
    'wildberries',
    'вайлдберриз',
    'rutube',
    'рутуб',
    '2gis',
    '2гис',
    'kinopoisk',
    'кинопоиск'
  ];

  final Duration _timeout;
  final List<String> _blockedKeywords;

  Future<List<BadAppFinding>> scan() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Bad app scanner is available on Windows only.');
    }

    final keywords = _normalizeKeywords(_blockedKeywords);
    if (keywords.isEmpty) {
      return const [];
    }

    final output = await _runPowerShell(_buildPowerShellScript(keywords));
    final findings = parseFindingsPayload(output.stdout);
    return _dedupeFindings(findings);
  }

  static List<BadAppFinding> parseFindingsPayload(String raw) {
    return parseFindingsJson(_decodeFindingsPayload(raw));
  }

  static List<BadAppFinding> parseFindingsJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
          'Bad app scanner JSON root must be an object.');
    }

    final rawFindings = decoded['findings'];
    if (rawFindings is! Iterable) {
      return const [];
    }

    return _dedupeFindings([
      for (final item in rawFindings)
        if (item is Map)
          BadAppFinding.fromJson(Map<String, Object?>.from(item)),
    ]);
  }

  Future<_ScannerOutput> _runPowerShell(String script) async {
    final process = await Process.start(
      _powershellExecutable(),
      [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-EncodedCommand',
        _encodePowerShellCommand(script),
      ],
      mode: ProcessStartMode.normal,
    );
    final stdout = _collectBytes(process.stdout);
    final stderr = _collectBytes(process.stderr);

    final exitCode = await process.exitCode.timeout(
      _timeout,
      onTimeout: () {
        process.kill();
        throw TimeoutException('Bad app scanner timed out.', _timeout);
      },
    );
    final output = _ScannerOutput(
      exitCode: exitCode,
      stdout: _decodeProcessBytes(await stdout),
      stderr: _decodeProcessBytes(await stderr),
    );

    if (output.exitCode != 0) {
      final details = output.stderr.trim().isEmpty
          ? output.stdout.trim()
          : output.stderr.trim();
      throw StateError(
        'Bad app scanner failed with exit code ${output.exitCode}: $details',
      );
    }
    return output;
  }

  static List<String> _normalizeKeywords(Iterable<String> values) {
    final seen = <String>{};
    final keywords = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !seen.add(trimmed.toLowerCase())) {
        continue;
      }
      keywords.add(trimmed);
    }
    return keywords;
  }

  static String _decodeFindingsPayload(String raw) {
    final trimmed = raw.replaceAll('\u0000', '').trim();
    if (trimmed.isEmpty || trimmed.startsWith('{')) {
      return trimmed;
    }

    try {
      return utf8.decode(base64Decode(trimmed));
    } on FormatException {
      return trimmed;
    }
  }

  static Future<List<int>> _collectBytes(Stream<List<int>> stream) {
    return stream.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
  }

  static String _decodeProcessBytes(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      try {
        return systemEncoding.decode(bytes);
      } on FormatException {
        return latin1.decode(bytes, allowInvalid: true);
      }
    }
  }

  static String _encodePowerShellCommand(String script) {
    final bytes = <int>[];
    for (final codeUnit in script.codeUnits) {
      bytes
        ..add(codeUnit & 0xFF)
        ..add(codeUnit >> 8);
    }
    return base64Encode(bytes);
  }

  static String _powershellExecutable() {
    final systemRoot = Platform.environment['SystemRoot'] ??
        Platform.environment['WINDIR'] ??
        r'C:\Windows';
    final bundledPath = '$systemRoot\\System32\\WindowsPowerShell\\v1.0'
        r'\powershell.exe';
    if (File(bundledPath).existsSync()) {
      return bundledPath;
    }
    return 'powershell.exe';
  }

  static List<BadAppFinding> _dedupeFindings(
    Iterable<BadAppFinding> findings,
  ) {
    final seen = <String>{};
    final unique = <BadAppFinding>[];
    for (final finding in findings) {
      if (seen.add(finding.dedupeKey)) {
        unique.add(finding);
      }
    }
    return unique;
  }

  static String _buildPowerShellScript(List<String> keywords) {
    final keywordJsonBase64 = base64Encode(utf8.encode(jsonEncode(keywords)));
    return r'''
$ErrorActionPreference = 'SilentlyContinue'
$utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$keywordJsonBase64 = '''
        "'$keywordJsonBase64'\r\n"
        r'''
$keywordJson = $utf8.GetString([Convert]::FromBase64String($keywordJsonBase64))
$decodedKeywords = ConvertFrom-Json -InputObject $keywordJson
$keywords = @(foreach ($keyword in $decodedKeywords) { [string]$keyword })
$escaped = @($keywords | ForEach-Object { [regex]::Escape([string]$_) })
$rx = $escaped -join '|'
$findings = New-Object System.Collections.Generic.List[object]
$scanRoots = New-Object System.Collections.Generic.List[string]
$scanRootSeen = New-Object 'System.Collections.Generic.HashSet[string]'

function Normalize-Text {
  param([object]$Value)
  if ($null -eq $Value) { return '' }
  return ([string]$Value).Trim()
}

function Get-KeywordMatches {
  param([object[]]$Values)

  $keywordMatches = New-Object System.Collections.Generic.List[string]
  foreach ($value in $Values) {
    $text = Normalize-Text $value
    if ($text.Length -eq 0) { continue }

    foreach ($match in [regex]::Matches(
      $text,
      $rx,
      [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )) {
      $keywordMatches.Add($match.Value.ToLowerInvariant()) | Out-Null
    }
  }

  return @($keywordMatches | Sort-Object -Unique)
}

function Add-Finding {
  param(
    [string]$Category,
    [object]$Name,
    [object]$Path,
    [object]$Publisher,
    [object]$Version,
    [object]$Status,
    [object]$State
  )

  $matchedKeywords = @(Get-KeywordMatches -Values @(
    $Name,
    $Path,
    $Publisher,
    $Version,
    $Status,
    $State
  ))
  if ($matchedKeywords.Count -eq 0) { return }

  $findings.Add([PSCustomObject]@{
    category = $Category
    name = Normalize-Text $Name
    path = Normalize-Text $Path
    publisher = Normalize-Text $Publisher
    version = Normalize-Text $Version
    status = Normalize-Text $Status
    state = Normalize-Text $State
    matchedKeywords = @($matchedKeywords)
  }) | Out-Null
}

function Add-ScanRoot {
  param([object]$Path)

  $text = Normalize-Text $Path
  if ($text.Length -eq 0) { return }

  $text = $text.Trim('"')
  if ($text.Length -eq 0) { return }

  if (Test-Path -LiteralPath $text -PathType Leaf) {
    Add-ExecutableFile -FilePath $text
    $text = Split-Path -LiteralPath $text -Parent
  }

  if (-not (Test-Path -LiteralPath $text -PathType Container)) { return }

  try {
    $fullPath = (Get-Item -LiteralPath $text -ErrorAction SilentlyContinue).FullName
    if ((Normalize-Text $fullPath).Length -eq 0) { return }
    $key = $fullPath.ToLowerInvariant()
    if ($scanRootSeen.Add($key)) {
      $scanRoots.Add($fullPath) | Out-Null
    }
  } catch {}
}

function Resolve-DisplayIconExecutable {
  param([object]$Value)

  $text = Normalize-Text $Value
  if ($text.Length -eq 0) { return '' }

  $quotedMatch = [regex]::Match($text, '"([^"]+\.exe)"')
  if ($quotedMatch.Success) { return $quotedMatch.Groups[1].Value }

  $pathMatch = [regex]::Match($text, '([A-Za-z]:\\[^,"<>|]+?\.exe)')
  if ($pathMatch.Success) { return $pathMatch.Groups[1].Value }

  return ''
}

function Add-ExecutableFile {
  param([object]$FilePath)

  $text = Normalize-Text $FilePath
  if ($text.Length -eq 0) { return }

  try {
    $file = if ($FilePath -is [System.IO.FileInfo]) {
      $FilePath
    } else {
      Get-Item -LiteralPath $text -ErrorAction SilentlyContinue
    }

    if ($null -eq $file -or $file.PSIsContainer) { return }
    if ($file.Extension -ine '.exe') { return }

    $versionInfo = $file.VersionInfo
    $version = Normalize-Text $versionInfo.ProductVersion
    if ($version.Length -eq 0) {
      $version = Normalize-Text $versionInfo.FileVersion
    }

    Add-Finding `
      -Category 'executable_file' `
      -Name $file.Name `
      -Path $file.FullName `
      -Publisher $versionInfo.CompanyName `
      -Version $version `
      -Status '' `
      -State ''
  } catch {}
}

function Scan-ExecutableRoot {
  param(
    [string]$Root,
    [int]$MaxDepth = 3,
    [int]$MaxFiles = 120
  )

  if ((Normalize-Text $Root).Length -eq 0) { return }
  if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return }

  Get-ChildItem `
      -LiteralPath $Root `
      -Filter '*.exe' `
      -File `
      -Recurse `
      -Depth $MaxDepth `
      -ErrorAction SilentlyContinue |
    Select-Object -First $MaxFiles |
    ForEach-Object { Add-ExecutableFile -FilePath $_ }
}

function Add-KeywordChildRoots {
  param(
    [object]$Root,
    [int]$MaxDepth = 2,
    [int]$MaxRoots = 40
  )

  $text = Normalize-Text $Root
  if ($text.Length -eq 0) { return }
  if (-not (Test-Path -LiteralPath $text -PathType Container)) { return }

  Get-ChildItem `
      -LiteralPath $text `
      -Directory `
      -Recurse `
      -Depth $MaxDepth `
      -ErrorAction SilentlyContinue |
    Where-Object { @(Get-KeywordMatches -Values @($_.FullName)).Count -gt 0 } |
    Select-Object -First $MaxRoots |
    ForEach-Object { Add-ScanRoot $_.FullName }
}

$uninstallRoots = @(
  'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$installedPrograms = @(Get-ItemProperty -Path $uninstallRoots -ErrorAction SilentlyContinue)
foreach ($program in $installedPrograms) {
  $programMatches = @(Get-KeywordMatches -Values @(
    $program.DisplayName,
    $program.InstallLocation,
    $program.Publisher,
    $program.DisplayVersion
  )).Count -gt 0

  Add-Finding `
    -Category 'installed_program' `
    -Name $program.DisplayName `
    -Path $program.InstallLocation `
    -Publisher $program.Publisher `
    -Version $program.DisplayVersion `
    -Status '' `
    -State ''

  if ($programMatches) {
    Add-ScanRoot $program.InstallLocation
  }

  $displayIconExe = Resolve-DisplayIconExecutable $program.DisplayIcon
  if ($displayIconExe.Length -gt 0) {
    Add-ExecutableFile -FilePath $displayIconExe
    if ($programMatches -or @(Get-KeywordMatches -Values @($displayIconExe)).Count -gt 0) {
      Add-ScanRoot (Split-Path -LiteralPath $displayIconExe -Parent)
    }
  }
}

foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
  Add-KeywordChildRoots $root
}

foreach ($baseRoot in @($env:LOCALAPPDATA, $env:APPDATA)) {
  if ((Normalize-Text $baseRoot).Length -eq 0) { continue }
  $programsRoot = Join-Path $baseRoot 'Programs'
  Add-KeywordChildRoots $programsRoot

  foreach ($keyword in $keywords) {
    Add-ScanRoot (Join-Path $baseRoot $keyword)
  }
}

foreach ($root in @($scanRoots | Select-Object -First 80)) {
  Scan-ExecutableRoot -Root $root
}

Get-Service -ErrorAction SilentlyContinue |
  ForEach-Object {
    Add-Finding `
      -Category 'service' `
      -Name $_.DisplayName `
      -Path $_.Name `
      -Publisher '' `
      -Version '' `
      -Status $_.Status `
      -State ''
  }

if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
  Get-ScheduledTask -ErrorAction SilentlyContinue |
    ForEach-Object {
      Add-Finding `
        -Category 'scheduled_task' `
        -Name $_.TaskName `
        -Path $_.TaskPath `
        -Publisher '' `
        -Version '' `
        -Status '' `
        -State $_.State
    }
}

$json = [PSCustomObject]@{
  findings = @($findings | Sort-Object category, name, path, publisher -Unique)
} | ConvertTo-Json -Depth 5 -Compress
[Console]::Out.Write([Convert]::ToBase64String($utf8.GetBytes($json)))
''';
  }
}

class _ScannerOutput {
  const _ScannerOutput({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}
