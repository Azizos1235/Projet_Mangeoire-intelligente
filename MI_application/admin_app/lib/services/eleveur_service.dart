import 'api_client.dart';

class EleveurRecord {
  const EleveurRecord({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  factory EleveurRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final createdAt = json['created_at'];
    if (id is! String || name is! String || createdAt is! String) {
      throw const FormatException('Invalid éleveur response.');
    }
    final parsedCreatedAt = DateTime.tryParse(createdAt);
    if (parsedCreatedAt == null) {
      throw const FormatException('Invalid éleveur creation date.');
    }
    return EleveurRecord(id: id, name: name, createdAt: parsedCreatedAt);
  }

  String get joinedDate {
    final date = createdAt.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class EleveurService {
  EleveurService._();

  static final EleveurService instance = EleveurService._();

  Future<List<EleveurRecord>> listEleveurs() async {
    final response = await ApiClient.instance.get<List<dynamic>>('/eleveurs');
    return response.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid éleveur list response.');
      }
      return EleveurRecord.fromJson(Map<String, dynamic>.from(item));
    }).toList(growable: false);
  }

  Future<void> deleteEleveur(String id) async {
    await ApiClient.instance
        .delete<Object?>('/eleveurs/${Uri.encodeComponent(id)}');
  }
}
