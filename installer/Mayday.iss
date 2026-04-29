#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif

#ifndef FlutterReleaseDir
  #error FlutterReleaseDir define is required
#endif

#ifndef AppExeName
  #define AppExeName "mayday_windows.exe"
#endif

#define AppName "Mayday"
#define AppPublisher "Mayday"

[Setup]
AppId={{E4EF9F3D-B8BA-4AF7-B8D1-3F8EA5D5A101}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
OutputDir=dist\installer
OutputBaseFilename=mayday-{#AppVersion}-setup
UninstallDisplayIcon={app}\{#AppExeName}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#FlutterReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent runascurrentuser

[UninstallRun]
Filename: "{sys}\schtasks.exe"; Parameters: "/Delete /F /TN ""Mayday"""; Flags: runhidden; RunOnceId: "delete-mayday-autostart-task"
