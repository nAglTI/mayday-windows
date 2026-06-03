import 'package:flutter/material.dart';

import '../../../../app/mayday_theme.dart';
import '../../../../core/l10n/app_texts.dart';
import '../../../../core/models/network_rescue_config.dart';
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
          child: StatRow(
            label: textCatalog.t('label.user_id'),
            value: profile.userId.trim().isEmpty
                ? textCatalog.t('status.not_set')
                : profile.userId.trim(),
          ),
        ),
        const SizedBox(height: 18),
        CollapsibleSection(
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
              DropdownField<TransportMode>(
                label: textCatalog.t('label.transport_mode'),
                selected: viewModel.transportMode,
                options: [
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
                  Segment(
                    value: TransportMode.ws,
                    label: textCatalog.t('label.transport_ws'),
                  ),
                  Segment(
                    value: TransportMode.https,
                    label: textCatalog.t('label.transport_https'),
                  ),
                  Segment(
                    value: TransportMode.rawUdp,
                    label: textCatalog.t('label.transport_raw_udp'),
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
        CollapsibleSection(
          title: textCatalog.t('section.runtime_options'),
          initiallyExpanded: false,
          expandTooltip: textCatalog.t('tooltip.expand_section'),
          collapseTooltip: textCatalog.t('tooltip.collapse_section'),
          child: RuntimeOptionsPanel(
            viewModel: viewModel,
            textCatalog: textCatalog,
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
        CollapsibleSection(
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

class RuntimeOptionsPanel extends StatelessWidget {
  const RuntimeOptionsPanel({
    super.key,
    required this.viewModel,
    required this.textCatalog,
  });

  final HomeViewModel viewModel;
  final AppTextCatalog textCatalog;

  @override
  Widget build(BuildContext context) {
    final enabled = !viewModel.isBusy;

    return Column(
      children: [
        DropdownField<NetworkRescueProfile>(
          label: textCatalog.t('label.network_rescue'),
          selected: viewModel.networkRescueProfile,
          options: [
            Segment(
              value: NetworkRescueProfile.off,
              label: textCatalog.t('label.network_rescue_off'),
            ),
            Segment(
              value: NetworkRescueProfile.stable,
              label: textCatalog.t('label.network_rescue_stable'),
            ),
            Segment(
              value: NetworkRescueProfile.extreme,
              label: textCatalog.t('label.network_rescue_extreme'),
            ),
          ],
          onChanged: enabled ? viewModel.setNetworkRescueProfile : null,
        ),
        const SizedBox(height: 6),
        Text(
          textCatalog.t('label.network_rescue_helper'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MaydayColors.muted,
              ),
        ),
        const Hairline(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.travel_explore_outlined),
          title: Text(textCatalog.t('label.prestart_full_probe')),
          value: viewModel.prestartFullProbe,
          onChanged: enabled ? viewModel.setPrestartFullProbe : null,
        ),
        const Hairline(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.speed_outlined),
          title: Text(textCatalog.t('label.steady_quick_probe')),
          value: viewModel.steadyStateQuickProbeEnabled,
          onChanged: enabled ? viewModel.setSteadyStateQuickProbeEnabled : null,
        ),
        const Hairline(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.analytics_outlined),
          title: Text(textCatalog.t('label.metrics_enabled')),
          value: viewModel.metricsEnabled,
          onChanged: enabled ? viewModel.setMetricsEnabled : null,
        ),
        const Hairline(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.query_stats_outlined),
          title: Text(textCatalog.t('label.steady_benchmark')),
          value: viewModel.steadyStateBenchmarkEnabled,
          onChanged: enabled ? viewModel.setSteadyStateBenchmarkEnabled : null,
        ),
        const Hairline(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.public_off_outlined),
          title: Text(textCatalog.t('label.disable_ipv6')),
          value: viewModel.disableIpv6,
          onChanged: enabled ? viewModel.setDisableIpv6 : null,
        ),
        const Hairline(),
        MaydayTextField(
          label: textCatalog.t('label.tunnel_mtu'),
          controller: viewModel.tunnelMtuController,
          helperText: textCatalog.t('label.tunnel_mtu_helper'),
          enabled: enabled,
          keyboardType: TextInputType.number,
          onChanged: viewModel.setTunnelMtuFromText,
        ),
        const SizedBox(height: 14),
        PacketFragmentPayloadField(
          textCatalog: textCatalog,
          enabled: enabled,
          controller: viewModel.packetFragmentPayloadController,
          value: viewModel.packetFragmentPayloadBytes,
          onTextChanged: viewModel.setPacketFragmentPayloadFromText,
          onPresetChanged: viewModel.setPacketFragmentPayloadBytes,
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.layers_clear_outlined),
          title: Text(textCatalog.t('label.disable_packet_batching')),
          value: viewModel.disablePacketBatching,
          onChanged: enabled ? viewModel.setDisablePacketBatching : null,
        ),
      ],
    );
  }
}

class PacketFragmentPayloadField extends StatelessWidget {
  const PacketFragmentPayloadField({
    super.key,
    required this.textCatalog,
    required this.enabled,
    required this.controller,
    required this.value,
    required this.onTextChanged,
    required this.onPresetChanged,
  });

  static const _marks = [0, 64, 100, 256, 512, 1200, 4096, 16384, 65536];

  final AppTextCatalog textCatalog;
  final bool enabled;
  final TextEditingController controller;
  final int value;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<int> onPresetChanged;

  @override
  Widget build(BuildContext context) {
    final currentIndex = _nearestMarkIndex(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MaydayTextField(
          label: textCatalog.t('label.packet_fragment_payload'),
          controller: controller,
          helperText: textCatalog.t('label.packet_fragment_payload_helper'),
          enabled: enabled,
          keyboardType: TextInputType.number,
          onChanged: onTextChanged,
        ),
        const SizedBox(height: 8),
        Slider(
          value: currentIndex.toDouble(),
          min: 0,
          max: (_marks.length - 1).toDouble(),
          divisions: _marks.length - 1,
          label: '${_marks[currentIndex]}',
          onChanged: enabled
              ? (rawIndex) {
                  onPresetChanged(_marks[rawIndex.round()]);
                }
              : null,
        ),
        Row(
          children: [
            Text(
              textCatalog.t('label.packet_fast'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: MaydayColors.muted,
                  ),
            ),
            const Spacer(),
            Text(
              '65536',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: MaydayColors.muted,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  int _nearestMarkIndex(int value) {
    var bestIndex = 0;
    var bestDistance = (value - _marks.first).abs();
    for (var index = 1; index < _marks.length; index += 1) {
      final distance = (value - _marks[index]).abs();
      if (distance < bestDistance) {
        bestIndex = index;
        bestDistance = distance;
      }
    }
    return bestIndex;
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

class SettingsActions extends StatelessWidget {
  const SettingsActions({
    super.key,
    required this.textCatalog,
    required this.enabled,
    required this.onImportKey,
  });

  final AppTextCatalog textCatalog;
  final bool enabled;
  final VoidCallback onImportKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enabled ? onImportKey : null,
        icon: const Icon(Icons.key_outlined),
        label: ButtonLabel(textCatalog.t('button.import_key')),
      ),
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
