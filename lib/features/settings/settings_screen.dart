import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flax/app/theme/theme_provider.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/enums.dart';
import 'package:flax/features/settings/lyrics_settings.dart';
import 'package:flax/features/settings/playback_settings.dart';
import 'package:flax/features/settings/scrobble_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final amoled = ref.watch(amoledProvider);
    final servers = ref.watch(serverListProvider);
    final activeServer = ref.watch(activeServerProvider);
    final scrobble = ref.watch(scrobbleEnabledProvider);

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
                ButtonSegment(
                  value: ThemeModeSetting.system,
                  label: Text('Auto'),
                ),
                ButtonSegment(
                  value: ThemeModeSetting.light,
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeModeSetting.dark,
                  label: Text('Dark'),
                ),
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
            onChanged: (v) => ref.read(amoledProvider.notifier).state = v,
          ),
          const Divider(),

          // ── Lyrics ──
          _SectionTitle(title: 'Lyrics'),
          const _LyricsSettingsSection(),
          const Divider(),

          // ── Playback ──
          _SectionTitle(title: 'Playback'),
          SwitchListTile(
            title: const Text('Report plays to server'),
            subtitle: const Text(
              'Keeps Recently Played and Most Played up to date',
            ),
            value: scrobble,
            onChanged: (v) =>
                ref.read(scrobbleEnabledProvider.notifier).setEnabled(v),
          ),
          SwitchListTile(
            title: const Text('Auto-switch to Now Playing'),
            subtitle: const Text(
              'Automatically switch to the Now Playing screen when starting playback',
            ),
            value: ref.watch(playbackSettingsProvider).autoSwitchToNowPlaying,
            onChanged: (v) => ref
                .read(playbackSettingsProvider.notifier)
                .setAutoSwitchToNowPlaying(v),
          ),
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
          const _AboutTile(),
        ],
      ),
    );
  }
}

/// Version read from the app bundle, never hardcoded.
///
/// This was a literal 'v0.1.0' string for a while, which meant every build ever
/// shipped claimed to be 0.1.0 — testers had no way to tell which build they had
/// installed, and the release pipeline's version stamping was invisible. The
/// build number matters as much as the name: two builds of the same version are
/// distinguished only by it.
class _AboutTile extends StatelessWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final String version;
        if (info == null) {
          version = snapshot.hasError ? 'version unavailable' : '…';
        } else {
          version = 'v${info.version} (build ${info.buildNumber})';
        }
        // Name the build mode so a leftover debug bundle cannot be mistaken for
        // an installed release. Release builds say nothing extra.
        const mode = kDebugMode
            ? ' · debug build'
            : (kProfileMode ? ' · profile build' : '');
        return ListTile(
          title: const Text('Flax'),
          // The licence is named here because handing someone a build is
          // distribution, and GPL expects an interactive program to say so
          // somewhere the recipient can find it.
          subtitle: Text(
            '$version$mode · High-fidelity music player\n'
            'GPL-3.0-or-later · source at github.com/neckbeard-io/flax',
          ),
        );
      },
    );
  }
}

/// Size and justification for the lyrics panel, over a live sample.
///
/// The sample is the point: a number of points means nothing until you can see
/// what it looks like, and the sung line's size is derived rather than chosen,
/// so seeing the pair together is the only way to judge the setting.
class _LyricsSettingsSection extends ConsumerWidget {
  const _LyricsSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(lyricsSettingsProvider);
    final notifier = ref.read(lyricsSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: const Text('Justification'),
          trailing: SegmentedButton<LyricsAlignment>(
            segments: [
              for (final a in LyricsAlignment.values)
                ButtonSegment(value: a, label: Text(a.label)),
            ],
            selected: {settings.alignment},
            onSelectionChanged: (s) => notifier.setAlignment(s.first),
          ),
        ),
        ListTile(
          title: const Text('Text size'),
          subtitle: Slider(
            value: settings.fontSize,
            min: LyricsSettings.minFontSize,
            max: LyricsSettings.maxFontSize,
            divisions: (LyricsSettings.maxFontSize - LyricsSettings.minFontSize)
                .round(),
            label: '${settings.fontSize.round()} pt',
            onChanged: notifier.setFontSize,
          ),
          trailing: Text(
            '${settings.fontSize.round()} pt',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (line, active) in const [
                  ('And return as falling snow', false),
                  ('To sweep the landscape a wind haunted', true),
                  ('Wings without bodies', false),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      line,
                      textAlign: settings.alignment.textAlign,
                      style: theme.textTheme.titleMedium?.copyWith(
                        height: 1.4,
                        fontSize: active
                            ? settings.activeFontSize
                            : settings.fontSize,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        color: active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.45,
                              ),
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
