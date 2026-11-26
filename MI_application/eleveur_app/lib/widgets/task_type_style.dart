import 'package:flutter/material.dart';

import '../core/theme.dart';

class TaskTypeStyle {
  static Color colorFor(String type) => switch (type) {
        'sell' => const Color(0xFF0277BD),
        'vet' => const Color(0xFF6A1B9A),
        'butcher' => const Color(0xFF8D4E00),
        'check_weight' => const Color(0xFF00838F),
        _ => AppTheme.primary,
      };

  static IconData iconFor(String type) => switch (type) {
        'sell' => Icons.sell_outlined,
        'vet' => Icons.medical_services_outlined,
        'butcher' => Icons.restaurant_outlined,
        'check_weight' => Icons.monitor_weight_outlined,
        _ => Icons.assignment_outlined,
      };
}
