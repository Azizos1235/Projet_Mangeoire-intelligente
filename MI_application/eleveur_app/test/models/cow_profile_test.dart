import 'package:flutter/foundation.dart' show compute;
import 'package:eleveur_app/models/cow_profile.dart';
import 'package:flutter_test/flutter_test.dart';

List<CowReference> _parseReferences(List<Map<String, dynamic>> values) =>
    values.map(CowReference.fromJson).toList(growable: false);

void main() {
  test(
      'cow references retain the internal ID for requests and public ID for display',
      () {
    final cow = CowReference.fromJson({
      'internal_id': 'RFID-17',
      'cow_id': 'COW-17',
    });

    expect(cow.internalId, 'RFID-17');
    expect(cow.displayId, 'COW-17');
  });

  test('cow references fall back to a public-looking internal ID', () {
    final cow = CowReference.fromJson({
      'internal_id': 'COW001',
      'cow_id': '',
    });

    expect(cow.displayId, 'COW001');
  });

  test('cow references never display an unresolved RFID as a public ID', () {
    final cow = CowReference.fromJson({
      'internal_id': 'RFID-17',
      'cow_id': 'RFID-17',
    });

    expect(cow.displayId, '—');
  });

  test('cow references can be parsed and returned from a background isolate',
      () async {
    final cows = await compute(_parseReferences, [
      {'internal_id': 'RFID-17', 'cow_id': 'COW-17'},
    ]);

    expect(cows.single.internalId, 'RFID-17');
    expect(cows.single.displayId, 'COW-17');
  });
}
