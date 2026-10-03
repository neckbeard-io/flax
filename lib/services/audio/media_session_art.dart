import 'package:path/path.dart' as p;

/// Authority of `FlaxArtProvider`: the application ID plus `.art`, as declared
/// in `android/app/src/main/AndroidManifest.xml`.
const mediaSessionArtAuthority = 'com.flaxplayer.flax.art';

/// The URI to give the media session for a cover stored at [path], a file in
/// the art cache.
///
/// On Android the session passes the URI to Android Auto and Android
/// Automotive, which open it in their own process. A file:// path into flax's
/// private storage cannot be read there: the large view (left) still showed the
/// cover, drawn from the bitmap audio_service decodes, but the small card
/// (right) loads the URI and stayed empty. `FlaxArtProvider` serves the file as
/// a content:// URI anyone can open, audio_service included. Elsewhere the art
/// is read in-process, so the path itself is fine.
Uri mediaSessionArtUri(String path, {required bool android}) => android
    ? Uri(
        scheme: 'content',
        host: mediaSessionArtAuthority,
        pathSegments: [p.basename(path)],
      )
    : Uri.file(path);

/// Whether [uri] is a stored cover rather than a server URL.
bool isStoredArt(Uri? uri) =>
    uri != null && (uri.scheme == 'file' || uri.scheme == 'content');
