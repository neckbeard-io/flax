/// A single GraphicEQ data point: frequency (Hz) → gain (dB).
class GraphicEqPoint {
  final double frequency;
  final double gain;

  const GraphicEqPoint({required this.frequency, required this.gain});
}

/// An AutoEQ headphone correction profile.
class AutoEqProfile {
  final int id;
  final String name;
  final String source;
  final int rank;

  /// Parsed GraphicEQ points (frequency → gain). Lazy-loaded from file.
  List<GraphicEqPoint>? _points;

  /// Raw GraphicEQ string from the file (e.g. "GraphicEQ: 20 -3.2; 21 -3.1; ...")
  String? rawGraphicEq;

  AutoEqProfile({
    required this.id,
    required this.name,
    required this.source,
    this.rank = 0,
    this.rawGraphicEq,
  });

  /// Brand extracted from the name (first word or common brand prefix).
  String get brand {
    // Common multi-word brand prefixes
    const multiWordBrands = [
      'Audio-Technica',
      'Audio Technica',
      'Dan Clark',
      'Campfire Audio',
      'Final Audio',
      'Empire Ears',
      'Noble Audio',
      'Unique Melody',
      'Rose Technics',
      'Tin HiFi',
      'KZ ',
      '64 Audio',
      'Periodic Audio',
    ];
    for (final b in multiWordBrands) {
      if (name.startsWith(b)) return b.trim();
    }
    return name.split(' ').first;
  }

  /// Whether this is an in-ear or over-ear model (heuristic from source path).
  String get type => source.contains('in-ear') ? 'in-ear' : 'over-ear';

  /// Parse the raw GraphicEQ string into points.
  List<GraphicEqPoint> get points {
    if (_points != null) return _points!;
    _points = parseGraphicEq(rawGraphicEq ?? '');
    return _points!;
  }

  set points(List<GraphicEqPoint> pts) => _points = pts;

  /// Parse a GraphicEQ string like "GraphicEQ: 20 -3.2; 21 -3.1; ..."
  static List<GraphicEqPoint> parseGraphicEq(String raw) {
    final result = <GraphicEqPoint>[];
    // Strip "GraphicEQ: " prefix if present
    var data = raw.replaceFirst(
      RegExp(r'^GraphicEQ:\s*', caseSensitive: false),
      '',
    );
    // Split by semicolons
    for (final pair in data.split(';')) {
      final trimmed = pair.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final freq = double.tryParse(parts[0]);
        final gain = double.tryParse(parts[1]);
        if (freq != null && gain != null) {
          result.add(GraphicEqPoint(frequency: freq, gain: gain));
        }
      }
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'source': source,
    'rank': rank,
  };

  factory AutoEqProfile.fromJson(Map<String, dynamic> json) => AutoEqProfile(
    id: json['id'] as int,
    name: json['name'] as String,
    source: json['source'] as String,
    rank: (json['rank'] as int?) ?? 0,
  );
}
