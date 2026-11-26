import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elevage_admin/core/cow_search.dart';
import 'package:smart_elevage_admin/models/models.dart';

void main() {
  final cow = Cow(
    id: 'COW-17',
    internalId: 'RFID-AB12',
    breed: 'Holstein',
    type: CowType.dairy,
    weightKg: 500,
    birthDate: DateTime(2020, 1, 1),
    ageMonths: 70,
    adminId: 'admin-1',
    nfcUid: '01AB23CD',
  );

  test('search matches cow ID, RFID, NFC UID and breed locally', () {
    expect(matchesCowSearch(cow, 'cow-17'), isTrue);
    expect(matchesCowSearch(cow, 'rfid-ab12'), isTrue);
    expect(matchesCowSearch(cow, '01ab23cd'), isTrue);
    expect(matchesCowSearch(cow, 'HOLSTEIN'), isTrue);
    expect(matchesCowSearch(cow, 'not-found'), isFalse);
  });

  test('search applies appetite filters after text matching', () {
    expect(
      matchesCowSearch(
        cow,
        'rfid',
        appetite: Appetite.low,
        appetiteFilter: Appetite.low,
      ),
      isTrue,
    );
    expect(
      matchesCowSearch(
        cow,
        'rfid',
        appetite: Appetite.low,
        appetiteFilter: Appetite.high,
      ),
      isFalse,
    );
    expect(
      matchesCowSearch(
        cow,
        'not-found',
        appetite: Appetite.low,
        appetiteFilter: Appetite.low,
      ),
      isFalse,
    );
  });
}
