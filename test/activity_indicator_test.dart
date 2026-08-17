import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flax/core/tasks/task.dart';
import 'package:flax/shared/widgets/activity_indicator.dart';

/// The sidebar's background-work row and its panel. Issue #43.
///
/// Both widgets under test take plain data, so none of this needs a registry, a
/// server, mpv or a router.
void main() {
  Task task({
    String id = 't1',
    String label = 'AutoEQ database',
    TaskKind kind = TaskKind.autoEqDatabase,
    TaskState state = TaskState.running,
    int itemsDone = 0,
    int? itemsTotal,
    int bytesDone = 0,
    int? bytesTotal,
    int itemsFailed = 0,
    bool cancelable = false,
    String? note,
    String? error,
  }) => Task(
    id: id,
    kind: kind,
    label: label,
    state: state,
    itemsDone: itemsDone,
    itemsTotal: itemsTotal,
    bytesDone: bytesDone,
    bytesTotal: bytesTotal,
    itemsFailed: itemsFailed,
    cancelable: cancelable,
    note: note,
    error: error,
  );

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SizedBox(width: 220, child: child)),
      ),
    );
  }

  group('ActivityIndicatorView', () {
    testWidgets('takes no height at all when nothing is running', (
      tester,
    ) async {
      await pump(tester, const ActivityIndicatorView(tasks: []));

      // Not merely invisible — zero-sized. An always-present empty row would
      // shift Settings every time a job started and stopped.
      expect(
        tester.getSize(find.byType(ActivityIndicatorView)),
        const Size(220, 0),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a single task names itself and shows its progress', (
      tester,
    ) async {
      await pump(
        tester,
        ActivityIndicatorView(
          tasks: [task(bytesDone: 12400000, bytesTotal: 98100000)],
        ),
      );

      expect(find.text('AutoEQ database'), findsOneWidget);
      // Compact form: no total (the ring shows the fraction) and no ETA. The
      // full form is ellipsised by the 220px rail — "100 MB of 105 MB · 15 M…"
      // is what actually rendered before this was split out.
      expect(find.text('12 MB'), findsOneWidget);
    });

    testWidgets('the collapsed line drops the total and the ETA', (
      tester,
    ) async {
      await pump(
        tester,
        ActivityIndicatorView(
          tasks: [
            Task(
              id: 't',
              kind: TaskKind.autoEqDatabase,
              label: 'AutoEQ database',
              state: TaskState.running,
              bytesDone: 100000000,
              bytesTotal: 105000000,
              ratePerSecond: 15000000,
              eta: const Duration(seconds: 30),
            ),
          ],
        ),
      );

      expect(find.text('100 MB · 15 MB/s'), findsOneWidget);
      expect(find.textContaining('of 105 MB'), findsNothing);
      expect(find.textContaining('about'), findsNothing);
      expect(
        tester.widget<Text>(find.text('100 MB · 15 MB/s')).overflow,
        TextOverflow.ellipsis,
      );
    });

    testWidgets('several tasks collapse to a count', (tester) async {
      await pump(
        tester,
        ActivityIndicatorView(
          tasks: [
            task(id: 'a', label: 'AutoEQ database'),
            task(id: 'b', label: 'Caching art', kind: TaskKind.artPrecache),
            task(
              id: 'c',
              label: 'Syncing library',
              kind: TaskKind.metadataCrawl,
            ),
          ],
        ),
      );

      // Three truncated labels in a 220px rail say less than the count does.
      expect(find.text('3 background tasks'), findsOneWidget);
      expect(find.text('AutoEQ database'), findsNothing);
    });

    testWidgets('the ring is determinate only with a known total', (
      tester,
    ) async {
      await pump(tester, ActivityIndicatorView(tasks: [task(bytesDone: 500)]));
      var ring = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(ring.value, isNull);

      await pump(
        tester,
        ActivityIndicatorView(tasks: [task(bytesDone: 500, bytesTotal: 1000)]),
      );
      ring = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(ring.value, closeTo(0.5, 1e-9));
    });

    testWidgets('a phase note wins over counters that have stopped', (
      tester,
    ) async {
      await pump(
        tester,
        ActivityIndicatorView(
          tasks: [
            task(
              bytesDone: 98100000,
              bytesTotal: 98100000,
              note: 'Extracting profiles...',
            ),
          ],
        ),
      );

      expect(find.text('Extracting profiles...'), findsOneWidget);
      expect(find.textContaining('98 MB of'), findsNothing);
    });

    testWidgets('tapping calls back', (tester) async {
      var taps = 0;
      await pump(
        tester,
        ActivityIndicatorView(tasks: [task()], onTap: () => taps++),
      );
      await tester.tap(find.byType(ActivityIndicatorView));
      expect(taps, 1);
    });
  });

  group('ActivityPanelView', () {
    testWidgets('lists every task with its own bar', (tester) async {
      await pump(
        tester,
        ActivityPanelView(
          tasks: [
            task(id: 'a', label: 'AutoEQ database'),
            task(
              id: 'b',
              label: 'Caching art',
              kind: TaskKind.artPrecache,
              itemsDone: 2140,
              itemsTotal: 5842,
            ),
          ],
        ),
      );

      expect(find.text('AutoEQ database'), findsOneWidget);
      expect(find.text('Caching art'), findsOneWidget);
      expect(find.text('2140 of 5842'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    });

    testWidgets('only cancelable, unfinished tasks offer a cancel', (
      tester,
    ) async {
      await pump(
        tester,
        ActivityPanelView(
          tasks: [
            task(id: 'a', label: 'Cancelable', cancelable: true),
            task(id: 'b', label: 'Not cancelable'),
            task(
              id: 'c',
              label: 'Already done',
              cancelable: true,
              state: TaskState.done,
            ),
          ],
          onCancel: (_) {},
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('cancel reports which task', (tester) async {
      Task? canceled;
      await pump(
        tester,
        ActivityPanelView(
          tasks: [task(id: 'a', label: 'Cancelable', cancelable: true)],
          onCancel: (t) => canceled = t,
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(canceled?.id, 'a');
    });

    testWidgets('a failed task shows its error, not its counters', (
      tester,
    ) async {
      await pump(
        tester,
        ActivityPanelView(
          tasks: [
            task(
              label: 'AutoEQ database',
              state: TaskState.failed,
              error: 'Connection closed',
            ),
          ],
        ),
      );

      expect(find.textContaining('Connection closed'), findsOneWidget);
      expect(find.textContaining('Failed'), findsOneWidget);
      // Terminal rows drop the bar — there is nothing left to progress.
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('failed items are surfaced without failing the task', (
      tester,
    ) async {
      await pump(
        tester,
        ActivityPanelView(
          tasks: [
            task(
              label: 'Caching art',
              kind: TaskKind.artPrecache,
              itemsDone: 5830,
              itemsTotal: 5842,
              itemsFailed: 12,
            ),
          ],
        ),
      );

      expect(find.textContaining('12 failed'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('clear finished appears only when something has finished', (
      tester,
    ) async {
      await pump(
        tester,
        ActivityPanelView(tasks: [task()], onClearFinished: () {}),
      );
      expect(find.text('Clear finished'), findsNothing);

      await pump(
        tester,
        ActivityPanelView(
          tasks: [task(state: TaskState.done)],
          onClearFinished: () {},
        ),
      );
      expect(find.text('Clear finished'), findsOneWidget);
    });
  });
}
