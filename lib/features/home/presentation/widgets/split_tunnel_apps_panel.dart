import 'package:flutter/material.dart';

import '../../../../app/mayday_theme.dart';
import '../../../../core/l10n/app_texts.dart';
import '../../../../core/models/split_tunnel_mode.dart';
import 'common_widgets.dart';

class SplitTunnelAppsPanel extends StatelessWidget {
  const SplitTunnelAppsPanel({
    super.key,
    required this.textCatalog,
    required this.mode,
    required this.apps,
    required this.enabled,
    required this.onModeChanged,
    required this.onPickFile,
    required this.onPickRunning,
    required this.onRemove,
  });

  final SplitTunnelMode mode;
  final List<String> apps;
  final bool enabled;
  final AppTextCatalog textCatalog;
  final ValueChanged<SplitTunnelMode>? onModeChanged;
  final VoidCallback? onPickFile;
  final VoidCallback? onPickRunning;
  final ValueChanged<String>? onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedField<SplitTunnelMode>(
          label: textCatalog.t('label.mode'),
          selected: mode,
          segments: [
            Segment(
              value: SplitTunnelMode.disabled,
              label: textCatalog.t('label.all_traffic'),
            ),
            Segment(
              value: SplitTunnelMode.onlySelected,
              label: textCatalog.t('label.only_selected'),
            ),
            Segment(
              value: SplitTunnelMode.excludeSelected,
              label: textCatalog.t('label.except'),
            ),
          ],
          onChanged: onModeChanged,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? onPickFile : null,
                icon: const Icon(Icons.folder_open_outlined),
                label: ButtonLabel(textCatalog.t('button.choose_exe')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? onPickRunning : null,
                icon: const Icon(Icons.window_outlined),
                label: ButtonLabel(textCatalog.t('button.running_app')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (apps.isEmpty)
          _EmptySplitTunnelList(mode: mode, textCatalog: textCatalog)
        else
          _SplitTunnelAppList(
            apps: apps,
            textCatalog: textCatalog,
            onRemove: onRemove,
          ),
      ],
    );
  }
}

class _EmptySplitTunnelList extends StatelessWidget {
  const _EmptySplitTunnelList({
    required this.mode,
    required this.textCatalog,
  });

  final SplitTunnelMode mode;
  final AppTextCatalog textCatalog;

  @override
  Widget build(BuildContext context) {
    final message = mode == SplitTunnelMode.disabled
        ? textCatalog.t('title.split_disabled_hint')
        : textCatalog.t('title.split_empty_hint');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: MaydayColors.sunken,
        borderRadius: BorderRadius.circular(MaydayRadii.large),
        border: Border.all(color: MaydayColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.route_outlined, color: MaydayColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: MaydayColors.muted,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitTunnelAppList extends StatelessWidget {
  const _SplitTunnelAppList({
    required this.apps,
    required this.textCatalog,
    required this.onRemove,
  });

  final List<String> apps;
  final AppTextCatalog textCatalog;
  final ValueChanged<String>? onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MaydayColors.sunken,
        borderRadius: BorderRadius.circular(MaydayRadii.large),
        border: Border.all(color: MaydayColors.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < apps.length; index += 1)
            _SplitTunnelAppTile(
              appPath: apps[index],
              textCatalog: textCatalog,
              showDivider: index < apps.length - 1,
              onRemove: onRemove,
            ),
        ],
      ),
    );
  }
}

class _SplitTunnelAppTile extends StatelessWidget {
  const _SplitTunnelAppTile({
    required this.appPath,
    required this.textCatalog,
    required this.showDivider,
    required this.onRemove,
  });

  final String appPath;
  final AppTextCatalog textCatalog;
  final bool showDivider;
  final ValueChanged<String>? onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = _basename(appPath);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: showDivider
              ? const BorderSide(color: MaydayColors.hairline)
              : BorderSide.none,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: MaydayColors.chip,
                borderRadius: BorderRadius.circular(MaydayRadii.medium),
                border: Border.all(color: MaydayColors.border),
              ),
              child: const SizedBox.square(
                dimension: 38,
                child: Icon(
                  Icons.apps_outlined,
                  size: 18,
                  color: MaydayColors.muted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    appPath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: MaydayColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: textCatalog.t('tooltip.remove'),
              child: IconButton(
                onPressed: onRemove == null ? null : () => onRemove!(appPath),
                icon: const Icon(Icons.close_outlined, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.split('/').last;
  }
}
