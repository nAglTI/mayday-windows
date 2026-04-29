import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/l10n/app_texts.dart';
import 'core/services/admin_elevation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final languageSettings = AppLanguageSettings();
  final appLanguage = await languageSettings.load();
  final appTextCatalog = AppTextCatalog(appLanguage);

  final adminElevationService = AdminElevationService(
    textCatalog: appTextCatalog,
  );
  final bootstrapResult = await adminElevationService.bootstrap();
  if (bootstrapResult.exitRequested) {
    return;
  }

  runApp(
    MaydayApp(
      appLanguage: appLanguage,
      appTextCatalog: appTextCatalog,
      adminBootstrapResult: bootstrapResult,
      adminElevationService: adminElevationService,
      languageSettings: languageSettings,
    ),
  );
}
