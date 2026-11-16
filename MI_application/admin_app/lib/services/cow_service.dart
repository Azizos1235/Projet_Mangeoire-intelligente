import '../models/models.dart';
import 'api_client.dart';

class CowConflictException implements Exception {
  const CowConflictException();
}

class PredictionUnavailableException implements Exception {
  const PredictionUnavailableException();
}

class CowService {
  CowService._(this._api);

  CowService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient.instance;

  static final CowService instance = CowService._(ApiClient.instance);

  final ApiClient _api;

  Future<List<Cow>> listProfiles() async {
    final response = await _api.get<List<dynamic>>('/profiles');
    return response.map(_parseCow).toList(growable: false);
  }

  Future<Cow> profile(String id) async {
    final response = await _api
        .get<Map<String, dynamic>>('/profiles/${Uri.encodeComponent(id)}');
    return Cow.fromJson(response);
  }

  Future<DailySummary?> latest(String id) async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/latest/${Uri.encodeComponent(id)}',
      );
      return DailySummary.fromJson(response);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<DailySummary>> daily(String id, {int? limit}) async {
    final response = await _api.get<List<dynamic>>(
      _pathWithLimit('/daily/${Uri.encodeComponent(id)}', limit),
    );
    return response.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid daily response.');
      }
      return DailySummary.fromJson(Map<String, dynamic>.from(item));
    }).toList(growable: false);
  }

  Future<List<dynamic>> dailyDocuments(String id, {int? limit}) async {
    return await _api.get<List<dynamic>>(
      _pathWithLimit('/daily/${Uri.encodeComponent(id)}', limit),
    );
  }

  Future<HomeAppetiteResponse> homeAppetite() async {
    final response = await _api.get<Map<String, dynamic>>('/home/appetite');
    return HomeAppetiteResponse.fromJson(response);
  }

  Future<List<RealtimeReading>> realtime(String id, {int? limit}) async {
    final response = await _api.get<List<dynamic>>(
      _pathWithLimit('/realtime/${Uri.encodeComponent(id)}', limit),
    );
    return response.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid realtime response.');
      }
      return RealtimeReading.fromJson(Map<String, dynamic>.from(item));
    }).toList(growable: false);
  }

  Future<List<DispatchRecord>> dispatch(String id, {int? limit}) async {
    final response = await _api.get<List<dynamic>>(
      _pathWithLimit('/dispatch/${Uri.encodeComponent(id)}', limit),
    );
    return response.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid dispatch response.');
      }
      return DispatchRecord.fromJson(Map<String, dynamic>.from(item));
    }).toList(growable: false);
  }

  Future<Object?> predict(String id) async {
    try {
      return await _api.get<Object?>('/predict/${Uri.encodeComponent(id)}');
    } on ApiException catch (error) {
      if (error.statusCode == 501 || error.statusCode == 502) {
        throw const PredictionUnavailableException();
      }
      rethrow;
    }
  }

  Future<Cow> createProfile({
    required String id,
    required DateTime birthDate,
    required double weightKg,
    required CowType type,
    required String breed,
    String? nfcUid,
  }) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/profiles',
        expectedStatusCode: 201,
        body: {
          'cow_id': id,
          'birth_date': _dateOnly(birthDate),
          'weight_kg': weightKg,
          'type': type.name,
          'breed': breed,
          if (nfcUid != null) 'nfc_uid': nfcUid,
        },
      );
      return Cow.fromJson(response);
    } on ApiException catch (error) {
      if (error.statusCode == 409) throw const CowConflictException();
      rethrow;
    }
  }

  Future<Cow> updateProfile({
    required String id,
    required DateTime birthDate,
    required double weightKg,
    required CowType type,
    required String breed,
    bool clearNfcUid = false,
    String? nfcUid,
  }) async {
    try {
      final response = await _api.put<Map<String, dynamic>>(
        '/profiles/${Uri.encodeComponent(id)}',
        body: {
          'birth_date': _dateOnly(birthDate),
          'weight_kg': weightKg,
          'type': type.name,
          'breed': breed,
          if (clearNfcUid)
            'nfc_uid': null
          else if (nfcUid != null)
            'nfc_uid': nfcUid,
        },
      );
      return Cow.fromJson(response);
    } on ApiException catch (error) {
      if (error.statusCode == 409) throw const CowConflictException();
      rethrow;
    }
  }

  Future<void> deleteProfile(String id) async {
    await _api.delete<Map<String, dynamic>>(
      '/profiles/${Uri.encodeComponent(id)}',
    );
  }

  Cow _parseCow(Object? item) {
    if (item is! Map) {
      throw const FormatException('Invalid profile list response.');
    }
    return Cow.fromJson(Map<String, dynamic>.from(item));
  }

  String _pathWithLimit(String path, int? limit) {
    if (limit == null) return path;
    return '$path?limit=$limit';
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
