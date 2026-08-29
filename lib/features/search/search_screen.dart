import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/core/providers/offline_mode_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/settings/playback_settings.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';
import 'package:flax/shared/widgets/window_buttons.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

/// Full search: cached hits first, then widened by the server. Issue #8.
///
/// Same two-emission shape as the sidebar's quick search. A failed server call
/// leaves the local hits in place rather than turning the screen into an error,
/// so searching still works with no network — over whatever has been browsed.
final searchResultsProvider = StreamProvider<SearchResult?>((ref) async* {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) {
    yield null;
    return;
  }

  final isOffline = ref.watch(isOfflineModeProvider);
  final repo = ref.watch(libraryRepositoryProvider);
  if (repo == null) {
    yield null;
    return;
  }

  if (isOffline) {
    yield SearchResult(
      artists: await repo.watchDownloadedArtistSearch(query).first,
      albums: await repo.watchDownloadedAlbumSearch(query).first,
      songs: await repo.watchDownloadedSongSearch(query).first,
    );
    return;
  }

  Future<SearchResult> local() async => SearchResult(
    artists: await repo.watchArtistSearch(query).first,
    albums: await repo.watchAlbumSearch(query).first,
    songs: await repo.watchSongSearch(query).first,
  );

  yield await local();

  try {
    await repo.cacheSearch(query);
  } catch (_) {
    return;
  }

  yield await local();
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  /// Query handed over from the sidebar's quick search, via `?q=`.
  ///
  /// Passed in the URL rather than through the shared provider the two
  /// searches used to sit on: that provider meant typing in the sidebar
  /// rewrote this screen and navigated to it, whether you wanted it or not.
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery ?? '';
    _controller.text = initial;
    // The field is the truth, including when it is empty. Leaving the provider
    // alone instead meant arriving here from the sidebar's Search item showed
    // the *previous* search's results under a blank field.
    //
    // After the first frame: writing a provider during initState throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(searchQueryProvider.notifier).state = initial;
    });
  }

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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 20),
                      ),
                      onChanged: (value) =>
                          ref.read(searchQueryProvider.notifier).state = value,
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _controller.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    ),
                  // AppChrome paints the window controls over this corner, so
                  // the clear button has to step aside — it was drawn directly
                  // under the close button, and neither was reliably clickable.
                  SizedBox(width: windowButtonsReservedWidth),
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
                                child: CoverArtImage(
                                  coverArtId: a.coverArtId,
                                  size: 40,
                                ),
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
                                child: CoverArtImage(
                                  coverArtId: a.coverArtId,
                                  size: 40,
                                ),
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
                        ...result.songs.map((song) {
                          return ListTile(
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${song.artistName ?? ''} — ${song.albumName ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              ref.read(playerProvider.notifier).playSong(song);
                              if (ref
                                  .read(playbackSettingsProvider)
                                  .autoSwitchToNowPlaying) {
                                context.push('/now-playing');
                              }
                            },
                          );
                        }),
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
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
