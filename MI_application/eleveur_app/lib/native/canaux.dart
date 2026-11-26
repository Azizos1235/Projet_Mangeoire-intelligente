import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'action_queue.dart';

class CanauxNatifs {
  CanauxNatifs._();

  static const MethodChannel _qrChannel = MethodChannel('qr/scanner');
  static const MethodChannel _nfcChannel = MethodChannel('nfc/tag');
  static const MethodChannel _notificationChannel =
      MethodChannel('alerte/notifier');
  static const MethodChannel _syncChannel = MethodChannel('sync/planifier');
  static const MethodChannel _sessionChannel = MethodChannel('session/natif');
  static final PendingNotificationTarget actions = pendingNotificationTarget;

  static Future<void> initializeNotificationActions() => actions.initialize();

  static Future<Map<String, dynamic>?> actionInitiale() =>
      _notificationChannel.invokeMapMethod<String, dynamic>('actionInitiale');

  static Future<void> ecouterActions(
    ValueChanged<Map<String, dynamic>> onAction,
  ) async {
    debugPrint('[MI_NOTIF] Installing Dart surAction handler');
    _notificationChannel.setMethodCallHandler((call) async {
      if (call.method != 'surAction') return;
      if (call.arguments is! Map) {
        throw const FormatException('Invalid native action.');
      }
      final action = Map<String, dynamic>.from(call.arguments as Map);
      debugPrint(
        '[MI_NOTIF] surAction received '
        'type=${action['type']} task_id=${action['task_id']}',
      );
      onAction(action);
    });
    await _notificationChannel.invokeMethod<void>('ecouterActions');
  }

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

  static Future<bool> demanderPermissionNotif() async =>
      await _notificationChannel.invokeMethod<bool>('demanderPermission') ??
      false;

  static Future<bool> notificationsAutorisees() async =>
      await _notificationChannel.invokeMethod<bool>('autorisee') ?? false;

  static Future<void> planifier() {
    debugPrint('[MI_NOTIF] planifier');
    return _syncChannel.invokeMethod<void>('planifier');
  }

  static Future<void> verifierMaintenant() {
    debugPrint('[MI_NOTIF] verifierMaintenant');
    return _syncChannel.invokeMethod<void>('maintenant');
  }

  static Future<void> annulerPlanification() {
    debugPrint('[MI_NOTIF] annulerPlanification');
    return _syncChannel.invokeMethod<void>('annuler');
  }

  static Future<void> marquerCommeNotifie(Iterable<String> ids) =>
      _notificationChannel.invokeMethod<void>(
        'marquerCommeNotifie',
        ids.toList(growable: false),
      );

  static Future<bool> notificationsActivees() async =>
      await _notificationChannel.invokeMethod<bool>('notificationsActivees') ??
      true;

  static Future<bool> serviceActif() async =>
      await _syncChannel.invokeMethod<bool>('serviceActif') ?? false;

  static Future<bool> consommerSessionExpiree() async =>
      await _notificationChannel
          .invokeMethod<bool>('consommerSessionExpiree') ??
      false;

  static Future<bool> guiderOptimisationBatterie() async =>
      await _notificationChannel
          .invokeMethod<bool>('guiderOptimisationBatterie') ??
      false;

  static Future<bool> ignoreOptimisationBatterie() async =>
      await _notificationChannel
          .invokeMethod<bool>('ignoreOptimisationBatterie') ??
      false;

  static Future<void> demanderIgnoreOptimisationBatterie() =>
      _notificationChannel.invokeMethod<void>(
        'demanderIgnoreOptimisationBatterie',
      );

  static Future<void> definirNotifications(bool enabled) =>
      _notificationChannel.invokeMethod<void>(
        'definirNotifications',
        {'enabled': enabled},
      );

  static Future<bool> permissionDejaExpliquee() async =>
      await _notificationChannel
          .invokeMethod<bool>('permissionDejaExpliquee') ??
      false;

  static Future<void> marquerPermissionExpliquee() =>
      _notificationChannel.invokeMethod<void>('marquerPermissionExpliquee');

  static Future<void> ouvrirParametresNotifications() =>
      _notificationChannel.invokeMethod<void>('ouvrirParametres');

  static Future<void> setSession({
    required String token,
    required String baseUrl,
    required String role,
    required String userId,
    required String language,
  }) {
    debugPrint('[MI_NOTIF] setSession role=$role userId=$userId');
    return _sessionChannel.invokeMethod<void>('setSession', {
      'token': token,
      'baseUrl': baseUrl,
      'role': role,
      'userId': userId,
      'language': language,
    });
  }

  static Future<void> clearSession() {
    debugPrint('[MI_NOTIF] clearSession');
    return _sessionChannel.invokeMethod<void>('clearSession');
  }
}

class _CanauxActionChannel implements NativeActionChannel {
  @override
  Future<void> startListening(ValueChanged<Map<String, dynamic>> onAction) =>
      CanauxNatifs.ecouterActions(onAction);

  @override
  Future<Map<String, dynamic>?> actionInitiale() =>
      CanauxNatifs.actionInitiale();
}

final PendingNotificationTarget pendingNotificationTarget =
    PendingNotificationTarget(_CanauxActionChannel());

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
