class CowTelemetry {
  const CowTelemetry({
    required this.cowId,
    required this.date,
    required this.totalFoodConsumedG,
    required this.totalFeedOfferedG,
    required this.totalEatingMinutes,
    required this.visits,
    required this.noFoodVisits,
    required this.averageMealDurationMin,
    this.firstVisitHour,
    this.lastVisitHour,
    this.ageMonths,
    this.timestamp,
  });

  final String cowId;
  final DateTime date;
  final double totalFoodConsumedG;
  final double totalFeedOfferedG;
  final double totalEatingMinutes;
  final double visits;
  final double noFoodVisits;
  final double averageMealDurationMin;
  final double? firstVisitHour;
  final double? lastVisitHour;
  final double? ageMonths;
  final DateTime? timestamp;

  factory CowTelemetry.fromJson(Map<String, dynamic> json) => CowTelemetry(
        cowId: _requiredString(json, 'cow_id'),
        date: DateTime.parse(_requiredString(json, 'date')),
        totalFoodConsumedG: _requiredNumber(
          json,
          'total_food_consumed_g',
          fallbackKey: 'food_consumed_g',
        ),
        totalFeedOfferedG: _requiredNumber(
          json,
          'total_feed_offered_g',
          fallbackKey: 'feed_offered_g',
        ),
        totalEatingMinutes: _requiredNumber(
          json,
          'total_eating_minutes',
          fallbackKey: 'eating_minutes',
        ),
        visits: _requiredNumber(json, 'visits'),
        noFoodVisits: _requiredNumber(json, 'no_food_visits'),
        averageMealDurationMin: _requiredNumber(json, 'avg_meal_duration_min'),
        firstVisitHour: _optionalNumber(json, 'first_visit_hour'),
        lastVisitHour: _optionalNumber(json, 'last_visit_hour'),
        ageMonths: _optionalNumber(json, 'age_months'),
        timestamp: _optionalDateTime(json, 'timestamp'),
      );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Missing or invalid "$key" in API response.');
}

double _requiredNumber(
  Map<String, dynamic> json,
  String key, {
  String? fallbackKey,
}) {
  final value = json[key];
  if (value is num) return value.toDouble();
  final fallback = fallbackKey == null ? null : json[fallbackKey];
  if (fallback is num) return fallback.toDouble();
  final keys = fallbackKey == null ? '"$key"' : '"$key" or "$fallbackKey"';
  throw FormatException('Missing or invalid $keys in API response.');
}

double? _optionalNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException('Invalid "$key" in API response.');
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String && value.isNotEmpty) return DateTime.parse(value);
  throw FormatException('Invalid "$key" in API response.');
}
