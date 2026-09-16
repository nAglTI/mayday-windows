# Mayday for Windows 2.1.5

## What's New

- Updated the bundled core and control utility.
- Core diagnostics now report the core's own version separately from the app version.
- Updated compatibility with the current transport catalog: legacy Raw UDP v1 is no longer offered for new configurations.
- Added named packet padding modes: Off, Minimal, and Extreme. Existing custom ranges are preserved.
- Added Auto Low CPU and Raw UDP v2 transport choices.

## Fixes And Compatibility

- Importing a replacement access key preserves the current split routing mode and app lists, including unsaved changes.
- Existing routing rules are retained when replacing an access key, including saved profiles that need to move away from Raw UDP v1.
- The core now applies app routing rules to IPv6. IPv6 traffic selected for direct routing is blocked; direct IPv4 remains available. IPv6-only resources are unavailable for those apps.
- The background quick-probe field is retained for compatibility and shown as inactive because it does not enable periodic probing in this core.
- Discovery only connects to relays explicitly included in the issued profile.

---

# Mayday для Windows 2.1.5

## Что нового

- Ядро и управляющая утилита обновлены.
- В диагностике отображается собственная версия ядра отдельно от версии приложения.
- Учтён актуальный набор транспортов: старый Raw UDP v1 больше не предлагается для новых конфигураций.
- Добавлены режимы padding: «Отключено», «Минимальный» и «Экстремальный». Существующие пользовательские диапазоны сохраняются.
- Добавлен выбор транспортов Auto Low CPU и Raw UDP v2.

## Исправления и совместимость

- При замене ключа доступа сохраняются текущий режим раздельной маршрутизации и списки приложений, включая несохранённые изменения.
- Правила маршрутизации сохраняются при замене ключа, в том числе при переходе с сохранённого профиля Raw UDP v1.
- Ядро применяет правила маршрутизации приложений к IPv6. IPv6-трафик, направленный в обход VPN, блокируется; прямой IPv4 остаётся доступен. Ресурсы только с IPv6 у таких приложений недоступны.
- Поле быстрой фоновой проверки сохраняется для совместимости и отображается неактивным: в этом ядре оно не включает периодическую проверку.
- Discovery подключается только к релеям, явно указанным в выданном профиле.
