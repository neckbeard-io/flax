import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flax/domain/models/models.dart';
import 'package:flax/features/player/lyrics_panel.dart';
import 'package:flax/features/player/lyrics_provider.dart';
import 'package:flax/features/player/player_provider.dart';

void main() {
  final song = Song(
    id: 's1',
    serverId: 'srv1',
    title: 'Black Diamond',
    artistName: 'Stratovarius',
    albumName: 'Visions',
    duration: 300,
  );

  const enhancedLrcText = '''
[00:10.00]<00:10.00>Again <00:12.00>I <00:14.00>see <00:16.00>you
[00:20.00]Standing there
''';

  final lyrics = Lyrics.fromLrcText(enhancedLrcText)!;

  Widget buildPanel({
    Lyrics? currentLyrics,
    Duration position = Duration.zero,
    Song? currentSong,
  }) {
    return ProviderScope(
      overrides: [
        playerProvider.overrideWith(
          (ref) => _FakePlayerNotifier(
            PlayerState(currentSong: currentSong ?? song, position: position),
          ),
        ),
        currentLyricsProvider.overrideWithValue(
          AsyncValue.data(currentLyrics ?? lyrics),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const Scaffold(body: LyricsPanel()),
      ),
    );
  }

  testWidgets('renders clean text without raw LRC/XML tags', (tester) async {
    await tester.pumpWidget(buildPanel(currentLyrics: lyrics));
    await tester.pumpAndSettle();

    // Verify clean text is rendered, not <00:10.00> XML/LRC tags
    expect(find.text('Again I see you'), findsOneWidget);
    expect(find.text('Standing there'), findsOneWidget);
    expect(find.textContaining('<00:10.00>'), findsNothing);
  });

  testWidgets('highlights sung words when active and position advances', (
    tester,
  ) async {
    // At 13s, line 0 is active (start 10s).
    // Word "Again " starts at 10s (sung).
    // Word "I " starts at 12s (sung).
    // Word "see " starts at 14s (unreached).
    // Word "you" starts at 16s (unreached).
    await tester.pumpWidget(
      buildPanel(currentLyrics: lyrics, position: const Duration(seconds: 13)),
    );
    await tester.pumpAndSettle();

    // Verify rich text is rendered with words
    final richTextFinder = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains('Again'),
    );
    expect(richTextFinder, findsOneWidget);

    final richText = tester.widget<RichText>(richTextFinder);
    final rootSpan = richText.text as TextSpan;
    final textSpan =
        (rootSpan.children != null && rootSpan.children!.isNotEmpty)
        ? rootSpan.children!.first as TextSpan
        : rootSpan;

    expect(textSpan.children, isNotNull);
    expect(textSpan.children!.length, 4);

    final word0 = textSpan.children![0] as TextSpan;
    final word1 = textSpan.children![1] as TextSpan;
    final word2 = textSpan.children![2] as TextSpan;
    final word3 = textSpan.children![3] as TextSpan;

    expect(word0.text, 'Again ');
    expect(word0.style?.fontWeight, FontWeight.w700);

    expect(word1.text, 'I ');
    expect(word1.style?.fontWeight, FontWeight.w700);

    expect(word2.text, 'see ');
    expect(word2.style?.fontWeight, FontWeight.w500);

    expect(word3.text, 'you');
    expect(word3.style?.fontWeight, FontWeight.w500);
  });

  testWidgets('renders on mobile phone dimensions without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildPanel(currentLyrics: lyrics, position: const Duration(seconds: 12)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Again I see you'), findsOneWidget);
  });
}

class _FakePlayerNotifier extends StateNotifier<PlayerState>
    implements PlayerNotifier {
  _FakePlayerNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
