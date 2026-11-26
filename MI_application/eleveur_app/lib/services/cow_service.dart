import 'package:flutter/foundation.dart' show compute, debugPrint, kDebugMode;
import '../models/cow_profile.dart';
import '../models/cow_telemetry.dart';
import 'api_client.dart';

class HomeAppetiteResponse {
  final Map<String, String?> appetiteByInternalId;
  final List<Object?> rawLabels;

  const HomeAppetiteResponse({
    required this.appetiteByInternalId,
    required this.rawLabels,
  });
}

abstract interface class CowProfileService {
  Future<CowProfile> getProfile(String cowId);

  Future<CowProfile> updateProfile({
    required String cowId,
    required DateTime birthDate,
    required double weightKg,
    required String type,
    required String breed,
  });
}

/// Loads livestock identifiers and daily sensor records from the backend.
class CowService implements CowProfileService {
  CowService._();

  static final CowService instance = CowService._();
  static const int _isolateParseThreshold = 100;
  static const Duration _cowListOperationTimeout = Duration(seconds: 30);
  final ApiClient _api = ApiClient.instance;

  void _debug(String message) {
    if (kDebugMode) debugPrint('[DBG] cows $message');
  }

  Future<dynamic> getProfiles() => _api.getProfiles();

  @override
  Future<CowProfile> getProfile(String cowId) async {
    final response = await _api.getProfile(cowId);
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid cow profile response from API.');
    }
    return CowProfile.fromJson(response);
  }

  Future<CowProfile> createProfile({
    required String cowId,
    required DateTime birthDate,
    required double weightKg,
    required String type,
    required String breed,
    required String nfcUid,
  }) async {
    final year = birthDate.year.toString().padLeft(4, '0');
    final month = birthDate.month.toString().padLeft(2, '0');
    final day = birthDate.day.toString().padLeft(2, '0');
    final formattedBirthDate = '$year-$month-$day';
    final response = await _api.post(
      '/profiles',
      {
        'cow_id': cowId,
        'birth_date': formattedBirthDate,
        'weight_kg': weightKg,
        'type': type,
        'breed': breed,
        'nfc_uid': nfcUid,
      },
      expectedStatusCode: 201,
    );
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid cow profile response from API.');
    }
    return CowProfile.fromJson(response);
  }

  @override
  Future<CowProfile> updateProfile({
    required String cowId,
    required DateTime birthDate,
    required double weightKg,
    required String type,
    required String breed,
  }) async {
    final y = birthDate.year.toString().padLeft(4, '0');
    final m = birthDate.month.toString().padLeft(2, '0');
    final d = birthDate.day.toString().padLeft(2, '0');
    final response = await _api.put('/profiles/${Uri.encodeComponent(cowId)}', {
      'birth_date': '$y-$m-$d',
      'weight_kg': weightKg,
      'type': type,
      'breed': breed,
    });
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid cow profile response from API.');
    }
    return CowProfile.fromJson(response);
  }

  Future<dynamic> getDaily(String cowId) => _api.getDaily(cowId);

  Future<dynamic> getRealtime(String cowId) => _api.getRealtime(cowId);

  Future<dynamic> getDispatch(String cowId) => _api.getDispatch(cowId);

  Future<List<CowReference>> getCows() {
    final stopwatch = Stopwatch()..start();
    _debug(
      'getCows total deadline start '
      'timeoutMs=${_cowListOperationTimeout.inMilliseconds}',
    );
    return _getCows().timeout(
      _cowListOperationTimeout,
      onTimeout: () {
        _debug(
          'getCows total deadline exceeded '
          '(${stopwatch.elapsedMilliseconds}ms)',
        );
        throw const NetworkApiException();
      },
    ).whenComplete(
      () => _debug(
        'getCows total deadline end (${stopwatch.elapsedMilliseconds}ms)',
      ),
    );
  }

  Future<List<CowReference>> _getCows() async {
    final stopwatch = Stopwatch()..start();
    _debug('getCows start');
    try {
      final response = await _api.getCows();
      _debug('getCows response received type=${response.runtimeType}');
      if (response is! Map<String, dynamic>) {
        throw const FormatException('Invalid cows response from API.');
      }

      final cowProfiles = response['cow_profiles'];
      if (cowProfiles is List) {
        _debug('cow_profiles parsing start count=${cowProfiles.length}');
        final cows = cowProfiles.length >= _isolateParseThreshold
            ? await _parseCowProfilesInIsolate(cowProfiles)
            : _parseCowProfiles(cowProfiles);
        _debug('cow_profiles parsing complete count=${cows.length}');
        return await _resolveMissingPublicIds(cows);
      }

      final cows = response['cows'];
      if (cows is! List) {
        throw const FormatException('Invalid cows response from API.');
      }
      _debug('legacy cows parsing start count=${cows.length}');
      final references = cows.length >= _isolateParseThreshold
          ? await _parseLegacyCowIdsInIsolate(cows)
          : _parseLegacyCowIds(cows);
      _debug('legacy cows parsing complete count=${references.length}');
      return await _resolveMissingPublicIds(references);
    } catch (error) {
      _debug('getCows failed (${stopwatch.elapsedMilliseconds}ms): $error');
      rethrow;
    } finally {
      _debug('getCows end (${stopwatch.elapsedMilliseconds}ms)');
    }
  }

  Future<HomeAppetiteResponse> getAppetite({
    required void Function(int statusCode) onStatus,
  }) async {
    final response = await _api.getHomeAppetite(onStatus: onStatus);
    if (response is! Map<String, dynamic> ||
        response['appetite'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid home appetite response from API.');
    }

    final appetite = response['appetite'] as Map<String, dynamic>;
    final result = <String, String?>{};
    final rawLabels = <String?>[];
    for (final entry in appetite.entries) {
      final record = entry.value;
      if (entry.key.trim().isEmpty || record is! Map<String, dynamic>) {
        throw const FormatException('Invalid cow appetite in API response.');
      }
      final value = record['appetite'];
      final raw = record['raw'];
      if (value != null && value is! String) {
        throw const FormatException('Invalid appetite class in API response.');
      }
      result[entry.key] = (value as String?)?.trim().toLowerCase();
      rawLabels.add(raw);
    }
    return HomeAppetiteResponse(
      appetiteByInternalId: result,
      rawLabels: rawLabels,
    );
  }

  Future<List<CowReference>> _resolveMissingPublicIds(
    List<CowReference> cows,
  ) async {
    final allHavePublicIds = cows.length >= _isolateParseThreshold
        ? await _allHavePublicIdsInIsolate(cows)
        : _allHavePublicIds(cows);
    if (allHavePublicIds) return cows;

    _debug('profile lookup GET /profiles start');
    final response = await _api.getProfiles();
    _debug('profile lookup GET /profiles complete');
    if (response is! List) {
      throw const FormatException('Invalid profiles response from API.');
    }

    _debug('profile ID index start count=${response.length}');
    final publicIdsByIdentifier = response.length >= _isolateParseThreshold
        ? await _indexPublicCowIdsInIsolate(response)
        : _indexPublicCowIds(response);
    _debug('profile ID index complete count=${publicIdsByIdentifier.length}');

    if (cows.length >= _isolateParseThreshold) {
      return await _resolveCowReferencesInIsolate(
        cows,
        publicIdsByIdentifier,
      );
    }
    return _resolveCowReferences(cows, publicIdsByIdentifier);
  }

  Future<CowReference> findCowByNfcUid(String uid) async {
    final normalizedUid = uid.trim().toUpperCase();
    if (normalizedUid.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'NFC UID must not be empty.');
    }

    final response = await _api.getProfileByNfc(normalizedUid);
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid NFC profile response from API.');
    }
    return CowReference.fromJson(response);
  }

  Future<CowTelemetry> getLatest(String cowId) async {
    final response = await _api.getLatest(cowId);
    if (response is! Map<String, dynamic>) {
      throw const FormatException('Invalid cow telemetry response from API.');
    }
    return CowTelemetry.fromJson(response);
  }
}

Future<List<CowReference>> _parseCowProfilesInIsolate(
  List<dynamic> values,
) async {
  final stopwatch = Stopwatch()..start();
  if (kDebugMode) {
    debugPrint(
      '[DBG] cows isolate cow_profiles parse start count=${values.length}',
    );
  }
  final result = await compute(_parseCowProfiles, values);
  if (kDebugMode) {
    debugPrint(
      '[DBG] cows isolate cow_profiles parse complete '
      'count=${result.length} (${stopwatch.elapsedMilliseconds}ms)',
    );
  }
  return result;
}

Future<List<CowReference>> _parseLegacyCowIdsInIsolate(
  List<dynamic> values,
) async {
  final stopwatch = Stopwatch()..start();
  if (kDebugMode) {
    debugPrint(
        '[DBG] cows isolate legacy IDs parse start count=${values.length}');
  }
  final result = await compute(_parseLegacyCowIds, values);
  if (kDebugMode) {
    debugPrint(
      '[DBG] cows isolate legacy IDs parse complete '
      'count=${result.length} (${stopwatch.elapsedMilliseconds}ms)',
    );
  }
  return result;
}

List<CowReference> _parseCowProfiles(List<dynamic> values) {
  final cows = <CowReference>[];
  for (var index = 0; index < values.length; index++) {
    final value = values[index];
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid cow profile in API response.');
    }
    cows.add(CowReference.fromJson(value, debugItem: index + 1));
  }
  return cows.toList(growable: false);
}

List<CowReference> _parseLegacyCowIds(List<dynamic> values) =>
    values.map<CowReference>((value) {
      if (value is! String || value.isEmpty) {
        throw const FormatException('Invalid cow identifier in API response.');
      }
      return CowReference(internalId: value, cowId: '');
    }).toList(growable: false);

Future<bool> _allHavePublicIdsInIsolate(List<CowReference> cows) async {
  final stopwatch = Stopwatch()..start();
  if (kDebugMode) {
    debugPrint('[DBG] cows isolate public ID check start count=${cows.length}');
  }
  final result = await compute(_allHavePublicIds, cows);
  if (kDebugMode) {
    debugPrint(
      '[DBG] cows isolate public ID check complete '
      'result=$result (${stopwatch.elapsedMilliseconds}ms)',
    );
  }
  return result;
}

bool _allHavePublicIds(List<CowReference> cows) =>
    cows.every((cow) => cow.hasPublicId);

Future<List<CowReference>> _resolveCowReferencesInIsolate(
  List<CowReference> cows,
  Map<String, String> publicIdsByIdentifier,
) async {
  final stopwatch = Stopwatch()..start();
  if (kDebugMode) {
    debugPrint('[DBG] cows isolate ID resolution start count=${cows.length}');
  }
  final result = await compute(
    _resolveCowReferencesMessage,
    <Object?>[cows, publicIdsByIdentifier],
  );
  if (kDebugMode) {
    debugPrint(
      '[DBG] cows isolate ID resolution complete '
      'count=${result.length} (${stopwatch.elapsedMilliseconds}ms)',
    );
  }
  return result;
}

List<CowReference> _resolveCowReferencesMessage(List<Object?> input) =>
    _resolveCowReferences(
      input[0] as List<CowReference>,
      input[1] as Map<String, String>,
    );

List<CowReference> _resolveCowReferences(
  List<CowReference> cows,
  Map<String, String> publicIdsByIdentifier,
) {
  return cows
      .map((cow) => cow.hasPublicId
          ? cow
          : CowReference(
              internalId: cow.internalId,
              cowId: publicIdsByIdentifier[cow.internalId] ?? '',
            ))
      .toList(growable: false);
}

Future<Map<String, String>> _indexPublicCowIdsInIsolate(
  List<dynamic> values,
) async {
  final stopwatch = Stopwatch()..start();
  if (kDebugMode) {
    debugPrint('[DBG] cows isolate profile index start count=${values.length}');
  }
  final result = await compute(_indexPublicCowIds, values);
  if (kDebugMode) {
    debugPrint(
      '[DBG] cows isolate profile index complete '
      'count=${result.length} (${stopwatch.elapsedMilliseconds}ms)',
    );
  }
  return result;
}

Map<String, String> _indexPublicCowIds(List<dynamic> values) {
  final publicIdsByIdentifier = <String, String>{};
  for (final value in values) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid cow profile in API response.');
    }
    final internalId = value['internal_id'];
    final cowId = value['cow_id'];
    if (internalId is! String ||
        internalId.trim().isEmpty ||
        cowId is! String ||
        cowId.trim().isEmpty) {
      continue;
    }

    final profile = CowReference(internalId: internalId, cowId: cowId);
    if (profile.hasPublicId) {
      publicIdsByIdentifier[internalId] = cowId.trim();
      publicIdsByIdentifier[cowId.trim()] = cowId.trim();
    }
  }
  return publicIdsByIdentifier;
}
