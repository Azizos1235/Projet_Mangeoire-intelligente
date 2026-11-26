import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elevage_admin/main.dart'
    show nativeNotificationFallbackRoute;

void main() {
  test('native notification URI falls back to the root session gate', () {
    final route = nativeNotificationFallbackRoute(
      const RouteSettings(name: 'native://notification/1486/view'),
      (_) => const Text('home'),
    );

    expect(route, isNotNull);
    expect(route!.settings.name, '/');
  });

  test('ordinary unknown route is not treated as a notification route', () {
    expect(
      nativeNotificationFallbackRoute(
        const RouteSettings(name: '/missing'),
        (_) => const Text('home'),
      ),
      isNull,
    );
  });
}
