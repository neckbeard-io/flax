import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flax/features/settings/android_auto_settings.dart';
import 'package:flax/l10n/app_localizations.dart';
import 'package:flax/shared/widgets/up_back_button.dart';
import 'package:flax/shared/widgets/window_buttons.dart';

/// What Android Auto shows. For now, which tabs run across the top of the
/// car's large view (left): the car takes four at most, and silently dropped
/// whatever came after the fourth.
class AndroidAutoScreen extends ConsumerWidget {
  const AndroidAutoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tabs = ref.watch(androidAutoTabsProvider);
    final notifier = ref.read(androidAutoTabsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        // Keeps the title out from under the window controls.
        actions: [SizedBox(width: WindowControlsInset.of(context))],
        leading: const UpBackButton(fallbackLocation: '/settings'),
        title: Text(l10n?.androidAutoSettings ?? 'Android Auto'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l10n?.androidAutoTabs ?? 'Tabs',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              l10n?.androidAutoTabsHint ??
                  'Choose up to 4. The car shows them in this order.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final tab in AutoTab.values)
            CheckboxListTile(
              key: ValueKey('androidAutoTab-${tab.name}'),
              value: tabs.contains(tab),
              title: Text(tab.label(l10n)),
              // A fifth tab would be dropped by the car, and none would leave
              // it with nothing to browse, so those boxes are disabled.
              onChanged: notifier.canSet(tab, !tabs.contains(tab))
                  ? (selected) => notifier.setSelected(tab, selected ?? false)
                  : null,
            ),
        ],
      ),
    );
  }
}
