import 'package:flutter_test/flutter_test.dart';

import 'package:flax/core/tasks/rate_estimator.dart';
import 'package:flax/core/tasks/task.dart';
import 'package:flax/core/tasks/task_registry.dart';

/// The task framework's arithmetic and state machine, with no widgets involved.
/// Issue #43.
void main() {
  final t0 = DateTime.utc(2026, 1, 1);

  group('RateEstimator', () {
    test('reports nothing until it has two readings', () {
      final e = RateEstimator();
      expect(e.ratePerSecond, isNull);
      e.sample(0, t0);
      expect(e.ratePerSecond, isNull);
      e.sample(10, t0.add(const Duration(seconds: 1)));
      expect(e.ratePerSecond, closeTo(10, 0.001));
    });

    test('a steady series converges on the true rate', () {
      final e = RateEstimator();
      for (var i = 0; i <= 30; i++) {
        e.sample(i * 20, t0.add(Duration(seconds: i)));
      }
      expect(e.ratePerSecond, closeTo(20, 0.5));
    });

    test('survives the cold-to-warm step change without overreacting', () {
      // The measured case from #32: covers arrive at ~20/s while the server
      // resizes them, then at ~290/s once its own cache is warm. The average
      // must move to the new reality, but not instantly — a single fast sample
      // should not rewrite the estimate.
      final e = RateEstimator(halfLife: const Duration(seconds: 5));
      var done = 0;
      for (var i = 1; i <= 20; i++) {
        done += 20;
        e.sample(done, t0.add(Duration(seconds: i)));
      }
      expect(e.ratePerSecond, closeTo(20, 1));

      // One second of the warm rate barely moves it.
      done += 290;
      e.sample(done, t0.add(const Duration(seconds: 21)));
      expect(e.ratePerSecond, lessThan(80));

      // Sustained, it gets there.
      for (var i = 22; i <= 45; i++) {
        done += 290;
        e.sample(done, t0.add(Duration(seconds: i)));
      }
      expect(e.ratePerSecond, closeTo(290, 15));
    });

    test('offers no ETA during warmup, however confident the rate looks', () {
      final e = RateEstimator(warmup: const Duration(seconds: 10));
      e.sample(0, t0);
      e.sample(100, t0.add(const Duration(seconds: 1)));

      expect(e.ratePerSecond, isNotNull);
      expect(e.etaTo(1000, t0.add(const Duration(seconds: 1))), isNull);

      // Past warmup the same rate does produce one.
      for (var i = 2; i <= 12; i++) {
        e.sample(i * 100, t0.add(Duration(seconds: i)));
      }
      final eta = e.etaTo(2000, t0.add(const Duration(seconds: 12)));
      expect(eta, isNotNull);
      expect(eta!.inSeconds, closeTo(8, 2));
    });

    test('a stalled job reports no ETA rather than a fictional one', () {
      final e = RateEstimator(warmup: Duration.zero);
      e.sample(0, t0);
      e.sample(100, t0.add(const Duration(seconds: 1)));
      // Nothing moves for a long time; the average decays to nothing.
      for (var i = 2; i <= 200; i++) {
        e.sample(100, t0.add(Duration(seconds: i)));
      }
      expect(e.etaTo(100000, t0.add(const Duration(seconds: 200))), isNull);
    });

    test('progress going backwards does not produce a negative rate', () {
      final e = RateEstimator();
      e.sample(500, t0);
      e.sample(100, t0.add(const Duration(seconds: 1)));
      expect(e.ratePerSecond, greaterThanOrEqualTo(0));
    });
  });

  group('Task', () {
    Task make({
      TaskKind kind = TaskKind.artPrecache,
      int itemsDone = 0,
      int? itemsTotal,
      int bytesDone = 0,
      int? bytesTotal,
    }) => Task(
      id: 'x',
      kind: kind,
      label: 'l',
      state: TaskState.running,
      itemsDone: itemsDone,
      itemsTotal: itemsTotal,
      bytesDone: bytesDone,
      bytesTotal: bytesTotal,
    );

    test('is indeterminate until the total lands', () {
      expect(make(itemsDone: 40).fraction, isNull);
      expect(make(itemsDone: 40, itemsTotal: 80).fraction, closeTo(0.5, 1e-9));
    });

    test('a non-positive total stays indeterminate', () {
      // dio reports total as -1 when there is no Content-Length. Treating that
      // as a real total would divide progress by a negative number.
      expect(
        make(
          kind: TaskKind.autoEqDatabase,
          bytesDone: 10,
          bytesTotal: -1,
        ).fraction,
        isNull,
      );
    });

    test('reads whichever counter its kind declares', () {
      // A bytes kind ignores item counts entirely, and the reverse.
      final bytesKind = make(
        kind: TaskKind.autoEqDatabase,
        itemsDone: 5,
        itemsTotal: 10,
        bytesDone: 25,
        bytesTotal: 100,
      );
      expect(bytesKind.fraction, closeTo(0.25, 1e-9));

      final itemsKind = make(
        kind: TaskKind.artPrecache,
        itemsDone: 5,
        itemsTotal: 10,
        bytesDone: 25,
        bytesTotal: 100,
      );
      expect(itemsKind.fraction, closeTo(0.5, 1e-9));
    });
  });

  group('formatting', () {
    test('bytes use decimal units', () {
      expect(formatBytes(999), '999 B');
      expect(formatBytes(1500), '1.5 KB');
      expect(formatBytes(98100000), '98 MB');
    });

    test('eta is coarse on purpose', () {
      expect(formatEta(const Duration(seconds: 3)), 'almost done');
      expect(formatEta(const Duration(seconds: 40)), 'less than a minute');
      expect(formatEta(const Duration(minutes: 1)), 'about 1 minute');
      expect(formatEta(const Duration(minutes: 5)), 'about 5 minutes');
      expect(formatEta(const Duration(minutes: 90)), 'about 2 hours');
    });

    test('the compact line is materially shorter than the full one', () {
      // The sidebar rail is 220px. The full line rendered there as
      // "100 MB of 105 MB · 15 M…" — ellipsised mid-rate, which is the one part
      // that proves the job is moving. The compact form drops the total (the
      // ring already shows it) and the ETA (the panel has room).
      const task = Task(
        id: 'x',
        kind: TaskKind.autoEqDatabase,
        label: 'AutoEQ database',
        state: TaskState.running,
        bytesDone: 100000000,
        bytesTotal: 105000000,
        ratePerSecond: 15000000,
        eta: Duration(seconds: 30),
      );

      expect(formatCompactLine(task), '100 MB · 15 MB/s');
      expect(formatProgressLine(task), contains('of 105 MB'));
      expect(
        formatCompactLine(task).length,
        lessThan(formatProgressLine(task).length),
      );
    });

    test('the compact line keeps item counts, which are the whole point', () {
      const task = Task(
        id: 'x',
        kind: TaskKind.artPrecache,
        label: 'Caching art',
        state: TaskState.running,
        itemsDone: 2140,
        itemsTotal: 5842,
        ratePerSecond: 18,
        itemsFailed: 3,
      );
      expect(formatCompactLine(task), '2140/5842 · 18/s · 3 failed');
    });

    test('audio downloads format rate as MB/s or KB/s rather than items/s', () {
      expect(formatRate(2500000, ProgressUnit.bytes), '2.5 MB/s');
      expect(formatRate(450000, ProgressUnit.bytes), '450 KB/s');
      expect(formatRate(12000000, ProgressUnit.bytes), '12 MB/s');

      const audioTask = Task(
        id: 'audio-1',
        kind: TaskKind.audioDownload,
        label: 'Downloading tracks',
        state: TaskState.running,
        itemsDone: 3,
        itemsTotal: 74,
        bytesDone: 25000000,
        bytesTotal: 250000000,
        ratePerSecond: 3200000,
      );
      expect(formatProgressLine(audioTask), contains('3.2 MB/s'));
      expect(formatCompactLine(audioTask), '25 MB · 3.2 MB/s');
    });

    test('a note replaces the counters', () {
      const task = Task(
        id: 'x',
        kind: TaskKind.autoEqDatabase,
        label: 'AutoEQ database',
        state: TaskState.running,
        bytesDone: 100,
        bytesTotal: 100,
        note: 'Extracting profiles...',
      );
      // Without the note this would read "100 B of 100 B" — a bar sitting at
      // 100% while the job is very much still working.
      expect(formatProgressLine(task), 'Extracting profiles...');
    });
  });

  group('TaskRegistry', () {
    test(
      'a new task starts queued and is not cancelable without a teardown',
      () {
        final r = TaskRegistry();
        r.start(kind: TaskKind.metadataCrawl, label: 'Crawl');
        expect(r.state.single.state, TaskState.queued);
        expect(r.state.single.cancelable, isFalse);
      },
    );

    test('progress moves it to running and fills in the rate', () {
      var now = DateTime.utc(2026, 1, 1);
      final r = TaskRegistry(clock: () => now);
      final h = r.start(kind: TaskKind.artPrecache, label: 'Art');
      h.enumerated(items: 100);

      h.progress(items: 0);
      now = now.add(const Duration(seconds: 1));
      h.progress(items: 20);

      final task = r.state.single;
      expect(task.state, TaskState.running);
      expect(task.itemsDone, 20);
      expect(task.fraction, closeTo(0.2, 1e-9));
      expect(task.ratePerSecond, closeTo(20, 0.001));
    });

    test('failed items do not fail the task', () {
      final r = TaskRegistry();
      final h = r.start(kind: TaskKind.artPrecache, label: 'Art');
      h.enumerated(items: 10);
      h.progress(items: 5);
      h.itemFailed();
      h.itemFailed(2);

      expect(r.state.single.itemsFailed, 3);
      expect(r.state.single.state, TaskState.running);

      h.complete();
      expect(r.state.single.state, TaskState.done);
      expect(r.state.single.itemsFailed, 3);
    });

    test('cancel runs the teardown and marks the task canceled', () {
      var torn = false;
      final r = TaskRegistry();
      final h = r.start(
        kind: TaskKind.autoEqDatabase,
        label: 'AutoEQ',
        onCancel: () => torn = true,
      );
      expect(r.state.single.cancelable, isTrue);
      expect(h.isCanceled, isFalse);

      r.cancel(h.id);

      expect(torn, isTrue);
      expect(h.isCanceled, isTrue);
      expect(r.state.single.state, TaskState.canceled);
    });

    test('progress after a terminal state is ignored', () {
      final r = TaskRegistry();
      final h = r.start(kind: TaskKind.artPrecache, label: 'Art');
      h.enumerated(items: 10);
      h.complete();
      h.progress(items: 9);
      expect(r.state.single.state, TaskState.done);
      expect(r.state.single.itemsDone, 0);
    });

    test('finished tasks are retained, but not without limit', () {
      final r = TaskRegistry();
      for (var i = 0; i < 9; i++) {
        r.start(kind: TaskKind.artPrecache, label: 'Job $i').complete();
      }
      expect(r.finished, hasLength(5));
      // The most recent survive, the oldest are dropped.
      expect(r.finished.last.label, 'Job 8');
      expect(r.finished.first.label, 'Job 4');
    });

    test('clearFinished leaves active work alone', () {
      final r = TaskRegistry();
      r.start(kind: TaskKind.artPrecache, label: 'Done').complete();
      final live = r.start(kind: TaskKind.metadataCrawl, label: 'Live');
      live.progress(items: 1);

      r.clearFinished();

      expect(r.state, hasLength(1));
      expect(r.state.single.label, 'Live');
    });

    test('the active list excludes anything terminal', () {
      final r = TaskRegistry();
      r.start(kind: TaskKind.artPrecache, label: 'Done').complete();
      r.start(kind: TaskKind.artPrecache, label: 'Failed').fail('boom');
      final live = r.start(kind: TaskKind.metadataCrawl, label: 'Live');
      live.progress(items: 1);

      expect(r.active.map((t) => t.label), ['Live']);
      expect(r.state.firstWhere((t) => t.label == 'Failed').error, 'boom');
    });
  });
}
