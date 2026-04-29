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
  });

  final HomeViewModel viewModel;
  final AppTextCatalog textCatalog;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final profile = viewModel.collectProfile();
    final configReady = viewModel.configurationReady(profile);

    return Column(
      children: [
        HeroPanel(
          statusText: viewModel.connectionStatus,
          statusColor: _connectionStatusColor,
          title: profile.displayName.isEmpty
              ? textCatalog.t('home.primary')
              : profile.displayName,
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
                  : viewModel.saveAndLaunch,
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
                label: textCatalog.t('label.config'),
                value: configReady
                    ? textCatalog.t('status.ready')
                    : textCatalog.t('status.not_set'),
                accent: configReady ? MaydayColors.accent : MaydayColors.warn,
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onOpenSettings,
          icon: const Icon(Icons.tune_outlined),
          label: ButtonLabel(textCatalog.t('button.open_settings')),
        ),
        if (!viewModel.engineReady) ...[
          const SizedBox(height: 18),
          SectionTitle(textCatalog.t('section.diagnostics')),
          const SizedBox(height: 8),
          SurfacePanel(
            child: MissingFilesList(
              files: viewModel.missingRuntimeFiles,
              title: textCatalog.t('title.missing_runtime_files'),
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
