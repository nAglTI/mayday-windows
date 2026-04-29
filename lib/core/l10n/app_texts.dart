import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../services/runtime_paths_service.dart';

enum AppLanguage { english, russian }

extension AppLanguageLabel on AppLanguage {
  String get storageValue => switch (this) {
        AppLanguage.english => 'en',
        AppLanguage.russian => 'ru',
      };

  String get nativeName => switch (this) {
        AppLanguage.english => 'English',
        AppLanguage.russian => 'Русский',
      };

  static AppLanguage fromStorageValue(String value) {
    switch (value.toLowerCase()) {
      case 'en':
      case 'eng':
      case 'english':
        return AppLanguage.english;
      case 'ru':
      case 'рус':
      case 'russian':
        return AppLanguage.russian;
      default:
        return AppLanguage.russian;
    }
  }
}

class AppTextCatalog {
  const AppTextCatalog(this.language);

  final AppLanguage language;

  static const Map<AppLanguage, Map<String, String>> _values = {
    AppLanguage.russian: {
      'app.title': 'Mayday',
      'app.title_short': 'mayday',
      'app.network_client': 'сетевой клиент',
      'button.cancel': 'Отмена',
      'button.connect': 'Подключиться',
      'button.stop': 'Отключить',
      'button.import': 'Импорт',
      'button.restart_as_admin': 'Перезапустить как администратор',
      'button.import_config': 'Импорт конфига',
      'button.import_key': 'Импорт ключа',
      'button.save_config': 'Сохранить',
      'button.save_settings': 'Сохранить настройки',
      'button.reload': 'Обновить',
      'button.choose_exe': 'Выбрать EXE',
      'button.running_app': 'Из запущенных',
      'button.open_settings': 'Открыть настройки',
      'menu.search': 'Поиск',
      'language.label': 'Язык',
      'language.english': 'Английский',
      'language.russian': 'Русский',
      'nav.connection': 'Подключение',
      'nav.settings': 'Настройки',
      'status.working': 'работает',
      'status.connected': 'подключено',
      'status.loading': 'загрузка',
      'status.importing': 'импорт',
      'status.saving': 'сохранение',
      'status.connecting': 'подключение',
      'status.stopping': 'остановка',
      'status.loading_apps': 'загрузка приложений',
      'status.idle': 'простой',
      'status.ready': 'готово',
      'status.missing': 'отсутствует',
      'status.not_set': 'не задано',
      'status.disconnected': 'не подключено',
      'status.launch_error': 'ошибка запуска',
      'status.runtime_started': 'запущен',
      'message.bootstrap_failed': 'Ошибка инициализации: {error}',
      'message.runtime_available': 'Файлы runtime доступны.',
      'message.runtime_incomplete':
          'Не все файлы среды выполнения найдены. Проверьте диагностику.',
      'message.import_cancelled': 'Импорт отменен.',
      'message.imported_file': 'Импортировано: {file}.',
      'message.imported_from_key': 'Конфиг импортирован из ключа.',
      'message.import_failed': 'Не удалось выполнить импорт: {error}',
      'message.import_key_failed': 'Не удалось импортировать ключ: {error}',
      'message.config_saved': 'Конфиг сохранен в {path}',
      'message.save_failed': 'Не удалось сохранить: {error}',
      'message.autostart_enabled': 'Автозапуск приложения включен.',
      'message.autostart_disabled': 'Автозапуск приложения выключен.',
      'message.autostart_apply_failed':
          'Не удалось применить автозапуск: {error}',
      'message.autostart_save_failed':
          'Не удалось изменить автозапуск: {error}',
      'message.launch_failed': 'Не удалось запустить: {error}',
      'message.stop_failed': 'Не удалось остановить: {error}',
      'message.app_picker_failed': 'Ошибка выбора приложения: {error}',
      'message.running_list_failed':
          'Не удалось получить список приложений: {error}',
      'message.added_split_app':
          'Добавлено в список раздельной маршрутизации: {app}',
      'message.pid_suffix': ' PID: {pid}.',
      'home.primary': 'Основной',
      'home.mayday': 'mayday',
      'home.tooltip.import_config': 'Импорт конфигурации',
      'home.tooltip.import_key': 'Импорт ключа',
      'home.tooltip.reload': 'Обновить',
      'home.preview_unavailable':
          '# Предпросмотр недоступен, пока профиль невалиден.\n# {error}',
      'home.endpoint_relay_not_configured': 'Реле не настроено',
      'home.config_ready': 'Конфигурация готова',
      'home.config_not_ready': 'Импортируйте ключ или конфиг в настройках',
      'home.runtime_not_ready': 'Файлы runtime не найдены',
      'section.diagnostics': 'диагностика',
      'section.application': 'приложение',
      'section.profile': 'профиль',
      'section.transport': 'транспорт',
      'section.network_transport': 'транспорт и dns',
      'section.metrics': 'метрики',
      'section.relays': 'реле',
      'section.servers': 'серверы',
      'section.split_routing': 'раздельная маршрутизация',
      'section.generated_preview': 'сгенерированный client.yaml',
      'section.config': 'конфиг',
      'section.imported': 'импортировано',
      'label.status': 'статус',
      'label.engine': 'движок',
      'label.autostart_app': 'Запускать Mayday при входе в Windows',
      'label.autostart_app_helper':
          'Приложение откроется само, но VPN не будет подключаться автоматически.',
      'label.user_id': 'user_id',
      'label.relays': 'реле',
      'label.servers': 'серверы',
      'label.server': 'сервер',
      'label.config': 'конфиг',
      'label.profile': 'профиль',
      'label.tun_name': 'tun',
      'label.dns': 'dns',
      'label.mode': 'режим',
      'label.transport_mode': 'режим транспорта',
      'label.transport_auto': 'авто',
      'label.transport_tcp': 'tcp',
      'label.transport_utp': 'utp',
      'label.failback_delay': 'задержка возврата',
      'label.failback_delay_helper':
          '-1 отключает автовозврат, 0 включает дефолт 60 секунд.',
      'label.metrics_enabled': 'Включить метрики',
      'label.metrics_window': 'Окно метрик, секунд',
      'label.metrics_window_helper':
          'Используется для in-memory окна и ротации файлов.',
      'label.metrics_file_enabled': 'Писать метрики в файл',
      'label.metrics_file_dir': 'Директория метрик',
      'label.metrics_file_dir_helper':
          'Это директория, например ./metrics. Пусто — рядом с vpnclient.exe.',
      'label.metrics_dir': 'директория метрик',
      'label.priority': 'приоритет',
      'label.all_traffic': 'весь трафик',
      'label.only_selected': 'только выбранные',
      'label.except': 'исключить',
      'label.one_relay_per_line': 'по одной строке на реле',
      'label.dns_helper': 'Через запятую. Например: 1.1.1.1, 8.8.8.8',
      'label.relay_format': 'Формат: id|addr|short_id|ports через запятую',
      'label.config_filter': 'Файлы конфигурации',
      'label.config_files_filter': '*.yaml;*.yml;*.json',
      'label.executable_filter': 'Исполняемые файлы',
      'label.exe_files_filter': '*.exe',
      'label.all_files_filter': 'Все файлы|*.*',
      'title.app_key_dialog': 'Импортировать ключ',
      'title.running_apps': 'Запущенные приложения',
      'title.section_relays_none': 'Реле не импортированы.',
      'title.section_servers_none': 'Серверы не импортированы.',
      'title.relay_item': 'реле {index}',
      'title.server_item': 'сервер {index}',
      'title.missing_runtime_files': 'Отсутствующие файлы runtime',
      'title.no_files_with_paths':
          'Не найдено приложений с путями исполняемых файлов.',
      'title.no_apps_found': 'Приложения не найдены.',
      'title.split_disabled_hint':
          'Раздельная маршрутизация отключена. Вы можете подготовить список приложений.',
      'title.split_empty_hint':
          'Добавьте хотя бы одно Windows-приложение для выбранного режима.',
      'tooltip.remove': 'Удалить',
      'tooltip.move': 'Переместить',
      'tooltip.expand_section': 'Развернуть раздел',
      'tooltip.collapse_section': 'Свернуть раздел',
      'admin.required_title': 'Нужны права администратора',
      'admin.description1':
          'Mayday должен запускаться с правами администратора, потому что Windows network runtime использует привилегированные сетевые компоненты, такие как WinDivert и Wintun.',
      'admin.description2':
          'Если UAC не перезапустил приложение автоматически, нажмите кнопку ниже.',
      'admin.started_message':
          'Запущен новый экземпляр с повышенными правами. Закройте это окно.',
      'admin.failed_message':
          'Перезапуск с правами администратора был отменен или завершился ошибкой.',
      'admin.restart_unsupported':
          'Перезапуск с правами администратора поддерживается только в Windows.',
      'admin.restart_failed':
          'Не удалось перезапустить от администратора: {error}',
      'admin.relaunch_cancelled_or_failed':
          'Перезапуск с правами администратора был отменен или не выполнен.',
      'admin.elevated_process_not_created':
          'Не удалось создать процесс с повышенными правами.',
      'error.admin_required':
          'Для работы приложения требуются права администратора.',
      'error.config_picker_unsupported':
          'Просмотрщик файлов конфигурации доступен только в Windows.',
      'error.executable_picker_unsupported':
          'Просмотрщик исполняемых файлов доступен только в Windows.',
      'error.file_picker_failed':
          'Не удалось открыть диалог выбора конфигурации: {error}',
      'error.executable_picker_failed':
          'Не удалось открыть диалог выбора EXE: {error}',
      'error.import_key_empty':
          'Вставленный ключ пуст или содержит только пробелы.',
      'error.running_list_unsupported':
          'Получение списка запущенных приложений доступно только в Windows.',
      'error.running_list_failed':
          'Не удалось получить список запущенных приложений: {error}',
      'file.import_key_name': 'Импортированный ключ',
      'file.saved_name': 'Сохраненный конфиг',
      'client.running': 'Сетевой процесс уже запущен.',
      'client.not_running': 'Сетевой процесс не запущен. Логи: {log}',
      'client.not_running_no_log': 'Сетевой процесс не запущен.',
      'client.config_unreadable':
          'Файл конфига недоступен для чтения: {error}\nЛог: {log}',
      'client.config_unreadable_no_log':
          'Файл конфига недоступен для чтения: {error}',
      'client.runtime_missing':
          'Отсутствуют файлы runtime:\n{files}\nЛог: {log}',
      'client.runtime_missing_no_log': 'Отсутствуют файлы runtime:\n{files}',
      'client.config_not_found': 'Файл конфигурации не найден: {configPath}',
      'client.exit_code': 'Код завершения: {code}',
      'client.logs': 'Логи: stdout={stdoutLog}, stderr={stderrLog}',
      'client.access_denied':
          'У приложения не хватило доступа. Запустите Mayday от администратора и примите запрос UAC.',
      'client.started':
          'Сетевой процесс запущен. Логи: {launcherLog} / {stdoutLog} / {stderrLog}.',
      'client.started_no_log': 'Сетевой процесс запущен.',
      'client.terminated_immediately':
          'Сетевой процесс закрылся сразу после запуска.',
      'client.stdout': 'stdout:',
      'client.stderr': 'stderr:',
      'client.started_failed':
          'Не удалось запустить сетевой процесс: {error}\nЛог: {log}',
      'client.started_failed_no_log':
          'Не удалось запустить сетевой процесс: {error}',
      'client.stop_requested': 'Запрошена остановка сетевого процесса.',
      'client.stopped':
          'Сетевой процесс остановлен. Код выхода: {code}. Лог: {log}',
      'client.stopped_no_log':
          'Сетевой процесс остановлен. Код выхода: {code}.',
      'client.stop_timeout':
          'Сетевой процесс не остановился вовремя. Лог: {log}',
      'client.stop_timeout_no_log': 'Сетевой процесс не остановился вовремя.',
      'client.stop_failed':
          'Не удалось остановить сетевой процесс: {error}\nЛог: {log}',
      'client.stop_failed_no_log':
          'Не удалось остановить сетевой процесс: {error}',
      'client.process_exit': 'Сетевой процесс завершился.',
      'codec.empty': 'Файл конфигурации пуст.',
      'codec.json_objects_only': 'Поддерживаются только JSON-объекты.',
      'codec.unsupported_yaml': 'Неподдерживаемая структура YAML.',
      'codec.user_id_non_negative':
          'user_id должен быть целым неотрицательным числом.',
      'codec.user_id_positive':
          'user_id должен быть целым положительным числом.',
      'codec.failback_delay_invalid':
          'server_failback_delay_sec должен быть -1 или больше.',
      'codec.metrics_window_invalid':
          'metrics.window_seconds должен быть положительным числом.',
      'codec.metrics_file_dir_required':
          'metrics.file_dir должен быть указан, если file_enabled=true.',
      'codec.relay_required': 'Должно быть хотя бы одно реле.',
      'codec.relay_addr_required': 'Требуется адрес реле.',
      'codec.relay_short_id_invalid':
          'short_id реле должен быть числом от 1 до 65535.',
      'codec.relay_short_id_unique':
          'short_id должен быть уникальным для каждого реле.',
      'codec.relay_ports_required':
          'У каждого реле должен быть хотя бы один порт.',
      'codec.relay_ports_invalid':
          'ports реле должны быть числами от 1 до 65535.',
      'codec.server_required': 'Должен быть хотя бы один сервер.',
      'codec.server_id_required': 'Требуется ID сервера.',
      'codec.server_key_required': 'Требуется ключ сервера.',
      'codec.server_key_hex':
          'Ключ сервера должен содержать ровно 64 hex-символа.',
      'codec.server_priority_invalid':
          'priority сервера должен быть положительным числом.',
      'codec.split_apps_required':
          'split_tunnel.apps_win должен содержать минимум одно Windows-приложение.',
      'codec.user_id_required': 'Требуется user_id.',
      'codec.user_id_integer':
          'user_id должен быть целым числом (не должно быть пустым).',
      'codec.imported_default_name': 'Импортировано',
    },
    AppLanguage.english: {
      'app.title': 'Mayday',
      'app.title_short': 'mayday',
      'app.network_client': 'network client',
      'button.cancel': 'Cancel',
      'button.connect': 'Connect',
      'button.stop': 'Stop',
      'button.import': 'Import',
      'button.restart_as_admin': 'Restart as administrator',
      'button.import_config': 'Import config',
      'button.import_key': 'Import key',
      'button.save_config': 'Save config',
      'button.save_settings': 'Save settings',
      'button.reload': 'Reload',
      'button.choose_exe': 'Choose EXE',
      'button.running_app': 'Running app',
      'button.open_settings': 'Open settings',
      'menu.search': 'Search',
      'language.label': 'Language',
      'language.english': 'English',
      'language.russian': 'Russian',
      'nav.connection': 'Connection',
      'nav.settings': 'Settings',
      'status.working': 'working',
      'status.connected': 'connected',
      'status.loading': 'loading',
      'status.importing': 'importing',
      'status.saving': 'saving',
      'status.connecting': 'connecting',
      'status.stopping': 'stopping',
      'status.loading_apps': 'loading apps',
      'status.idle': 'idle',
      'status.ready': 'ready',
      'status.missing': 'missing',
      'status.not_set': 'not set',
      'status.disconnected': 'disconnected',
      'status.launch_error': 'launch error',
      'status.runtime_started': 'runtime started',
      'message.bootstrap_failed': 'Bootstrap failed: {error}',
      'message.runtime_available': 'Runtime files are available.',
      'message.runtime_incomplete': 'Runtime is incomplete. Check diagnostics.',
      'message.import_cancelled': 'Import cancelled.',
      'message.imported_file': 'Imported {file}.',
      'message.imported_from_key': 'Imported config from key.',
      'message.import_failed': 'Import failed: {error}',
      'message.import_key_failed': 'Import key failed: {error}',
      'message.config_saved': 'Config saved to {path}',
      'message.save_failed': 'Save failed: {error}',
      'message.autostart_enabled': 'App autostart enabled.',
      'message.autostart_disabled': 'App autostart disabled.',
      'message.autostart_apply_failed': 'Failed to apply autostart: {error}',
      'message.autostart_save_failed': 'Failed to change autostart: {error}',
      'message.launch_failed': 'Launch failed: {error}',
      'message.stop_failed': 'Stop failed: {error}',
      'message.app_picker_failed': 'App picker failed: {error}',
      'message.running_list_failed': 'Running app list failed: {error}',
      'message.added_split_app': 'Added split app: {app}',
      'message.pid_suffix': ' PID: {pid}.',
      'home.primary': 'Primary',
      'home.mayday': 'mayday',
      'home.tooltip.import_config': 'Import config',
      'home.tooltip.import_key': 'Import key',
      'home.tooltip.reload': 'Reload',
      'home.preview_unavailable':
          '# Preview is unavailable until the profile is valid.\n# {error}',
      'home.endpoint_relay_not_configured': 'Relay not configured',
      'home.config_ready': 'Configuration ready',
      'home.config_not_ready': 'Import a key or config in settings',
      'home.runtime_not_ready': 'Runtime files are missing',
      'section.diagnostics': 'diagnostics',
      'section.application': 'application',
      'section.profile': 'profile',
      'section.transport': 'transport',
      'section.network_transport': 'transport and dns',
      'section.metrics': 'metrics',
      'section.relays': 'relays',
      'section.servers': 'servers',
      'section.split_routing': 'split routing',
      'section.generated_preview': 'generated client.yaml',
      'section.config': 'config',
      'section.imported': 'imported',
      'label.status': 'status',
      'label.engine': 'engine',
      'label.autostart_app': 'Start Mayday when signing in to Windows',
      'label.autostart_app_helper':
          'The app opens automatically, but the VPN does not connect automatically.',
      'label.user_id': 'user id',
      'label.relays': 'relays',
      'label.servers': 'servers',
      'label.server': 'server',
      'label.config': 'config',
      'label.profile': 'profile',
      'label.tun_name': 'tun',
      'label.dns': 'dns',
      'label.mode': 'mode',
      'label.transport_mode': 'transport mode',
      'label.transport_auto': 'auto',
      'label.transport_tcp': 'tcp',
      'label.transport_utp': 'utp',
      'label.failback_delay': 'failback delay',
      'label.failback_delay_helper':
          '-1 disables automatic failback, 0 uses the 60-second default.',
      'label.metrics_enabled': 'Enable metrics',
      'label.metrics_window': 'Metrics window, seconds',
      'label.metrics_window_helper':
          'Used for the in-memory window and file rotation.',
      'label.metrics_file_enabled': 'Write metrics file',
      'label.metrics_file_dir': 'Metrics directory',
      'label.metrics_file_dir_helper':
          'A directory, for example ./metrics. Empty means next to vpnclient.exe.',
      'label.metrics_dir': 'metrics directory',
      'label.priority': 'priority',
      'label.all_traffic': 'all traffic',
      'label.only_selected': 'only selected',
      'label.except': 'except',
      'label.one_relay_per_line': 'one relay per line',
      'label.dns_helper': 'Comma-separated, for example: 1.1.1.1, 8.8.8.8',
      'label.relay_format': 'Format: id|addr|short_id|comma-separated ports',
      'label.config_filter': 'Config files',
      'label.config_files_filter': '*.yaml;*.yml;*.json',
      'label.executable_filter': 'Executable files',
      'label.exe_files_filter': '*.exe',
      'label.all_files_filter': 'All files|*.*',
      'title.app_key_dialog': 'import key',
      'title.running_apps': 'running apps',
      'title.section_relays_none': 'No relays imported.',
      'title.section_servers_none': 'No servers imported.',
      'title.relay_item': 'relay {index}',
      'title.server_item': 'server {index}',
      'title.missing_runtime_files': 'missing runtime files',
      'title.no_files_with_paths': 'No running apps with executable paths.',
      'title.no_apps_found': 'No apps found.',
      'title.split_disabled_hint':
          'Split tunneling is disabled. You can still prepare an app list.',
      'title.split_empty_hint':
          'Add at least one Windows app for this split-tunnel mode.',
      'tooltip.remove': 'Remove',
      'tooltip.move': 'Move',
      'tooltip.expand_section': 'Expand section',
      'tooltip.collapse_section': 'Collapse section',
      'admin.required_title': 'Administrator access required',
      'admin.description1':
          'Mayday must run with administrator privileges because the Windows network runtime uses privileged networking components such as WinDivert and Wintun.',
      'admin.description2':
          'If UAC did not restart the app automatically, use the button below.',
      'admin.started_message':
          'A new elevated instance has been started. You can close this window.',
      'admin.failed_message':
          'The administrator restart was cancelled or failed.',
      'admin.restart_unsupported':
          'Administrator restart is only supported on Windows.',
      'admin.restart_failed': 'Failed to restart as administrator: {error}',
      'admin.relaunch_cancelled_or_failed':
          'The administrator restart was cancelled or failed.',
      'admin.elevated_process_not_created':
          'Failed to create elevated process.',
      'error.admin_required':
          'Administrator privileges are required to use this app.',
      'error.config_picker_unsupported':
          'Config file picker is available on Windows only.',
      'error.executable_picker_unsupported':
          'Executable picker is available on Windows only.',
      'error.file_picker_failed': 'Failed to open config picker: {error}',
      'error.executable_picker_failed': 'Failed to open exe picker: {error}',
      'error.import_key_empty':
          'The provided import key is empty or contains only whitespace.',
      'error.running_list_unsupported':
          'Running apps listing is available on Windows only.',
      'error.running_list_failed': 'Failed to list running apps: {error}',
      'file.import_key_name': 'Imported key',
      'file.saved_name': 'Saved config',
      'client.running': 'The network runtime is already running.',
      'client.not_running': 'The network runtime is not running. Log: {log}',
      'client.not_running_no_log': 'The network runtime is not running.',
      'client.config_unreadable':
          'Config file is not readable: {error}\nLog: {log}',
      'client.config_unreadable_no_log': 'Config file is not readable: {error}',
      'client.runtime_missing':
          'Runtime files are missing:\n{files}\nLog: {log}',
      'client.runtime_missing_no_log': 'Runtime files are missing:\n{files}',
      'client.config_not_found': 'Config file not found: {configPath}',
      'client.exit_code': 'Exit code: {code}',
      'client.logs': 'Logs: stdout={stdoutLog}, stderr={stderrLog}',
      'client.access_denied':
          'The network runtime was denied access. Start Mayday as administrator and accept the UAC prompt.',
      'client.started':
          'The network runtime started. Logs: {launcherLog} / {stdoutLog} / {stderrLog}.',
      'client.started_no_log': 'The network runtime started.',
      'client.terminated_immediately':
          'The network runtime exited immediately.',
      'client.stdout': 'stdout:',
      'client.stderr': 'stderr:',
      'client.started_failed':
          'Failed to start the network runtime: {error}\nLog: {log}',
      'client.started_failed_no_log':
          'Failed to start the network runtime: {error}',
      'client.stop_requested': 'Network runtime stop requested.',
      'client.stopped':
          'The network runtime stopped. Exit code: {code}. Log: {log}',
      'client.stopped_no_log':
          'The network runtime stopped. Exit code: {code}.',
      'client.stop_timeout':
          'The network runtime did not stop within timeout. Log: {log}',
      'client.stop_timeout_no_log':
          'The network runtime did not stop within timeout.',
      'client.stop_failed':
          'Failed to stop the network runtime: {error}\nLog: {log}',
      'client.stop_failed_no_log':
          'Failed to stop the network runtime: {error}',
      'client.process_exit': 'The network runtime exited.',
      'codec.empty': 'Config file is empty.',
      'codec.json_objects_only': 'Only JSON objects are supported.',
      'codec.unsupported_yaml': 'Unsupported YAML structure.',
      'codec.user_id_non_negative': 'user_id must be a non-negative integer.',
      'codec.user_id_positive': 'user_id must be a positive integer.',
      'codec.failback_delay_invalid':
          'server_failback_delay_sec must be -1 or greater.',
      'codec.metrics_window_invalid':
          'metrics.window_seconds must be a positive number.',
      'codec.metrics_file_dir_required':
          'metrics.file_dir is required when file_enabled=true.',
      'codec.relay_required': 'At least one relay is required.',
      'codec.relay_addr_required': 'Relay address is required.',
      'codec.relay_short_id_invalid':
          'Relay short_id must be between 1 and 65535.',
      'codec.relay_short_id_unique':
          'Relay short_id must be unique for each relay.',
      'codec.relay_ports_required': 'Each relay must have at least one port.',
      'codec.relay_ports_invalid': 'Relay ports must be between 1 and 65535.',
      'codec.server_required': 'At least one server is required.',
      'codec.server_id_required': 'Server ID is required.',
      'codec.server_key_required': 'Server key is required.',
      'codec.server_key_hex':
          'Server key must contain exactly 64 hex characters.',
      'codec.server_priority_invalid':
          'Server priority must be a positive number.',
      'codec.split_apps_required':
          'split_tunnel.apps_win must contain at least one Windows app.',
      'codec.user_id_required': 'user_id is required.',
      'codec.user_id_integer': 'user_id must be an integer.',
      'codec.imported_default_name': 'Imported',
    },
  };

  String t(String key, [Map<String, Object?>? values]) {
    final raw =
        _values[language]?[key] ?? _values[AppLanguage.english]?[key] ?? key;
    if (values == null || values.isEmpty) {
      return raw;
    }

    var result = raw;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return result;
  }
}

class AppLanguageSettings {
  AppLanguageSettings({RuntimePathsService? runtimePathsService})
      : _runtimePathsService =
            runtimePathsService ?? const RuntimePathsService();

  static const _settingsFile = 'app_settings.json';
  static const _languageKey = 'language';
  static const _autoStartEnabledKey = 'autoStartEnabled';

  final RuntimePathsService _runtimePathsService;

  Future<AppLanguage> load() async {
    final settings = await _readSettings();
    final language = settings[_languageKey];
    if (language is String) {
      return AppLanguageLabel.fromStorageValue(language);
    }

    return AppLanguage.russian;
  }

  Future<bool> loadAutoStartEnabled() async {
    final settings = await _readSettings();
    final enabled = settings[_autoStartEnabledKey];
    if (enabled is bool) {
      return enabled;
    }

    return true;
  }

  Future<void> save(AppLanguage language) async {
    await _writeSettings({
      ...await _readSettings(),
      _languageKey: language.storageValue,
    });
  }

  Future<void> saveAutoStartEnabled(bool enabled) async {
    await _writeSettings({
      ...await _readSettings(),
      _autoStartEnabledKey: enabled,
    });
  }

  Future<Map<String, Object?>> _readSettings() async {
    try {
      final file = await _settingsFileHandle();
      if (!await file.exists()) {
        return const {};
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const {};
      }

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return Map<String, Object?>.from(decoded);
      }
    } catch (_) {
      // Ignore malformed local settings and keep defaults.
    }

    return const {};
  }

  Future<void> _writeSettings(Map<String, Object?> settings) async {
    final paths = await _runtimePathsService.getPaths();
    await Directory(paths.configDir).create(recursive: true);
    final file = await _settingsFileHandle();
    await file.writeAsString(jsonEncode(settings), flush: true);
  }

  Future<File> _settingsFileHandle() async {
    final paths = await _runtimePathsService.getPaths();
    return File(p.join(paths.configDir, _settingsFile));
  }
}
