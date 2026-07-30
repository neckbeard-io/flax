import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/shared/widgets/cover_art_image.dart';

final artistsProvider = FutureProvider<List<Artist>>((ref) async {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return [];
  return client.getArtists();
});

class ArtistsScreen extends ConsumerWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final artistsAsync = ref.watch(artistsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Artists',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: artistsAsync.when(
        data: (artists) => ListView.builder(
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            return ListTile(
              leading: ClipOval(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CoverArtImage(
                    coverArtId: artist.coverArtId,
                    size: 48,
                  ),
                ),
              ),
              title: Text(artist.name),
              subtitle: Text(
                '${artist.albumCount} album${artist.albumCount != 1 ? 's' : ''}',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              trailing: artist.starred
                  ? Icon(Icons.favorite, color: theme.colorScheme.primary, size: 18)
                  : null,
              onTap: () => context.push('/artists/${artist.id}'),
            );
          },
        ),
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
