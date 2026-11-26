import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/core/providers/library_provider.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/player_provider.dart';
import 'package:flax/features/player/queue_panel.dart';

class _FakePlayerNotifier extends StateNotifier<PlayerState>
    implements PlayerNotifier {
  _FakePlayerNotifier(super.state);

  void playAt(int index, {Duration position = Duration.zero}) {
    state = state.copyWith(
      queueIndex: index,
      currentSong: state.queue[index],
      position: position,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 60 tracks of 100s each, ten to an album.
final _queue = [
  for (var i = 0; i < 60; i++)
    Song(
      id: 's$i',
      serverId: 'srv',
      title: 'Song ${i + 1}',
      artistName: 'Artist',
      albumName: 'Album ${i ~/ 10 + 1}',
      track: i % 10 + 1,
      duration: 100,
    ),
];

Future<_FakePlayerNotifier> _pump(
  WidgetTester tester, {
  int index = 0,
  Duration position = Duration.zero,
  Size size = const Size(800, 700),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final player = _FakePlayerNotifier(
    PlayerState(
      queue: _queue,
      queueIndex: index,
      currentSong: _queue[index],
      position: position,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerProvider.overrideWith((ref) => player),
        downloadedSongIdsProvider.overrideWith((ref) => Stream.value(const {})),
      ],
      child: const MaterialApp(home: Scaffold(body: QueuePanel())),
    ),
  );
  await tester.pumpAndSettle();
  return player;
}

bool _inView(WidgetTester tester, String title) {
  final finder = find.text(title);
  if (finder.evaluate().isEmpty) return false;
  final list = tester.getRect(find.byType(ListView));
  final row = tester.getRect(finder);
  return row.top >= list.top && row.bottom <= list.bottom;
}

final _showPlaying = find.byKey(const ValueKey('queue-show-playing'));

void main() {
  test('time left counts the rest of the track and everything after', () {
    expect(queueSecondsLeft(_queue, 4, const Duration(seconds: 30)), 5570);
    expect(queueSecondsLeft(_queue, 59, const Duration(seconds: 250)), 0);
    expect(queueSecondsLeft(_queue, -1, Duration.zero), 0);
  });

  testWidgets('summary shows position, total and time left', (tester) async {
    await _pump(tester, index: 4, position: const Duration(seconds: 30));

    expect(
      find.text('Track 5 of 60 · 1:40:00 total · 1:32:50 left'),
      findsOneWidget,
    );
  });

  testWidgets('opening the queue scrolls to the playing track', (tester) async {
    await _pump(tester, index: 45);

    expect(_inView(tester, 'Song 46'), isTrue);
    expect(_showPlaying, findsNothing);
  });

  testWidgets('the list follows the playing track', (tester) async {
    final player = await _pump(tester);
    expect(_inView(tester, 'Song 1'), isTrue);
    expect(_inView(tester, 'Song 41'), isFalse);

    player.playAt(40);
    await tester.pumpAndSettle();

    expect(_inView(tester, 'Song 41'), isTrue);
    expect(_showPlaying, findsNothing);
  });

  testWidgets('scrolling away stops following and offers a way back', (
    tester,
  ) async {
    final player = await _pump(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(_inView(tester, 'Song 1'), isFalse);
    expect(_showPlaying, findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    // The next track starts: the list stays where it was put.
    final before = tester.getRect(find.byType(ListView));
    final anchor = tester.getRect(find.text('Album 4').first);
    player.playAt(1);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Album 4').first), anchor);
    expect(tester.getRect(find.byType(ListView)), before);
    expect(_inView(tester, 'Song 2'), isFalse);

    await tester.tap(_showPlaying);
    await tester.pumpAndSettle();

    expect(_inView(tester, 'Song 2'), isTrue);
    expect(_showPlaying, findsNothing);
  });

  testWidgets('a song queued twice is marked playing only once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final song = _queue.first;
    final player = _FakePlayerNotifier(
      PlayerState(queue: [song, song], queueIndex: 1, currentSong: song),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith((ref) => player),
          downloadedSongIdsProvider.overrideWith(
            (ref) => Stream.value(const {}),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: QueuePanel())),
      ),
    );
    await tester.pumpAndSettle();

    final titles = tester
        .widgetList<Text>(find.text('Song 1'))
        .where((t) => t.style?.fontWeight == FontWeight.w600);
    expect(titles, hasLength(1));
  });

  testWidgets('queue renders on phone dimensions without overflow', (
    tester,
  ) async {
    await _pump(
      tester,
      index: 30,
      position: const Duration(seconds: 12),
      size: const Size(390, 844),
    );

    final summary = tester.getRect(find.byKey(const ValueKey('queue-summary')));
    expect(summary.right, lessThanOrEqualTo(390));
    expect(_inView(tester, 'Song 31'), isTrue);
  });
}
