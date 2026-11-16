/// One daily sensor record returned by the livestock telemetry API.
class CowTelemetry {
  final String cowId;
  final DateTime date;
  final double? ageMonths;
  final int foodConsumedGrams;
  final int feedOfferedGrams;
  final int visits;
  final int eatingMinutes;
  final double averageMealDurationMinutes;
  final int visitsWithoutFood;
  final double? firstVisitHour;
  final double? lastVisitHour;
  final bool? dayOver;

  const CowTelemetry({
    required this.cowId,
    required this.date,
    required this.ageMonths,
    required this.foodConsumedGrams,
    required this.feedOfferedGrams,
    required this.visits,
    required this.eatingMinutes,
    required this.averageMealDurationMinutes,
    required this.visitsWithoutFood,
    required this.firstVisitHour,
    required this.lastVisitHour,
    required this.dayOver,
  });

  factory CowTelemetry.fromJson(Map<String, dynamic> json) {
    return CowTelemetry(
      cowId: _requiredString(json, 'cow_id'),
      date: DateTime.parse(_requiredString(json, 'date')),
      ageMonths: _optionalNumber(json, 'age_months'),
      foodConsumedGrams: _requiredNumber(
        json,
        'food_consumed_g',
        fallbackKey: 'total_food_consumed_g',
      ).toInt(),
      feedOfferedGrams: _requiredNumber(
        json,
        'feed_offered_g',
        fallbackKey: 'total_feed_offered_g',
      ).toInt(),
      visits: _requiredNumber(json, 'visits').toInt(),
      eatingMinutes: _requiredNumber(
        json,
        'eating_minutes',
        fallbackKey: 'total_eating_minutes',
      ).toInt(),
      averageMealDurationMinutes:
          _requiredNumber(json, 'avg_meal_duration_min').toDouble(),
      visitsWithoutFood: _requiredNumber(json, 'no_food_visits').toInt(),
      firstVisitHour: _optionalNumber(json, 'first_visit_hour'),
      lastVisitHour: _optionalNumber(json, 'last_visit_hour'),
      dayOver: _optionalBool(json, 'day_over'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Missing or invalid "$key" in API response.');
}

num _requiredNumber(
  Map<String, dynamic> json,
  String key, {
  String? fallbackKey,
}) {
  final value = json[key];
  if (value is num) return value;
  final fallback = fallbackKey == null ? null : json[fallbackKey];
  if (fallback is num) return fallback;
  final acceptedKeys =
      fallbackKey == null ? '"$key"' : '"$key" or "$fallbackKey"';
  throw FormatException('Missing or invalid $acceptedKeys in API response.');
}

double? _optionalNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num && value.isFinite) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed.isFinite) return parsed;
  }
  throw FormatException('Invalid "$key" in API response.');
}

bool? _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is bool) return value;
  throw FormatException('Invalid "$key" in API response.');
}
