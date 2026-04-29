import 'package:flutter/material.dart';

import '../../../../app/mayday_theme.dart';
import '../../../../core/l10n/app_texts.dart';
import '../../../../core/models/relay_target.dart';
import '../../../../core/models/transport_config.dart';
import '../home_view_model.dart';
import 'common_widgets.dart';
import 'connection_view.dart';
import 'server_priority_list.dart';
import 'split_tunnel_apps_panel.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.viewModel,
    required this.textCatalog,
    required this.onImportKey,
    required this.onPickRunningApp,
  });

  final HomeViewModel viewModel;
  final AppTextCatalog textCatalog;
  final VoidCallback onImportKey;
  final VoidCallback onPickRunningApp;

  @override
  Widget build(BuildContext context) {
    final profile = viewModel.collectProfile();

    return Column(
      children: [
        SettingsActions(
          textCatalog: textCatalog,
          enabled: !viewModel.isBusy,
          onImportConfig: viewModel.importConfig,
          onImportKey: onImportKey,
        ),
        const SizedBox(height: 12),
        HomeMessagePanel(viewModel: viewModel),
        const SizedBox(height: 18),
        SectionTitle(textCatalog.t('section.application')),
        const SizedBox(height: 8),
        SurfacePanel(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.login_outlined),
            title: Text(textCatalog.t('label.autostart_app')),
            subtitle: Text(textCatalog.t('label.autostart_app_helper')),
            value: viewModel.autoStartEnabled,
            onChanged: viewModel.isBusy ? null : viewModel.setAutoStartEnabled,
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle(textCatalog.t('section.profile')),
        const SizedBox(height: 8),
        SurfacePanel(
          child: Column(
            children: [
              MaydayTextField(
                label: textCatalog.t('label.profile'),
                controller: viewModel.displayNameController,
              ),
              const SizedBox(height: 14),
              MaydayTextField(
                label: textCatalog.t('label.user_id'),
                controller: viewModel.userIdController,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SettingsCollapsibleSection(
          title: textCatalog.t('section.network_transport'),
          initiallyExpanded: false,
          expandTooltip: textCatalog.t('tooltip.expand_section'),
          collapseTooltip: textCatalog.t('tooltip.collapse_section'),
          child: Column(
            children: [
              MaydayTextField(
                label: textCatalog.t('label.tun_name'),
                controller: viewModel.tunNameController,
              ),
              const SizedBox(height: 14),
              MaydayTextField(
                label: textCatalog.t('label.dns'),
                controller: viewModel.dnsController,
                helperText: textCatalog.t('label.dns_helper'),
              ),
              const SizedBox(height: 14),
              SegmentedField<TransportMode>(
                label: textCatalog.t('label.transport_mode'),
                selected: viewModel.transportMode,
                segments: [
                  Segment(
                    value: TransportMode.auto,
                    label: textCatalog.t('label.transport_auto'),
                  ),
                  Segment(
                    value: TransportMode.tcp,
                    label: textCatalog.t('label.transport_tcp'),
                  ),
                  Segment(
                    value: TransportMode.utp,
                    label: textCatalog.t('label.transport_utp'),
                  ),
                ],
                onChanged: viewModel.isBusy ? null : viewModel.setTransportMode,
              ),
              const SizedBox(height: 14),
              MaydayTextField(
                label: textCatalog.t('label.failback_delay'),
                controller: viewModel.failbackDelayController,
                helperText: textCatalog.t('label.failback_delay_helper'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SettingsCollapsibleSection(
          title: textCatalog.t('section.metrics'),
          initiallyExpanded: false,
          expandTooltip: textCatalog.t('tooltip.expand_section'),
          collapseTooltip: textCatalog.t('tooltip.collapse_section'),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(textCatalog.t('label.metrics_enabled')),
                value: viewModel.metricsEnabled,
                onChanged:
                    viewModel.isBusy ? null : viewModel.setMetricsEnabled,
              ),
              const Hairline(),
              MaydayTextField(
                label: textCatalog.t('label.metrics_window'),
                controller: viewModel.metricsWindowController,
                helperText: textCatalog.t('label.metrics_window_helper'),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(textCatalog.t('label.metrics_file_enabled')),
                value: viewModel.metricsFileEnabled,
                onChanged:
                    viewModel.isBusy ? null : viewModel.setMetricsFileEnabled,
              ),
              const Hairline(),
              MaydayTextField(
                label: textCatalog.t('label.metrics_file_dir'),
                controller: viewModel.metricsFileDirController,
                helperText: textCatalog.t('label.metrics_file_dir_helper'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle(textCatalog.t('section.relays')),
        const SizedBox(height: 8),
        SurfacePanel(
          child: RelayNameList(
            relays: viewModel.relays,
            textCatalog: textCatalog,
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle(textCatalog.t('section.servers')),
        const SizedBox(height: 8),
        SurfacePanel(
          child: ServerPriorityList(
            servers: viewModel.servers,
            textCatalog: textCatalog,
            enabled: !viewModel.isBusy,
            onReorder: viewModel.reorderServers,
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle(textCatalog.t('section.split_routing')),
        const SizedBox(height: 8),
        SurfacePanel(
          child: SplitTunnelAppsPanel(
            textCatalog: textCatalog,
            mode: viewModel.splitTunnelMode,
            apps: viewModel.windowsApps,
            enabled: !viewModel.isBusy,
            onModeChanged:
                viewModel.isBusy ? null : viewModel.setSplitTunnelMode,
            onPickFile:
                viewModel.isBusy ? null : viewModel.addSplitTunnelAppFromFile,
            onPickRunning: viewModel.isBusy ? null : onPickRunningApp,
            onRemove: viewModel.isBusy ? null : viewModel.removeSplitTunnelApp,
          ),
        ),
        const SizedBox(height: 18),
        SettingsCollapsibleSection(
          title: textCatalog.t('section.diagnostics'),
          initiallyExpanded: false,
          expandTooltip: textCatalog.t('tooltip.expand_section'),
          collapseTooltip: textCatalog.t('tooltip.collapse_section'),
          child: Column(
            children: [
              StatRow(
                label: textCatalog.t('label.engine'),
                value: viewModel.engineReady
                    ? textCatalog.t('status.ready')
                    : textCatalog.t('status.missing'),
                accent: viewModel.engineReady
                    ? MaydayColors.accent
                    : MaydayColors.danger,
              ),
              const Hairline(),
              StatRow(
                label: textCatalog.t('label.relays'),
                value: '${profile.relays.length}',
              ),
              if (viewModel.paths != null) ...[
                const Hairline(),
                StatRow(
                  label: textCatalog.t('section.config'),
                  value: viewModel.paths!.configPath,
                ),
                const Hairline(),
                StatRow(
                  label: textCatalog.t('label.metrics_dir'),
                  value: viewModel.metricsDirectory(profile),
                ),
              ],
              if (viewModel.lastImportedPath != null) ...[
                const Hairline(),
                StatRow(
                  label: textCatalog.t('section.imported'),
                  value: viewModel.lastImportedPath!,
                ),
              ],
              if (viewModel.missingRuntimeFiles.isNotEmpty) ...[
                const Hairline(),
                MissingFilesList(
                  files: viewModel.missingRuntimeFiles,
                  title: textCatalog.t('title.missing_runtime_files'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class RelayNameList extends StatelessWidget {
  const RelayNameList({
    super.key,
    required this.relays,
    required this.textCatalog,
  });

  final List<RelayTarget> relays;
  final AppTextCatalog textCatalog;

  @override
  Widget build(BuildContext context) {
    if (relays.isEmpty) {
      return Text(
        textCatalog.t('title.section_relays_none'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: MaydayColors.muted,
            ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < relays.length; index += 1)
          _RelayNameTile(
            relay: relays[index],
            index: index,
            textCatalog: textCatalog,
            showDivider: index < relays.length - 1,
          ),
      ],
    );
  }
}

class _RelayNameTile extends StatelessWidget {
  const _RelayNameTile({
    required this.relay,
    required this.index,
    required this.textCatalog,
    required this.showDivider,
  });

  final RelayTarget relay;
  final int index;
  final AppTextCatalog textCatalog;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = relay.id.trim().isEmpty
        ? textCatalog.t('title.relay_item', {'index': index + 1})
        : relay.id.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: showDivider
              ? const BorderSide(color: MaydayColors.hairline)
              : BorderSide.none,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: MaydayColors.accentSoft,
                borderRadius: BorderRadius.circular(MaydayRadii.medium),
                border: Border.all(color: MaydayColors.border),
              ),
              child: const SizedBox.square(
                dimension: 42,
                child: Center(
                  child: Icon(
                    Icons.hub_outlined,
                    size: 19,
                    color: MaydayColors.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsCollapsibleSection extends StatefulWidget {
  const SettingsCollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    required this.expandTooltip,
    required this.collapseTooltip,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final String expandTooltip;
  final String collapseTooltip;
  final bool initiallyExpanded;

  @override
  State<SettingsCollapsibleSection> createState() =>
      _SettingsCollapsibleSectionState();
}

class _SettingsCollapsibleSectionState
    extends State<SettingsCollapsibleSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SectionTitle(widget.title)),
            Tooltip(
              message:
                  _expanded ? widget.collapseTooltip : widget.expandTooltip,
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _expanded = !_expanded;
                  });
                },
                icon: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
              ),
            ),
          ],
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          SurfacePanel(child: widget.child),
        ],
      ],
    );
  }
}

class SettingsActions extends StatelessWidget {
  const SettingsActions({
    super.key,
    required this.textCatalog,
    required this.enabled,
    required this.onImportConfig,
    required this.onImportKey,
  });

  final AppTextCatalog textCatalog;
  final bool enabled;
  final VoidCallback onImportConfig;
  final VoidCallback onImportKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: enabled ? onImportConfig : null,
            icon: const Icon(Icons.upload_file_outlined),
            label: ButtonLabel(textCatalog.t('button.import_config')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: enabled ? onImportKey : null,
            icon: const Icon(Icons.key_outlined),
            label: ButtonLabel(textCatalog.t('button.import_key')),
          ),
        ),
      ],
    );
  }
}

class SettingsSaveButton extends StatelessWidget {
  const SettingsSaveButton({
    super.key,
    required this.textCatalog,
    required this.enabled,
    required this.onSave,
  });

  final AppTextCatalog textCatalog;
  final bool enabled;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Tooltip(
        message: textCatalog.t('button.save_settings'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        verticalOffset: 36,
        child: FilledButton(
          onPressed: enabled ? onSave : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.square(58),
            fixedSize: const Size.square(58),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MaydayRadii.large),
            ),
            backgroundColor: MaydayColors.accent,
            foregroundColor: MaydayColors.sunken,
            disabledBackgroundColor: MaydayColors.chip,
            disabledForegroundColor: MaydayColors.subtle,
          ),
          child: const Icon(Icons.save_outlined, size: 25),
        ),
      ),
    );
  }
}
