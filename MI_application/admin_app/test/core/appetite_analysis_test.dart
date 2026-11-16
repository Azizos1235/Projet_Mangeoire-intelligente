import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elevage_admin/core/appetite_analysis.dart';
import 'package:smart_elevage_admin/models/models.dart';

void main() {
  test('normalizes appetite probabilities to one', () {
    final probabilities = AppetiteAnalysis.probabilitiesOf({
      'appetite_pct': {'low': 20, 'normal': 30, 'high': 50},
    });

    expect(probabilities, isNotNull);
    expect(probabilities![CowAppetiteClass.decreasing], closeTo(0.2, 1e-9));
    expect(probabilities[CowAppetiteClass.stable], closeTo(0.3, 1e-9));
    expect(probabilities[CowAppetiteClass.increasing], closeTo(0.5, 1e-9));
    expect(
      probabilities.values.reduce((total, value) => total + value),
      closeTo(1, 1e-9),
    );
  });

  test('uses the top probability when the daily document has no label', () {
    expect(
      AppetiteAnalysis.appetiteOf({
        'appetite_pct': {'low': 15, 'normal': 20, 'high': 65},
      }),
      CowAppetiteClass.increasing,
    );
  });

  test('anchors the fourteen-day window on the newest valid record date', () {
    final days = AppetiteAnalysis.trendWindow(
      [
        {'date': '2026-03-20T00:00:00Z', 'appetite_class': 'stable'},
        {'date': 'bad-date'},
        {'date': '2026-04-01T23:59:59Z', 'appetite_class': 'increasing'},
      ],
      fallback: DateTime(2026, 1, 1),
    );

    expect(days, hasLength(14));
    expect(days.first, DateTime(2026, 3, 19));
    expect(days.last, DateTime(2026, 4, 1));
  });

  test('maps home appetite classes to the cows internal ids', () {
    final response = HomeAppetiteResponse.fromJson({
      'appetite': {
        'internal-1': {'appetite': 'increasing'},
        'internal-2': {'appetite': 'stable'},
        'internal-3': {'appetite': 'decreasing'},
        'internal-4': {'appetite': null},
      },
    });

    final values = response.appetiteByInternalId;
    expect(values['internal-1'], Appetite.high);
    expect(values['internal-2'], Appetite.normal);
    expect(values['internal-3'], Appetite.low);
    expect(values['internal-4'], isNull);
    expect(values.values.where((value) => value == Appetite.high).length, 1);
    expect(values.values.where((value) => value == Appetite.normal).length, 1);
    expect(values.values.where((value) => value == Appetite.low).length, 1);

    final cow = Cow.fromJson({
      'cow_id': 'COW001',
      'internal_id': 'internal-1',
      'breed': 'Holstein',
      'type': 'dairy',
      'weight_kg': 500,
      'birth_date': '2020-01-01',
      'age_months': 75,
    });
    expect(values[cow.internalId], Appetite.high);
  });
}
