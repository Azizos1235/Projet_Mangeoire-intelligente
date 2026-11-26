import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'cow_profile.dart';

enum CowAppetiteClass { increasing, stable, decreasing }

extension CowAppetiteClassStyle on CowAppetiteClass {
  String get labelKey => 'appetite_$name';
  String get key => labelKey;
  AppetiteTrend get trend => AppetiteTrendStyle.parse(name)!;
  Color get color => trend.color;
  Color get lightColor => trend.lightColor;
  IconData get icon => trend.icon;
}

enum CowAppetiteFilter { increasing, stable, decreasing, noData }

extension CowAppetiteFilterLabels on CowAppetiteFilter {
  String get labelKey => switch (this) {
        CowAppetiteFilter.increasing => 'appetite_increasing',
        CowAppetiteFilter.stable => 'appetite_stable',
        CowAppetiteFilter.decreasing => 'appetite_decreasing',
        CowAppetiteFilter.noData => 'appetite_no_data',
      };

  String get descriptionKey => switch (this) {
        CowAppetiteFilter.increasing => 'appetite_increasing_description',
        CowAppetiteFilter.stable => 'appetite_stable_description',
        CowAppetiteFilter.decreasing => 'appetite_decreasing_description',
        CowAppetiteFilter.noData => 'appetite_no_data_description',
      };

  CowAppetiteClass? get appetiteClass => switch (this) {
        CowAppetiteFilter.increasing => CowAppetiteClass.increasing,
        CowAppetiteFilter.stable => CowAppetiteClass.stable,
        CowAppetiteFilter.decreasing => CowAppetiteClass.decreasing,
        CowAppetiteFilter.noData => null,
      };
}

class CowAppetiteEntry {
  final CowReference cow;
  final CowAppetiteClass? appetite;

  const CowAppetiteEntry({required this.cow, required this.appetite});
}

String normalizeCowIdentifier(String value) =>
    value.trim().toUpperCase().replaceAll('-', '').replaceAll('_', '');

Map<String, CowAppetiteClass> appetiteClassesByIdentifier(
  Map<String, String?> appetiteByIdentifier,
) {
  final result = <String, CowAppetiteClass>{};
  for (final entry in appetiteByIdentifier.entries) {
    final identifier = normalizeCowIdentifier(entry.key);
    final appetite = switch (AppetiteTrendStyle.parse(entry.value)) {
      AppetiteTrend.increasing => CowAppetiteClass.increasing,
      AppetiteTrend.stable => CowAppetiteClass.stable,
      AppetiteTrend.decreasing => CowAppetiteClass.decreasing,
      null => null,
    };
    if (identifier.isNotEmpty && appetite != null) {
      result[identifier] = appetite;
    }
  }
  return result;
}

CowAppetiteClass? appetiteForCow(
  CowReference cow,
  Map<String, CowAppetiteClass> appetiteByIdentifier,
) {
  for (final identifier in [cow.internalId, cow.cowId]) {
    final normalized = normalizeCowIdentifier(identifier);
    final appetite = appetiteByIdentifier[normalized];
    if (appetite != null) return appetite;
  }
  return null;
}

List<CowAppetiteEntry> cowAppetiteEntries(
  List<CowReference> cows,
  Map<String, String?> appetiteByIdentifier,
) {
  final normalized = appetiteClassesByIdentifier(appetiteByIdentifier);
  return [
    for (final cow in cows)
      CowAppetiteEntry(
        cow: cow,
        appetite: appetiteForCow(cow, normalized),
      ),
  ];
}

Map<CowAppetiteClass, int> cowAppetiteCounts(
  List<CowAppetiteEntry> entries,
) {
  return {
    for (final appetite in CowAppetiteClass.values)
      appetite: entries.where((entry) => entry.appetite == appetite).length,
  };
}

bool matchesCowAppetiteFilter(
  CowAppetiteEntry entry,
  CowAppetiteFilter filter,
) {
  if (filter == CowAppetiteFilter.noData) return entry.appetite == null;
  return entry.appetite == filter.appetiteClass;
}
