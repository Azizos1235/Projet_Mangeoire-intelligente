import 'package:flutter/foundation.dart' show visibleForTesting;
import '../models/cow_profile.dart';
import '../native/canaux.dart';
import 'api_client.dart';
import 'cow_service.dart';

enum NfcScanMode { add, view }

class NfcScanResult {
  final NfcScanMode mode;
  final String uid;

  const NfcScanResult({required this.mode, required this.uid});
}

enum NfcLookupStatus { found, notFound, registeredElsewhere }

class NfcLookupResult {
  final NfcScanMode mode;
  final String uid;
  final NfcLookupStatus status;
  final CowReference? cow;

  const NfcLookupResult({
    required this.mode,
    required this.uid,
    required this.status,
    this.cow,
  });
}

/// Coordinates NFC tag reading and cow lookup.
class NfcService {
  NfcService._() : _findCow = CowService.instance.findCowByNfcUid;

  @visibleForTesting
  NfcService.forTesting({
    required Future<CowReference> Function(String uid) findCow,
  }) : _findCow = findCow;

  static final NfcService instance = NfcService._();

  final Future<CowReference> Function(String uid) _findCow;

  Future<bool> isAvailable() => CanauxNatifs.nfcDisponible();

  Future<TagNfc?> readTag({int delaiSec = 30}) =>
      CanauxNatifs.lireTagNfc(delaiSec: delaiSec);

  Future<NfcLookupResult> lookupTag(
    String uid, {
    required NfcScanMode mode,
  }) async {
    final normalizedUid = normalizeUid(uid);
    try {
      final cow = await _findCow(normalizedUid);
      return NfcLookupResult(
        mode: mode,
        uid: normalizedUid,
        status: NfcLookupStatus.found,
        cow: cow,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return NfcLookupResult(
          mode: mode,
          uid: normalizedUid,
          status: NfcLookupStatus.notFound,
        );
      }
      if (error.statusCode == 409) {
        return NfcLookupResult(
          mode: mode,
          uid: normalizedUid,
          status: NfcLookupStatus.registeredElsewhere,
        );
      }
      rethrow;
    }
  }

  static String normalizeUid(String uid) {
    final normalized = uid.toUpperCase().replaceAll(RegExp(r'[:\-\s]'), '');
    if (!RegExp(r'^[0-9A-F]{8,32}$').hasMatch(normalized)) {
      throw const FormatException('Invalid NFC tag UID.');
    }
    return normalized;
  }

  Future<void> cancelScan() => CanauxNatifs.annulerNfc();

  Future<void> openSettings() => CanauxNatifs.ouvrirParametresNfc();
}
