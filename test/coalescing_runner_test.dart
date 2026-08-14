import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flax/shared/async/coalescing_runner.dart';

/// The property that matters is that the **last request** wins, not the last
/// completion. Overlapping runs read state at different moments and finish in
/// whatever order the far end decides, which is how the EQ came up off at
/// startup while every setting said it was on (#35).
void main() {
  test('runs immediately when idle', () async {
    final runner = CoalescingRunner();
    var runs = 0;
    await runner.run(() async => runs++);
    expect(runs, 1);
  });

  test('never runs two actions at once', () async {
    final runner = CoalescingRunner();
    var concurrent = 0;
    var maxConcurrent = 0;
    final gate = Completer<void>();

    Future<void> action() async {
      concurrent++;
      maxConcurrent = concurrent > maxConcurrent ? concurrent : maxConcurrent;
      await gate.future;
      concurrent--;
    }

    final first = runner.run(action);
    final second = runner.run(action);
    gate.complete();
    await Future.wait([first, second]);

    expect(maxConcurrent, 1);
  });

  test('a request during a run causes exactly one more run', () async {
    final runner = CoalescingRunner();
    var runs = 0;
    final gate = Completer<void>();

    final first = runner.run(() async {
      runs++;
      await gate.future;
    });
    // Three requests while busy must collapse into a single re-run, not three.
    await runner.run(() async => runs++);
    await runner.run(() async => runs++);
    await runner.run(() async => runs++);
    expect(runs, 1, reason: 'coalesced requests do not run on their own');

    gate.complete();
    await first;
    expect(runs, 2);
  });

  test('the re-run sees state written after the first run started', () async {
    // The actual bug: the value the far end keeps must be the newest, not
    // whichever write finished last.
    final runner = CoalescingRunner();
    var current = 'stale';
    final written = <String>[];
    final gate = Completer<void>();

    final first = runner.run(() async {
      written.add(current);
      await gate.future;
    });

    current = 'fresh';
    await runner.run(() async => written.add(current));

    gate.complete();
    await first;

    expect(written, ['stale', 'fresh']);
    expect(written.last, 'fresh', reason: 'the newest state must land last');
  });

  test('no re-run when nothing was requested while busy', () async {
    final runner = CoalescingRunner();
    var runs = 0;
    await runner.run(() async => runs++);
    await runner.run(() async => runs++);
    expect(runs, 2, reason: 'sequential calls each run, without extra passes');
  });

  test('a throwing action leaves the runner usable', () async {
    final runner = CoalescingRunner();
    await expectLater(
      runner.run(() async => throw StateError('boom')),
      throwsStateError,
    );
    expect(runner.isRunning, isFalse);

    var runs = 0;
    await runner.run(() async => runs++);
    expect(runs, 1);
  });

  test(
    'a request made during a failing run is not silently dropped forever',
    () async {
      // The flag has to be cleared on the way out, or one exception wedges every
      // later request into "someone else will run it" and nothing ever does.
      final runner = CoalescingRunner();
      final gate = Completer<void>();
      final first = runner.run(() async {
        await gate.future;
        throw StateError('boom');
      });
      await runner.run(() async {});
      gate.complete();
      await expectLater(first, throwsStateError);

      var runs = 0;
      await runner.run(() async => runs++);
      expect(runs, 1);
    },
  );
}
