import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/services/autoeq/autoeq_provider.dart';
import 'package:flax/services/autoeq/autoeq_profile.dart';

class AutoEqScreen extends ConsumerStatefulWidget {
  const AutoEqScreen({super.key});

  @override
  ConsumerState<AutoEqScreen> createState() => _AutoEqScreenState();
}

class _AutoEqScreenState extends ConsumerState<AutoEqScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load initial results if DB is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(autoEqProvider);
      if (state.dbAvailable && state.searchResults.isEmpty) {
        ref.read(autoEqProvider.notifier).search('');
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(autoEqProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AutoEQ'),
        actions: [
          if (state.activeProfile != null)
            TextButton(
              onPressed: () => ref.read(autoEqProvider.notifier).clearProfile(),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Active profile banner ──
          if (state.activeProfile != null) _buildActiveProfileBanner(theme, state),

          // ── Not downloaded state ──
          if (!state.dbAvailable && !state.downloading)
            _buildDownloadPrompt(theme, state),

          // ── Downloading state ──
          if (state.downloading) _buildDownloadProgress(theme, state),

          // ── Search + results ──
          if (state.dbAvailable && !state.downloading) ...[
            _buildDbInfoBar(theme, state),
            _buildSearchBar(theme, state),
            Expanded(child: _buildResultsList(theme, state)),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveProfileBanner(ThemeData theme, AutoEqState state) {
    final profile = state.activeProfile!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.primaryContainer,
      child: Row(
        children: [
          Icon(Icons.headphones, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Source: ${profile.source} · ${profile.points.length} bands',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: theme.colorScheme.primary),
        ],
      ),
    );
  }

  Widget _buildDbInfoBar(ThemeData theme, AutoEqState state) {
    // Show status message if we just checked, otherwise show the DB date
    final statusText = state.downloadStatus;
    final showStatus = statusText != null &&
        (statusText.contains('up to date') || statusText.contains('Update available'));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.dbDate != null ? 'DB: ${state.dbDate}' : 'AutoEQ Database',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (state.updateAvailable)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: FilledButton.tonalIcon(
                    onPressed: () =>
                        ref.read(autoEqProvider.notifier).downloadDatabase(),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Update'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
              if (state.checking)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (!state.updateAvailable)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Check for updates',
                  onPressed: () =>
                      ref.read(autoEqProvider.notifier).checkForUpdate(),
                ),
            ],
          ),
          if (showStatus)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 2, bottom: 2),
              child: Row(
                children: [
                  Icon(
                    state.updateAvailable ? Icons.info_outline : Icons.check_circle_outline,
                    size: 14,
                    color: state.updateAvailable
                        ? theme.colorScheme.primary
                        : Colors.green,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    state.updateAvailable ? 'A newer database is available' : 'Up to date',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: state.updateAvailable
                          ? theme.colorScheme.primary
                          : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 2, bottom: 2),
              child: Text(
                state.error!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDownloadPrompt(ThemeData theme, AutoEqState state) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.headphones,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'AutoEQ Headphone Correction',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Download the AutoEQ database to access correction profiles '
                'for thousands of headphones. The database is ~5-10 MB and is '
                'cached locally for offline use.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(autoEqProvider.notifier).downloadDatabase(),
                icon: const Icon(Icons.download),
                label: const Text('Download Database'),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.error!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadProgress(ThemeData theme, AutoEqState state) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                state.downloadStatus ?? 'Downloading...',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, AutoEqState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search headphones...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(autoEqProvider.notifier).search('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: (query) {
          ref.read(autoEqProvider.notifier).search(query);
        },
      ),
    );
  }

  Widget _buildResultsList(ThemeData theme, AutoEqState state) {
    if (state.loading && state.searchResults.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.searchResults.isEmpty) {
      return Center(
        child: Text(
          state.searchQuery.isEmpty
              ? 'No profiles found'
              : 'No results for "${state.searchQuery}"',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Group by brand
    final grouped = <String, List<AutoEqProfile>>{};
    for (final profile in state.searchResults) {
      final brand = profile.brand;
      grouped.putIfAbsent(brand, () => []).add(profile);
    }

    // Sort brands alphabetically
    final brands = grouped.keys.toList()..sort();

    // If searching, show flat list for speed
    if (state.searchQuery.isNotEmpty) {
      // Limit displayed results for performance
      final displayed = state.searchResults.take(100).toList();
      return ListView.builder(
        controller: _scrollController,
        itemCount: displayed.length + (state.searchResults.length > 100 ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= displayed.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${state.searchResults.length - 100} more results...\nRefine your search to see them.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }
          return _buildProfileTile(theme, displayed[index], state);
        },
      );
    }

    // Default: grouped by brand
    return ListView.builder(
      controller: _scrollController,
      itemCount: brands.length,
      itemBuilder: (context, index) {
        final brand = brands[index];
        final profiles = grouped[brand]!;
        return ExpansionTile(
          title: Text(
            brand,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text('${profiles.length} profiles'),
          children:
              profiles.map((p) => _buildProfileTile(theme, p, state)).toList(),
        );
      },
    );
  }

  Widget _buildProfileTile(
      ThemeData theme, AutoEqProfile profile, AutoEqState state) {
    final isActive = state.activeProfile?.id == profile.id;
    return ListTile(
      leading: Icon(
        profile.source.toLowerCase().contains('in-ear')
            ? Icons.earbuds
            : Icons.headphones,
        color: isActive ? theme.colorScheme.primary : null,
      ),
      title: Text(
        profile.name,
        style: isActive
            ? TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              )
            : null,
      ),
      subtitle: Text(
        profile.source,
        style: theme.textTheme.bodySmall,
      ),
      trailing: isActive
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : const Icon(Icons.chevron_right),
      onTap: () {
        ref.read(autoEqProvider.notifier).selectProfile(profile);
      },
    );
  }
}
