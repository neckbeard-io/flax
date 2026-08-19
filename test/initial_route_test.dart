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
    expect(initialLocationFor(hasServer: true), '/albums');
  });

  test('with no server, setup is the only sensible start', () {
    expect(initialLocationFor(hasServer: false), '/add-server');
  });

  test('when a saved route exists, launch reopens on the saved route', () {
    expect(
      initialLocationFor(hasServer: true, savedRoute: '/artists/abc'),
      '/artists/abc',
    );
    expect(
      initialLocationFor(hasServer: true, savedRoute: '/settings/equalizer'),
      '/settings/equalizer',
    );
    expect(
      initialLocationFor(hasServer: true, savedRoute: '/now-playing'),
      '/now-playing',
    );
  });

  test('saved route to /add-server is ignored when server is configured', () {
    expect(
      initialLocationFor(hasServer: true, savedRoute: '/add-server'),
      '/albums',
    );
  });

  test('no server still wins over any saved route', () {
    expect(
      initialLocationFor(hasServer: false, savedRoute: '/artists/abc'),
      '/add-server',
    );
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

  test('a debug route takes precedence over a saved route in debug mode', () {
    expect(
      initialLocationFor(
        hasServer: true,
        debugRoute: '/search',
        allowDebugRoute: true,
        savedRoute: '/artists',
      ),
      '/search',
    );
  });

  test('in release mode, saved route is used instead of debug route', () {
    expect(
      initialLocationFor(
        hasServer: true,
        debugRoute: '/search',
        allowDebugRoute: false,
        savedRoute: '/artists',
      ),
      '/artists',
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
      '/albums',
    );
  });

  test('debug routes are ignored in release builds', () {
    expect(
      initialLocationFor(
        hasServer: true,
        debugRoute: '/albums/abc',
        allowDebugRoute: false,
      ),
      '/albums',
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
