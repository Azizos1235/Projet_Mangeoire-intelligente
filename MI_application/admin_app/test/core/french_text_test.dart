import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Admin UI and strings contain no common English UI words', () {
    const forbidden = <String>[
      'Cows',
      'Alerts',
      'Tasks',
      'Search',
      'Delete',
      'Cancel',
      'Save',
      'Loading',
      'Error',
      'Low',
      'High',
      'Increasing',
      'Decreasing',
      'Pending',
      'Done',
    ];

    final files = <File>[
      File('lib/core/strings.dart'),
      ...Directory('lib/screens')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
    ];

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final word in forbidden) {
        expect(
          source.contains(RegExp('\\b$word\\b')),
          isFalse,
          reason: '$word found in ${file.path}',
        );
      }
    }
  });
}
