import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flax/core/tasks/rate_estimator.dart';
import 'package:flax/core/tasks/task.dart';

/// The one place long-running work reports itself, so there is one place the UI
/// reads it from. See issue #43.
///
/// Jobs do not know about Riverpod or about the sidebar. They are handed a
/// [TaskHandle] and call methods on it; everything else — smoothing, ETA,
/// ordering, retention — happens here.
///
/// In-memory only. Surviving a relaunch is issue #44, which moves this into the
/// drift database from #8.
class TaskRegistry extends StateNotifier<List<Task>> {
  TaskRegistry({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const []);

  /// Injectable so rate and ETA behaviour can be tested against a synthetic
  /// series rather than against wall-clock timing.
  final DateTime Function() _clock;

  final _estimators = <String, RateEstimator>{};
  final _onCancel = <String, void Function()>{};

  var _nextId = 0;

  /// How many finished tasks to keep so the panel can say "Cached 5,842 images"
  /// rather than having the row vanish at the moment it becomes interesting.
  static const _keepFinished = 5;

  List<Task> get active => state.where((t) => t.state.isActive).toList();
  List<Task> get finished => state.where((t) => t.state.isTerminal).toList();

  /// Register a new job. The returned handle is the job's only interface.
  ///
  /// [onCancel] is invoked when the user cancels; it is where a `CancelToken`
  /// gets torn down. Providing it is what makes the task [Task.cancelable].
  TaskHandle start({
    required TaskKind kind,
    required String label,
    String? serverId,
    void Function()? onCancel,
  }) {
    final id = 'task-${_nextId++}';
    if (onCancel != null) _onCancel[id] = onCancel;
    _estimators[id] = RateEstimator();

    _put(
      Task(
        id: id,
        kind: kind,
        label: label,
        serverId: serverId,
        state: TaskState.queued,
        cancelable: onCancel != null,
      ),
    );
    return TaskHandle._(this, id);
  }

  void cancel(String id) {
    final task = _find(id);
    if (task == null || task.state.isTerminal) return;
    _onCancel[id]?.call();
    _update(id, (t) => t.copyWith(state: TaskState.canceled, clearRate: true));
  }

  /// Drop finished rows from the list. The active ones are untouched.
  void clearFinished() {
    state = state.where((t) => t.state.isActive).toList();
  }

  Task? _find(String id) {
    for (final t in state) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _put(Task task) {
    state = [...state, task];
  }

  void _update(String id, Task Function(Task) change) {
    var touched = false;
    final next = <Task>[];
    for (final t in state) {
      if (t.id == id) {
        touched = true;
        next.add(change(t));
      } else {
        next.add(t);
      }
    }
    if (!touched) return;

    // Retention: keep every active task, and only the most recent handful of
    // finished ones. Without this a long session accumulates every completed
    // job forever.
    final active = next.where((t) => t.state.isActive).toList();
    final done = next.where((t) => t.state.isTerminal).toList();
    state = [
      ...active,
      ...done.length <= _keepFinished
          ? done
          : done.sublist(done.length - _keepFinished),
    ];

    if (_find(id)?.state.isTerminal ?? false) {
      _estimators.remove(id);
      _onCancel.remove(id);
    }
  }

  /// Records a progress reading and recomputes the derived rate and ETA.
  void _progress(String id, {int? items, int? bytes}) {
    final task = _find(id);
    if (task == null || task.state.isTerminal) return;

    final now = _clock();
    final estimator = _estimators[id];

    final itemsDone = items ?? task.itemsDone;
    final bytesDone = bytes ?? task.bytesDone;

    // Sample whichever counter this kind actually renders, so the rate matches
    // the number next to it.
    final (done, total) = switch (task.kind.unit) {
      ProgressUnit.items => (itemsDone, task.itemsTotal),
      ProgressUnit.bytes => (bytesDone, task.bytesTotal),
    };
    estimator?.sample(done, now);

    _update(
      id,
      (t) => t.copyWith(
        state: t.state == TaskState.running ? null : TaskState.running,
        itemsDone: itemsDone,
        bytesDone: bytesDone,
        ratePerSecond: estimator?.ratePerSecond,
        eta: total == null ? null : estimator?.etaTo(total, now),
      ),
    );
  }
}

/// A running job's view of itself. Handed out by [TaskRegistry.start].
class TaskHandle {
  TaskHandle._(this._registry, this.id);

  final TaskRegistry _registry;
  final String id;

  /// Working out how much there is to do. Progress is indeterminate until
  /// [enumerated] lands.
  void enumerating() {
    _registry._update(id, (t) => t.copyWith(state: TaskState.enumerating));
  }

  /// The total is now known. Either counter may be supplied; the kind decides
  /// which one drives the bar.
  void enumerated({int? items, int? bytes}) {
    _registry._update(
      id,
      (t) => t.copyWith(
        state: TaskState.running,
        itemsTotal: items,
        bytesTotal: bytes,
      ),
    );
  }

  /// Cumulative progress, not a delta.
  void progress({int? items, int? bytes}) {
    _registry._progress(id, items: items, bytes: bytes);
  }

  /// What is happening right now, for phases the counters cannot express.
  /// Pass null to go back to showing the counters.
  void note(String? text) {
    _registry._update(
      id,
      (t) => t.copyWith(note: text, clearNote: text == null),
    );
  }

  /// One unit of work failed. The job carries on; see the note on
  /// [Task.itemsFailed].
  void itemFailed([int count = 1]) {
    _registry._update(
      id,
      (t) => t.copyWith(itemsFailed: t.itemsFailed + count),
    );
  }

  void pause() {
    _registry._update(
      id,
      (t) => t.state.isTerminal
          ? t
          : t.copyWith(state: TaskState.paused, clearRate: true),
    );
  }

  void complete() {
    _registry._update(
      id,
      (t) => t.copyWith(state: TaskState.done, clearRate: true),
    );
  }

  void fail(Object error) {
    _registry._update(
      id,
      (t) => t.copyWith(
        state: TaskState.failed,
        error: error.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
        clearRate: true,
      ),
    );
  }

  /// True once the user has canceled. Long loops should check this between
  /// units and stop cooperatively rather than relying only on the teardown
  /// passed to [TaskRegistry.start].
  bool get isCanceled => _registry._find(id)?.state == TaskState.canceled;
}

final taskRegistryProvider = StateNotifierProvider<TaskRegistry, List<Task>>((
  ref,
) {
  return TaskRegistry();
});

/// Just the running work — what the sidebar indicator counts.
final activeTasksProvider = Provider<List<Task>>((ref) {
  return ref
      .watch(taskRegistryProvider)
      .where((t) => t.state.isActive)
      .toList();
});
