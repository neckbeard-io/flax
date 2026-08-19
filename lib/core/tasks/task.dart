/// A long-running background job and everything the UI needs to draw it.
///
/// See issue #43. The shape here is deliberate in three places:
///
/// - [enumerating] is a state of its own. Some jobs know their size up front
///   (art precache counts rows); others must ask the server first. Reporting
///   determinate progress before the total lands makes the bar jump backwards.
/// - [itemsTotal] and [bytesTotal] are nullable. Anything else forces a lie.
/// - [itemsFailed] is not failure. One missing cover must not kill a job of
///   several thousand; finish the run and offer a retry of what failed.
library;

/// Which counter is the headline for a kind of work.
///
/// Art averages ~13 KiB an image, so bytes/sec reads as pathetic while
/// items/sec reads fine. Audio is the reverse — track counts mean nothing and
/// MB/s is what people understand. Both counters are always tracked; this only
/// decides what gets rendered.
enum ProgressUnit { items, bytes }

enum TaskKind {
  autoEqDatabase,
  metadataCrawl,
  artPrecache,
  audioDownload;

  ProgressUnit get unit => switch (this) {
    TaskKind.autoEqDatabase => ProgressUnit.bytes,
    TaskKind.metadataCrawl => ProgressUnit.items,
    TaskKind.artPrecache => ProgressUnit.items,
    TaskKind.audioDownload => ProgressUnit.bytes,
  };
}

enum TaskState {
  queued,
  enumerating,
  running,
  paused,
  done,
  failed,
  canceled;

  /// Still occupying the queue — the activity indicator shows these.
  bool get isActive => switch (this) {
    TaskState.queued ||
    TaskState.enumerating ||
    TaskState.running ||
    TaskState.paused => true,
    _ => false,
  };

  /// Finished for good, however it ended.
  bool get isTerminal => !isActive;

  String get label => switch (this) {
    TaskState.queued => 'Waiting',
    TaskState.enumerating => 'Preparing',
    TaskState.running => 'Running',
    TaskState.paused => 'Paused',
    TaskState.done => 'Done',
    TaskState.failed => 'Failed',
    TaskState.canceled => 'Canceled',
  };
}

class Task {
  const Task({
    required this.id,
    required this.kind,
    required this.label,
    required this.state,
    this.serverId,
    this.itemsDone = 0,
    this.itemsTotal,
    this.bytesDone = 0,
    this.bytesTotal,
    this.itemsFailed = 0,
    this.cancelable = false,
    this.error,
    this.note,
    this.ratePerSecond,
    this.eta,
  });

  final String id;
  final TaskKind kind;

  /// Which server this belongs to, for work that is per-server. Null for jobs
  /// that are not — the AutoEQ database is global.
  final String? serverId;

  final String label;
  final TaskState state;

  final int itemsDone;
  final int? itemsTotal;
  final int bytesDone;
  final int? bytesTotal;
  final int itemsFailed;

  final bool cancelable;
  final String? error;

  /// What the job is doing right now, when counters alone would mislead.
  ///
  /// Phased work needs this. The AutoEQ download spends its first minute
  /// fetching bytes and its next stretch unpacking ~8,850 profiles, and without
  /// a note that second phase renders as a bar frozen at 100%. When set, this
  /// replaces the computed progress line.
  final String? note;

  /// Smoothed rate in [ProgressUnit] per second, and the estimate derived from
  /// it. Both are derived rather than stored state — the registry fills them in
  /// from a [RateEstimator] so the UI only has one type to read. Both are null
  /// until an estimate is trustworthy; see `rate_estimator.dart` for why that
  /// matters more here than it usually would.
  final double? ratePerSecond;
  final Duration? eta;

  /// 0..1, or null when the total is not yet known.
  ///
  /// Reads whichever counter the kind declares, falling back to the other counter
  /// if the primary counter's total is null.
  double? get fraction {
    final (done, total) = switch (kind.unit) {
      ProgressUnit.items => (itemsDone, itemsTotal),
      ProgressUnit.bytes => (bytesDone, bytesTotal),
    };
    if (total != null && total > 0) {
      return (done / total).clamp(0.0, 1.0);
    }
    if (kind.unit == ProgressUnit.bytes &&
        itemsTotal != null &&
        itemsTotal! > 0) {
      return (itemsDone / itemsTotal!).clamp(0.0, 1.0);
    }
    if (kind.unit == ProgressUnit.items &&
        bytesTotal != null &&
        bytesTotal! > 0) {
      return (bytesDone / bytesTotal!).clamp(0.0, 1.0);
    }
    return null;
  }

  bool get isDeterminate => fraction != null;

  Task copyWith({
    TaskState? state,
    int? itemsDone,
    int? itemsTotal,
    int? bytesDone,
    int? bytesTotal,
    int? itemsFailed,
    bool? cancelable,
    String? error,
    String? note,
    bool clearNote = false,
    double? ratePerSecond,
    Duration? eta,
    bool clearRate = false,
  }) {
    return Task(
      id: id,
      kind: kind,
      serverId: serverId,
      label: label,
      state: state ?? this.state,
      itemsDone: itemsDone ?? this.itemsDone,
      itemsTotal: itemsTotal ?? this.itemsTotal,
      bytesDone: bytesDone ?? this.bytesDone,
      bytesTotal: bytesTotal ?? this.bytesTotal,
      itemsFailed: itemsFailed ?? this.itemsFailed,
      cancelable: cancelable ?? this.cancelable,
      error: error ?? this.error,
      note: clearNote ? null : (note ?? this.note),
      ratePerSecond: clearRate ? null : (ratePerSecond ?? this.ratePerSecond),
      eta: clearRate ? null : (eta ?? this.eta),
    );
  }
}

/// `1.2 MB`, `948 KB`, `12 B`. Decimal units, because that is what every
/// download UI and every storage vendor means by MB.
String formatBytes(int bytes) {
  if (bytes < 1000) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  return '${value < 10 ? value.toStringAsFixed(1) : value.round()} '
      '${units[unit]}';
}

/// `1.2 MB/s` or `18/s`, depending on what the kind counts.
String formatRate(double perSecond, ProgressUnit unit) {
  return switch (unit) {
    ProgressUnit.bytes => '${formatBytes(perSecond.round())}/s',
    ProgressUnit.items =>
      '${perSecond < 10 ? perSecond.toStringAsFixed(1) : perSecond.round()}/s',
  };
}

/// Deliberately coarse. Throughput against a music server can swing by more
/// than an order of magnitude mid-job once the server's own caches warm, so a
/// countdown to the second would be false precision. See `rate_estimator.dart`.
String formatEta(Duration eta) {
  final seconds = eta.inSeconds;
  if (seconds < 10) return 'almost done';
  if (seconds < 60) return 'less than a minute';
  final minutes = eta.inMinutes;
  if (minutes < 60) return 'about $minutes minute${minutes == 1 ? '' : 's'}';
  final hours = (minutes / 60).round();
  return 'about $hours hour${hours == 1 ? '' : 's'}';
}

/// The one-line summary under a task's label: `12.4 MB of 98.1 MB · 1.2 MB/s`.
///
/// A [Task.note] wins outright — a phase the counters cannot express is more
/// informative than counters that have stopped moving.
String formatProgressLine(Task task) {
  final note = task.note;
  if (note != null && note.isNotEmpty) return note;

  final parts = <String>[];

  switch (task.kind.unit) {
    case ProgressUnit.bytes:
      final total = task.bytesTotal;
      parts.add(
        total == null
            ? formatBytes(task.bytesDone)
            : '${formatBytes(task.bytesDone)} of ${formatBytes(total)}',
      );
    case ProgressUnit.items:
      final total = task.itemsTotal;
      parts.add(
        total == null ? '${task.itemsDone}' : '${task.itemsDone} of $total',
      );
  }

  final rate = task.ratePerSecond;
  if (rate != null && task.state == TaskState.running) {
    parts.add(formatRate(rate, task.kind.unit));
  }

  final eta = task.eta;
  if (eta != null && task.state == TaskState.running) {
    parts.add(formatEta(eta));
  }

  if (task.itemsFailed > 0) {
    parts.add('${task.itemsFailed} failed');
  }

  return parts.join(' · ');
}

/// The same information, sized for the 220px sidebar rail.
///
/// [formatProgressLine] does not fit there and gets ellipsised mid-rate —
/// "100 MB of 105 MB · 15 M…" was what actually rendered. Two things go:
///
/// - **The total**, because the ring beside it already shows the fraction.
/// - **The ETA**, because the panel is one click away and has room for it.
///
/// What survives is the pair that changes every frame, which is what makes the
/// row read as alive rather than stuck.
String formatCompactLine(Task task) {
  final note = task.note;
  if (note != null && note.isNotEmpty) return note;

  final parts = <String>[];

  switch (task.kind.unit) {
    case ProgressUnit.bytes:
      parts.add(formatBytes(task.bytesDone));
    case ProgressUnit.items:
      final total = task.itemsTotal;
      parts.add(
        total == null ? '${task.itemsDone}' : '${task.itemsDone}/$total',
      );
  }

  final rate = task.ratePerSecond;
  if (rate != null && task.state == TaskState.running) {
    parts.add(formatRate(rate, task.kind.unit));
  }

  if (task.itemsFailed > 0) {
    parts.add('${task.itemsFailed} failed');
  }

  return parts.join(' · ');
}
