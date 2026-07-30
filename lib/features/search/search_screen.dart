import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<SearchResult?>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return null;
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return null;
  return client.search(query);
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resultAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Search artists, albums, songs...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        prefixIcon: const Icon(Icons.search, size: 20),
                      ),
                      onChanged: (value) =>
                          ref.read(searchQueryProvider.notifier).state = value,
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    ),
                ],
              ),
            ),
            Expanded(
              child: resultAsync.when(
        data: (result) {
          if (result == null) {
            return Center(
              child: Text(
                'Search your library',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          if (result.isEmpty) {
            return Center(
              child: Text(
                'No results',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView(
            children: [
              if (result.artists.isNotEmpty) ...[
                _SectionHeader(title: 'Artists'),
                ...result.artists.map(
                  (a) => ListTile(
                    leading: ClipOval(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CoverArtImage(coverArtId: a.coverArtId, size: 40),
                      ),
                    ),
                    title: Text(a.name),
                    onTap: () => context.push('/artists/${a.id}'),
                  ),
                ),
              ],
              if (result.albums.isNotEmpty) ...[
                _SectionHeader(title: 'Albums'),
                ...result.albums.map(
                  (a) => ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CoverArtImage(coverArtId: a.coverArtId, size: 40),
                      ),
                    ),
                    title: Text(a.name),
                    subtitle: Text(a.artistName ?? ''),
                    onTap: () => context.push('/albums/${a.id}'),
                  ),
                ),
              ],
              if (result.songs.isNotEmpty) ...[
                _SectionHeader(title: 'Songs'),
                ...result.songs.asMap().entries.map(
                  (entry) {
                    final song = entry.value;
                    return ListTile(
                      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${song.artistName ?? ''} — ${song.albumName ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        ref.read(playerProvider.notifier).playSong(
                              song,
                              queue: result.songs,
                              index: entry.key,
                            );
                      },
                    );
                  },
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
