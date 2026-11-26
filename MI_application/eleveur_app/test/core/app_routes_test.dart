import 'package:eleveur_app/core/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native notification URI falls back to the session startup route', () {
    final route = AppRoutes.onGenerateRoute(
      const RouteSettings(name: 'native://notification/1486/view'),
    );

    expect(route.settings.name, AppRoutes.startup);
  });
}
