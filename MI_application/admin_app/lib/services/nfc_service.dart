import 'package:flutter/foundation.dart' show visibleForTesting;
import '../models/models.dart';
import '../native/canaux.dart';
import 'api_client.dart';
import 'cow_service.dart';

enum NfcScanMode { add, view }

class NfcScanResult {
  const NfcScanResult({required this.mode, required this.uid});

  final NfcScanMode mode;
  final String uid;
}

enum NfcLookupStatus { found, notFound, registeredElsewhere }

class NfcLookupResult {
  const NfcLookupResult({
    required this.mode,
    required this.uid,
    required this.status,
    this.cow,
  });

  final NfcScanMode mode;
  final String uid;
  final NfcLookupStatus status;
  final Cow? cow;
}

class NfcService {
  NfcService._()
      : _isAvailable = CanauxNatifs.nfcDisponible,
        _readTag = _readTagFromNative,
        _findCow = CowService.instance.findCowByNfcUid,
        _cancelScan = CanauxNatifs.annulerNfc,
        _openSettings = CanauxNatifs.ouvrirParametresNfc;

  @visibleForTesting
  NfcService.forTesting({
    required Future<bool> Function() isAvailable,
    required Future<TagNfc?> Function(int delaiSec) readTag,
    required Future<Cow> Function(String uid) findCow,
    required Future<void> Function() cancelScan,
    required Future<void> Function() openSettings,
  })  : _isAvailable = isAvailable,
        _readTag = readTag,
        _findCow = findCow,
        _cancelScan = cancelScan,
        _openSettings = openSettings;

  static final NfcService instance = NfcService._();

  static Future<TagNfc?> _readTagFromNative(int delaiSec) =>
      CanauxNatifs.lireTagNfc(delaiSec: delaiSec);

  final Future<bool> Function() _isAvailable;
  final Future<TagNfc?> Function(int delaiSec) _readTag;
  final Future<Cow> Function(String uid) _findCow;
  final Future<void> Function() _cancelScan;
  final Future<void> Function() _openSettings;

  Future<bool> isAvailable() => _isAvailable();

  Future<TagNfc?> readTag({int delaiSec = 30}) => _readTag(delaiSec);

  Future<void> cancelScan() => _cancelScan();

  Future<void> openSettings() => _openSettings();

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
}
