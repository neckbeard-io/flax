import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/app/theme/theme_palette.dart';
import 'package:flax/app/theme/theme_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/features/settings/theme_palette_picker.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/shared/widgets/up_back_button.dart';
import 'package:flax/shared/widgets/window_buttons.dart';

extension ThemeModeSettingLabels on ThemeModeSetting {
  String label(AppLocalizations? l10n) => switch (this) {
    ThemeModeSetting.system => l10n?.themeSystem ?? 'System',
    ThemeModeSetting.light => l10n?.themeLight ?? 'Light',
    ThemeModeSetting.dark => l10n?.themeDark ?? 'Dark',
  };
}

/// The Settings row's subtitle: "Dark · Nord · AMOLED Pure Black".
String themeSummary(
  AppLocalizations? l10n, {
  required ThemeModeSetting mode,
  required ThemePalette palette,
  required bool amoled,
}) => [
  mode.label(l10n),
  palette.label(l10n),
  if (amoled) l10n?.amoledBlack ?? 'AMOLED Pure Black',
].join(' · ');

/// Light or dark, the color theme and AMOLED black, kept off the main
/// Settings list because the swatches alone fill a phone screen.
class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final amoled = ref.watch(amoledProvider);

    return Scaffold(
      appBar: AppBar(
        // Keeps the title out from under the window controls.
        actions: [SizedBox(width: WindowControlsInset.of(context))],
        leading: const UpBackButton(fallbackLocation: '/settings'),
        title: Text(l10n?.theme ?? 'Theme'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          // Beside the title it needs about 520pt, more than a phone has once
          // the labels are translated, so narrow windows put it underneath.
          LayoutBuilder(
            builder: (context, constraints) {
              final choice = SegmentedButton<ThemeModeSetting>(
                segments: [
                  for (final mode in ThemeModeSetting.values)
                    ButtonSegment(value: mode, label: Text(mode.label(l10n))),
                ],
                selected: {themeMode},
                onSelectionChanged: (s) =>
                    ref.read(themeModeProvider.notifier).set(s.first),
              );
              final title = Text(l10n?.themeMode ?? 'Light or dark');
              if (constraints.maxWidth >= 520) {
                return ListTile(title: title, trailing: choice);
              }
              return ListTile(
                title: title,
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(alignment: Alignment.centerLeft, child: choice),
                ),
              );
            },
          ),
          // Above the swatches, which run past the bottom of a phone.
          SwitchListTile(
            title: Text(l10n?.amoledBlack ?? 'AMOLED Pure Black'),
            subtitle: Text(
              l10n?.amoledBlackSubtitle ??
                  'Pure black behind every dark theme, for OLED screens',
            ),
            value: amoled,
            onChanged: (v) => ref.read(amoledProvider.notifier).set(v),
          ),
          const ThemePaletteSettings(),
        ],
      ),
    );
  }
}
