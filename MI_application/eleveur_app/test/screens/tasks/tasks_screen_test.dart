import 'package:eleveur_app/core/app_routes.dart';
import 'package:eleveur_app/core/l10n.dart';
import 'package:eleveur_app/models/cow_profile.dart';
import 'package:eleveur_app/models/farm_task.dart';
import 'package:eleveur_app/screens/cows/edit_profile_screen.dart';
import 'package:eleveur_app/screens/tasks/tasks_screen.dart';
import 'package:eleveur_app/services/cow_service.dart';
import 'package:eleveur_app/services/task_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sorts overdue tasks first, then by due date and newest creation date',
      () {
    final now = DateTime.utc(2026, 4, 5);
    FarmTask task(
      String id, {
      DateTime? dueAt,
      required DateTime createdAt,
    }) =>
        FarmTask(
          id: id,
          title: id,
          dueAt: dueAt,
          createdAt: createdAt,
        );
    final tasks = [
      task('no-due-old', createdAt: DateTime.utc(2026, 1, 1)),
      task(
        'due-later',
        dueAt: DateTime.utc(2026, 4, 7),
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      task(
        'overdue-later',
        dueAt: DateTime.utc(2026, 4, 4),
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      task(
        'due-soon-old',
        dueAt: DateTime.utc(2026, 4, 6),
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      task('no-due-new', createdAt: DateTime.utc(2026, 2, 1)),
      task(
        'overdue-earlier',
        dueAt: DateTime.utc(2026, 4, 2),
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      task(
        'due-soon-new',
        dueAt: DateTime.utc(2026, 4, 6),
        createdAt: DateTime.utc(2026, 2, 1),
      ),
    ];

    final sorted = TaskService.sortPendingTasks(tasks, now: now);

    expect(
      sorted.map((item) => item.id),
      [
        'overdue-earlier',
        'overdue-later',
        'due-soon-new',
        'due-soon-old',
        'due-later',
        'no-due-new',
        'no-due-old',
      ],
    );
    expect(tasks.first.id, 'no-due-old');
  });

  testWidgets(
    'check-weight task opens the editor and retries completion without updating twice',
    (tester) async {
      final events = <String>[];
      final task = FarmTask(
        id: 'task-1',
        title: 'Vérifier le poids de la vache',
        taskType: 'check_weight',
        plan: 'Peser la vache et noter le résultat.',
        cowId: 'COW004',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final profile = CowProfile(
        internalId: 'cow-internal-4',
        cowId: 'COW004',
        adminId: 'admin-1',
        breed: 'Holstein',
        type: 'dairy',
        weightKg: 400,
        birthDate: DateTime(2023, 1, 1),
        ageMonths: 36,
        nfcUid: null,
      );
      final cowService = _FakeCowProfileService(profile, events);
      final taskService = _FakeTaskService(task, events);
      EditProfileRouteArguments? openedArguments;

      await tester.pumpWidget(
        LangScope(
          controller: LangController(),
          child: MaterialApp(
            home: TasksScreen(
              cowService: cowService,
              taskService: taskService,
            ),
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.editCowProfile) {
                final arguments =
                    settings.arguments! as EditProfileRouteArguments;
                openedArguments = arguments;
                return MaterialPageRoute<bool>(
                  settings: settings,
                  builder: (_) => EditProfileScreen(
                    profile: arguments.profile,
                    task: arguments.task,
                    cowService: cowService,
                    taskService: taskService,
                  ),
                );
              }
              return AppRoutes.onGenerateRoute(settings);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Peser la vache'), findsOneWidget);
      await tester.tap(find.text(task.title));
      await tester.pumpAndSettle();

      expect(openedArguments?.task.id, task.id);
      expect(openedArguments?.task.title, task.title);
      expect(openedArguments?.task.plan, task.plan);
      await tester.drag(
        find.byType(Scrollable).last,
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();
      expect(find.text('Consignes de l’administrateur'), findsOneWidget);
      expect(find.text(task.title), findsOneWidget);
      expect(find.text(task.plan), findsOneWidget);

      final sliderFinder = find.byKey(const ValueKey('profile-weight-slider'));
      await tester.drag(
        find.byType(Scrollable).last,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ancien poids: 400.0 kg'), findsOneWidget);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Le poids est inchangé, confirmer ?'), findsOneWidget);
      await tester.tap(find.text('Annuler').last);
      await tester.pumpAndSettle();

      await tester.drag(sliderFinder, const Offset(45, 0));
      await tester.pumpAndSettle();
      final newWeight = tester.widget<Slider>(sliderFinder).value;
      if (newWeight == profile.weightKg) {
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmer').last);
      } else {
        await tester.tap(find.text('Enregistrer'));
      }
      await tester.pumpAndSettle();

      expect(events, ['load', 'update', 'done']);
      expect(cowService.updatedWeight, isNotNull);
      expect(taskService.previousWeight, profile.weightKg);
      expect(taskService.completedWeight, cowService.updatedWeight);
      expect(taskService.completedWeight, isNot(profile.weightKg));
      expect(
          find.text(
              'Le poids est enregistré, mais la tâche reste à confirmer. Réessayez.'),
          findsOneWidget);

      await tester.tap(find.text('Réessayer').last);
      await tester.pumpAndSettle();

      expect(events, ['load', 'update', 'done', 'done']);
      expect(cowService.updateCount, 1);
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(find.text(task.title), findsNothing);
    },
  );
}

class _FakeCowProfileService implements CowProfileService {
  _FakeCowProfileService(this.profile, this.events);

  final CowProfile profile;
  final List<String> events;
  double? updatedWeight;
  int updateCount = 0;

  @override
  Future<CowProfile> getProfile(String cowId) async {
    events.add('load');
    return profile;
  }

  @override
  Future<CowProfile> updateProfile({
    required String cowId,
    required DateTime birthDate,
    required double weightKg,
    required String type,
    required String breed,
  }) async {
    events.add('update');
    updateCount++;
    updatedWeight = weightKg;
    return profile;
  }
}

class _FakeTaskService implements TaskServiceApi {
  _FakeTaskService(this.task, this.events);

  final FarmTask task;
  final List<String> events;
  int _completionFailures = 1;
  double? previousWeight;
  double? completedWeight;

  @override
  Future<List<FarmTask>> listMyPendingTasks() async => [task];

  @override
  Future<void> markDone(
    String taskId, {
    double? completedWeightKg,
    double? previousWeightKg,
    String? completionNote,
  }) async {
    events.add('done');
    previousWeight = previousWeightKg;
    completedWeight = completedWeightKg;
    if (_completionFailures > 0) {
      _completionFailures--;
      throw StateError('Temporary completion failure');
    }
  }
}
