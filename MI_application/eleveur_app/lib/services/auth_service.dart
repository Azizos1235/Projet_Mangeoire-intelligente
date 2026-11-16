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
