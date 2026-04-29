import 'package:flutter/material.dart';

import '../../../app/mayday_theme.dart';
import '../../../core/l10n/app_texts.dart';
import '../../../core/services/admin_elevation_service.dart';

class AdminRequiredPage extends StatefulWidget {
  const AdminRequiredPage({
    super.key,
    required this.appLanguage,
    required this.textCatalog,
    required this.adminBootstrapResult,
    required this.adminElevationService,
  });

  final AppLanguage appLanguage;
  final AppTextCatalog textCatalog;
  final AdminBootstrapResult adminBootstrapResult;
  final AdminElevationService adminElevationService;

  @override
  State<AdminRequiredPage> createState() => _AdminRequiredPageState();
}

class _AdminRequiredPageState extends State<AdminRequiredPage> {
  bool _isBusy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _message = widget.adminBootstrapResult.message;
  }

  Future<void> _restartAsAdmin() async {
    setState(() {
      _isBusy = true;
      _message = null;
    });

    final result = await widget.adminElevationService.restartAsAdministrator();
    if (!mounted) {
      return;
    }

    if (result.started) {
      setState(() {
        _message = widget.textCatalog.t('admin.started_message');
      });
      return;
    }

    setState(() {
      _message = result.message ?? widget.textCatalog.t('admin.failed_message');
      _isBusy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: ColoredBox(
        color: MaydayColors.background,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: MaydayColors.surface,
                  borderRadius: BorderRadius.circular(MaydayRadii.extraLarge),
                  border: Border.all(color: MaydayColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MAYDAY',
                        style: textTheme.labelLarge?.copyWith(
                          color: MaydayColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.textCatalog.t('admin.required_title'),
                        style: textTheme.displayMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.textCatalog.t('admin.description1'),
                        style: textTheme.bodyLarge?.copyWith(
                          color: MaydayColors.muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.textCatalog.t('admin.description2'),
                        style: textTheme.bodySmall?.copyWith(
                          color: MaydayColors.muted,
                        ),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: MaydayColors.accentSoft,
                            borderRadius:
                                BorderRadius.circular(MaydayRadii.large),
                            border: Border.all(color: MaydayColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              _message!,
                              style: textTheme.bodySmall?.copyWith(
                                color: MaydayColors.accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _isBusy ? null : _restartAsAdmin,
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: Text(
                          widget.textCatalog.t('button.restart_as_admin'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
