import 'package:eleveur_app/core/theme.dart';
import 'package:eleveur_app/models/cow_appetite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps backend appetite labels and aliases to semantic colors', () {
    for (final value in ['high', 'increasing', 'increased', 'increase']) {
      expect(AppetiteTrendStyle.parse(value), AppetiteTrend.increasing);
      expect(
        AppetiteTrendStyle.parse(value)!.color,
        AppTheme.appetiteIncreasing,
      );
      expect(
        appetiteClassesByIdentifier({'cow': value})['COW'],
        CowAppetiteClass.increasing,
      );
    }

    for (final value in ['low', 'decreasing', 'decreased', 'decrease']) {
      expect(AppetiteTrendStyle.parse(value), AppetiteTrend.decreasing);
      expect(
        AppetiteTrendStyle.parse(value)!.color,
        AppTheme.appetiteDecreasing,
      );
      expect(
        appetiteClassesByIdentifier({'cow': value})['COW'],
        CowAppetiteClass.decreasing,
      );
    }

    for (final value in ['normal', 'stable', 'steady']) {
      expect(AppetiteTrendStyle.parse(value), AppetiteTrend.stable);
      expect(AppetiteTrendStyle.parse(value)!.color, AppTheme.appetiteStable);
      expect(
        appetiteClassesByIdentifier({'cow': value})['COW'],
        CowAppetiteClass.stable,
      );
    }
  });
}
