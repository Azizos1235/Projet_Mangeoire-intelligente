import 'package:flutter/material.dart';

import '../core/strings.dart';

enum CowType { dairy, beef, dual }

extension CowTypeX on CowType {
  String get label => switch (this) {
        CowType.dairy => AppStrings.cowTypeDairy,
        CowType.beef => AppStrings.cowTypeBeef,
        CowType.dual => AppStrings.cowTypeDual,
      };

  static CowType parse(String value) => switch (value) {
        'dairy' => CowType.dairy,
        'beef' => CowType.beef,
        'dual' => CowType.dual,
        _ => throw FormatException('Unknown cow type: $value'),
      };
}

enum Appetite { low, normal, high }

extension AppetiteX on Appetite {
  String get label => switch (this) {
        Appetite.low => AppStrings.appetiteLow,
        Appetite.normal => AppStrings.appetiteNormal,
        Appetite.high => AppStrings.appetiteHigh,
      };

  Color get color => switch (this) {
        Appetite.low => const Color(0xFFE65100),
        Appetite.normal => const Color(0xFF2E7D32),
        Appetite.high => const Color(0xFF1E88E5),
      };

  static Appetite? parse(String? value) => switch (value) {
        'low' || 'decreasing' || 'decreased' || 'decrease' => Appetite.low,
        'normal' || 'stable' => Appetite.normal,
        'high' || 'increasing' || 'increased' || 'increase' => Appetite.high,
        _ => null,
      };

  String get trendLabel => switch (this) {
        Appetite.low => AppStrings.trendDecreasing,
        Appetite.normal => AppStrings.trendStable,
        Appetite.high => AppStrings.trendIncreasing,
      };
}

const breedsByType = <CowType, List<String>>{
  CowType.dairy: ['Holstein', 'Jersey'],
  CowType.beef: ['Angus', 'Limousin', 'Charolais'],
  CowType.dual: ['Simmental'],
};

class Cow {
  const Cow({
    required this.id,
    required this.internalId,
    required this.breed,
    required this.type,
    required this.weightKg,
    required this.birthDate,
    required this.ageMonths,
    required this.adminId,
    required this.nfcUid,
  });

  final String id;
  final String internalId;
  final String? adminId;
  final String breed;
  final CowType type;
  final double weightKg;
  final DateTime birthDate;
  final int ageMonths;
  final String? nfcUid;

  factory Cow.fromJson(Map<String, dynamic> json) {
    final weight = json['weight_kg'];
    final ageMonths = json['age_months'];
    if (weight is! num || ageMonths is! int) {
      throw const FormatException('Invalid cow profile response.');
    }

    return Cow(
      id: _requiredString(json, 'cow_id'),
      internalId: _optionalString(json, 'internal_id') ??
          _requiredString(json, 'cow_id'),
      adminId: _optionalString(json, 'admin_id'),
      breed: _requiredString(json, 'breed'),
      type: CowTypeX.parse(_requiredString(json, 'type')),
      weightKg: weight.toDouble(),
      birthDate: DateTime.parse(_requiredString(json, 'birth_date')),
      ageMonths: ageMonths,
      nfcUid: _optionalString(json, 'nfc_uid'),
    );
  }
}

class DailySummary {
  const DailySummary({
    required this.cowId,
    required this.date,
    required this.firstReadingAt,
    required this.lastUpdated,
    required this.totalFoodConsumedG,
    required this.totalFeedOfferedG,
    required this.totalEatingMinutes,
    required this.visits,
    required this.noFoodVisits,
    required this.averageMealDurationMin,
    required this.firstVisitHour,
    required this.lastVisitHour,
    required this.appetiteClass,
    required this.appetitePct,
    required this.appetiteSource,
    required this.appetiteComputedAt,
  });

  final String cowId;
  final DateTime date;
  final DateTime firstReadingAt;
  final DateTime lastUpdated;
  final double totalFoodConsumedG;
  final double totalFeedOfferedG;
  final double totalEatingMinutes;
  final double visits;
  final double noFoodVisits;
  final double averageMealDurationMin;
  final Object? firstVisitHour;
  final Object? lastVisitHour;
  final String? appetiteClass;
  final Map<String, double>? appetitePct;
  final String? appetiteSource;
  final DateTime? appetiteComputedAt;

  Appetite? get appetite => AppetiteX.parse(appetiteClass);

  factory DailySummary.fromJson(Map<String, dynamic> json) => DailySummary(
        cowId: _requiredString(json, 'cow_id'),
        date: DateTime.parse(_requiredString(json, 'date')),
        firstReadingAt:
            DateTime.parse(_requiredString(json, 'first_reading_at')),
        lastUpdated: DateTime.parse(_requiredString(json, 'last_updated')),
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
        firstVisitHour: json['first_visit_hour'],
        lastVisitHour: json['last_visit_hour'],
        appetiteClass: _optionalString(json, 'appetite_class'),
        appetitePct: _optionalNumberMap(json, 'appetite_pct'),
        appetiteSource: _optionalString(json, 'appetite_source'),
        appetiteComputedAt: _optionalDateTime(json, 'appetite_computed_at'),
      );
}

class HomeAppetiteResponse {
  const HomeAppetiteResponse(this.appetiteByInternalId);

  final Map<String, Appetite?> appetiteByInternalId;

  factory HomeAppetiteResponse.fromJson(Map<String, dynamic> json) {
    final appetite = json['appetite'];
    if (appetite is! Map) {
      throw const FormatException('Invalid home appetite response.');
    }

    final result = <String, Appetite?>{};
    for (final entry in appetite.entries) {
      final internalId = entry.key;
      if (internalId is! String || internalId.trim().isEmpty) {
        throw const FormatException('Invalid cow appetite in API response.');
      }
      if (entry.value is! Map) {
        throw const FormatException('Invalid cow appetite in API response.');
      }
      final record = Map<String, dynamic>.from(entry.value as Map);
      final value = record['appetite'];
      if (value != null && value is! String) {
        throw const FormatException('Invalid appetite class in API response.');
      }
      result[internalId] =
          AppetiteX.parse((value as String?)?.trim().toLowerCase());
    }
    return HomeAppetiteResponse(Map.unmodifiable(result));
  }
}

class RealtimeReading {
  const RealtimeReading({
    required this.cowId,
    required this.timestamp,
    required this.visits,
    required this.foodConsumedG,
    required this.feedOfferedG,
    required this.eatingMinutes,
    required this.noFoodVisits,
  });

  final String cowId;
  final DateTime timestamp;
  final Object? visits;
  final Object? foodConsumedG;
  final Object? feedOfferedG;
  final Object? eatingMinutes;
  final Object? noFoodVisits;

  factory RealtimeReading.fromJson(Map<String, dynamic> json) =>
      RealtimeReading(
        cowId: _requiredString(json, 'cow_id'),
        timestamp: DateTime.parse(_requiredString(json, 'timestamp')),
        visits: json['visits'],
        foodConsumedG: json['food_consumed_g'],
        feedOfferedG: json['feed_offered_g'],
        eatingMinutes: json['eating_minutes'],
        noFoodVisits: json['no_food_visits'],
      );
}

class DispatchRecord {
  const DispatchRecord({
    required this.cowId,
    required this.date,
    required this.foodG,
    required this.servedAt,
  });

  final String cowId;
  final String date;
  final double foodG;
  final String servedAt;

  factory DispatchRecord.fromJson(Map<String, dynamic> json) {
    final foodG = json['food_g'];
    if (foodG is! num) {
      throw const FormatException('Invalid dispatch response.');
    }
    return DispatchRecord(
      cowId: _requiredString(json, 'cow_id'),
      date: _requiredString(json, 'date'),
      foodG: foodG.toDouble(),
      servedAt: _requiredString(json, 'served_at'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Missing or invalid "$key" in API response.');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value;
  throw FormatException('Invalid "$key" in API response.');
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

Map<String, double>? _optionalNumberMap(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value == null) return null;
  if (value is! Map) {
    throw FormatException('Invalid "$key" in API response.');
  }

  final result = <String, double>{};
  for (final entry in value.entries) {
    if (entry.key is! String || entry.value is! num) {
      throw FormatException('Invalid "$key" in API response.');
    }
    result[entry.key as String] = (entry.value as num).toDouble();
  }
  return Map.unmodifiable(result);
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String && value.isNotEmpty) return DateTime.parse(value);
  throw FormatException('Invalid "$key" in API response.');
}
