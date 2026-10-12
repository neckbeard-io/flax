import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';
import 'package:flax/services/network/certificate_trust.dart';
import 'package:flax/services/network/network_target_resolver.dart';
import 'package:flax/services/platform/native_downloader.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

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

const _lan = LocalNetworkConfig(
  enabled: true,
  localHost: '192.168.1.20',
  localPort: 4533,
  useHttps: true,
);

void main() {
  group('acceptsAnyCertificate', () {
    test('trusts the local target host and port, and nothing else there', () {
      final server = _server(local: _lan);
      expect(acceptsAnyCertificate(server, '192.168.1.20', 4533), isTrue);
      expect(acceptsAnyCertificate(server, '192.168.1.20', 443), isFalse);
      expect(acceptsAnyCertificate(server, '192.168.1.21', 4533), isFalse);
    });

    test('does not trust a local target that is turned off', () {
      final server = _server(local: _lan.copyWith(enabled: false));
      expect(acceptsAnyCertificate(server, '192.168.1.20', 4533), isFalse);
    });

    test('trusts the remote host only with Verify certificates off', () {
      expect(
        acceptsAnyCertificate(_server(), 'music.example.com', 443),
        isFalse,
      );
      final unverified = _server(verifyCertificates: false);
      expect(
        acceptsAnyCertificate(unverified, 'music.example.com', 443),
        isTrue,
      );
      expect(
        acceptsAnyCertificate(unverified, 'MUSIC.example.com', 443),
        isTrue,
      );
      expect(
        acceptsAnyCertificate(unverified, 'music.example.com', 8443),
        isFalse,
      );
    });

    test('never trusts an unrelated host', () {
      final permissive = _server(verifyCertificates: false, local: _lan);
      for (final host in [
        'api.github.com',
        'musicbrainz.org',
        'raw.githubusercontent.com',
        'example.com',
      ]) {
        expect(acceptsAnyCertificate(permissive, host, 443), isFalse);
      }
    });

    test('plain http has no certificate to trust', () {
      final server = _server(
        url: 'http://music.example.com',
        verifyCertificates: false,
        local: _lan.copyWith(useHttps: false),
      );
      expect(
        acceptsAnyCertificateFor(
          server,
          Uri.parse('http://192.168.1.20:4533/rest/download'),
        ),
        isFalse,
      );
      expect(
        acceptsAnyCertificateFor(
          server,
          Uri.parse('http://music.example.com/rest/download'),
        ),
        isFalse,
      );
    });
  });

  group('Server', () {
    test('verifies certificates unless told not to', () {
      final json = _server().toJson()..remove('verifyCertificates');
      expect(Server.fromJson(json).verifyCertificates, isTrue);

      final off = Server.fromJson(_server(verifyCertificates: false).toJson());
      expect(off.verifyCertificates, isFalse);
    });

    test('ignores the old Trust Self-Signed Certificates switch', () {
      final json = _server(local: _lan).toJson();
      (json['localNetworkConfig']
              as Map<String, dynamic>)['trustSelfSignedCerts'] =
          true;
      final restored = Server.fromJson(json);
      expect(restored.verifyCertificates, isTrue);
      expect(
        restored.localNetworkConfig.toJson().containsKey(
          'trustSelfSignedCerts',
        ),
        isFalse,
      );
    });
  });

  group('startDownload payload', () {
    // Built the way the download and cover sync batches build their tasks.
    Map<String, dynamic> payload(SubsonicClient client) => NativeDownloadTask(
      songId: 'song-1',
      serverId: client.server.id,
      title: 'Track',
      downloadUrl: client.getDownloadUri('song-1').toString(),
      destinationPath: '/tmp/song-1.flac',
      trustAnyCertificate: acceptsAnyCertificateFor(
        client.server,
        client.getDownloadUri('song-1'),
      ),
    ).toJson();

    test('flags a task for the local target', () {
      final server = _server(local: _lan);
      final client = SubsonicClient(
        server: server,
        customBaseUrl: _lan.localBaseUrl,
      );
      expect(payload(client)['trustAnyCertificate'], isTrue);
    });

    test('flags a task for the remote host only with verification off', () {
      expect(
        payload(SubsonicClient(server: _server(local: _lan))),
        containsPair('trustAnyCertificate', false),
      );
      expect(
        payload(SubsonicClient(server: _server(verifyCertificates: false))),
        containsPair('trustAnyCertificate', true),
      );
    });

    test('flags nothing else', () {
      final client = SubsonicClient(
        server: _server(verifyCertificates: false, local: _lan),
        customBaseUrl: 'https://mirror.example.net',
      );
      expect(payload(client)['trustAnyCertificate'], isFalse);
    });
  });

  // A real HTTPS server with a self-signed certificate for "localhost", so the
  // callbacks are exercised end to end rather than read back.
  group('against a self-signed server', () {
    late HttpServer https;
    late int port;

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
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'subsonic-response': {'status': 'ok', 'version': '1.16.1'},
            }),
          )
          ..close();
      });
    });

    tearDownAll(() => https.close(force: true));

    LocalNetworkConfig localAt(String host) => LocalNetworkConfig(
      enabled: true,
      localHost: host,
      localPort: port,
      useHttps: true,
    );

    test('SubsonicClient refuses the remote host by default', () async {
      final client = SubsonicClient(
        server: _server(url: 'https://localhost:$port'),
      );
      await expectLater(client.ping(), throwsA(isA<DioException>()));
    });

    test(
      'SubsonicClient accepts the remote host with verification off',
      () async {
        final client = SubsonicClient(
          server: _server(
            url: 'https://localhost:$port',
            verifyCertificates: false,
          ),
        );
        expect(await client.ping(), isTrue);
      },
    );

    test('SubsonicClient accepts the local target', () async {
      final local = localAt('localhost');
      final client = SubsonicClient(
        server: _server(local: local),
        customBaseUrl: local.localBaseUrl,
      );
      expect(await client.ping(), isTrue);
    });

    test(
      'SubsonicClient refuses a host that is not the local target',
      () async {
        // The same server, reached by a name the local target does not use.
        final client = SubsonicClient(
          server: _server(local: localAt('localhost')),
          customBaseUrl: 'https://127.0.0.1:$port',
        );
        await expectLater(client.ping(), throwsA(isA<DioException>()));
      },
    );

    test('tryPing names an untrusted certificate', () async {
      final client = SubsonicClient(
        server: _server(url: 'https://localhost:$port'),
      );
      expect(
        await client.tryPing(),
        SubsonicClient.untrustedCertificateMessage,
      );
    });

    test('a server is added without verifying only when asked', () async {
      SharedPreferences.setMockInitialValues({});
      final servers = ServerListNotifier(initialServers: []);
      addTearDown(servers.dispose);
      Future<Server> add({required bool verify}) => servers.addServer(
        name: 'Home',
        url: 'https://localhost:$port',
        username: 'alice',
        password: 'pw',
        verifyCertificates: verify,
      );

      await expectLater(
        add(verify: true),
        throwsA(isA<UntrustedCertificateException>()),
      );
      expect(servers.state, isEmpty);

      final added = await add(verify: false);
      expect(added.verifyCertificates, isFalse);
      expect(servers.state.single.verifyCertificates, isFalse);
    });

    test('the local target probe trusts only the local target', () async {
      expect(
        await NetworkTargetResolver.probeLocalEndpoint(
          'https://localhost:$port',
          server: _server(local: localAt('localhost')),
        ),
        isTrue,
      );
      expect(
        await NetworkTargetResolver.probeLocalEndpoint(
          'https://localhost:$port',
          server: _server(local: localAt('127.0.0.1')),
        ),
        isFalse,
      );
    });
  });
}
