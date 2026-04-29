# Mayday for Windows

[Русская версия](README.ru.md)

Mayday for Windows is a Flutter desktop application for managing a Mayday secure connection from a simple Windows interface. It focuses on everyday use: import your access data, connect or disconnect when needed, and keep the app available from the system tray.

This README describes the application at a product level and intentionally avoids internal connection details.

## Features

- One-click connect and disconnect flow.
- Windows system tray integration with separate connected and disconnected icons.
- Close-to-tray behavior, with **Show Mayday** and **Exit** actions in the tray menu.
- Single-instance behavior: launching Mayday again brings the existing window forward.
- Import by file or import key.
- Local app settings with Russian and English UI language support.
- Optional Windows autostart for opening the app after sign-in.
- App selection controls for choosing which Windows applications participate in the connection.
- Diagnostics screen for user-facing readiness and file availability checks.
- Administrator gate with a guided restart flow when elevated permissions are required.

## App Flow

Open Mayday, import the access data issued for your account, and press **Connect**. The main screen shows the current connection state and provides the primary action button. When the connection is active, the tray icon changes to the connected variant.

Closing the window keeps Mayday running in the tray. Use the tray menu to show the window again or exit the app. Exiting through the tray asks the Flutter layer to stop the active connection before the native Windows runner closes the application.

## Settings

The settings area groups the controls a user is expected to adjust:

- App launch behavior.
- Imported profile identity.
- Connection preferences exposed by the UI.
- Windows application selection.
- Diagnostics and readiness information.
- Language selection.

Most users should only need the import controls, the main connect button, and the tray menu.

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
- Re-import your access data if the app says setup is incomplete.

Autostart opens the application after Windows sign-in. It does not automatically start a connection.
