import 'package:flutter/services.dart';

class CanauxNatifs {
  CanauxNatifs._();

  static const MethodChannel _qrChannel = MethodChannel('qr/scanner');
  static const MethodChannel _nfcChannel = MethodChannel('nfc/tag');

  static Future<String?> scannerQr() =>
      _qrChannel.invokeMethod<String>('scanner');

  static Future<bool> nfcDisponible() async {
    final available = await _nfcChannel.invokeMethod<bool>('disponible');
    if (available == null) {
      throw StateError('The native NFC availability response was empty.');
    }
    return available;
  }

  static Future<TagNfc?> lireTagNfc({int delaiSec = 30}) async {
    final data = await _nfcChannel.invokeMapMethod<String, dynamic>(
      'lire',
      {'delai': delaiSec},
    );
    return data == null ? null : TagNfc.fromMap(data);
  }

  static Future<void> annulerNfc() => _nfcChannel.invokeMethod<void>('annuler');

  static Future<void> ouvrirParametresNfc() =>
      _nfcChannel.invokeMethod<void>('parametres');
}

class TagNfc {
  final String uid;
  final List<String> techs;
  final String? texte;

  const TagNfc({
    required this.uid,
    required this.techs,
    required this.texte,
  });

  String get uidCompact => uid.replaceAll(':', '').toUpperCase();

  factory TagNfc.fromMap(Map<String, dynamic> data) {
    final uid = data['uid'];
    final rawTechs = data['techs'];
    final text = data['texte'];
    if (uid is! String || uid.isEmpty || rawTechs is! List) {
      throw const FormatException('Invalid native NFC tag response.');
    }
    if (rawTechs.any((tech) => tech is! String) ||
        (text != null && text is! String)) {
      throw const FormatException('Invalid native NFC tag response.');
    }

    return TagNfc(
      uid: uid,
      techs: List<String>.unmodifiable(rawTechs.cast<String>()),
      texte: text as String?,
    );
  }
}
