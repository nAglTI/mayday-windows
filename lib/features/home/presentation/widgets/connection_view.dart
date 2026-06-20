import 'package:flutter/material.dart';

import '../../../../app/mayday_theme.dart';
import '../../../../core/l10n/app_texts.dart';
import '../home_view_model.dart';
import 'common_widgets.dart';

class ConnectionView extends StatelessWidget {
  const ConnectionView({
    super.key,
    required this.viewModel,
    required this.textCatalog,
    required this.onOpenSettings,
    required this.onConnect,
    required this.onPreflightScan,
    required this.onOpenPreflightResults,
  });

  final HomeViewModel viewModel;
  final AppTextCatalog textCatalog;
  final VoidCallback onOpenSettings;
  final VoidCallback onConnect;
  final VoidCallback onPreflightScan;
  final VoidCallback onOpenPreflightResults;

  @override
  Widget build(BuildContext context) {
    final profile = viewModel.collectProfile();
    final configReady = viewModel.configurationReady(profile);
    final userId = profile.userId.trim();

    return Column(
      children: [
        HeroPanel(
          statusText: viewModel.connectionStatus,
          statusColor: _connectionStatusColor,
          title: textCatalog.t('app.title'),
          subtitle: viewModel.connectionSummary(profile, viewModel.engineReady),
          detail: textCatalog.t('app.network_client'),
          actionText: viewModel.isBusy
              ? textCatalog.t(viewModel.busyStatusText)
              : viewModel.isRuntimeStarted
                  ? textCatalog.t('button.stop')
                  : textCatalog.t('button.connect'),
          onAction: viewModel.isBusy
              ? null
              : viewModel.isRuntimeStarted
                  ? viewModel.stopConnection
                  : onConnect,
        ),
        const SizedBox(height: 12),
        HomeMessagePanel(viewModel: viewModel),
        const SizedBox(height: 18),
        SurfacePanel(
          child: Column(
            children: [
              StatRow(
                label: textCatalog.t('label.status'),
                value: viewModel.statusLine,
                accent: _connectionStatusColor,
              ),
              const Hairline(),
              StatRow(
                label: textCatalog.t('label.user_id'),
                value:
                    userId.isEmpty ? textCatalog.t('status.not_set') : userId,
                accent: userId.isEmpty ? MaydayColors.warn : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CollapsibleSection(
          title: textCatalog.t('section.advanced'),
          initiallyExpanded: false,
          expandTooltip: textCatalog.t('tooltip.expand_section'),
          collapseTooltip: textCatalog.t('tooltip.collapse_section'),
          child: _ConnectionAdvancedDetails(
            viewModel: viewModel,
            textCatalog: textCatalog,
            configReady: configReady,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: viewModel.isBusy || viewModel.isRuntimeStarted
                    ? null
                    : onPreflightScan,
                icon: const Icon(Icons.health_and_safety_outlined),
                label: ButtonLabel(textCatalog.t('button.preflight_scan')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.tune_outlined),
                label: ButtonLabel(textCatalog.t('button.open_settings')),
              ),
            ),
          ],
        ),
        if (viewModel.hasBadAppScanResult) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: viewModel.isBusy ? null : onOpenPreflightResults,
              icon: const Icon(Icons.fact_check_outlined),
              label: ButtonLabel(textCatalog.t('button.open_scan_results')),
            ),
          ),
        ],
      ],
    );
  }

  Color get _connectionStatusColor {
    if (viewModel.errorMessage != null) {
      return MaydayColors.danger;
    }
    if (viewModel.isBusy) {
      return MaydayColors.warn;
    }
    if (viewModel.isRuntimeStarted) {
      return MaydayColors.accent;
    }
    return MaydayColors.muted;
  }
}

class _ConnectionAdvancedDetails extends StatelessWidget {
  const _ConnectionAdvancedDetails({
    required this.viewModel,
    required this.textCatalog,
    required this.configReady,
  });

  final HomeViewModel viewModel;
  final AppTextCatalog textCatalog;
  final bool configReady;

  @override
  Widget build(BuildContext context) {
    final runtimeStatus = viewModel.runtimeStatus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatRow(
          label: textCatalog.t('label.config'),
          value: configReady
              ? textCatalog.t('status.ready')
              : textCatalog.t('status.not_set'),
          accent: configReady ? MaydayColors.accent : MaydayColors.warn,
        ),
        const Hairline(),
        StatRow(
          label: textCatalog.t('label.engine'),
          value: viewModel.engineReady
              ? textCatalog.t('status.ready')
              : textCatalog.t('status.missing'),
          accent:
              viewModel.engineReady ? MaydayColors.accent : MaydayColors.danger,
        ),
        const Hairline(),
        StatRow(
          label: textCatalog.t('label.transport_mode'),
          value: viewModel.transportModeLabel(viewModel.transportMode),
        ),
        if (viewModel.isRuntimeStarted && !runtimeStatus.hasData) ...[
          const Hairline(),
          StatRow(
            label: textCatalog.t('label.runtime_status'),
            value: textCatalog.t('status.runtime_status_waiting'),
            accent: MaydayColors.muted,
          ),
        ],
        if (runtimeStatus.coreState.isNotEmpty) ...[
          const Hairline(),
          StatRow(
            label: textCatalog.t('label.core_state'),
            value: runtimeStatus.coreState,
          ),
        ],
        if (runtimeStatus.vpnState.isNotEmpty) ...[
          const Hairline(),
          StatRow(
            label: textCatalog.t('label.vpn_state'),
            value: runtimeStatus.vpnState,
          ),
        ],
        if (runtimeStatus.activeRelayId.isNotEmpty) ...[
          const Hairline(),
          StatRow(
            label: textCatalog.t('label.active_relay'),
            value: runtimeStatus.activeRelayId,
          ),
        ],
        if (runtimeStatus.activeTransportId.isNotEmpty) ...[
          const Hairline(),
          StatRow(
            label: textCatalog.t('label.active_transport'),
            value: viewModel
                .runtimeTransportLabel(runtimeStatus.activeTransportId),
          ),
        ],
        if (runtimeStatus.activeServerId.isNotEmpty) ...[
          const Hairline(),
          StatRow(
            label: textCatalog.t('label.exit_server'),
            value: runtimeStatus.activeServerId,
          ),
        ],
        if (runtimeStatus.hasRates) ...[
          if (runtimeStatus.uploadBps > 0) ...[
            const Hairline(),
            StatRow(
              label: textCatalog.t('label.upload_rate'),
              value: viewModel.rateLabel(runtimeStatus.uploadBps),
            ),
          ],
          if (runtimeStatus.downloadBps > 0) ...[
            const Hairline(),
            StatRow(
              label: textCatalog.t('label.download_rate'),
              value: viewModel.rateLabel(runtimeStatus.downloadBps),
            ),
          ],
          if (runtimeStatus.aggregateBps > 0) ...[
            const Hairline(),
            StatRow(
              label: textCatalog.t('label.total_rate'),
              value: viewModel.rateLabel(runtimeStatus.aggregateBps),
            ),
          ],
        ],
        if (runtimeStatus.protocolDiagnostics.isNotEmpty) ...[
          const Hairline(),
          DiagnosticsTextBlock(
            label: textCatalog.t('label.protocols'),
            rows: runtimeStatus.protocolDiagnostics,
          ),
        ],
        if (runtimeStatus.endpointDiagnostics.isNotEmpty) ...[
          const Hairline(),
          DiagnosticsTextBlock(
            label: textCatalog.t('label.endpoints'),
            rows: runtimeStatus.endpointDiagnostics,
          ),
        ],
        const Hairline(),
        StatRow(
          label: textCatalog.t('label.relays'),
          value: '${viewModel.relays.length}',
        ),
        const Hairline(),
        StatRow(
          label: textCatalog.t('label.servers'),
          value: '${viewModel.servers.length}',
        ),
        const Hairline(),
        StatRow(
          label: textCatalog.t('label.mode'),
          value: viewModel.splitModeLabel(viewModel.splitTunnelMode),
        ),
        const Hairline(),
        StatRow(
          label: textCatalog.t('label.preflight_scan'),
          value: viewModel.badAppScanSummary,
          accent: _preflightScanColor,
        ),
        if (!viewModel.engineReady) ...[
          const Hairline(),
          MissingFilesList(
            files: viewModel.missingRuntimeFiles,
            title: textCatalog.t('title.missing_runtime_files'),
          ),
        ],
      ],
    );
  }

  Color? get _preflightScanColor {
    if (viewModel.badAppScanFailed) {
      return MaydayColors.warn;
    }
    final findings = viewModel.badAppFindings;
    if (findings == null) {
      return MaydayColors.muted;
    }
    return findings.isEmpty ? MaydayColors.accent : MaydayColors.danger;
  }
}

class DiagnosticsTextBlock extends StatelessWidget {
  const DiagnosticsTextBlock({
    super.key,
    required this.label,
    required this.rows,
  });

  final String label;
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: textTheme.labelMedium?.copyWith(color: MaydayColors.muted),
        ),
        const SizedBox(height: 6),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              row,
              style: textTheme.bodySmall?.copyWith(color: MaydayColors.text),
            ),
          ),
      ],
    );
  }
}

class HomeMessagePanel extends StatelessWidget {
  const HomeMessagePanel({
    super.key,
    required this.viewModel,
  });

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.errorMessage != null) {
      return MessagePanel(
        message: viewModel.errorMessage!,
        color: MaydayColors.danger,
        backgroundColor: const Color(0xFF2A1913),
      );
    }

    if (viewModel.warningMessage != null) {
      return MessagePanel(
        message: viewModel.warningMessage!,
        color: MaydayColors.warn,
        backgroundColor: const Color(0xFF282315),
      );
    }

    if (viewModel.statusMessage != null) {
      return MessagePanel(
        message: viewModel.statusMessage!,
        color: MaydayColors.accent,
        backgroundColor: MaydayColors.accentSoft,
      );
    }

    return const SizedBox.shrink();
  }
}
