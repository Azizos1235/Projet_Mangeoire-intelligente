import 'package:eleveur_app/models/cow_profile.dart';
import 'package:eleveur_app/services/api_client.dart';
import 'package:eleveur_app/services/nfc_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cow = CowReference(internalId: 'RFID-001', cowId: 'COW001');

  test('registered tag in add mode resolves to its cow', () async {
    final service = NfcService.forTesting(
      findCow: (_) async => cow,
    );

    final result = await service.lookupTag(
      'a1:b2:c3:d4',
      mode: NfcScanMode.add,
    );

    expect(result.mode, NfcScanMode.add);
    expect(result.uid, 'A1B2C3D4');
    expect(result.status, NfcLookupStatus.found);
    expect(result.cow, cow);
  });

  test('unregistered tag in add mode is eligible for the add form', () async {
    final service = NfcService.forTesting(
      findCow: (_) async => throw const NotFoundApiException(),
    );

    final result = await service.lookupTag(
      'A1B2C3D4',
      mode: NfcScanMode.add,
    );

    expect(result.mode, NfcScanMode.add);
    expect(result.status, NfcLookupStatus.notFound);
    expect(result.cow, isNull);
  });

  test('registered tag in view mode resolves to its cow', () async {
    final service = NfcService.forTesting(
      findCow: (_) async => cow,
    );

    final result = await service.lookupTag(
      'A1B2C3D4',
      mode: NfcScanMode.view,
    );

    expect(result.mode, NfcScanMode.view);
    expect(result.status, NfcLookupStatus.found);
    expect(result.cow, cow);
  });

  test('unknown tag in view mode is reported as not found', () async {
    final service = NfcService.forTesting(
      findCow: (_) async => throw const NotFoundApiException(),
    );

    final result = await service.lookupTag(
      'A1B2C3D4',
      mode: NfcScanMode.view,
    );

    expect(result.mode, NfcScanMode.view);
    expect(result.status, NfcLookupStatus.notFound);
    expect(result.cow, isNull);
  });

  test('tag owned elsewhere never returns profile data', () async {
    final service = NfcService.forTesting(
      findCow: (_) async => throw const ConflictApiException(),
    );

    final result = await service.lookupTag(
      'A1B2C3D4',
      mode: NfcScanMode.view,
    );

    expect(result.status, NfcLookupStatus.registeredElsewhere);
    expect(result.cow, isNull);
  });

  test('tag owned elsewhere in add mode cannot enter the add form', () async {
    final service = NfcService.forTesting(
      findCow: (_) async => throw const ConflictApiException(),
    );

    final result = await service.lookupTag(
      'A1B2C3D4',
      mode: NfcScanMode.add,
    );

    expect(result.mode, NfcScanMode.add);
    expect(result.status, NfcLookupStatus.registeredElsewhere);
    expect(result.cow, isNull);
  });

  test('normalization removes separators and whitespace', () {
    expect(
      NfcService.normalizeUid(' a1:b2-c3 d4 '),
      'A1B2C3D4',
    );
  });
}
