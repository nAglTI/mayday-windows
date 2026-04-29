import 'package:flutter/material.dart';

import '../../../core/l10n/app_texts.dart';
import '../../../core/models/running_windows_app.dart';
import '../application/client_controller.dart';
import 'home_view_model.dart';
import 'widgets/home_chrome.dart';
import 'widgets/settings_view.dart';
import 'widgets/connection_view.dart';

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
  late final HomeViewModel _viewModel = HomeViewModel(
    controller: widget.controller,
    textCatalog: widget.textCatalog,
  );

  @override
  void initState() {
    super.initState();
    _viewModel.bootstrap();
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

    final selectedPath = await _showRunningAppsDialog(apps);
    if (selectedPath == null) {
      return;
    }
    _viewModel.addSplitTunnelApp(selectedPath);
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

  Future<String?> _showRunningAppsDialog(List<RunningWindowsApp> apps) async {
    final searchController = TextEditingController();
    var query = '';
    final result = await showDialog<String>(
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
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.apps_outlined),
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
                                  onTap: () =>
                                      Navigator.of(context).pop(app.path),
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
              ],
            );
          },
        );
      },
    );
    searchController.dispose();
    return result;
  }
}
