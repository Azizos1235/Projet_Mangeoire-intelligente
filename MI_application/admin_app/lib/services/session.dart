import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Session {
  Session({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static final Session instance = Session();
  static const _tokenKey = 'admin_auth_token';

  final FlutterSecureStorage _storage;
  final ValueNotifier<Map<String, dynamic>?> currentUser =
      ValueNotifier<Map<String, dynamic>?>(null);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  void setCurrentUser(Map<String, dynamic>? user) {
    currentUser.value =
        user == null ? null : Map<String, dynamic>.unmodifiable(user);
  }

  Future<void> clear() async {
    await deleteToken();
    currentUser.value = null;
  }
}
