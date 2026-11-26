import 'theme.dart';

enum CowAppetiteClass { increasing, stable, decreasing }

abstract final class AppetiteAnalysis {
  static const trendLength = 14;

  static CowAppetiteClass? classFromLabel(String label) =>
      switch (AppetiteTrendStyle.parse(label)) {
        AppetiteTrend.increasing => CowAppetiteClass.increasing,
        AppetiteTrend.stable => CowAppetiteClass.stable,
        AppetiteTrend.decreasing => CowAppetiteClass.decreasing,
        _ => null,
      };

  static Map<String, Map<String, dynamic>> indexDaily(Iterable<dynamic> docs) {
    final result = <String, Map<String, dynamic>>{};
    for (final item in docs) {
      if (item is! Map) continue;
      final date = item['date'];
      if (date is! String || date.length < 10) continue;
      result.putIfAbsent(
        date.substring(0, 10),
        () => Map<String, dynamic>.from(item),
      );
    }
    return result;
  }

  static DateTime newestRecordDate(
    Iterable<dynamic> docs, {
    DateTime? fallback,
  }) {
    DateTime? newest;
    for (final item in docs) {
      if (item is! Map) continue;
      final date = item['date'];
      if (date is! String || date.length < 10) continue;
      final parsed = DateTime.tryParse(date.substring(0, 10));
      if (parsed == null) continue;
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      if (newest == null || day.isAfter(newest)) newest = day;
    }
    final selected = newest ?? fallback ?? DateTime.now();
    return DateTime(selected.year, selected.month, selected.day);
  }

  static List<DateTime> trendWindow(
    Iterable<dynamic> docs, {
    DateTime? fallback,
  }) {
    final newest = newestRecordDate(docs, fallback: fallback);
    return List<DateTime>.generate(
      trendLength,
      (index) => newest.subtract(Duration(days: trendLength - index - 1)),
      growable: false,
    );
  }

  static CowAppetiteClass? appetiteOf(Map<String, dynamic>? doc) {
    if (doc == null) return null;
    Object? value = doc['appetite_class'] ?? doc['appetite'];
    if (value is Map) {
      value = value['label'] ??
          value['class'] ??
          value['value'] ??
          value['appetite'];
    }
    if (value is! String) {
      final probabilities = probabilitiesOf(doc);
      return probabilities == null ? null : topOf(probabilities);
    }
    return classFromLabel(value);
  }

  static Map<CowAppetiteClass, double>? probabilitiesOf(
    Map<String, dynamic> doc,
  ) {
    final hint = RegExp(r'appetite|prob|pct|percent|score|confidence');
    final maps = <Map>[
      for (final entry in doc.entries)
        if (entry.value is Map && hint.hasMatch(entry.key.toLowerCase()))
          entry.value as Map,
      for (final entry in doc.entries)
        if (entry.value is Map && !hint.hasMatch(entry.key.toLowerCase()))
          entry.value as Map,
    ];
    for (final source in maps) {
      final raw = <CowAppetiteClass, double>{};
      for (final entry in source.entries) {
        final appetite =
            entry.key is String ? classFromLabel(entry.key as String) : null;
        final value = entry.value;
        if (appetite != null && value is num && value.isFinite && value >= 0) {
          raw[appetite] = value.toDouble();
        }
      }
      final normalized = normalise(raw);
      if (normalized != null) return normalized;
    }

    final flatHint = RegExp(r'pct|prob|percent|score');
    final raw = <CowAppetiteClass, double>{};
    for (final entry in doc.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;
      if (value is! num ||
          !value.isFinite ||
          value < 0 ||
          !flatHint.hasMatch(key)) {
        continue;
      }
      for (final token in key.split(RegExp(r'[_\-\s]'))) {
        final appetite = classFromLabel(token);
        if (appetite != null) {
          raw[appetite] = value.toDouble();
          break;
        }
      }
    }
    return normalise(raw);
  }

  static Map<CowAppetiteClass, double>? normalise(
    Map<CowAppetiteClass, double> raw,
  ) {
    final sum = raw.values.fold<double>(0, (total, value) => total + value);
    if (raw.length < 2 || !sum.isFinite || sum <= 0) return null;
    return {
      for (final appetite in CowAppetiteClass.values)
        appetite: (raw[appetite] ?? 0) / sum,
    };
  }

  static CowAppetiteClass topOf(Map<CowAppetiteClass, double> probabilities) {
    var best = CowAppetiteClass.values.first;
    for (final appetite in CowAppetiteClass.values) {
      if ((probabilities[appetite] ?? 0) > (probabilities[best] ?? 0)) {
        best = appetite;
      }
    }
    return best;
  }

  static String pct(double probability) => '${(probability * 100).round()}%';

  static String dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
