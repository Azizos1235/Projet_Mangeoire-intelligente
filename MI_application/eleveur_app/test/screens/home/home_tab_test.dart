import 'dart:math' as math;

import 'package:eleveur_app/core/l10n.dart';
import 'package:eleveur_app/models/cow_profile.dart';
import 'package:eleveur_app/screens/home/home_tab.dart';
import 'package:eleveur_app/widgets/cow_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
