import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elevage_admin/models/cow_telemetry.dart';

void main() {
  test('parses daily telemetry with total keys and optional fields absent', () {
    final telemetry = CowTelemetry.fromJson({
      'cow_id': 'COW001',
      'date': '2026-04-01T00:00:00Z',
      'total_food_consumed_g': 425.5,
      'total_feed_offered_g': 500,
      'total_eating_minutes': 37,
      'visits': 8,
      'no_food_visits': 2,
      'first_visit_hour': 5.1,
      'last_visit_hour': 19.4,
      'avg_meal_duration_min': 13.3,
    });

    expect(telemetry.cowId, 'COW001');
    expect(telemetry.totalFoodConsumedG, 425.5);
    expect(telemetry.totalFeedOfferedG, 500);
    expect(telemetry.totalEatingMinutes, 37);
    expect(telemetry.visits, 8);
    expect(telemetry.noFoodVisits, 2);
    expect(telemetry.firstVisitHour, 5.1);
    expect(telemetry.lastVisitHour, 19.4);
    expect(telemetry.averageMealDurationMin, 13.3);
    expect(telemetry.ageMonths, isNull);
    expect(telemetry.timestamp, isNull);
  });

  test('accepts short food, feed, and eating keys', () {
    final telemetry = CowTelemetry.fromJson({
      'cow_id': 'COW002',
      'date': '2026-04-02',
      'food_consumed_g': 110,
      'feed_offered_g': 125,
      'eating_minutes': 17,
      'visits': 3,
      'no_food_visits': 1,
      'avg_meal_duration_min': 5.6,
    });

    expect(telemetry.totalFoodConsumedG, 110);
    expect(telemetry.totalFeedOfferedG, 125);
    expect(telemetry.totalEatingMinutes, 17);
  });
}
