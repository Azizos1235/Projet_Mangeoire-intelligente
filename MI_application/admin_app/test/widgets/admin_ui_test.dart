import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elevage_admin/core/theme.dart';
import 'package:smart_elevage_admin/core/strings.dart';
import 'package:smart_elevage_admin/models/alert.dart';
import 'package:smart_elevage_admin/models/models.dart';
import 'package:smart_elevage_admin/screens/alerts/alerts_screen.dart';
import 'package:smart_elevage_admin/screens/home/home_screen.dart';
import 'package:smart_elevage_admin/services/eleveur_service.dart';
import 'package:smart_elevage_admin/services/session.dart';
import 'package:smart_elevage_admin/services/alert_service.dart';
import 'package:smart_elevage_admin/services/api_client.dart';
import 'package:smart_elevage_admin/widgets/async_state.dart';
import 'package:smart_elevage_admin/widgets/widgets.dart';
import 'package:smart_elevage_admin/widgets/task_form_dialog.dart';

void main() {
  testWidgets('home dashboard uses the shared light greeting and card style',
      (tester) async {
    Session.instance.setCurrentUser({
      'name': 'Fatima Ben Ali',
      'email': 'fatima@example.com',
    });
    addTearDown(() => Session.instance.setCurrentUser(null));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in [const Size(360, 780), const Size(430, 932)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: HomeScreen(
            onOpenCows: (_) {},
            onOpenAlerts: () {},
            skipInitialLoad: true,
          ),
        ),
      );

      expect(find.text('Bonjour, Fatima Ben Ali'), findsOneWidget);
      expect(find.text('fatima@example.com'), findsOneWidget);
      expect(find.text(AppStrings.loginTitle), findsNothing);
      expect(AppTheme.theme.scaffoldBackgroundColor, AppTheme.background);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'home header listens for current user updates and handles scaling',
      (tester) async {
    Session.instance.setCurrentUser(null);
    addTearDown(() => Session.instance.setCurrentUser(null));
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          theme: AppTheme.theme,
          home: HomeScreen(
            onOpenCows: (_) {},
            onOpenAlerts: () {},
            skipInitialLoad: true,
          ),
        ),
      ),
    );

    expect(find.text(AppStrings.greeting), findsOneWidget);
    Session.instance.setCurrentUser({
      'name': 'Fatima Ben Ali Avec Un Nom Très Long',
      'email': 'fatima.benali.avec.une.adresse.tres.longue@example.com',
    });
    await tester.pump();

    expect(find.textContaining('Fatima Ben Ali'), findsOneWidget);
    expect(find.textContaining('@example.com'), findsOneWidget);
    expect(find.text(AppStrings.loginTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home KPI and appetite rows route to their callbacks',
      (tester) async {
    Appetite? selectedAppetite;
    var openedAlerts = false;
    var openedEleveurs = false;
    var addedCow = false;
    var scannedTag = false;
    Session.instance.setCurrentUser({
      'name': 'Administrateur Avec Un Nom Très Long',
      'email': 'admin.avec.une.adresse.email.tres.longue@example.com',
    });
    addTearDown(() => Session.instance.setCurrentUser(null));
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = HomeDashboardFixture(
      cows: [
        (_testCow('COW-1'), Appetite.high),
        (_testCow('COW-2'), Appetite.high),
        (_testCow('COW-3'), Appetite.normal),
        (_testCow('COW-4'), Appetite.low),
      ],
      unreadAlertCount: 2,
      eleveurCount: 3,
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          theme: AppTheme.theme,
          home: HomeScreen(
            onOpenCows: (appetite) => selectedAppetite = appetite,
            onOpenAlerts: () => openedAlerts = true,
            onOpenEleveurs: () => openedEleveurs = true,
            onAddCow: () async => addedCow = true,
            onScanCow: () async => scannedTag = true,
            dashboardFixture: fixture,
          ),
        ),
      ),
    );

    final alertsKpi = find.ancestor(
      of: find.text(AppStrings.dashboardAlerts),
      matching: find.byType(KpiTile),
    );
    expect(tester.widget<KpiTile>(alertsKpi).color,
        AppTheme.theme.colorScheme.error);

    await tester.tap(find.ancestor(
      of: find.text(AppStrings.dashboardCowCount),
      matching: find.byType(KpiTile),
    ));
    expect(selectedAppetite, isNull);
    await tester.tap(alertsKpi);
    expect(openedAlerts, isTrue);
    await tester.tap(find.ancestor(
      of: find.text(AppStrings.dashboardEleveurs),
      matching: find.byType(KpiTile),
    ));
    expect(openedEleveurs, isTrue);

    await tester.tap(find.text(AppetiteTrend.increasing.labelFr).first);
    expect(selectedAppetite, Appetite.high);
    await tester.tap(find.text(AppetiteTrend.stable.labelFr).first);
    expect(selectedAppetite, Appetite.normal);
    await tester.tap(find.text(AppetiteTrend.decreasing.labelFr).first);
    expect(selectedAppetite, Appetite.low);
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.pump();
    expect(addedCow, isTrue);
    await tester.tap(find.byIcon(Icons.nfc_rounded));
    await tester.pump();
    expect(scannedTag, isTrue);

    expect(find.text('50 %'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home appetite empty and no-data error states are shared',
      (tester) async {
    final noAppetiteFixture = HomeDashboardFixture(
      cows: [(_testCow('COW-EMPTY'), null)],
      unreadAlertCount: 0,
      eleveurCount: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: HomeScreen(
          onOpenCows: (_) {},
          onOpenAlerts: () {},
          dashboardFixture: noAppetiteFixture,
        ),
      ),
    );
    expect(find.text(AppStrings.appetiteDataUnavailable), findsOneWidget);
    expect(find.byIcon(Icons.insights_outlined), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: HomeScreen(
          key: const ValueKey('empty-home-error'),
          onOpenCows: (_) {},
          onOpenAlerts: () {},
          skipInitialLoad: true,
        ),
      ),
    );
    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
  });

  testWidgets('task-completed alert uses the shared alert card',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final alert = Alert(
      id: 'alert-1',
      source: 'system',
      message: 'Amina a terminé la tâche : Vérifier le poids',
      severity: AlertSeverity.info,
      cowId: 'COW-1',
      adminId: 'admin-1',
      action: null,
      type: 'task_completed',
      appetiteClass: null,
      appetitePct: null,
      status: 'unread',
      createdAt: DateTime.utc(2026, 11, 19),
      readAt: null,
      taskId: 'task-1',
      handled: false,
      completionNote: 'Tout semble normal',
      completedWeightKg: 425.5,
      previousWeightKg: 400,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: AlertCard(
            alert: alert,
            dateLabel: '19/11/2026',
            sendingTask: false,
            onSendTask: (_) {},
            onMarkRead: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('Amina a terminé la tâche : Vérifier le poids'),
        findsOneWidget);
    expect(
      find.text('Ancien poids : 400.0 kg → 425.5 kg'),
      findsOneWidget,
    );
    expect(find.text('Note : Tout semble normal'), findsOneWidget);
    expect(find.byTooltip(AppStrings.delete), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('alert delete confirmation can be cancelled or confirmed',
      (tester) async {
    var deleteCount = 0;
    final alert = Alert(
      id: 'alert-delete',
      source: 'system',
      message: 'Alerte test',
      severity: AlertSeverity.warning,
      cowId: 'COW-1',
      adminId: 'admin-1',
      action: null,
      type: 'appetite_low',
      appetiteClass: 'low',
      appetitePct: null,
      status: 'unread',
      createdAt: DateTime.utc(2026, 11, 20),
      readAt: null,
      taskId: null,
      handled: false,
      completionNote: null,
      completedWeightKg: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Builder(
          builder: (context) => Scaffold(
            body: AlertCard(
              alert: alert,
              dateLabel: '20/11/2026',
              sendingTask: false,
              onSendTask: (_) {},
              onMarkRead: () {},
              onDelete: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text(AppStrings.deleteAlertTitle),
                    content: const Text(AppStrings.deleteAlertConfirmation),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text(AppStrings.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text(AppStrings.delete),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) deleteCount++;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip(AppStrings.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();
    expect(deleteCount, 0);

    await tester.tap(find.byTooltip(AppStrings.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.delete));
    await tester.pump(const Duration(milliseconds: 100));
    expect(deleteCount, 1);
  });

  testWidgets('delete removes task_completed and appetite alerts',
      (tester) async {
    final service = _FakeDeleteAlertService();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: AlertsScreen(
          isActive: true,
          alertService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amina a terminé une tâche'), findsOneWidget);
    expect(find.text('Appétit faible détecté'), findsOneWidget);

    await tester.tap(
      find.byTooltip(AppStrings.delete).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.delete));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Amina a terminé une tâche'), findsNothing);

    await tester.tap(
      find.byTooltip(AppStrings.delete).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.delete));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Appétit faible détecté'), findsNothing);
  });

  testWidgets('task form fits a small phone and shows the weight-check plan',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => TaskFormDialog(
                  eleveurs: [
                    EleveurRecord(
                      id: 'eleveur-1',
                      name: 'Amina',
                      createdAt: DateTime.utc(2026, 1, 1),
                    ),
                  ],
                  cows: const <Cow>[],
                  initialTaskType: 'check_weight',
                ),
              ),
              child: const Text('Open task form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open task form'));
    await tester.pumpAndSettle();

    expect(find.text('Assigner une tâche'), findsOneWidget);
    final textFields = tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    );
    expect(
      textFields.any((field) =>
          field.controller?.text.contains('Vérifier son état corporel.') ??
          false),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeDeleteAlertService extends AlertService {
  _FakeDeleteAlertService() : super();

  @override
  Future<List<Alert>> listAlerts({String? status, int limit = 50}) async => [
        Alert(
          id: 'task-alert-id',
          source: 'system',
          message: 'Amina a terminé une tâche',
          severity: AlertSeverity.info,
          cowId: 'COW-1',
          adminId: 'admin-1',
          action: null,
          type: 'task_completed',
          appetiteClass: null,
          appetitePct: null,
          status: 'read',
          createdAt: DateTime.utc(2026, 11, 20),
          readAt: null,
          taskId: 'linked-task-id',
          handled: true,
          completionNote: null,
          completedWeightKg: 410,
          previousWeightKg: 400,
        ),
        Alert(
          id: 'appetite-alert-id',
          source: 'system',
          message: 'Appétit faible détecté',
          severity: AlertSeverity.warning,
          cowId: 'COW-2',
          adminId: 'admin-1',
          action: null,
          type: 'appetite_low',
          appetiteClass: 'low',
          appetitePct: null,
          status: 'unread',
          createdAt: DateTime.utc(2026, 11, 20),
          readAt: null,
          taskId: null,
          handled: false,
          completionNote: null,
          completedWeightKg: null,
        ),
      ];

  @override
  Future<void> deleteAlert(String alertId) async {
    if (alertId == 'task-alert-id') {
      return;
    }
    throw const ApiException(
      statusCode: 404,
      message: AppStrings.alertDeletedOrMissing,
      error: 'not_found',
      detail: 'Alerte introuvable',
    );
  }
}

Cow _testCow(String id) => Cow(
      id: id,
      internalId: id,
      adminId: 'admin-1',
      breed: 'Holstein',
      type: CowType.dairy,
      weightKg: 400,
      birthDate: DateTime.utc(2020, 1, 1),
      ageMonths: 70,
      nfcUid: null,
    );
