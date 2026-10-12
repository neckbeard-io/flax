import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/shared/widgets/art_cache.dart';

Server _server({
  String url = 'https://music.example.com',
  bool verifyCertificates = true,
  LocalNetworkConfig local = const LocalNetworkConfig(),
}) => Server(
  id: 'srv',
  name: 'Home',
  url: url,
  username: 'alice',
  tokenHash: 'pw',
  salt: '',
  isActive: true,
  verifyCertificates: verifyCertificates,
  localNetworkConfig: local,
);

// A real HTTPS server with the self-signed "localhost" fixture, so the art
// cache's client is checked end to end. No test binding: it would replace
// HttpClient with one that answers every request with 400.
void main() {
  late HttpServer https;
  late int port;
  final fileService = HttpFileService(
    httpClient: IOClient(ArtCache.httpClient()),
  );

  setUpAll(() async {
    final context = SecurityContext()
      ..useCertificateChain('test/fixtures/tls/self_signed.crt')
      ..usePrivateKey('test/fixtures/tls/self_signed.key');
    https = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    port = https.port;
    https.listen((request) {
      request.response
        ..headers.contentType = ContentType('image', 'jpeg')
        ..add(const [0xFF, 0xD8, 0xFF, 0xD9])
        ..close();
    });
  });

  tearDownAll(() => https.close(force: true));
  tearDown(() => ArtCache.activeServer = null);

  String cover() => 'https://localhost:$port/rest/getCoverArt?id=al-1';

  test('fetches a cover from the local target', () async {
    ArtCache.activeServer = _server(
      local: LocalNetworkConfig(
        enabled: true,
        localHost: 'localhost',
        localPort: port,
        useHttps: true,
      ),
    );
    final response = await fileService.get(cover());
    expect(response.statusCode, 200);
  });

  test('refuses the remote host while it is verified', () async {
    ArtCache.activeServer = _server(url: 'https://localhost:$port');
    await expectLater(
      fileService.get(cover()),
      throwsA(isA<HandshakeException>()),
    );
  });

  test('fetches from the remote host with verification off', () async {
    ArtCache.activeServer = _server(
      url: 'https://localhost:$port',
      verifyCertificates: false,
    );
    final response = await fileService.get(cover());
    expect(response.statusCode, 200);
  });

  test('refuses everything with no server', () async {
    await expectLater(
      fileService.get(cover()),
      throwsA(isA<HandshakeException>()),
    );
  });
}
