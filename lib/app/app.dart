import 'package:flutter/material.dart';

import '../core/l10n/app_texts.dart';
import '../core/services/admin_elevation_service.dart';
import '../core/services/runtime_launcher.dart';
import '../features/home/application/client_controller.dart';
import '../features/home/presentation/admin_required_page.dart';
import '../features/home/presentation/home_page.dart';
import 'mayday_theme.dart';

class MaydayApp extends StatefulWidget {
  const MaydayApp({
    super.key,
    required this.appLanguage,
    required this.appTextCatalog,
    required this.adminBootstrapResult,
    required this.adminElevationService,
    required this.languageSettings,
  });

  final AppLanguage appLanguage;
  final AppTextCatalog appTextCatalog;
  final AdminBootstrapResult adminBootstrapResult;
  final AdminElevationService adminElevationService;
  final AppLanguageSettings languageSettings;

  @override
  State<MaydayApp> createState() => _MaydayAppState();
}

class _MaydayAppState extends State<MaydayApp> {
  late AppLanguage _appLanguage = widget.appLanguage;
  late AppTextCatalog _textCatalog = widget.appTextCatalog;
  late final RuntimeLauncher _runtimeLauncher =
      RuntimeLauncher(appTextCatalog: _textCatalog);
  late ClientController _controller = _buildController();

  @override
  void initState() {
    super.initState();
    _controller = _buildController();
  }

  ClientController _buildController() {
    return ClientController(
      appTextCatalog: _textCatalog,
      launcher: _runtimeLauncher,
    );
  }

  Future<void> _setLanguage(AppLanguage language) async {
    if (_appLanguage == language) {
      return;
    }

    final newCatalog = AppTextCatalog(language);

    _runtimeLauncher.updateTextCatalog(newCatalog);
    setState(() {
      _appLanguage = language;
      _textCatalog = newCatalog;
      _controller = _buildController();
    });

    await widget.languageSettings.save(language);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _textCatalog.t('app.title'),
      debugShowCheckedModeBanner: false,
      theme: MaydayTheme.dark(),
      home: widget.adminBootstrapResult.isElevated
          ? HomePage(
              controller: _controller,
              appLanguage: _appLanguage,
              textCatalog: _textCatalog,
              onLanguageChanged: _setLanguage,
            )
          : AdminRequiredPage(
              adminBootstrapResult: widget.adminBootstrapResult,
              adminElevationService: widget.adminElevationService,
              appLanguage: _appLanguage,
              textCatalog: _textCatalog,
            ),
    );
  }
}
