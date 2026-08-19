import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flax/domain/models/song.dart';
import 'package:flax/services/platform/now_playing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NowPlayingService service;
  late List<MethodCall> outgoingCalls;

  setUp(() {
    outgoingCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.flax/now_playing'), (
          call,
        ) async {
          outgoingCalls.add(call);
          return null;
        });
    service = NowPlayingService(isSupported: true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.flax/now_playing'),
          null,
        );
  });

  group('NowPlayingService transport callbacks', () {
    test('dispatches onPlay callback', () async {
      var called = 0;
      service.onPlay = () => called++;

      await service.handleMethodForTesting(const MethodCall('onPlay'));
      expect(called, equals(1));
    });

    test('dispatches onPause callback', () async {
      var called = 0;
      service.onPause = () => called++;

      await service.handleMethodForTesting(const MethodCall('onPause'));
      expect(called, equals(1));
    });

    test('dispatches onTogglePlayPause callback', () async {
      var called = 0;
      service.onTogglePlayPause = () => called++;

      await service.handleMethodForTesting(
        const MethodCall('onTogglePlayPause'),
      );
      expect(called, equals(1));
    });

    test('dispatches onNext callback', () async {
      var called = 0;
      service.onNext = () => called++;

      await service.handleMethodForTesting(const MethodCall('onNext'));
      expect(called, equals(1));
    });

    test('dispatches onPrevious callback', () async {
      var called = 0;
      service.onPrevious = () => called++;

      await service.handleMethodForTesting(const MethodCall('onPrevious'));
      expect(called, equals(1));
    });

    test('dispatches onSeek callback with accurate duration', () async {
      Duration? seekPos;
      service.onSeek = (pos) => seekPos = pos;

      await service.handleMethodForTesting(const MethodCall('onSeek', 42.5));
      expect(seekPos, equals(const Duration(milliseconds: 42500)));
    });
  });

  group('NowPlayingService debouncing', () {
    test('ignores rapid duplicate transport events within 300ms', () async {
      var toggleCount = 0;
      service.onTogglePlayPause = () => toggleCount++;

      // First call should execute
      await service.handleMethodForTesting(
        const MethodCall('onTogglePlayPause'),
      );
      expect(toggleCount, equals(1));

      // Second call immediately after (e.g. from parallel MPRemoteCommandCenter + NSEvent) should be ignored
      await service.handleMethodForTesting(
        const MethodCall('onTogglePlayPause'),
      );
      expect(toggleCount, equals(1));

      await service.handleMethodForTesting(const MethodCall('onPlay'));
      expect(toggleCount, equals(1));
    });

    test('allows subsequent transport events after 300ms delay', () async {
      var nextCount = 0;
      service.onNext = () => nextCount++;

      await service.handleMethodForTesting(const MethodCall('onNext'));
      expect(nextCount, equals(1));

      // Wait 350ms to exceed debounce window
      await Future<void>.delayed(const Duration(milliseconds: 350));

      await service.handleMethodForTesting(const MethodCall('onNext'));
      expect(nextCount, equals(2));
    });

    test('does not debounce onSeek calls', () async {
      final seeks = <Duration>[];
      service.onSeek = (pos) => seeks.add(pos);

      await service.handleMethodForTesting(const MethodCall('onSeek', 1.0));
      await service.handleMethodForTesting(const MethodCall('onSeek', 2.0));
      await service.handleMethodForTesting(const MethodCall('onSeek', 3.0));

      expect(seeks.length, equals(3));
      expect(seeks[0], equals(const Duration(seconds: 1)));
      expect(seeks[1], equals(const Duration(seconds: 2)));
      expect(seeks[2], equals(const Duration(seconds: 3)));
    });
  });

  group('NowPlayingService outgoing platform invocations', () {
    const testSong = Song(
      id: 'song-123',
      serverId: 'server-1',
      title: 'The Great Escape',
      artistName: 'Seventh Wonder',
      albumName: 'The Great Escape',
      duration: 1814,
      track: 7,
      coverArtId: 'art-456',
    );

    test('updateNowPlaying sends complete metadata payload', () async {
      await service.updateNowPlaying(
        song: testSong,
        position: const Duration(seconds: 15),
        duration: const Duration(seconds: 1814),
        isPlaying: true,
        artUrl: 'http://localhost/cover.png',
      );

      expect(outgoingCalls.length, equals(1));
      expect(outgoingCalls.first.method, equals('updateNowPlaying'));

      final args = outgoingCalls.first.arguments as Map<dynamic, dynamic>;
      expect(args['title'], equals('The Great Escape'));
      expect(args['artist'], equals('Seventh Wonder'));
      expect(args['album'], equals('The Great Escape'));
      expect(args['duration'], equals(1814.0));
      expect(args['position'], equals(15.0));
      expect(args['rate'], equals(1.0));
      expect(args['trackNumber'], equals(7));
      expect(args['artUrl'], equals('http://localhost/cover.png'));
    });

    test('updatePlaybackState sends position and playback rate', () async {
      await service.updatePlaybackState(
        position: const Duration(seconds: 45),
        isPlaying: false,
      );

      expect(outgoingCalls.length, equals(1));
      expect(outgoingCalls.first.method, equals('updatePlaybackState'));

      final args = outgoingCalls.first.arguments as Map<dynamic, dynamic>;
      expect(args['position'], equals(45.0));
      expect(args['rate'], equals(0.0));
    });

    test('clear sends clearNowPlaying method', () async {
      await service.clear();

      expect(outgoingCalls.length, equals(1));
      expect(outgoingCalls.first.method, equals('clearNowPlaying'));
    });
  });
}
