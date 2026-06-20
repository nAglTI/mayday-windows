# Mayday for Windows 2.1.1

## What's New

- Bundled the refreshed runtime `2.0.3`.
- Added full client-profile support for packet padding fields: `packet_padding_min_bytes` and `packet_padding_max_bytes`.
- Added advanced packet padding controls with Off, Light, and Strong presets.
- Added realtime connection analytics in advanced diagnostics, including active relay, active protocol, server, speeds, protocol details, and endpoint details.

## Fixes

- Improved profile import and save behavior so packet padding values are preserved instead of being reset.
- Improved validation for packet padding ranges according to the current runtime contract.
- Improved advanced diagnostics so protocol and exit information comes from live runtime status instead of only the selected profile settings.
- Improved release documentation so the Windows app version and bundled runtime version are documented separately.

## Compatibility

- Supports Windows 10 and Windows 11 on 64-bit PCs.
- Bundles Mayday client runtime `2.0.3`.
- Requires a current Mayday access key for the current runtime configuration contract.
- Older saved profiles may need to be replaced by importing a fresh access key.
- Autostart opens Mayday after sign-in, but does not start a connection automatically.

---

# Mayday для Windows 2.1.1

## Что нового

- В сборку включен обновленный runtime `2.0.3`.
- Добавлена полная поддержка полей packet padding в клиентском профиле: `packet_padding_min_bytes` и `packet_padding_max_bytes`.
- Добавлены расширенные настройки packet padding с пресетами Off, Light и Strong.
- Добавлена realtime-аналитика подключения в расширенной диагностике: активное реле, активный протокол, server, скорости, детали протоколов и точки подключения.

## Исправления

- Улучшено поведение импорта и сохранения профиля: значения packet padding теперь сохраняются, а не сбрасываются.
- Улучшена валидация диапазонов packet padding согласно текущему контракту runtime.
- Улучшена расширенная диагностика: protocol и exit теперь берутся из live runtime status, а не только из выбранных настроек профиля.
- Улучшена релизная документация: версия Windows-приложения и версия встроенного runtime описаны отдельно.

## Совместимость

- Поддерживаются Windows 10 и Windows 11 на 64-битных ПК.
- Включает Mayday client runtime `2.0.3`.
- Для текущего контракта конфигурации runtime нужен актуальный ключ доступа Mayday.
- Старые сохраненные профили может потребоваться заменить, импортировав свежий ключ доступа.
- Автозапуск открывает Mayday после входа в Windows, но не включает подключение автоматически.
