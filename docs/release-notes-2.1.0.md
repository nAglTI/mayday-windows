# Mayday for Windows 2.1.0

## What's New

- Added import by Mayday access key as the only supported import flow.
- Added read-only display for the imported user/configuration ID so profile identity cannot be edited manually.
- Added support for the current Mayday runtime configuration contract, including per-transport relay ports, probe settings, network rescue, packet fragmentation, and packet batching options.
- Added advanced network settings for transport mode, network rescue mode, MTU, packet fragmentation size, and packet batching.
- Replaced the transport mode selector with a dropdown so longer transport names fit better in the interface.
- Simplified the main screen so everyday users see the connection status and imported ID first, with technical details moved into expandable advanced sections.
- Added background checks for risky installed apps, executable files, services, and scheduled tasks.
- Added a pre-connect risk dialog when the app check has not passed cleanly, with actions to accept the risk or run the check.
- Added saved app-check results that can be reopened later.
- Added full path display and copy support in the app-check results dialog.
- Added GitHub Releases update checking with a small update banner when a newer version is available.
- Added tray icons that adapt to the Windows light or dark taskbar theme.

## Fixes

- Improved handling of incompatible saved profiles by asking the user to import a fresh access key.
- Improved import validation for the new runtime configuration format.
- Improved the connection flow so app-check warnings are explained before connection instead of silently blocking the user.
- Improved visibility of advanced connection details by moving protocol, core state, and similar technical fields away from the primary status area.
- Improved tray icon sizing and theme behavior for better visibility on Windows.
- Improved Windows runtime naming so user-facing helper processes use Mayday-specific names.
- Improved release and installer build scripts so app versions are read consistently from `pubspec.yaml`.

## Compatibility

- Supports Windows 10 and Windows 11 on 64-bit PCs.
- Requires a current Mayday access key for this runtime configuration contract.
- Older saved profiles may need to be replaced by importing a fresh access key.
- Requires the permissions requested by the app for connection control.
- Autostart opens Mayday after sign-in, but does not start a connection automatically.

---

# Mayday для Windows 2.1.0

## Что нового

- Добавлен импорт только через ключ доступа Mayday.
- Добавлено отображение импортированного ID пользователя/конфигурации только для чтения, чтобы идентификатор профиля нельзя было изменить вручную.
- Добавлена поддержка текущего контракта конфигурации Mayday runtime, включая порты реле по транспортам, настройки probe, network rescue, packet fragmentation и packet batching.
- Добавлены расширенные сетевые настройки: режим транспорта, network rescue, MTU, размер packet fragmentation и packet batching.
- Выбор режима транспорта заменен на выпадающий список, чтобы длинные названия транспортов лучше помещались в интерфейсе.
- Упрощен главный экран: обычный пользователь сначала видит статус подключения и импортированный ID, а технические детали вынесены в раскрываемые advanced-разделы.
- Добавлена фоновая проверка рискованных установленных приложений, exe-файлов, служб и запланированных задач.
- Добавлен диалог перед подключением, если проверка приложений не была успешно пройдена, с действиями принять риск или запустить проверку.
- Добавлено сохранение результатов проверки приложений, чтобы их можно было открыть повторно.
- Добавлены отображение полного пути и копирование пути в диалоге результатов проверки.
- Добавлена проверка обновлений через GitHub Releases с небольшим баннером при наличии новой версии.
- Добавлены иконки трея, которые подстраиваются под светлую или темную тему панели задач Windows.

## Исправления

- Улучшена обработка несовместимых сохраненных профилей: приложение просит импортировать свежий ключ доступа.
- Улучшена проверка импорта для нового формата конфигурации runtime.
- Улучшен сценарий подключения: предупреждения проверки приложений объясняются пользователю до подключения, а не блокируют действие молча.
- Улучшена читаемость главного экрана: protocol, core state и похожие технические поля убраны из основной области статуса.
- Улучшены размер и поведение иконок трея для лучшей видимости в Windows.
- Улучшены имена Windows runtime-файлов, чтобы пользовательские helper-процессы использовали названия Mayday.
- Улучшены скрипты релизной сборки и установщика: версия приложения читается из `pubspec.yaml` единообразно.

## Совместимость

- Поддерживаются Windows 10 и Windows 11 на 64-битных ПК.
- Для этой версии нужен актуальный ключ доступа Mayday под текущий контракт конфигурации runtime.
- Старые сохраненные профили может потребоваться заменить, импортировав свежий ключ доступа.
- Для управления подключением нужны права, которые запрашивает приложение.
- Автозапуск открывает Mayday после входа в Windows, но не включает подключение автоматически.
