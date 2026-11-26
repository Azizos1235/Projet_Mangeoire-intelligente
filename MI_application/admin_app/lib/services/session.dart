import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../native/canaux.dart';

class Session {
  Session({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static final Session instance = Session();
  static const _tokenKey = 'admin_auth_token';

  final FlutterSecureStorage _storage;
  final ValueNotifier<Map<String, dynamic>?> currentUser =
      ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<int> tokenRevision = ValueNotifier(0);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    tokenRevision.value++;
  }

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  void setCurrentUser(Map<String, dynamic>? user) {
    currentUser.value =
        user == null ? null : Map<String, dynamic>.unmodifiable(user);
  }

  Future<void> clear() async {
    try {
      await deleteToken();
    } finally {
      currentUser.value = null;
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await CanauxNatifs.clearSession();
        } on PlatformException catch (error) {
          FlutterError.reportError(FlutterErrorDetails(exception: error));
        } on MissingPluginException catch (error) {
          FlutterError.reportError(FlutterErrorDetails(exception: error));
        }
        try {
          await CanauxNatifs.annulerPlanification();
        } on PlatformException catch (error) {
          FlutterError.reportError(FlutterErrorDetails(exception: error));
        } on MissingPluginException catch (error) {
          FlutterError.reportError(FlutterErrorDetails(exception: error));
        }
      }
    }
  }
}
