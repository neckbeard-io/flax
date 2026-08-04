// Verifies the preset table in equalizer_screen.dart matches the source
// foobar2000 .feq files in /tmp/foobar-presets.
//
// Run: dart run tool/verify_presets.dart
import 'dart:io';

void main() {
  final src = File('lib/features/settings/equalizer_screen.dart')
      .readAsStringSync();

  // Extract the _presetGains map body
  final start = src.indexOf('const _presetGains');
  final open = src.indexOf('{', start);
  final close = src.indexOf('\n};', open);
  final body = src.substring(open + 1, close);

  final entry = RegExp(r"'([^']+)':\s*\[([^\]]+)\]");
  final parsed = <String, List<int>>{};
  for (final m in entry.allMatches(body)) {
    parsed[m.group(1)!] = m
        .group(2)!
        .split(',')
        .map((s) => int.parse(s.trim()))
        .toList();
  }

  final dir = Directory('/tmp/foobar-presets');
  if (!dir.existsSync()) {
    stderr.writeln('Source presets not found at ${dir.path}');
    exit(2);
  }

  var failures = 0;
  var checked = 0;

  for (final f in dir.listSync().whereType<File>()) {
    if (!f.path.endsWith('.feq')) continue;
    final name = f.uri.pathSegments.last.replaceAll('.feq', '');
    final expected = f
        .readAsStringSync()
        .replaceAll('\r', '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map((l) => int.parse(l.trim()))
        .toList();

    final actual = parsed[name];
    checked++;

    if (actual == null) {
      print('MISSING  $name');
      failures++;
      continue;
    }
    if (actual.length != 18) {
      print('BAD LEN  $name: ${actual.length} (want 18)');
      failures++;
      continue;
    }
    if (!_eq(actual, expected)) {
      print('MISMATCH $name');
      print('  file: $expected');
      print('  code: $actual');
      failures++;
      continue;
    }
    print('ok       $name');
  }

  // Every code preset should map to a file (Flat is in both)
  for (final name in parsed.keys) {
    if (!File('/tmp/foobar-presets/$name.feq').existsSync()) {
      print('EXTRA    $name (no source file)');
      failures++;
    }
  }

  print('\n$checked presets checked, $failures problem(s)');
  if (failures > 0) exit(1);
}

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
