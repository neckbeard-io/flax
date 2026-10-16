import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flax/app/router.dart';
import 'package:flax/core/providers/server_provider.dart';
import 'package:flax/domain/models/server.dart';

const _server = Server(
  id: 'srv',
  name: 'Test',
  url: 'http://localhost:4533',
  username: 'u',
  tokenHash: 't',
  salt: 's',
  isActive: true,
);

class _FakeServers extends ServerListNotifier {
  _FakeServers() {
    state = [_server];
  }
}

/// Every path the router registers, with each `:param` filled in.
List<String> _registeredPaths(List<RouteBase> routes, [String parent = '']) {
  final paths = <String>[];
  for (final route in routes) {
    var base = parent;
    if (route is GoRoute) {
      base = route.path.startsWith('/')
          ? route.path
          : '${parent == '/' ? '' : parent}/${route.path}';
      paths.add(base.replaceAllMapped(RegExp(r':\w+'), (_) => 'x'));
    }
    paths.addAll(_registeredPaths(route.routes, base));
  }
  return paths;
}

/// The redirect sends whatever [isValidRoute] rejects to /albums. Settings ›
/// Android Auto was added to the router but not to that list, and tapping it
/// opened Albums; its own widget test built the screen directly and never
/// noticed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every registered route passes isValidRoute', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [serverListProvider.overrideWith((ref) => _FakeServers())],
    );
    addTearDown(container.dispose);

    final router = container.read(routerProvider);
    addTearDown(router.dispose);

    // '/' is a redirect to /albums, never a destination of its own.
    final paths = _registeredPaths(
      router.configuration.routes,
    ).where((path) => path != '/').toList();

    expect(paths, contains('/settings/android-auto'));
    expect(paths.where((path) => !isValidRoute(path)), isEmpty);
  });
}
