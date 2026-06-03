# Mayday for Windows

[Русская версия](README.ru.md)

Mayday for Windows is a Flutter desktop application for managing a Mayday secure connection from a simple Windows interface. It focuses on everyday use: import your access key, connect or disconnect when needed, and keep the app available from the system tray.

This README describes the application at a product level and intentionally avoids internal connection details.

## Features

- One-click connect and disconnect flow.
- Windows system tray integration with connected and disconnected icons that adapt to the Windows light or dark taskbar theme.
- Close-to-tray behavior, with **Show Mayday** and **Exit** actions in the tray menu.
- Single-instance behavior: launching Mayday again brings the existing window forward.
- Import by access key only.
- Read-only imported user/configuration ID; the user cannot edit the profile identity manually.
- Local app settings with Russian and English UI language support.
- Optional Windows autostart for opening the app after sign-in.
- App selection controls for split routing.
- Background app-risk scanning with saved results and a pre-connect risk dialog.
- Advanced network controls for transport mode, network rescue mode, MTU, packet fragmentation, and packet batching.
- GitHub Releases update check with a dismissible update banner.
- Diagnostics screen for user-facing readiness and file availability checks.
- Administrator gate with a guided restart flow when elevated permissions are required.

## App Flow

Open Mayday, import the access key issued for your account, and press **Connect**. The main screen shows the current connection state and the imported user/configuration ID. Technical details are kept in expandable sections so the normal screen stays focused.

Mayday checks for risky installed apps, executable files, services, and scheduled tasks in the background when a new app session starts. If the check has not passed cleanly, connecting opens a dialog that explains the risk and offers two choices: accept the possible consequences and connect, or run the scan. Scan results can be reopened later, including full paths that can be selected or copied.

When the connection is active, the tray icon changes to the connected variant. Closing the window keeps Mayday running in the tray. Use the tray menu to show the window again or exit the app. Exiting through the tray asks the Flutter layer to stop the active connection before the native Windows runner closes the application.

If Mayday detects that a saved profile was created for an older runtime contract, it asks the user to import a fresh access key instead of using the old profile silently.

## Settings

The settings area groups the controls a user is expected to adjust:

- App launch behavior.
- Imported profile identity, shown read-only.
- Transport mode and advanced network protection options.
- Split routing Windows application selection.
- Diagnostics and readiness information.
- Language selection.

Most users should only need the import controls, the main connect button, and the tray menu.

## Release Notes

See [docs/release-notes-2.1.0.md](docs/release-notes-2.1.0.md) for the current release notes.

## Flutter Layer

Mayday is organized as a small layered Flutter desktop app:

```text
lib/
  main.dart                 app entry point
  app/                      theme, language state, top-level wiring
  core/
    models/                 UI-facing data models
    services/               local storage, platform bridges, pickers
    l10n/                   built-in Russian and English text
  features/home/
    application/            screen-level coordination
    presentation/           view model, pages, and widgets
windows/                    native Windows runner and tray integration
```

The Flutter layer owns the user interface, screen state, localization, import flow, local app preferences, and connection controls. The native Windows runner handles desktop integration such as tray behavior, single-instance activation, and window lifecycle.

## Privacy And Local Data

Mayday stores app data locally for the current Windows user. Sensitive user data is protected at rest using Windows user-scoped protection where applicable. The README does not document internal data formats or connection internals.

## Troubleshooting

If Mayday does not connect:

- Make sure the app is running with the permissions it requested.
- Reopen the existing Mayday window from the tray or Start menu.
- Re-import your access key if the app says the saved profile is incompatible or setup is incomplete.
- Run the app-risk scan and review the result dialog if Mayday warns before connecting.

Autostart opens the application after Windows sign-in. It does not automatically start a connection.
