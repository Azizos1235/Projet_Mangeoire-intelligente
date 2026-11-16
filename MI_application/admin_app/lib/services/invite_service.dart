import 'api_client.dart';

class Invite {
  const Invite({
    required this.id,
    required this.code,
    required this.qrPayload,
    required this.expiresAt,
  });

  final String id;
  final String code;
  final String qrPayload;
  final DateTime expiresAt;

  factory Invite.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final code = json['code'];
    final qrPayload = json['qr_payload'];
    final expiresAt = json['expires_at'];
    if (id is! String ||
        code is! String ||
        qrPayload is! String ||
        expiresAt is! String) {
      throw const FormatException('Invalid invite response.');
    }
    final parsedExpiry = DateTime.tryParse(expiresAt);
    if (parsedExpiry == null) {
      throw const FormatException('Invalid invite expiry.');
    }
    return Invite(
      id: id,
      code: code,
      qrPayload: qrPayload,
      expiresAt: parsedExpiry,
    );
  }
}

class InviteRecord {
  const InviteRecord({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.usedByName,
  });

  final String id;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? usedByName;

  factory InviteRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final status = json['status'];
    final createdAt = json['created_at'];
    final expiresAt = json['expires_at'];
    final usedByName = json['used_by_name'];
    if (id is! String ||
        status is! String ||
        createdAt is! String ||
        expiresAt is! String ||
        (usedByName != null && usedByName is! String)) {
      throw const FormatException('Invalid invite list response.');
    }
    final parsedCreatedAt = DateTime.tryParse(createdAt);
    final parsedExpiresAt = DateTime.tryParse(expiresAt);
    if (parsedCreatedAt == null || parsedExpiresAt == null) {
      throw const FormatException('Invalid invite dates.');
    }
    return InviteRecord(
      id: id,
      status: status,
      createdAt: parsedCreatedAt,
      expiresAt: parsedExpiresAt,
      usedByName: usedByName is String ? usedByName : null,
    );
  }
}

class InviteService {
  InviteService._();

  static final InviteService instance = InviteService._();

  Future<Invite> createInvite() async {
    final response =
        await ApiClient.instance.post<Map<String, dynamic>>('/invites');
    return Invite.fromJson(response);
  }

  Future<List<InviteRecord>> listInvites() async {
    final response = await ApiClient.instance.get<List<dynamic>>('/invites');
    return response.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid invite list response.');
      }
      return InviteRecord.fromJson(Map<String, dynamic>.from(item));
    }).toList(growable: false);
  }

  Future<void> revokeInvite(String id) async {
    await ApiClient.instance
        .delete<Object?>('/invites/${Uri.encodeComponent(id)}');
  }
}
