import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/eleveur_user.dart';
import '../native/canaux.dart';

class Session {
  Session._();

  static final Session instance = Session._();
  static const String _tokenKey = 'jwt';
  static const Duration _storageTimeout = Duration(seconds: 10);
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  final ValueNotifier<EleveurUser?> currentUser =
      ValueNotifier<EleveurUser?>(null);
  final ValueNotifier<int> tokenRevision = ValueNotifier(0);
  int _authGeneration = 0;

  int get authGeneration => _authGeneration;

  void setCurrentUser(EleveurUser user) {
    _authGeneration++;
    currentUser.value = user;
  }

  Future<void> saveToken(String token) async {
    final value = token.trim();
    if (value.isEmpty) {
      throw ArgumentError('JWT must not be empty.');
    }
    await _storage.write(key: _tokenKey, value: value).timeout(_storageTimeout);
    tokenRevision.value++;
  }

  Future<String?> readToken() =>
      _storage.read(key: _tokenKey).timeout(_storageTimeout);

  Future<void> deleteToken() async {
    _authGeneration++;
    currentUser.value = null;
    try {
      await _storage.delete(key: _tokenKey).timeout(_storageTimeout);
    } finally {
      await _clearNativeSession();
      currentUser.value = null;
    }
  }

  Future<void> _clearNativeSession() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await CanauxNatifs.clearSession();
    } on PlatformException catch (error) {
      debugPrint('Unable to clear the native notification session: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Native notification channel is unavailable: $error');
    }
    try {
      await CanauxNatifs.annulerPlanification();
    } on PlatformException catch (error) {
      debugPrint('Unable to cancel native notification work: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Native notification channel is unavailable: $error');
    }
  }
}
