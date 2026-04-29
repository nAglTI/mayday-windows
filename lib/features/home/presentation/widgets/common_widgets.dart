import 'package:flutter/material.dart';

import '../../../../app/mayday_theme.dart';

class HeroPanel extends StatelessWidget {
  const HeroPanel({
    super.key,
    required this.statusText,
    required this.statusColor,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.actionText,
    required this.onAction,
  });

  final String statusText;
  final Color statusColor;
  final String title;
  final String subtitle;
  final String detail;
  final String actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: MaydayColors.surface,
        borderRadius: BorderRadius.circular(MaydayRadii.extraLarge),
        border: Border.all(color: MaydayColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusDot(color: statusColor),
                const SizedBox(width: 8),
                Text(
                  statusText.toUpperCase(),
                  style: textTheme.labelLarge?.copyWith(
                    color: MaydayColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.displayLarge,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: MaydayColors.muted),
            ),
            const SizedBox(height: 10),
            Text(
              detail,
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAction,
              child: ButtonLabel(actionText),
            ),
          ],
        ),
      ),
    );
  }
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MaydayColors.surface,
        borderRadius: BorderRadius.circular(MaydayRadii.large),
        border: Border.all(color: MaydayColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: MaydayColors.muted,
          ),
    );
  }
}

class StatRow extends StatelessWidget {
  const StatRow({
    super.key,
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: textTheme.labelMedium?.copyWith(color: MaydayColors.muted),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: textTheme.bodySmall?.copyWith(
              color: accent ?? MaydayColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

class Hairline extends StatelessWidget {
  const Hairline({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(),
    );
  }
}

class MissingFilesList extends StatelessWidget {
  const MissingFilesList({
    super.key,
    required this.files,
    required this.title,
  });

  final List<String> files;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        const SizedBox(height: 8),
        for (final file in files)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              file,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: MaydayColors.danger,
                  ),
            ),
          ),
      ],
    );
  }
}

class MessagePanel extends StatelessWidget {
  const MessagePanel({
    super.key,
    required this.message,
    required this.color,
    required this.backgroundColor,
  });

  final String message;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(MaydayRadii.large),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ),
    );
  }
}

class ButtonLabel extends StatelessWidget {
  const ButtonLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      softWrap: true,
    );
  }
}

class MaydayTextField extends StatelessWidget {
  const MaydayTextField({
    super.key,
    required this.label,
    required this.controller,
    this.helperText,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? helperText;
  final int maxLines;

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
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: textTheme.bodyLarge,
          cursorColor: MaydayColors.accent,
          decoration: InputDecoration(helperText: helperText),
        ),
      ],
    );
  }
}

class SegmentedField<T> extends StatelessWidget {
  const SegmentedField({
    super.key,
    required this.label,
    required this.selected,
    required this.segments,
    required this.onChanged,
  });

  final String label;
  final T selected;
  final List<Segment<T>> segments;
  final ValueChanged<T>? onChanged;

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
        DecoratedBox(
          decoration: BoxDecoration(
            color: MaydayColors.chip,
            borderRadius: BorderRadius.circular(MaydayRadii.medium),
            border: Border.all(color: MaydayColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                for (final segment in segments)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: _SegmentButton<T>(
                        segment: segment,
                        selected: segment.value == selected,
                        onChanged: onChanged,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class Segment<T> {
  const Segment({required this.value, required this.label});

  final T value;
  final String label;
}

class _SegmentButton<T> extends StatelessWidget {
  const _SegmentButton({
    required this.segment,
    required this.selected,
    required this.onChanged,
  });

  final Segment<T> segment;
  final bool selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = selected ? MaydayColors.text : MaydayColors.muted;

    return Material(
      color: selected ? MaydayColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(MaydayRadii.small),
      child: InkWell(
        borderRadius: BorderRadius.circular(MaydayRadii.small),
        onTap: onChanged == null ? null : () => onChanged!(segment.value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
          child: Text(
            segment.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: textTheme.labelLarge?.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox.square(dimension: 8),
    );
  }
}
