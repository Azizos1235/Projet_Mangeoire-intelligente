import 'dart:math' as math;

import 'package:eleveur_app/core/app_route_observer.dart';
import 'package:eleveur_app/core/l10n.dart';
import 'package:eleveur_app/models/cow_profile.dart';
import 'package:eleveur_app/models/farm_task.dart';
import 'package:eleveur_app/screens/home/home_tab.dart';
import 'package:eleveur_app/screens/tasks/tasks_screen.dart';
import 'package:eleveur_app/services/task_service.dart';
import 'package:eleveur_app/widgets/cow_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home appetite summary omits the removed heading and hint',
      (tester) async {
    await _pumpSeededHome(tester);

    expect(find.text('herd_today'), findsNothing);
    expect(find.text('tap_hint'), findsNothing);
  });

  testWidgets('home preview displays only the first three pending tasks',
      (tester) async {
    final tasks = [
      _task('task-1', 'Peser COW001',
          taskType: 'check_weight', cowId: 'COW001'),
      _task('task-2', 'Vendre COW002', taskType: 'sell', cowId: 'COW002'),
      _task('task-3', 'Visite COW003', taskType: 'vet', cowId: 'COW003'),
      _task('task-4', 'Tâche COW004', taskType: 'custom', cowId: 'COW004'),
    ];

    await tester.pumpWidget(_homeTab(pendingTasks: tasks));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tâches à faire'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    for (final task in tasks.take(3)) {
      await tester.ensureVisible(find.byKey(ValueKey('home-task-${task.id}')));
      expect(find.byKey(ValueKey('home-task-${task.id}')), findsOneWidget);
      expect(find.text(task.title), findsOneWidget);
    }
    expect(find.text(tasks.last.title), findsNothing);
    expect(find.textContaining('Bovin: COW001'), findsOneWidget);
    expect(find.textContaining('alert'), findsNothing);
  });

  testWidgets('home preview shows the localized empty state without tasks',
      (tester) async {
    await tester.pumpWidget(_homeTab());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tâches à faire'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Aucune tâche pour le moment'), findsOneWidget);
  });

  testWidgets('completed tasks disappear from home and only task APIs are used',
      (tester) async {
    final task = _task('task-1', 'Contrôler la clôture');
    final service = _FakeHomeTaskService(task);
    await tester.pumpWidget(
      LangScope(
        controller: LangController(),
        child: MaterialApp(
          home: _HomeTasksHarness(taskService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final previewTask = find.byKey(const ValueKey('home-task-task-1'));
    await tester.scrollUntilVisible(
      previewTask,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(previewTask, findsOneWidget);
    expect(service.calls, contains('/tasks/mine'));

    await tester.tap(
      find.descendant(
        of: previewTask,
        matching: find.text(task.title),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer').last);
    await tester.pumpAndSettle();

    expect(service.completed, isTrue);
    expect(previewTask, findsNothing);
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();

    expect(find.text('Aucune tâche pour le moment'), findsOneWidget);
    expect(service.calls.where((call) => call.contains('alerts')), isEmpty);
    expect(service.calls, contains('/tasks/task-1/done'));
  });

  testWidgets('home task polling runs every 30 seconds only while visible',
      (tester) async {
    final service =
        _FakeHomeTaskService(_task('task-1', 'Contrôler la clôture'));
    await tester.pumpWidget(
      LangScope(
        controller: LangController(),
        child: MaterialApp(
          navigatorObservers: [appRouteObserver],
          home: _HomeTasksHarness(taskService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.calls.where((call) => call == '/tasks/mine').length, 1);

    await tester.pump(const Duration(seconds: 29));
    expect(service.calls.where((call) => call == '/tasks/mine').length, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(service.calls.where((call) => call == '/tasks/mine').length, 2);

    await tester.tap(find.text('Couvrir'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(service.calls.where((call) => call == '/tasks/mine').length, 2);

    Navigator.of(tester.element(find.text('Couvert'))).pop();
    await tester.pumpAndSettle();
    expect(service.calls.where((call) => call == '/tasks/mine').length, 3);
  });

  testWidgets('Add Cow quick action starts the add flow directly',
      (tester) async {
    var addCowStarted = false;
    var selectedTab = false;
    await tester.pumpWidget(
      LangScope(
        controller: LangController(),
        child: MaterialApp(
          home: HomeTab(
            onGoTab: (_) => selectedTab = true,
            onAddCow: () => addCowStarted = true,
            onLogout: () {},
            initialCows: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addButton = find.text('Ajouter un bovin');
    await tester.scrollUntilVisible(
      addButton,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);

    expect(addCowStarted, isTrue);
    expect(selectedTab, isFalse);
  });

  testWidgets('stable tile opens only matching cows with matching count',
      (tester) async {
    await _pumpSeededHome(tester);

    await _expectFilteredList(
      tester,
      tileKey: const ValueKey('home-appetite-tile-stable'),
      countKey: const ValueKey('appetite-count-stable'),
      percentageKey: const ValueKey('appetite-percentage-stable'),
      expectedCount: 2,
      expectedPercentage: '40%',
      expectedIds: ['COW002', 'COW003'],
    );
  });

  testWidgets('decreasing tile opens only matching cows with matching count',
      (tester) async {
    await _pumpSeededHome(tester);

    await _expectFilteredList(
      tester,
      tileKey: const ValueKey('home-appetite-tile-decreasing'),
      countKey: const ValueKey('appetite-count-decreasing'),
      percentageKey: const ValueKey('appetite-percentage-decreasing'),
      expectedCount: 1,
      expectedPercentage: '20%',
      expectedIds: ['COW004'],
    );
  });

  testWidgets('no-data tile opens only cows without appetite data',
      (tester) async {
    await _pumpSeededHome(tester);

    await _expectFilteredList(
      tester,
      tileKey: const ValueKey('home-appetite-tile-noData'),
      countKey: const ValueKey('appetite-count-noData'),
      percentageKey: const ValueKey('appetite-percentage-noData'),
      expectedCount: 1,
      expectedPercentage: '20%',
      expectedIds: ['COW005'],
    );
  });

  testWidgets('tapping a colored donut segment opens its appetite filter',
      (tester) async {
    await _pumpSeededHome(tester);
    final donut = find.byKey(const ValueKey('home-appetite-donut'));
    await tester.ensureVisible(donut);
    await tester.pumpAndSettle();
    final topLeft = tester.getTopLeft(donut);
    await tester.tapAt(topLeft + const Offset(203, 47));
    await tester.pumpAndSettle();

    expect(find.byType(CowTile), findsOneWidget);
    expect(find.text('COW001'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('cows-by-class-count')))
          .data,
      endsWith('(1)'),
    );
  });

  test('donut hit test maps ring angles and excludes hole, gap, and outside',
      () {
    const size = Size(250, 250);
    const values = [1.0, 1.0, 1.0, 1.0];
    final center = size.center(Offset.zero);
    Offset atAngle(double angle, {double radius = 110}) => Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        );

    for (var index = 0; index < 4; index++) {
      final start = -math.pi / 2 + index * math.pi / 2;
      final point = atAngle(start + (math.pi / 2 - 0.03) / 2);
      expect(
        homeAppetiteDonutSegmentAt(
          position: point,
          size: size,
          values: values,
        ),
        index,
      );
    }

    expect(
      homeAppetiteDonutSegmentAt(
        position: center,
        size: size,
        values: values,
      ),
      isNull,
    );
    expect(
      homeAppetiteDonutSegmentAt(
        position: atAngle(-math.pi / 2 + math.pi / 2 - 0.015),
        size: size,
        values: values,
      ),
      isNull,
    );
    expect(
      homeAppetiteDonutSegmentAt(
        position: atAngle(0, radius: 126),
        size: size,
        values: values,
      ),
      isNull,
    );
  });
}

Widget _homeTab({List<FarmTask> pendingTasks = const []}) => LangScope(
      controller: LangController(),
      child: MaterialApp(
        home: HomeTab(
          onGoTab: (_) {},
          onAddCow: () {},
          onLogout: () {},
          initialCows: const [],
          pendingTasks: pendingTasks,
        ),
      ),
    );

class _HomeTasksHarness extends StatefulWidget {
  const _HomeTasksHarness({required this.taskService});

  final TaskServiceApi taskService;

  @override
  State<_HomeTasksHarness> createState() => _HomeTasksHarnessState();
}

class _HomeTasksHarnessState extends State<_HomeTasksHarness> {
  final _tasksKey = GlobalKey<TasksScreenState>();
  List<FarmTask> _tasks = const [];
  bool _loading = true;
  Object? _error;
  int _tab = 0;

  void _updateTasks(List<FarmTask> tasks) =>
      setState(() => _tasks = List.unmodifiable(tasks));

  void _setLoading(bool loading) => setState(() => _loading = loading);

  void _setError(Object? error) => setState(() => _error = error);

  Future<void> _refreshTasks() async {
    await _tasksKey.currentState?.refreshFromHome();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            HomeTab(
              onGoTab: (_) => setState(() => _tab = 1),
              onAddCow: () {},
              onLogout: () {},
              initialCows: const [],
              pendingTasks: _tasks,
              tasksLoading: _loading,
              tasksError: _error,
              onRefreshTasks: _refreshTasks,
              onTaskTap: (_) => setState(() => _tab = 1),
              onViewAllTasks: () => setState(() => _tab = 1),
              isActive: _tab == 0,
            ),
            TasksScreen(
              key: _tasksKey,
              isActive: _tab == 1,
              taskService: widget.taskService,
              onTasksChanged: _updateTasks,
              onLoadingChanged: _setLoading,
              onErrorChanged: _setError,
            ),
          ],
        ),
        bottomNavigationBar: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => setState(() => _tab = 0),
              child: const Text('Accueil'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Center(child: Text('Couvert')),
                  ),
                ),
              ),
              child: const Text('Couvrir'),
            ),
          ],
        ),
      );
}

FarmTask _task(
  String id,
  String title, {
  String taskType = 'custom',
  String? cowId,
}) =>
    FarmTask(
      id: id,
      title: title,
      taskType: taskType,
      cowId: cowId,
      createdAt: DateTime.utc(2026, 1, 1),
      dueAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
    );

class _FakeHomeTaskService implements TaskServiceApi {
  _FakeHomeTaskService(this.task);

  final FarmTask task;
  final calls = <String>[];
  bool completed = false;

  @override
  Future<List<FarmTask>> listMyPendingTasks() async {
    calls.add('/tasks/mine');
    return completed ? [] : [task];
  }

  @override
  Future<void> markDone(
    String taskId, {
    double? completedWeightKg,
    double? previousWeightKg,
    String? completionNote,
  }) async {
    calls.add('/tasks/$taskId/done');
    completed = true;
  }
}

Future<void> _pumpSeededHome(WidgetTester tester) async {
  const cows = [
    CowReference(internalId: 'a', cowId: 'COW001'),
    CowReference(internalId: 'b', cowId: 'COW002'),
    CowReference(internalId: 'c', cowId: 'COW003'),
    CowReference(internalId: 'd', cowId: 'COW004'),
    CowReference(internalId: 'e', cowId: 'COW005'),
  ];

  await tester.pumpWidget(
    LangScope(
      controller: LangController(),
      child: MaterialApp(
        home: HomeTab(
          onGoTab: (_) {},
          onAddCow: () {},
          onLogout: () {},
          initialCows: cows,
          initialAppetiteByInternalId: const {
            'a': 'increasing',
            'b': 'stable',
            'c': 'stable',
            'd': 'decreasing',
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectFilteredList(
  WidgetTester tester, {
  required Key tileKey,
  required Key countKey,
  required Key percentageKey,
  required int expectedCount,
  required String expectedPercentage,
  required List<String> expectedIds,
}) async {
  await tester.ensureVisible(find.byKey(tileKey));
  await tester.pumpAndSettle();

  expect(
    tester.widget<Text>(find.byKey(countKey)).data,
    '$expectedCount',
  );
  expect(
    tester.widget<Text>(find.byKey(percentageKey)).data,
    expectedPercentage,
  );

  await tester.tap(find.byKey(tileKey));
  await tester.pumpAndSettle();

  expect(find.byType(CowTile), findsNWidgets(expectedCount));
  expect(
    tester.widget<Text>(find.byKey(const ValueKey('cows-by-class-count'))).data,
    endsWith('($expectedCount)'),
  );
  for (final id in expectedIds) {
    expect(find.text(id), findsOneWidget);
  }
}
