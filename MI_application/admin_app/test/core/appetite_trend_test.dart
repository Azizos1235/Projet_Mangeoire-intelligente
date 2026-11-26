import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elevage_admin/core/theme.dart';

void main() {
  test('maps appetite labels and aliases to semantic colors', () {
    for (final value in ['high', 'increasing', 'increased', 'increase']) {
      expect(AppetiteTrendStyle.parse(value), AppetiteTrend.increasing);
      expect(
        AppetiteTrendStyle.parse(value)!.color,
        AppTheme.appetiteIncreasing,
      );
    }

    for (final value in ['low', 'decreasing', 'decreased', 'decrease']) {
      expect(AppetiteTrendStyle.parse(value), AppetiteTrend.decreasing);
      expect(
        AppetiteTrendStyle.parse(value)!.color,
        AppTheme.appetiteDecreasing,
      );
    }

    for (final value in ['normal', 'stable', 'steady']) {
      expect(AppetiteTrendStyle.parse(value), AppetiteTrend.stable);
      expect(AppetiteTrendStyle.parse(value)!.color, AppTheme.appetiteStable);
    }
  });
}
