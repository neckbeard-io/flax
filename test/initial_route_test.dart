import 'package:flutter_test/flutter_test.dart';

import 'package:flax/app/router.dart';

/// Which screen the app opens on.
///
/// Tests the decision directly rather than standing up a router, so it touches
/// nothing on the machine running it — the real server configuration in the
/// app's own preferences is never read or written. That matters here: the bug
/// this guards looked exactly like the saved server having been wiped, when in
/// fact a debug build had /add-server compiled in as its start route.
void main() {
  test('a configured server is never asked for again on launch', () {
    expect(initialLocationFor(hasServer: true), '/home');
  });

  test('with no server, setup is the only sensible start', () {
    expect(initialLocationFor(hasServer: false), '/add-server');
  });

  test('a debug route opens that screen instead', () {
    expect(
      initialLocationFor(
        hasServer: true,
        debugRoute: '/albums/abc',
        allowDebugRoute: true,
      ),
      '/albums/abc',
    );
  });

  test('a debug route cannot strand you on setup', () {
    // The actual regression: --route /add-server left every subsequent launch
    // of that build sitting on the setup screen, indistinguishable from the
    // server having been forgotten.
    expect(
      initialLocationFor(
        hasServer: true,
        debugRoute: '/add-server',
        allowDebugRoute: true,
      ),
      '/home',
    );
  });

  test('debug routes are ignored in release builds', () {
    expect(
      initialLocationFor(
        hasServer: true,
        debugRoute: '/albums/abc',
        allowDebugRoute: false,
      ),
      '/home',
    );
  });

  test('no server still wins over any debug route', () {
    expect(
      initialLocationFor(
        hasServer: false,
        debugRoute: '/albums/abc',
        allowDebugRoute: true,
      ),
      '/add-server',
    );
  });
}
