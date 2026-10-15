import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

/// A ping is how flax decides whether the server is there after a request
/// failed, so it must not ride a pooled connection that may be the reason the
/// request failed (#167).
void main() {
  late HttpServer http;
  final remotePorts = <int>[];

  setUpAll(() async {
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen((request) {
      remotePorts.add(request.connectionInfo!.remotePort);
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

  tearDownAll(() => http.close(force: true));

  test('a ping opens its own connection instead of a pooled one', () async {
    final client = SubsonicClient(
      server: Server(
        id: 'srv-1',
        name: 'Test Server',
        url: 'http://127.0.0.1:${http.port}',
        username: 'admin',
        tokenHash: 'secret',
        salt: '',
      ),
    );

    await client.ping();
    expect(await client.tryPing(), isNull);
    await client.ping();

    expect(remotePorts, hasLength(3));
    expect(remotePorts[2], remotePorts[0], reason: 'requests share a pool');
    expect(remotePorts[1], isNot(remotePorts[0]));
  });
}
