import 'package:flutter/material.dart';

import '../../../../app/mayday_theme.dart';
import '../../../../core/l10n/app_texts.dart';
import '../home_view_model.dart';

class MaydayBackground extends StatelessWidget {
  const MaydayBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MaydayColors.background,
      child: child,
    );
  }
}

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.appLanguage,
    required this.textCatalog,
    required this.onReload,
    required this.onLanguageChanged,
  });

  final AppLanguage appLanguage;
  final AppTextCatalog textCatalog;
  final VoidCallback? onReload;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                textCatalog.t('home.mayday'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineMedium,
              ),
              Text(
                textCatalog.t('app.network_client'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: MaydayColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        LanguageButton(
          appLanguage: appLanguage,
          textCatalog: textCatalog,
          onChanged: onLanguageChanged,
        ),
        const SizedBox(width: 8),
        SquareIconButton(
          tooltip: textCatalog.t('button.reload'),
          icon: Icons.refresh_outlined,
          onPressed: onReload,
        ),
      ],
    );
  }
}

class ScreenTabs extends StatelessWidget {
  const ScreenTabs({
    super.key,
    required this.selected,
    required this.textCatalog,
    required this.onChanged,
  });

  final HomeSection selected;
  final AppTextCatalog textCatalog;
  final ValueChanged<HomeSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MaydayColors.chip,
        borderRadius: BorderRadius.circular(MaydayRadii.medium),
        border: Border.all(color: MaydayColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            Expanded(
              child: _ScreenTabButton(
                icon: Icons.power_settings_new_outlined,
                label: textCatalog.t('nav.connection'),
                selected: selected == HomeSection.connection,
                onTap: () => onChanged(HomeSection.connection),
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: _ScreenTabButton(
                icon: Icons.tune_outlined,
                label: textCatalog.t('nav.settings'),
                selected: selected == HomeSection.settings,
                onTap: () => onChanged(HomeSection.settings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenTabButton extends StatelessWidget {
  const _ScreenTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? MaydayColors.text : MaydayColors.muted;

    return Material(
      color: selected ? MaydayColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(MaydayRadii.small),
      child: InkWell(
        borderRadius: BorderRadius.circular(MaydayRadii.small),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LanguageButton extends StatelessWidget {
  const LanguageButton({
    super.key,
    required this.appLanguage,
    required this.textCatalog,
    required this.onChanged,
  });

  final AppLanguage appLanguage;
  final AppTextCatalog textCatalog;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    final languageCode = appLanguage == AppLanguage.english ? 'EN' : 'RU';
    final currentLanguage = appLanguage == AppLanguage.english
        ? textCatalog.t('language.english')
        : textCatalog.t('language.russian');
    final textTheme = Theme.of(context).textTheme;

    return Tooltip(
      message: '${textCatalog.t('language.label')}: $currentLanguage',
      child: PopupMenuButton<AppLanguage>(
        initialValue: appLanguage,
        tooltip: '',
        color: MaydayColors.surface,
        elevation: 8,
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MaydayRadii.medium),
          side: const BorderSide(color: MaydayColors.border),
        ),
        onSelected: onChanged,
        itemBuilder: (context) => [
          for (final language in AppLanguage.values)
            PopupMenuItem<AppLanguage>(
              value: language,
              height: 40,
              child: Text(
                language == AppLanguage.english
                    ? textCatalog.t('language.english')
                    : textCatalog.t('language.russian'),
                style: textTheme.bodyMedium,
              ),
            ),
        ],
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: MaydayColors.surface,
            borderRadius: BorderRadius.circular(MaydayRadii.medium),
            border: Border.all(color: MaydayColors.border),
          ),
          child: SizedBox(
            width: 70,
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.language_outlined, size: 17),
                  const SizedBox(width: 6),
                  Text(
                    languageCode,
                    style: textTheme.labelLarge?.copyWith(
                      color: MaydayColors.text,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.keyboard_arrow_down_outlined, size: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MaydayColors.surface,
          borderRadius: BorderRadius.circular(MaydayRadii.medium),
          border: Border.all(color: MaydayColors.border),
        ),
        child: SizedBox.square(
          dimension: 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
          ),
        ),
      ),
    );
  }
}
