import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elevage_admin/models/models.dart';
import 'package:smart_elevage_admin/native/canaux.dart';
import 'package:smart_elevage_admin/services/api_client.dart';
import 'package:smart_elevage_admin/services/nfc_service.dart';

void main() {
  final cow = Cow(
    id: 'COW-17',
    internalId: 'RFID-17',
    breed: 'Holstein',
    type: CowType.dairy,
    weightKg: 500,
    birthDate: DateTime(2020, 1, 1),
    ageMonths: 70,
    adminId: 'admin-1',
    nfcUid: '0AB12C3D',
  );

  NfcService serviceFor(Future<Cow> Function(String) findCow) =>
      NfcService.forTesting(
        isAvailable: () async => true,
        readTag: (_) async => const TagNfc(
          uid: '0A:B1:2C:3D',
          techs: [],
          texte: null,
        ),
        findCow: findCow,
        cancelScan: () async {},
        openSettings: () async {},
      );

  test('known scanned UID resolves to its cow', () async {
    String? requestedUid;
    final result = await serviceFor((uid) async {
      requestedUid = uid;
      return cow;
    }).lookupTag('0a:b1:2c:3d', mode: NfcScanMode.view);

    expect(requestedUid, '0AB12C3D');
    expect(result.status, NfcLookupStatus.found);
    expect(result.cow, same(cow));
  });

  test('404 from by-NFC is an unknown tag, not a scan error', () async {
    final result = await serviceFor(
      (_) => Future.error(
        const ApiException(statusCode: 404, message: 'not found'),
      ),
    ).lookupTag('0A-B1-2C-3D', mode: NfcScanMode.add);

    expect(result.status, NfcLookupStatus.notFound);
    expect(result.uid, '0AB12C3D');
  });

  test('409 from by-NFC is reported as registered elsewhere', () async {
    final result = await serviceFor(
      (_) => Future.error(
        const ApiException(statusCode: 409, message: 'registered elsewhere'),
      ),
    ).lookupTag('0AB12C3D', mode: NfcScanMode.add);

    expect(result.status, NfcLookupStatus.registeredElsewhere);
  });
}
