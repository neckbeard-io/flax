import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/app/theme/theme_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final amoled = ref.watch(amoledProvider);
    final servers = ref.watch(serverListProvider);
    final activeServer = ref.watch(activeServerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Servers ──
          _SectionTitle(title: 'Servers'),
          ...servers.map(
            (s) => ListTile(
              leading: Icon(
                s.isActive ? Icons.check_circle : Icons.circle_outlined,
                color: s.isActive ? theme.colorScheme.primary : null,
              ),
              title: Text(s.name),
              subtitle: Text(s.url, style: theme.textTheme.bodySmall),
              onTap: () =>
                  ref.read(serverListProvider.notifier).setActiveServer(s.id),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remove server?'),
                      content: Text('Remove "${s.name}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    ref.read(serverListProvider.notifier).removeServer(s.id);
                  }
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: () => context.go('/add-server'),
              icon: const Icon(Icons.add),
              label: const Text('Add Server'),
            ),
          ),
          const Divider(),

          // ── Appearance ──
          _SectionTitle(title: 'Appearance'),
          ListTile(
            title: const Text('Theme'),
            trailing: SegmentedButton<ThemeModeSetting>(
              segments: const [
                ButtonSegment(value: ThemeModeSetting.system, label: Text('Auto')),
                ButtonSegment(value: ThemeModeSetting.light, label: Text('Light')),
                ButtonSegment(value: ThemeModeSetting.dark, label: Text('Dark')),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).state = s.first,
            ),
          ),
          SwitchListTile(
            title: const Text('AMOLED Black'),
            subtitle: const Text('Pure black background for OLED screens'),
            value: amoled,
            onChanged: (v) =>
                ref.read(amoledProvider.notifier).state = v,
          ),
          const Divider(),

          // ── Playback ──
          _SectionTitle(title: 'Playback'),
          ListTile(
            title: const Text('Audio Output'),
            subtitle: const Text('DAC, sample rate, exclusive mode'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/audio'),
          ),
          ListTile(
            title: const Text('Equalizer'),
            subtitle: const Text('Parametric EQ, AutoEQ, presets'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/equalizer'),
          ),
          ListTile(
            title: const Text('Transcoding'),
            subtitle: Text(
              activeServer != null
                  ? 'Wi-Fi: ${activeServer.transcodingConfig.wifiQuality.label} · '
                    'Cellular: ${activeServer.transcodingConfig.cellularQuality.label}'
                  : 'No server',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/transcoding'),
          ),
          const Divider(),

          // ── About ──
          _SectionTitle(title: 'About'),
          const ListTile(
            title: Text('Flax'),
            subtitle: Text('v0.1.0 · High-fidelity music player'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
