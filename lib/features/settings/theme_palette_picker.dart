import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/app/theme/flax_theme.dart';
import 'package:flax/app/theme/theme_palette.dart';
import 'package:flax/app/theme/theme_provider.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/shared/widgets/hover_effects.dart';

extension ThemePaletteLabels on ThemePalette {
  String label(AppLocalizations? l10n) => switch (this) {
    ThemePalette.device => l10n?.themePaletteDevice ?? 'Device',
    ThemePalette.flax => l10n?.themePaletteFlax ?? 'Flax',
    ThemePalette.album => l10n?.themePaletteAlbum ?? 'Album',
    ThemePalette.evergreen => l10n?.themePaletteEvergreen ?? 'Evergreen',
    ThemePalette.nord => l10n?.themePaletteNord ?? 'Nord',
    ThemePalette.catppuccin => l10n?.themePaletteCatppuccin ?? 'Catppuccin',
    ThemePalette.dracula => l10n?.themePaletteDracula ?? 'Dracula',
    ThemePalette.gruvbox => l10n?.themePaletteGruvbox ?? 'Gruvbox',
    ThemePalette.synthwave => l10n?.themePaletteSynthwave ?? 'Synthwave',
  };

  String description(AppLocalizations? l10n) => switch (this) {
    ThemePalette.device =>
      l10n?.themePaletteDeviceDescription ?? 'Your wallpaper or accent color',
    ThemePalette.flax => l10n?.themePaletteFlaxDescription ?? 'Classic violet',
    ThemePalette.album =>
      l10n?.themePaletteAlbumDescription ?? 'Colors follow the playing cover',
    ThemePalette.evergreen =>
      l10n?.themePaletteEvergreenDescription ?? 'Forest greens, night and day',
    ThemePalette.nord =>
      l10n?.themePaletteNordDescription ?? 'Arctic, muted blues',
    ThemePalette.catppuccin =>
      l10n?.themePaletteCatppuccinDescription ?? 'Soft pastels',
    ThemePalette.dracula =>
      l10n?.themePaletteDraculaDescription ?? 'Purple and pink on charcoal',
    ThemePalette.gruvbox =>
      l10n?.themePaletteGruvboxDescription ?? 'Retro warm browns and orange',
    ThemePalette.synthwave =>
      l10n?.themePaletteSynthwaveDescription ?? 'Neon magenta and cyan',
  };
}

/// The color theme picker in Settings, wired to the saved choice.
class ThemePaletteSettings extends ConsumerWidget {
  const ThemePaletteSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(themePaletteProvider);
    final amoled = ref.watch(amoledProvider);
    final device = ref.watch(platformColorSchemesProvider).valueOrNull;
    final album = ref.watch(albumColorSchemesProvider).valueOrNull;
    final brightness = Theme.of(context).brightness;

    return ListTile(
      title: Text(l10n?.colorTheme ?? 'Color theme'),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.colorThemeHint ??
                  'Every theme has a light and a dark version',
            ),
            const SizedBox(height: 12),
            ThemePalettePicker(
              selected: selected,
              schemeFor: (palette) {
                final scheme = resolvePaletteScheme(
                  palette,
                  brightness,
                  device: device,
                  album: album,
                );
                return amoled && brightness == Brightness.dark
                    ? FlaxTheme.amoledScheme(scheme)
                    : scheme;
              },
              onSelected: (palette) =>
                  ref.read(themePaletteProvider.notifier).set(palette),
            ),
          ],
        ),
      ),
    );
  }
}

/// A swatch for every [ThemePalette], each a small sketch of the app drawn in
/// that palette's colors. No providers, so it can be tested on its own.
class ThemePalettePicker extends StatelessWidget {
  const ThemePalettePicker({
    super.key,
    required this.selected,
    required this.schemeFor,
    required this.onSelected,
  });

  final ThemePalette selected;
  final ColorScheme Function(ThemePalette palette) schemeFor;
  final ValueChanged<ThemePalette> onSelected;

  static const _spacing = 12.0;
  static const _maxTileWidth = 156.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // At least two across on a phone: a single column of swatches is a
        // long scroll for nine choices.
        final width = constraints.maxWidth;
        final perRow = ((width + _spacing) / (_maxTileWidth + _spacing))
            .floor()
            .clamp(2, 99);
        final tileWidth = ((width - _spacing * (perRow - 1)) / perRow).clamp(
          0.0,
          _maxTileWidth,
        );
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final palette in ThemePalette.values)
              SizedBox(
                width: tileWidth,
                child: _PaletteTile(
                  key: ValueKey('theme-palette-${palette.name}'),
                  palette: palette,
                  scheme: schemeFor(palette),
                  selected: palette == selected,
                  onTap: () => onSelected(palette),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    super.key,
    required this.palette,
    required this.scheme,
    required this.selected,
    required this.onTap,
  });

  final ThemePalette palette;
  final ColorScheme scheme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = theme.colorScheme;
    final radius = BorderRadius.circular(12);

    return Semantics(
      selected: selected,
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: selected
              ? colors.primaryContainer.withValues(alpha: 0.5)
              : colors.surfaceContainerLow,
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: HoverSurface(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PalettePreview(scheme: scheme),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        palette.label(l10n),
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check_circle, size: 16, color: colors.primary),
                    ],
                  ],
                ),
                Text(
                  palette.description(l10n),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A sidebar, two lines of text and the accent colors, in [scheme].
class _PalettePreview extends StatelessWidget {
  const _PalettePreview({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    Widget bar(Color color, double width, {double height = 4}) => Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
    Widget dot(Color color) => Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    final muted = scheme.onSurfaceVariant.withValues(alpha: 0.6);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              color: scheme.surfaceContainerHigh,
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(scheme.primary, 18),
                  bar(muted, 14),
                  bar(muted, 16),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(scheme.onSurface, 44, height: 5),
                    bar(muted, 30),
                    const Spacer(),
                    Row(
                      children: [
                        dot(scheme.primary),
                        dot(scheme.secondary),
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: scheme.tertiary.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
