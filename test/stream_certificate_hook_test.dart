import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart' as mpv;
import 'package:flax/domain/models/server.dart';
import 'package:flax/features/player/stream_certificate_hook.dart';

const _lan = LocalNetworkConfig(
  enabled: true,
  localHost: '192.168.1.20',
  localPort: 4533,
  useHttps: true,
);

Server _server({bool verifyCertificates = true}) => Server(
  id: 'srv',
  name: 'Home',
  url: 'https://music.example.com',
  username: 'alice',
  tokenHash: 'pw',
  salt: '',
  isActive: true,
  verifyCertificates: verifyCertificates,
  localNetworkConfig: _lan,
);

/// Answers one hook for [url] and reports whether the check was skipped and
/// which hook ids were resumed.
Future<({bool skipped, List<int> resumed})> _answer(
  String? url, {
  Server? server,
  mpv.Hook hook = mpv.Hook.load,
  bool failToRead = false,
}) async {
  var skipped = false;
  final resumed = <int>[];
  await StreamCertificateHook(
    server: () => server,
    openFilename: () async {
      if (failToRead) throw StateError('mpv went away');
      return url;
    },
    skipCheck: () async => skipped = true,
    resume: (id) async => resumed.add(id),
  ).handle(mpv.MpvHookEvent(7, hook));
  return (skipped: skipped, resumed: resumed);
}

void main() {
  const stream = '/rest/stream?id=song-1&u=alice&t=x&s=y';

  test('skips the check for the local target', () async {
    final r = await _answer(
      'https://192.168.1.20:4533$stream',
      server: _server(),
    );
    expect(r.skipped, isTrue);
    expect(r.resumed, [7]);
  });

  test('checks the remote host unless verification is off', () async {
    const url = 'https://music.example.com$stream';
    expect((await _answer(url, server: _server())).skipped, isFalse);
    expect(
      (await _answer(url, server: _server(verifyCertificates: false))).skipped,
      isTrue,
    );
  });

  test('checks every other host, files, and loads with no server', () async {
    final server = _server(verifyCertificates: false);
    expect(
      (await _answer('https://cdn.example.net/a.flac', server: server)).skipped,
      isFalse,
    );
    expect(
      (await _answer('/music/offline/srv/song-1.flac', server: server)).skipped,
      isFalse,
    );
    expect(
      (await _answer('https://192.168.1.20:4533$stream')).skipped,
      isFalse,
    );
  });

  test('always lets mpv carry on', () async {
    final other = await _answer(
      'https://192.168.1.20:4533$stream',
      server: _server(),
      hook: mpv.Hook.unload,
    );
    expect(other.skipped, isFalse);
    expect(other.resumed, [7]);

    final failed = await _answer(null, server: _server(), failToRead: true);
    expect(failed.skipped, isFalse);
    expect(failed.resumed, [7]);
  });
}
