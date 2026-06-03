import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/mayday_theme.dart';
import '../../../core/l10n/app_texts.dart';
import '../../../core/models/app_update_info.dart';
import '../../../core/models/running_windows_app.dart';
import '../../../core/models/bad_app_finding.dart';
import '../application/client_controller.dart';
import 'home_view_model.dart';
import 'widgets/home_chrome.dart';
import 'widgets/settings_view.dart';
import 'widgets/connection_view.dart';

enum _PreflightRiskAction { acceptRisk, runScan }

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.appLanguage,
    required this.textCatalog,
    required this.onLanguageChanged,
  });

  final ClientController controller;
  final AppLanguage appLanguage;
  final AppTextCatalog textCatalog;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _debugShowPreflightDialogOnStart = bool.fromEnvironment(
    'MAYDAY_DEBUG_SHOW_PREFLIGHT_DIALOG_ON_START',
  );

  late final HomeViewModel _viewModel = HomeViewModel(
    controller: widget.controller,
    textCatalog: widget.textCatalog,
  );

  @override
  void initState() {
    super.initState();
    _viewModel.bootstrap();
    if (_debugShowPreflightDialogOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_showPreflightRiskDialog());
      });
    }
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.textCatalog != widget.textCatalog) {
      _viewModel.updateDependencies(
        controller: widget.controller,
        textCatalog: widget.textCatalog,
      );
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        final isSettings = _viewModel.selectedSection == HomeSection.settings;

        return Scaffold(
          body: Stack(
            children: [
              MaydayBackground(
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          22,
                          10,
                          22,
                          isSettings ? 112 : 24,
                        ),
                        children: [
                          HomeTopBar(
                            appLanguage: widget.appLanguage,
                            textCatalog: widget.textCatalog,
                            onLanguageChanged: widget.onLanguageChanged,
                            onReload:
                                _viewModel.isBusy ? null : _viewModel.bootstrap,
                          ),
                          if (_viewModel.shouldShowUpdateBanner &&
                              _viewModel.availableUpdate != null) ...[
                            const SizedBox(height: 12),
                            _UpdateBanner(
                              update: _viewModel.availableUpdate!,
                              textCatalog: widget.textCatalog,
                              onOpen: () {
                                unawaited(_viewModel.openAvailableUpdate());
                              },
                              onDismiss: _viewModel.dismissAvailableUpdate,
                            ),
                          ],
                          const SizedBox(height: 12),
                          ScreenTabs(
                            selected: _viewModel.selectedSection,
                            textCatalog: widget.textCatalog,
                            onChanged: _viewModel.setSelectedSection,
                          ),
                          const SizedBox(height: 18),
                          if (isSettings)
                            SettingsView(
                              viewModel: _viewModel,
                              textCatalog: widget.textCatalog,
                              onImportKey: _importConfigFromKey,
                              onPickRunningApp: _addSplitTunnelAppFromRunning,
                            )
                          else
                            ConnectionView(
                              viewModel: _viewModel,
                              textCatalog: widget.textCatalog,
                              onConnect: () {
                                unawaited(_connectWithPreflight());
                              },
                              onPreflightScan: () {
                                unawaited(_runPreflightScan());
                              },
                              onOpenPreflightResults: () {
                                unawaited(_openPreflightResults());
                              },
                              onOpenSettings: () {
                                _viewModel.setSelectedSection(
                                  HomeSection.settings,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (isSettings)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
                          child: SettingsSaveButton(
                            textCatalog: widget.textCatalog,
                            enabled: !_viewModel.isBusy,
                            onSave: _viewModel.saveProfile,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_viewModel.isBusy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importConfigFromKey() async {
    final importKey = await _showImportKeyDialog();
    if (importKey == null) {
      return;
    }
    await _viewModel.importConfigFromKey(importKey);
  }

  Future<void> _addSplitTunnelAppFromRunning() async {
    final apps = await _viewModel.listRunningWindowsApps();
    if (!mounted || apps.isEmpty) {
      return;
    }

    final selectedPaths = await _showRunningAppsDialog(apps);
    if (selectedPaths == null || selectedPaths.isEmpty) {
      return;
    }
    _viewModel.addSplitTunnelApps(selectedPaths);
  }

  Future<void> _connectWithPreflight() async {
    if (_viewModel.isBadAppPreflightPassed) {
      await _viewModel.saveAndLaunch();
      return;
    }

    final action = await _showPreflightRiskDialog();
    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _PreflightRiskAction.acceptRisk:
        await _viewModel.saveAndLaunch();
      case _PreflightRiskAction.runScan:
        final findings = await _viewModel.scanBadAppFindings();
        if (!mounted || findings == null) {
          return;
        }

        if (findings.isEmpty) {
          await _viewModel.saveAndLaunch();
          return;
        }

        await _showBadAppScanResultsDialog(findings);
    }
  }

  Future<void> _runPreflightScan() async {
    final findings = await _viewModel.scanBadAppFindings();
    if (!mounted || findings == null || findings.isEmpty) {
      return;
    }
    await _showBadAppScanResultsDialog(findings);
  }

  Future<void> _openPreflightResults() async {
    final findings = _viewModel.badAppFindings;
    if (!mounted || findings == null) {
      return;
    }
    await _showBadAppScanResultsDialog(findings);
  }

  Future<String?> _showImportKeyDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(widget.textCatalog.t('title.app_key_dialog')),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 5,
              maxLines: 8,
              style: Theme.of(context).textTheme.bodySmall,
              decoration: const InputDecoration(
                labelText: 'mayday://import/<base64>',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(widget.textCatalog.t('button.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(widget.textCatalog.t('button.import')),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result?.trim().isEmpty ?? true ? null : result?.trim();
  }

  Future<_PreflightRiskAction?> _showPreflightRiskDialog() {
    return showDialog<_PreflightRiskAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(widget.textCatalog.t('title.preflight_risk')),
          content: SizedBox(
            width: 520,
            child: Text(widget.textCatalog.t('message.preflight_risk_body')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                _PreflightRiskAction.acceptRisk,
              ),
              child: Text(widget.textCatalog.t('button.accept_preflight_risk')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(
                _PreflightRiskAction.runScan,
              ),
              icon: const Icon(Icons.health_and_safety_outlined),
              label: Text(widget.textCatalog.t('button.preflight_scan')),
            ),
          ],
        );
      },
    );
  }

  Future<List<String>?> _showRunningAppsDialog(
    List<RunningWindowsApp> apps,
  ) async {
    final searchController = TextEditingController();
    final selectedPaths = <String>{};
    var query = '';
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = apps.where((app) {
              final normalizedQuery = query.trim().toLowerCase();
              if (normalizedQuery.isEmpty) {
                return true;
              }
              return app.name.toLowerCase().contains(normalizedQuery) ||
                  app.path.toLowerCase().contains(normalizedQuery);
            }).toList();

            return AlertDialog(
              title: Text(widget.textCatalog.t('title.running_apps')),
              content: SizedBox(
                width: 560,
                height: 520,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: widget.textCatalog.t('menu.search'),
                        prefixIcon: const Icon(Icons.search_outlined),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          query = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                apps.isEmpty
                                    ? widget.textCatalog.t(
                                        'title.no_files_with_paths',
                                      )
                                    : widget.textCatalog.t(
                                        'title.no_apps_found',
                                      ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final app = filtered[index];
                                final isSelected =
                                    selectedPaths.contains(app.path);
                                return CheckboxListTile(
                                  dense: true,
                                  value: isSelected,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(
                                    app.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    app.path,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (value ?? false) {
                                        selectedPaths.add(app.path);
                                      } else {
                                        selectedPaths.remove(app.path);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(widget.textCatalog.t('button.cancel')),
                ),
                FilledButton.icon(
                  onPressed: selectedPaths.isEmpty
                      ? null
                      : () {
                          final orderedSelection = [
                            for (final app in apps)
                              if (selectedPaths.contains(app.path)) app.path,
                          ];
                          Navigator.of(context).pop(orderedSelection);
                        },
                  icon: const Icon(Icons.add_outlined),
                  label: Text(
                    widget.textCatalog.t('button.add_selected', {
                      'count': selectedPaths.length,
                    }),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    searchController.dispose();
    return result;
  }

  Future<void> _showBadAppScanResultsDialog(
    List<BadAppFinding> findings,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        final hasFindings = findings.isNotEmpty;
        final scannedAt = _viewModel.badAppScannedAt;

        return AlertDialog(
          title: Text(
            widget.textCatalog.t(
              hasFindings ? 'title.vpn_scan_blocked' : 'title.vpn_scan_results',
            ),
          ),
          content: SizedBox(
            width: 600,
            height: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.textCatalog.t(
                    hasFindings
                        ? 'title.vpn_scan_blocked_body'
                        : 'message.vpn_scan_clear',
                  ),
                ),
                if (scannedAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${widget.textCatalog.t('label.bad_app_scanned_at')}: '
                    '${_formatLocalDateTime(scannedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 14),
                Expanded(
                  child: hasFindings
                      ? ListView.separated(
                          itemCount: findings.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _BadAppFindingTile(
                              finding: findings[index],
                              textCatalog: widget.textCatalog,
                            );
                          },
                        )
                      : const _EmptyBadAppScanResult(),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(widget.textCatalog.t('button.close')),
            ),
          ],
        );
      },
    );
  }

  String _formatLocalDateTime(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-'
        '${twoDigits(local.month)}-'
        '${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}';
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({
    required this.update,
    required this.textCatalog,
    required this.onOpen,
    required this.onDismiss,
  });

  final AppUpdateInfo update;
  final AppTextCatalog textCatalog;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF282315),
        borderRadius: BorderRadius.circular(MaydayRadii.large),
        border: Border.all(color: MaydayColors.warn.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Icon(
                Icons.system_update_alt_outlined,
                size: 19,
                color: MaydayColors.warn,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    textCatalog.t('update.banner_title', {
                      'version': update.latestVersion.displayVersion,
                    }),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: MaydayColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    textCatalog.t('update.banner_body'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: MaydayColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_outlined, size: 16),
              label: Text(textCatalog.t('button.update')),
            ),
            Tooltip(
              message: textCatalog.t('tooltip.dismiss_update'),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBadAppScanResult extends StatelessWidget {
  const _EmptyBadAppScanResult();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.verified_user_outlined,
        size: 42,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _BadAppFindingTile extends StatelessWidget {
  const _BadAppFindingTile({
    required this.finding,
    required this.textCatalog,
  });

  final BadAppFinding finding;
  final AppTextCatalog textCatalog;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = finding.title;
    final details = _detailLines();
    final path = finding.path.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_categoryIcon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: MaydayColors.chip,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      _categoryLabel,
                      style: textTheme.labelMedium,
                    ),
                  ),
                ),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final detail in details)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ),
            ],
            if (path.isNotEmpty) ...[
              const SizedBox(height: 8),
              _BadAppPathRow(
                path: path,
                textCatalog: textCatalog,
              ),
            ],
            if (finding.matchedKeywords.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${textCatalog.t('label.vpn_scan_signals')}: '
                '${finding.matchedKeywords.join(', ')}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData get _categoryIcon {
    return switch (finding.category) {
      'executable_file' => Icons.description_outlined,
      'service' => Icons.miscellaneous_services_outlined,
      'scheduled_task' => Icons.event_repeat_outlined,
      _ => Icons.apps_outlined,
    };
  }

  String get _categoryLabel {
    return switch (finding.category) {
      'executable_file' => textCatalog.t('category.bad_app_executable_file'),
      'service' => textCatalog.t('category.bad_app_service'),
      'scheduled_task' => textCatalog.t('category.bad_app_scheduled_task'),
      _ => textCatalog.t('category.bad_app_installed_program'),
    };
  }

  List<String> _detailLines() {
    final lines = <String>[];
    void add(String labelKey, String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return;
      }
      lines.add('${textCatalog.t(labelKey)}: $trimmed');
    }

    add('label.bad_app_publisher', finding.publisher);
    add('label.bad_app_version', finding.version);
    add('label.bad_app_status', finding.status);
    add('label.bad_app_state', finding.state);
    return lines;
  }
}

class _BadAppPathRow extends StatelessWidget {
  const _BadAppPathRow({
    required this.path,
    required this.textCatalog,
  });

  final String path;
  final AppTextCatalog textCatalog;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: MaydayColors.sunken,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MaydayColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    textCatalog.t('label.bad_app_path'),
                    style: textTheme.labelMedium,
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    path,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Tooltip(
              message: textCatalog.t('tooltip.copy_path'),
              child: IconButton(
                onPressed: () {
                  unawaited(Clipboard.setData(ClipboardData(text: path)));
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(
                      content: Text(textCatalog.t('message.path_copied')),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
