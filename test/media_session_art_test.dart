import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flax/services/audio/media_session_art.dart';
import 'package:flax/shared/widgets/art_cache.dart';

/// The content:// art URIs only work if the Dart side, the manifest and the
/// provider agree on where covers are. Each lives in a different language, and
/// a mismatch fails silently, on a car: the small card just shows no cover.
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final provider = File(
    'android/app/src/main/kotlin/com/flaxplayer/flax/FlaxArtProvider.kt',
  ).readAsStringSync();

  test('the manifest exports the art provider under the Dart authority', () {
    final declaration = RegExp(
      r'<provider[^>]*android:name="\.FlaxArtProvider"[^>]*>',
    ).firstMatch(manifest)?.group(0);
    expect(declaration, isNotNull, reason: 'FlaxArtProvider is not declared');

    // Android Auto runs in another process, so the provider must be exported.
    expect(declaration, contains('android:exported="true"'));

    final authority = RegExp(
      r'android:authorities="([^"]+)"',
    ).firstMatch(declaration!)!.group(1)!;
    final applicationId = RegExp(
      r'applicationId = "([^"]+)"',
    ).firstMatch(gradle)!.group(1)!;
    expect(
      authority.replaceAll(r'${applicationId}', applicationId),
      mediaSessionArtAuthority,
    );
  });

  test('the provider serves the folder the art cache writes to', () {
    expect(provider, contains('ART_CACHE_DIR = "${ArtCache.key}"'));
  });

  test('a stored cover is named by its file alone', () {
    final uri = mediaSessionArtUri(
      '/data/user/0/com.flaxplayer.flax/cache/flaxArtCache/1b2c.jpeg',
      android: true,
    );
    expect(uri.toString(), 'content://$mediaSessionArtAuthority/1b2c.jpeg');
    expect(uri.pathSegments, ['1b2c.jpeg']);
  });

  test('off Android, the stored cover stays a file path', () {
    const path = '/var/mobile/Library/Caches/flaxArtCache/1b2c.jpeg';
    expect(mediaSessionArtUri(path, android: false), Uri.file(path));
  });
}
