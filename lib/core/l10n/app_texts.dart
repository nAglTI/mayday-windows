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
      'button.update': 'Обновиться',
      'tooltip.dismiss_update': 'Скрыть уведомление',
      'message.update_open_failed':
          'Не удалось открыть страницу обновления: {error}',
      'update.banner_title': 'Доступна версия {version}',
      'update.banner_body':
          'Вышла новая версия Mayday. Можно обновиться через GitHub Releases.',
      'app.network_client': 'сетевой клиент',
      'button.cancel': 'Отмена',
      'button.close': 'Закрыть',
      'button.connect': 'Подключиться',
      'button.stop': 'Отключить',
      'button.import': 'Импорт',
      'button.restart_as_admin': 'Перезапустить как администратор',
      'button.import_key': 'Импортировать ключ',
      'button.save_config': 'Сохранить',
      'button.save_settings': 'Сохранить настройки',
      'button.reload': 'Обновить',
      'button.choose_exe': 'Выбрать EXE',
      'button.running_app': 'Из запущенных',
      'button.add_selected': 'Добавить ({count})',
      'button.open_settings': 'Открыть настройки',
      'button.preflight_scan': 'Проверить приложения',
      'button.accept_preflight_risk': 'Принимаю последствия',
      'button.open_scan_results': 'Показать результаты',
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
      'status.stopping': 'отключение',
      'status.loading_apps': 'загрузка приложений',
      'status.scanning_apps': 'проверка приложений',
      'status.not_scanned': 'не проверено',
      'status.scan_failed': 'ошибка проверки',
      'status.scan_clear': 'ничего не найдено',
      'status.scan_blocked_count': 'найдено: {count}',
      'status.idle': 'не подключено',
      'status.ready': 'готово',
      'status.missing': 'отсутствует',
      'status.not_set': 'не задано',
      'status.disconnected': 'не подключено',
      'status.launch_error': 'ошибка подключения',
      'status.runtime_started': 'VPN подключен',
      'message.bootstrap_failed': 'Ошибка инициализации: {error}',
      'message.runtime_available': 'Файлы runtime доступны.',
      'message.runtime_incomplete':
          'Не все файлы среды выполнения найдены. Проверьте диагностику.',
      'message.imported_from_key': 'Данные доступа импортированы.',
      'message.import_key_incompatible':
          'Этот ключ доступа создан для старого формата Mayday. Получите новый ключ и импортируйте его заново.',
      'message.import_key_failed': 'Не удалось импортировать ключ: {error}',
      'message.saved_config_incompatible':
          'Сохраненный профиль не подходит для текущей версии Mayday. Получите новый ключ доступа и импортируйте его заново.',
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
      'message.added_split_apps':
          'Добавлено приложений в список раздельной маршрутизации: {count}',
      'message.vpn_scan_blocked': 'Найдены нежелательные приложения: {count}.',
      'message.vpn_scan_failed':
          'Не удалось проверить приложения перед подключением: {error}',
      'message.vpn_scan_clear':
          'Проверка завершена: нежелательные приложения не найдены.',
      'message.preflight_risk_body':
          'Проверка приложений не была успешно пройдена. Установленные приложения, службы или автозадачи могут нарушать безопасность подключения или работоспособность VPN. Вы можете принять возможные последствия и подключиться сейчас либо запустить проверку.',
      'message.path_copied': 'Путь скопирован.',
      'home.mayday': 'mayday',
      'home.tooltip.import_key': 'Импорт ключа',
      'home.tooltip.reload': 'Обновить',
      'home.preview_unavailable':
          '# Предпросмотр недоступен, пока профиль невалиден.\n# {error}',
      'home.endpoint_relay_not_configured': 'Реле не настроено',
      'home.config_ready': 'Конфигурация готова',
      'home.config_not_ready': 'Импортируйте ключ в настройках',
      'home.runtime_not_ready': 'Файлы runtime не найдены',
      'section.advanced': 'подробности',
      'section.diagnostics': 'диагностика',
      'section.application': 'приложение',
      'section.profile': 'профиль',
      'section.transport': 'транспорт',
      'section.network_transport': 'транспорт и dns',
      'section.runtime_options': 'ядро и защита',
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
      'label.user_id': 'ID пользователя',
      'label.relays': 'реле',
      'label.servers': 'серверы',
      'label.server': 'сервер',
      'label.config': 'конфиг',
      'label.tun_name': 'tun',
      'label.dns': 'dns',
      'label.mode': 'режим',
      'label.preflight_scan': 'проверка',
      'label.transport_mode': 'режим транспорта',
      'label.transport_auto': 'Автоматически',
      'label.transport_tcp': 'TCP',
      'label.transport_utp': 'uTP',
      'label.transport_ws': 'WebSocket',
      'label.transport_https': 'HTTPS REST',
      'label.transport_raw_udp': 'Raw UDP (rescue)',
      'label.failback_delay': 'задержка возврата',
      'label.failback_delay_helper':
          '-1 отключает автовозврат, 0 включает дефолт 60 секунд.',
      'label.network_rescue': 'Защита для плохих сетей',
      'label.network_rescue_off': 'Отключено / fast',
      'label.network_rescue_stable': 'Stable rescue',
      'label.network_rescue_extreme': 'Extreme rescue',
      'label.network_rescue_helper':
          'Отдельная политика для нестабильных сетей. Stable предпочитает HTTPS/WS/TCP, Extreme может сначала выбрать raw-udp.',
      'label.prestart_full_probe': 'Полная проверка перед подключением',
      'label.steady_quick_probe': 'Быстрая проверка в фоне',
      'label.steady_benchmark': 'Фоновый benchmark',
      'label.disable_ipv6': 'Отключить IPv6',
      'label.tunnel_mtu': 'MTU туннеля',
      'label.tunnel_mtu_helper':
          'Auto: 1280 для auto/uTP, 1420 для TCP/WS/HTTPS. Максимум 1500.',
      'label.packet_fragment_payload': 'Размер packet_fragment',
      'label.packet_fragment_payload_helper':
          '0 отключает дробление. Диапазон защиты: 64–65536 байт.',
      'label.packet_fast': 'быстро',
      'label.disable_packet_batching': 'Отключить batching пакетов',
      'label.metrics_enabled': 'Включить метрики',
      'label.metrics_window': 'Окно метрик, секунд',
      'label.metrics_window_helper':
          'Используется для in-memory окна и ротации файлов.',
      'label.metrics_file_enabled': 'Писать метрики в файл',
      'label.metrics_file_dir': 'Директория метрик',
      'label.metrics_file_dir_helper':
          'Это директория, например ./metrics. Пусто — рядом со вспомогательным файлом Mayday.',
      'label.metrics_dir': 'директория метрик',
      'label.priority': 'приоритет',
      'label.all_traffic': 'весь трафик',
      'label.only_selected': 'только выбранные',
      'label.except': 'исключить',
      'label.one_relay_per_line': 'по одной строке на реле',
      'label.dns_helper': 'Через запятую. Например: 1.1.1.1, 8.8.8.8',
      'label.relay_format': 'Формат: id|addr|short_id|transport_ports',
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
      'title.preflight_risk': 'Проверка приложений не пройдена',
      'title.vpn_scan_blocked': 'Найдены нежелательные приложения',
      'title.vpn_scan_blocked_body':
          'Mayday нашел приложения, exe-файлы, службы или автозадачи из списка риска. Они могут нарушать безопасность подключения или работоспособность VPN.',
      'title.vpn_scan_results': 'Результаты проверки',
      'title.split_disabled_hint':
          'Раздельная маршрутизация отключена. Вы можете подготовить список приложений.',
      'title.split_empty_hint':
          'Добавьте хотя бы одно Windows-приложение для выбранного режима.',
      'tooltip.remove': 'Удалить',
      'tooltip.copy_path': 'Скопировать путь',
      'label.vpn_scan_score': 'тип',
      'label.vpn_scan_signals': 'совпадения',
      'label.vpn_scan_exe_candidates': 'детали',
      'label.bad_app_path': 'путь',
      'label.bad_app_scanned_at': 'проверено',
      'label.bad_app_publisher': 'издатель',
      'label.bad_app_version': 'версия',
      'label.bad_app_status': 'статус',
      'label.bad_app_state': 'состояние',
      'category.bad_app_installed_program': 'программа',
      'category.bad_app_executable_file': 'exe-файл',
      'category.bad_app_service': 'служба',
      'category.bad_app_scheduled_task': 'автозадача',
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
      'error.executable_picker_unsupported':
          'Просмотрщик исполняемых файлов доступен только в Windows.',
      'error.executable_picker_failed':
          'Не удалось открыть диалог выбора EXE: {error}',
      'error.import_key_empty':
          'Вставленный ключ пуст или содержит только пробелы.',
      'error.running_list_unsupported':
          'Получение списка запущенных приложений доступно только в Windows.',
      'error.running_list_failed':
          'Не удалось получить список запущенных приложений: {error}',
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
          'Сетевой процесс готов. Диагностика: {launcherLog} / {stdoutLog} / {stderrLog}.',
      'client.started_no_log': 'Сетевой процесс готов.',
      'client.vpn_started': 'VPN подключен.',
      'client.vpn_started_no_log': 'VPN подключен.',
      'client.vpn_stopped': 'VPN отключен.',
      'client.vpn_stopped_no_log': 'VPN отключен.',
      'client.shutdown': 'Сетевой процесс остановлен.',
      'client.shutdown_no_log': 'Сетевой процесс остановлен.',
      'client.control_failed':
          'Не удалось выполнить действие «{command}»: {error}\nДиагностика: {log}',
      'client.control_failed_no_log':
          'Не удалось выполнить действие «{command}»: {error}',
      'client.control_command_start': 'подключение VPN',
      'client.control_command_stop': 'отключение VPN',
      'client.control_command_status': 'проверка состояния',
      'client.control_command_shutdown': 'остановка сетевого процесса',
      'client.control_command_transports': 'проверка транспорта',
      'client.control_error_access_denied': 'нужны права администратора.',
      'client.control_error_timeout': 'сетевой процесс не ответил вовремя.',
      'client.control_error_code': 'сетевой процесс вернул код {code}.',
      'client.control_error_generic':
          'сетевой процесс не ответил ожидаемым образом.',
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
      'codec.contract_legacy_relays':
          'Конфиг использует старый список relays вместо discovery_relays.',
      'codec.contract_discovery_relays_required':
          'В конфиге нет discovery_relays.',
      'codec.contract_servers_required': 'В конфиге нет servers.',
      'codec.contract_apps_win_required':
          'В конфиге нет split_tunnel.apps_win.',
      'codec.contract_apps_mode_required':
          'В конфиге нет split_tunnel.apps_mode.',
      'codec.contract_relay_key_required':
          'В discovery_relays должен быть relay_key для каждого реле.',
      'codec.contract_transport_ports_required':
          'В discovery_relays должен быть transport_ports для каждого реле.',
      'codec.contract_transport_mode_unsupported':
          'transport.mode не поддерживается текущей версией Mayday.',
      'codec.contract_network_rescue_profile_unsupported':
          'network_rescue.profile не поддерживается текущей версией Mayday.',
      'codec.contract_current_field_required':
          'В конфиге нет обязательного поля {field}.',
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
      'codec.tunnel_mtu_invalid':
          'tunnel_mtu должен быть от 1280 до 1500, либо от 100 до 1500 при disable_ipv6=true.',
      'codec.packet_fragment_payload_invalid':
          'packet_fragment_payload_bytes должен быть 0 или числом от 64 до 65536.',
      'codec.relay_required': 'Должно быть хотя бы одно реле.',
      'codec.relay_addr_required': 'Требуется адрес реле.',
      'codec.relay_short_id_invalid':
          'short_id реле должен быть числом от 1 до 65535.',
      'codec.relay_short_id_unique':
          'short_id должен быть уникальным для каждого реле.',
      'codec.relay_ports_required':
          'У каждого реле должен быть хотя бы один порт в transport_ports.',
      'codec.relay_ports_invalid':
          'transport_ports реле должны быть числами от 1 до 65535.',
      'codec.relay_key_hex': 'relay_key должен содержать ровно 64 hex-символа.',
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
    },
    AppLanguage.english: {
      'app.title': 'Mayday',
      'app.title_short': 'mayday',
      'button.update': 'Update',
      'tooltip.dismiss_update': 'Dismiss update notice',
      'message.update_open_failed': 'Failed to open update page: {error}',
      'update.banner_title': 'Version {version} is available',
      'update.banner_body':
          'A new Mayday release is available on GitHub Releases.',
      'app.network_client': 'network client',
      'button.cancel': 'Cancel',
      'button.close': 'Close',
      'button.connect': 'Connect',
      'button.stop': 'Stop',
      'button.import': 'Import',
      'button.restart_as_admin': 'Restart as administrator',
      'button.import_key': 'Import key',
      'button.save_config': 'Save config',
      'button.save_settings': 'Save settings',
      'button.reload': 'Reload',
      'button.choose_exe': 'Choose EXE',
      'button.running_app': 'Running app',
      'button.add_selected': 'Add ({count})',
      'button.open_settings': 'Open settings',
      'button.preflight_scan': 'Preflight scan',
      'button.accept_preflight_risk': 'Accept consequences',
      'button.open_scan_results': 'Show results',
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
      'status.stopping': 'disconnecting',
      'status.loading_apps': 'loading apps',
      'status.scanning_apps': 'scanning apps',
      'status.not_scanned': 'not scanned',
      'status.scan_failed': 'scan failed',
      'status.scan_clear': 'nothing found',
      'status.scan_blocked_count': 'found: {count}',
      'status.idle': 'not connected',
      'status.ready': 'ready',
      'status.missing': 'missing',
      'status.not_set': 'not set',
      'status.disconnected': 'disconnected',
      'status.launch_error': 'connection error',
      'status.runtime_started': 'VPN connected',
      'message.bootstrap_failed': 'Bootstrap failed: {error}',
      'message.runtime_available': 'Runtime files are available.',
      'message.runtime_incomplete': 'Runtime is incomplete. Check diagnostics.',
      'message.imported_from_key': 'Access data imported.',
      'message.import_key_incompatible':
          'This access key was created for an older Mayday format. Get a new key and import it again.',
      'message.import_key_failed': 'Import key failed: {error}',
      'message.saved_config_incompatible':
          'The saved profile is not compatible with this Mayday version. Get a new access key and import it again.',
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
      'message.added_split_apps': 'Added {count} split apps',
      'message.vpn_scan_blocked': 'Blocked apps were found: {count}.',
      'message.vpn_scan_failed':
          'Failed to scan apps before connecting: {error}',
      'message.vpn_scan_clear': 'Scan complete: no blocked apps were found.',
      'message.preflight_risk_body':
          'The app check has not passed successfully. Installed apps, services, or scheduled tasks may affect connection security or VPN reliability. You can accept the possible consequences and connect now, or run the check.',
      'message.path_copied': 'Path copied.',
      'home.mayday': 'mayday',
      'home.tooltip.import_key': 'Import key',
      'home.tooltip.reload': 'Reload',
      'home.preview_unavailable':
          '# Preview is unavailable until the profile is valid.\n# {error}',
      'home.endpoint_relay_not_configured': 'Relay not configured',
      'home.config_ready': 'Configuration ready',
      'home.config_not_ready': 'Import a key in settings',
      'home.runtime_not_ready': 'Runtime files are missing',
      'section.advanced': 'details',
      'section.diagnostics': 'diagnostics',
      'section.application': 'application',
      'section.profile': 'profile',
      'section.transport': 'transport',
      'section.network_transport': 'transport and dns',
      'section.runtime_options': 'core and protection',
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
      'label.tun_name': 'tun',
      'label.dns': 'dns',
      'label.mode': 'mode',
      'label.preflight_scan': 'preflight',
      'label.transport_mode': 'transport mode',
      'label.transport_auto': 'Automatic',
      'label.transport_tcp': 'TCP',
      'label.transport_utp': 'uTP',
      'label.transport_ws': 'WebSocket',
      'label.transport_https': 'HTTPS REST',
      'label.transport_raw_udp': 'Raw UDP (rescue)',
      'label.failback_delay': 'failback delay',
      'label.failback_delay_helper':
          '-1 disables automatic failback, 0 uses the 60-second default.',
      'label.network_rescue': 'Network rescue',
      'label.network_rescue_off': 'Off / fast',
      'label.network_rescue_stable': 'Stable rescue',
      'label.network_rescue_extreme': 'Extreme rescue',
      'label.network_rescue_helper':
          'Separate policy for unstable networks. Stable prefers HTTPS/WS/TCP, Extreme may try raw-udp first.',
      'label.prestart_full_probe': 'Full probe before connect',
      'label.steady_quick_probe': 'Background quick probe',
      'label.steady_benchmark': 'Background benchmark',
      'label.disable_ipv6': 'Disable IPv6',
      'label.tunnel_mtu': 'Tunnel MTU',
      'label.tunnel_mtu_helper':
          'Auto: 1280 for auto/uTP, 1420 for TCP/WS/HTTPS. Maximum 1500.',
      'label.packet_fragment_payload': 'packet_fragment size',
      'label.packet_fragment_payload_helper':
          '0 disables fragmentation. Protection range: 64-65536 bytes.',
      'label.packet_fast': 'fast',
      'label.disable_packet_batching': 'Disable packet batching',
      'label.metrics_enabled': 'Enable metrics',
      'label.metrics_window': 'Metrics window, seconds',
      'label.metrics_window_helper':
          'Used for the in-memory window and file rotation.',
      'label.metrics_file_enabled': 'Write metrics file',
      'label.metrics_file_dir': 'Metrics directory',
      'label.metrics_file_dir_helper':
          'A directory, for example ./metrics. Empty means next to the Mayday helper file.',
      'label.metrics_dir': 'metrics directory',
      'label.priority': 'priority',
      'label.all_traffic': 'all traffic',
      'label.only_selected': 'only selected',
      'label.except': 'except',
      'label.one_relay_per_line': 'one relay per line',
      'label.dns_helper': 'Comma-separated, for example: 1.1.1.1, 8.8.8.8',
      'label.relay_format': 'Format: id|addr|short_id|transport_ports',
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
      'title.preflight_risk': 'App check has not passed',
      'title.vpn_scan_blocked': 'Blocked apps found',
      'title.vpn_scan_blocked_body':
          'Mayday found apps, exe files, services, or scheduled tasks from the risk list. They may affect connection security or VPN reliability.',
      'title.vpn_scan_results': 'Scan results',
      'title.split_disabled_hint':
          'Split tunneling is disabled. You can still prepare an app list.',
      'title.split_empty_hint':
          'Add at least one Windows app for this split-tunnel mode.',
      'tooltip.remove': 'Remove',
      'tooltip.copy_path': 'Copy path',
      'label.vpn_scan_score': 'type',
      'label.vpn_scan_signals': 'matches',
      'label.vpn_scan_exe_candidates': 'details',
      'label.bad_app_path': 'path',
      'label.bad_app_scanned_at': 'scanned',
      'label.bad_app_publisher': 'publisher',
      'label.bad_app_version': 'version',
      'label.bad_app_status': 'status',
      'label.bad_app_state': 'state',
      'category.bad_app_installed_program': 'app',
      'category.bad_app_executable_file': 'exe file',
      'category.bad_app_service': 'service',
      'category.bad_app_scheduled_task': 'scheduled task',
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
      'error.executable_picker_unsupported':
          'Executable picker is available on Windows only.',
      'error.executable_picker_failed': 'Failed to open exe picker: {error}',
      'error.import_key_empty':
          'The provided import key is empty or contains only whitespace.',
      'error.running_list_unsupported':
          'Running apps listing is available on Windows only.',
      'error.running_list_failed': 'Failed to list running apps: {error}',
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
          'The network runtime is ready. Diagnostics: {launcherLog} / {stdoutLog} / {stderrLog}.',
      'client.started_no_log': 'The network runtime is ready.',
      'client.vpn_started': 'VPN connected.',
      'client.vpn_started_no_log': 'VPN connected.',
      'client.vpn_stopped': 'VPN disconnected.',
      'client.vpn_stopped_no_log': 'VPN disconnected.',
      'client.shutdown': 'The network runtime stopped.',
      'client.shutdown_no_log': 'The network runtime stopped.',
      'client.control_failed':
          'Could not complete "{command}": {error}\nDiagnostics: {log}',
      'client.control_failed_no_log': 'Could not complete "{command}": {error}',
      'client.control_command_start': 'connect VPN',
      'client.control_command_stop': 'disconnect VPN',
      'client.control_command_status': 'check status',
      'client.control_command_shutdown': 'stop network runtime',
      'client.control_command_transports': 'check transport',
      'client.control_error_access_denied': 'administrator access is required.',
      'client.control_error_timeout':
          'the network runtime did not respond in time.',
      'client.control_error_code': 'the network runtime returned code {code}.',
      'client.control_error_generic':
          'the network runtime returned an unexpected response.',
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
      'codec.contract_legacy_relays':
          'Config uses the old relays list instead of discovery_relays.',
      'codec.contract_discovery_relays_required':
          'Config is missing discovery_relays.',
      'codec.contract_servers_required': 'Config is missing servers.',
      'codec.contract_apps_win_required':
          'Config is missing split_tunnel.apps_win.',
      'codec.contract_apps_mode_required':
          'Config is missing split_tunnel.apps_mode.',
      'codec.contract_relay_key_required':
          'discovery_relays must include relay_key for every relay.',
      'codec.contract_transport_ports_required':
          'discovery_relays must include transport_ports for every relay.',
      'codec.contract_transport_mode_unsupported':
          'transport.mode is not supported by this Mayday version.',
      'codec.contract_network_rescue_profile_unsupported':
          'network_rescue.profile is not supported by this Mayday version.',
      'codec.contract_current_field_required':
          'Config is missing required field {field}.',
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
      'codec.tunnel_mtu_invalid':
          'tunnel_mtu must be between 1280 and 1500, or between 100 and 1500 when disable_ipv6=true.',
      'codec.packet_fragment_payload_invalid':
          'packet_fragment_payload_bytes must be 0 or between 64 and 65536.',
      'codec.relay_required': 'At least one relay is required.',
      'codec.relay_addr_required': 'Relay address is required.',
      'codec.relay_short_id_invalid':
          'Relay short_id must be between 1 and 65535.',
      'codec.relay_short_id_unique':
          'Relay short_id must be unique for each relay.',
      'codec.relay_ports_required':
          'Each relay must have at least one transport_ports port.',
      'codec.relay_ports_invalid':
          'Relay transport_ports must be between 1 and 65535.',
      'codec.relay_key_hex':
          'relay_key must contain exactly 64 hex characters.',
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
