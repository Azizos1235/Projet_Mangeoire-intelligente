import '../models/eleveur_user.dart';
import 'api_client.dart';
import 'session.dart';

class InviteCheckResult {
  final bool valid;
  final String? adminName;

  const InviteCheckResult({required this.valid, required this.adminName});

  factory InviteCheckResult.fromJson(Map<String, dynamic> json) {
    final valid = json['valid'];
    final adminName = json['admin_name'];
    if (valid is! bool || (adminName != null && adminName is! String)) {
      throw const FormatException('Invalid invitation check response.');
    }
    return InviteCheckResult(valid: valid, adminName: adminName as String?);
  }
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  final ApiClient _api = ApiClient.instance;
  final Session _session = Session.instance;

  Future<InviteCheckResult> checkInvite(String code) async {
    final inviteCode = code.trim();
    if (inviteCode.isEmpty) {
      throw ArgumentError('Invitation code is required.');
    }

    final response = await _api.post('/invites/check', {'code': inviteCode});
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid invitation check response.');
    }
    return InviteCheckResult.fromJson(response);
  }

  Future<EleveurUser> register(String inviteCode, String name) async {
    final code = inviteCode.trim();
    final normalizedName = name.trim();
    if (code.isEmpty) {
      throw ArgumentError('Invitation code is required.');
    }
    if (normalizedName.length < 2 || normalizedName.length > 60) {
      throw ArgumentError.value(
        name,
        'name',
        'Name must contain 2 to 60 characters.',
      );
    }

    final response = await _api.post(
      '/auth/eleveur/register',
      {'invite_code': code, 'name': normalizedName},
      expectedStatusCode: 201,
    );
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid registration response.');
    }

    final token = response['token'];
    final rawUser = response['user'];
    if (token is! String ||
        token.trim().isEmpty ||
        rawUser is! Map<String, dynamic>) {
      throw const FormatException('Invalid registration response.');
    }
    final user = EleveurUser.fromJson(rawUser);
    await _session.saveToken(token);
    _session.setCurrentUser(user);
    return user;
  }

  Future<EleveurUser> qrLogin(String token, String name) async {
    final qrToken = token.trim();
    final normalizedName = name.trim();
    if (qrToken.isEmpty) {
      throw ArgumentError('QR token is required.');
    }
    _validateName(normalizedName, name);

    final response = await _api.post(
      '/auth/eleveur/qr-login',
      {'token': qrToken, 'name': normalizedName},
      handleUnauthorized: false,
    );
    final user = _userFromAuthResponse(response, 'QR login');
    final rawToken = response['token'] as String;
    await _session.saveToken(rawToken);
    _session.setCurrentUser(user);
    return user;
  }

  Future<EleveurUser> verifyName(String name) async {
    final normalizedName = name.trim();
    _validateName(normalizedName, name);
    final response = await _api.post(
      '/auth/eleveur/verify-name',
      {'name': normalizedName},
      handleUnauthorized: false,
    );
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid name verification response.');
    }
    final user = EleveurUser.fromJson(response);
    _session.setCurrentUser(user);
    return user;
  }

  void _validateName(String normalizedName, String originalName) {
    if (normalizedName.length < 2 || normalizedName.length > 60) {
      throw ArgumentError.value(
        originalName,
        'name',
        'Name must contain 2 to 60 characters.',
      );
    }
  }

  EleveurUser _userFromAuthResponse(
    dynamic response,
    String responseName,
  ) {
    if (response is! Map<String, dynamic>) {
      throw FormatException('Invalid $responseName response.');
    }
    final token = response['token'];
    final rawUser = response['user'];
    if (token is! String ||
        token.trim().isEmpty ||
        rawUser is! Map<String, dynamic>) {
      throw FormatException('Invalid $responseName response.');
    }
    return EleveurUser.fromJson(rawUser);
  }

  Future<EleveurUser> me() async {
    final authGeneration = _session.authGeneration;
    final response = await _api.get('/auth/me');
    final rawUser = response is Map<String, dynamic> && response['user'] != null
        ? response['user']
        : response;
    if (rawUser is! Map<String, dynamic>) {
      throw const FormatException('Invalid current user response.');
    }

    final user = EleveurUser.fromJson(rawUser);
    if (_session.authGeneration == authGeneration) {
      _session.currentUser.value = user;
    }
    return user;
  }

  Future<void> logout() => _session.deleteToken();
}
