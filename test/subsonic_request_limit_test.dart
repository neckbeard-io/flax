import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/services/subsonic/subsonic_client.dart';

/// A large response still arriving was cut off by the 15s total limit, and
/// the log said only "DioException [connection timeout]: null" (#169).
void main() {
  late HttpServer http;

  setUpAll(() async {
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen((request) async {
      final body = utf8.encode(
        jsonEncode({
          'subsonic-response': {'status': 'ok', 'version': '1.16.1'},
        }),
      );
      // Sent in pieces over about 600ms: never idle long, but slow in total.
      request.response
        ..headers.contentType = ContentType.json
        ..contentLength = body.length;
      final third = body.length ~/ 3;
      for (final piece in [
        body.sublist(0, third),
        body.sublist(third, 2 * third),
        body.sublist(2 * third),
      ]) {
        request.response.add(piece);
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      await request.response.close();
    });
  });

  tearDownAll(() => http.close(force: true));

  SubsonicClient client() => SubsonicClient(
    server: Server(
      id: 'srv-1',
      name: 'Test Server',
      url: 'http://127.0.0.1:${http.port}',
      username: 'admin',
      tokenHash: 'secret',
      salt: '',
    ),
    requestLimit: const Duration(milliseconds: 300),
  );

  test('the total limit names the endpoint and the limit', () async {
    final error = await client().ping().then<Object?>(
      (_) => null,
      onError: (Object e) => e,
    );

    expect(error, isA<DioException>());
    final e = error! as DioException;
    expect(e.type, DioExceptionType.connectionTimeout);
    expect(
      e.toString().split('\n').first,
      contains('ping took longer than 300ms'),
    );
  });

  test('the background client lets a slow response finish', () async {
    expect(await client().withoutRequestLimit().ping(), isTrue);
  });

  test('limits read as seconds, or milliseconds below one', () {
    expect(SubsonicClient.describeLimit(const Duration(seconds: 15)), '15s');
    expect(
      SubsonicClient.describeLimit(const Duration(milliseconds: 300)),
      '300ms',
    );
  });
}
