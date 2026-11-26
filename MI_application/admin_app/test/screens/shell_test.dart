import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elevage_admin/native/action_queue.dart';
import 'package:smart_elevage_admin/screens/shell.dart';

void main() {
  testWidgets('shell navigation has the remaining tabs and no feeder tab',
      (tester) async {
    var selectedIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: ShellNavigationBar(
            selectedIndex: selectedIndex,
            unreadAlerts: 3,
            onDestinationSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.destinations, hasLength(ShellTab.count));
    for (final label in ['Accueil', 'Vaches', 'Alertes', 'Éleveurs', 'Plus']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Mangeoires'), findsNothing);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Alertes'));
    expect(selectedIndex, ShellTab.alerts);

    const AlertsNotificationRouter().route(
      {'action': 'voir', 'scope': 'alerts'},
      openAlert: (_) => selectedIndex = ShellTab.alerts,
      openAlerts: () => selectedIndex = ShellTab.alerts,
    );
    expect(selectedIndex, ShellTab.alerts);
  });
}
