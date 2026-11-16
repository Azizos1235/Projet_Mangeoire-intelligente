import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/eleveur_user.dart';

class Session {
  Session._();

  static final Session instance = Session._();
  static const String _tokenKey = 'jwt';
  static const Duration _storageTimeout = Duration(seconds: 10);
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  final ValueNotifier<EleveurUser?> currentUser =
      ValueNotifier<EleveurUser?>(null);
  int _authGeneration = 0;

  int get authGeneration => _authGeneration;

  void setCurrentUser(EleveurUser user) {
    _authGeneration++;
    currentUser.value = user;
  }

  Future<void> saveToken(String token) {
    final value = token.trim();
    if (value.isEmpty) {
      throw ArgumentError('JWT must not be empty.');
    }
    return _storage
        .write(key: _tokenKey, value: value)
        .timeout(_storageTimeout);
  }

  Future<String?> readToken() =>
      _storage.read(key: _tokenKey).timeout(_storageTimeout);

  Future<void> deleteToken() async {
    _authGeneration++;
    currentUser.value = null;
    try {
      await _storage.delete(key: _tokenKey).timeout(_storageTimeout);
    } finally {
      currentUser.value = null;
    }
  }
}
