import 'package:flax/core/logging/app_logger.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/services/network/certificate_trust.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart' as mpv;

/// Turns mpv's certificate check off for the streams whose host the server
/// trusts, and only for those.
///
/// mpv checked no certificates at all: mpv_audio_kit leaves `tls-verify` off,
/// and every stream URL carries the login token. The player now turns it on,
/// and since `tls-verify` is player-wide, this answers mpv's `on_load` hook for
/// each file: a URL [acceptsAnyCertificateFor] trusts — the local network
/// target, or the remote host with Verify Certificates off — gets a file-local
/// `tls-verify=no`. Everything else keeps the check.
class StreamCertificateHook {
  StreamCertificateHook({
    required this.server,
    required this.openFilename,
    required this.skipCheck,
    required this.resume,
  });

  /// The server the queue streams from.
  final Server? Function() server;

  /// mpv's `stream-open-filename` for the file being loaded.
  final Future<String?> Function() openFilename;

  /// Sets `file-local-options/tls-verify` to `no` for the file being loaded.
  final Future<void> Function() skipCheck;

  /// Lets mpv carry on loading. Always called, or playback stalls.
  final Future<void> Function(int id) resume;

  Future<void> handle(mpv.MpvHookEvent event) async {
    try {
      if (event.hook != mpv.Hook.load) return;
      final current = server();
      final url = await openFilename();
      final uri = url == null ? null : Uri.tryParse(url);
      if (current != null &&
          uri != null &&
          acceptsAnyCertificateFor(current, uri)) {
        await skipCheck();
      }
    } catch (e) {
      AppLogger.w('Player', 'Stream certificate hook failed: $e');
    } finally {
      await resume(event.id);
    }
  }
}
