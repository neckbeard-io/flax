import 'package:flutter_test/flutter_test.dart';

import 'package:flax/app/router.dart';

/// [isValidRoute] is derived from [appRoutes]. The redirect sends whatever it
/// rejects to /albums, and a hand-kept list once left Settings › Android Auto
/// out, so tapping it opened Albums (#174, #176).
void main() {
  final paths = routePaths(appRoutes);

  test('walks nested and shell routes into full paths', () {
    expect(
      paths,
      containsAll([
        '/albums',
        '/albums/:id',
        '/settings/android-auto',
        '/settings/equalizer/autoeq',
      ]),
    );
  });

  test('every registered route passes isValidRoute', () {
    final rejected = [
      for (final path in paths)
        if (path != '/')
          if (!isValidRoute(path.replaceAllMapped(RegExp(r':\w+'), (_) => 'x')))
            path,
    ];
    expect(rejected, isEmpty);
  });
}
