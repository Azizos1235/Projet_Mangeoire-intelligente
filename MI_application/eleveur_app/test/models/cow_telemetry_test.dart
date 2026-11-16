import 'package:eleveur_app/models/cow_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the sensor record emitted by the ESP32', () {
    final cow = CowTelemetry.fromJson({
      'cow_id': 'COW-17',
      'date': '2026-11-13',
      'age_months': 42.0,
      'food_consumed_g': 12000,
      'feed_offered_g': 15000,
      'visits': 3,
      'eating_minutes': 24,
      'avg_meal_duration_min': 8.0,
      'no_food_visits': 1,
      'first_visit_hour': 7.5,
      'last_visit_hour': 18.0,
      'day_over': true,
    });

    expect(cow.cowId, 'COW-17');
    expect(cow.foodConsumedGrams, 12000);
    expect(cow.dayOver, isTrue);
  });

  test('rejects records missing required sensor fields', () {
    expect(
      () => CowTelemetry.fromJson({
        'cow_id': 'COW-17',
        'date': '2026-11-13',
      }),
      throwsFormatException,
    );
  });

  test('accepts a legacy daily summary without optional telemetry fields', () {
    final cow = CowTelemetry.fromJson({
      'cow_id': 'COW-17',
      'date': '2026-11-13',
      'food_consumed_g': 12000,
      'feed_offered_g': 15000,
      'visits': 3,
      'eating_minutes': 24,
      'avg_meal_duration_min': 8.0,
      'no_food_visits': 1,
    });

    expect(cow.ageMonths, isNull);
    expect(cow.firstVisitHour, isNull);
    expect(cow.lastVisitHour, isNull);
    expect(cow.dayOver, isNull);
  });

  test('parses daily summaries with total sensor field names', () {
    final cow = CowTelemetry.fromJson({
      'cow_id': 'COW-17',
      'date': '2026-11-15',
      'total_food_consumed_g': 12000,
      'total_feed_offered_g': 15000,
      'total_eating_minutes': 24,
      'visits': 3,
      'no_food_visits': 1,
      'first_visit_hour': 5.1,
      'last_visit_hour': 19.4,
      'avg_meal_duration_min': 13.3,
    });

    expect(cow.foodConsumedGrams, 12000);
    expect(cow.feedOfferedGrams, 15000);
    expect(cow.eatingMinutes, 24);
    expect(cow.visits, 3);
    expect(cow.visitsWithoutFood, 1);
    expect(cow.firstVisitHour, 5.1);
    expect(cow.lastVisitHour, 19.4);
    expect(cow.averageMealDurationMinutes, 13.3);
    expect(cow.ageMonths, isNull);
  });

  test('accepts age_months as a numeric string', () {
    final cow = CowTelemetry.fromJson({
      'cow_id': 'COW-17',
      'date': '2026-11-13',
      'age_months': '42',
      'food_consumed_g': 12000,
      'feed_offered_g': 15000,
      'visits': 3,
      'eating_minutes': 24,
      'avg_meal_duration_min': 8.0,
      'no_food_visits': 1,
    });

    expect(cow.ageMonths, 42);
  });
}
