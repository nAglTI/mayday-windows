import 'package:flutter/material.dart';

import '../../../../app/mayday_theme.dart';
import '../../../../core/l10n/app_texts.dart';
import '../../../../core/models/server_target.dart';

class ServerPriorityList extends StatelessWidget {
  const ServerPriorityList({
    super.key,
    required this.servers,
    required this.textCatalog,
    required this.enabled,
    required this.onReorder,
  });

  final List<ServerTarget> servers;
  final AppTextCatalog textCatalog;
  final bool enabled;
  final ReorderCallback onReorder;

  @override
  Widget build(BuildContext context) {
    if (servers.isEmpty) {
      return Text(
        textCatalog.t('title.section_servers_none'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: MaydayColors.muted,
            ),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final elevation = Tween<double>(begin: 0, end: 8).evaluate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            return Material(
              color: Colors.transparent,
              elevation: elevation,
              borderRadius: BorderRadius.circular(MaydayRadii.large),
              child: child,
            );
          },
          child: child,
        );
      },
      itemCount: servers.length,
      onReorder: enabled ? onReorder : (_, __) {},
      itemBuilder: (context, index) {
        final server = servers[index];
        return _ServerPriorityTile(
          key: ValueKey('${server.id}-${server.key.hashCode}'),
          server: server,
          textCatalog: textCatalog,
          index: index,
          enabled: enabled,
          showDivider: index < servers.length - 1,
        );
      },
    );
  }
}

class _ServerPriorityTile extends StatelessWidget {
  const _ServerPriorityTile({
    super.key,
    required this.server,
    required this.index,
    required this.textCatalog,
    required this.enabled,
    required this.showDivider,
  });

  final ServerTarget server;
  final int index;
  final AppTextCatalog textCatalog;
  final bool enabled;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
              child: SizedBox.square(
                dimension: 42,
                child: Center(
                  child: Text(
                    '#${server.priority}',
                    style: textTheme.labelLarge?.copyWith(
                      color: MaydayColors.accent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.id.isEmpty
                        ? textCatalog.t('title.server_item', {
                            'index': index + 1,
                          })
                        : server.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${textCatalog.t('label.priority')} ${server.priority}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: MaydayColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              enabled: enabled,
              child: Tooltip(
                message: textCatalog.t('tooltip.move'),
                child: const Icon(
                  Icons.drag_handle_outlined,
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
