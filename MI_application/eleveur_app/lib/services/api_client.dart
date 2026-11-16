import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show compute, debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../core/app_routes.dart';
import 'session.dart';

/// Provides authenticated HTTP access to backend resources.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const Duration _timeout = Duration(seconds: 60);
  static const Duration _cowListTimeout = Duration(seconds: 15);
  static const Duration _wakingUpThreshold = Duration(seconds: 5);
  static const int _largeJsonThreshold = 64 * 1024;

  final ValueNotifier<bool> isServerWakingUp = ValueNotifier<bool>(false);
  GlobalKey<NavigatorState>? navigatorKey;
  int _longRequestCount = 0;

  void _debug(String message) {
    if (kDebugMode) debugPrint('[DBG] api $message');
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    if (query == null) return uri;
    final clean = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };
    return clean.isEmpty ? uri : uri.replace(queryParameters: clean);
  }

  String _id(String value) => Uri.encodeComponent(value);

  Future<Map<String, String>> _headers({bool json = false}) async {
    final stopwatch = Stopwatch()..start();
    _debug('token read start');
    try {
      final token = await Session.instance.readToken();
      _debug('token read complete (${stopwatch.elapsedMilliseconds}ms)');
      if (token == null || token.isEmpty) {
        _debug('Authorization header present=false tokenLength=0');
      } else {
        _debug(
          'Authorization header present=true '
          'tokenHint=${_tokenHint(token)} '
          'tokenLength=${token.length} '
          'outerWhitespace=${token != token.trim()} '
          'wrappedInQuotes=${_isWrappedInQuotes(token)} '
          '${_jwtDiagnostics(token)}',
        );
      }
      return {
        if (json) 'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
    } catch (error) {
      _debug('token read failed (${stopwatch.elapsedMilliseconds}ms): $error');
      rethrow;
    }
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    required String label,
    Duration timeout = _timeout,
    bool retryOnTimeout = true,
  }) async {
    var isLongRequest = false;
    final wakingUpTimer = Timer(_wakingUpThreshold, () {
      isLongRequest = true;
      _longRequestCount++;
      isServerWakingUp.value = true;
    });
    try {
      for (var attempt = 0;; attempt++) {
        final stopwatch = Stopwatch()..start();
        _debug(
          '$label HTTP send start attempt=${attempt + 1} timeoutMs=${timeout.inMilliseconds}',
        );
        try {
          final response = await request().timeout(timeout);
          _debug(
            '$label HTTP send complete (${stopwatch.elapsedMilliseconds}ms) '
            'status=${response.statusCode} '
            'bodyLength=${response.body.length}',
          );
          return response;
        } on TimeoutException {
          _debug(
            '$label HTTP timeout (${stopwatch.elapsedMilliseconds}ms) '
            'attempt=${attempt + 1}',
          );
          if (retryOnTimeout && attempt == 0) continue;
          throw const NetworkApiException();
        } on http.ClientException {
          _debug(
            '$label HTTP send failed (${stopwatch.elapsedMilliseconds}ms)',
          );
          throw const NetworkApiException();
        }
      }
    } finally {
      wakingUpTimer.cancel();
      if (isLongRequest) {
        _longRequestCount--;
        isServerWakingUp.value = _longRequestCount > 0;
      }
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Duration timeout = _timeout,
    bool retryOnTimeout = true,
    Duration? totalTimeout,
    void Function(int statusCode)? onStatus,
  }) async {
    final stopwatch = Stopwatch()..start();
    if (totalTimeout != null) {
      _debug(
        'GET $path total deadline start '
        'timeoutMs=${totalTimeout.inMilliseconds}',
      );
    }
    final operation = Future<dynamic>(() async {
      _debug('GET $path headers await start');
      final headers = await _headers();
      _debug('GET $path headers await complete');
      final response = await _send(
        () => http.get(_uri(path, query), headers: headers),
        label: 'GET $path',
        timeout: timeout,
        retryOnTimeout: retryOnTimeout,
      );
      onStatus?.call(response.statusCode);
      if (path == '/home/appetite') {
        final body = response.body;
        final loggedBody =
            body.length <= 2000 ? body : '${body.substring(0, 2000)}...';
        _debug(
          'GET $path bodyLength=${body.length} body=$loggedBody',
        );
      }
      _debug('GET $path parse start');
      final result = await _parse(response);
      _debug('GET $path parse complete');
      return result;
    });
    try {
      final result = totalTimeout == null
          ? await operation
          : await operation.timeout(totalTimeout);
      _debug(
        'GET $path operation complete (${stopwatch.elapsedMilliseconds}ms)',
      );
      return result;
    } on TimeoutException {
      if (totalTimeout == null) {
        _debug(
          'GET $path operation timed out (${stopwatch.elapsedMilliseconds}ms)',
        );
        rethrow;
      }
      _debug(
        'GET $path total deadline exceeded '
        '(${stopwatch.elapsedMilliseconds}ms)',
      );
      throw const NetworkApiException();
    } catch (error) {
      _debug(
        'GET $path operation failed '
        '(${stopwatch.elapsedMilliseconds}ms): $error',
      );
      rethrow;
    }
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    int expectedStatusCode = 200,
  }) async {
    _debug('POST $path headers await start');
    final headers = await _headers(json: true);
    _debug('POST $path headers await complete');
    _debug('POST $path send await start');
    final response = await _send(
      () => http.post(
        _uri(path),
        headers: headers,
        body: jsonEncode(body),
      ),
      label: 'POST $path',
    );
    _debug('POST $path send await complete');
    _debug('POST $path parse await start');
    final result =
        await _parse(response, expectedStatusCode: expectedStatusCode);
    _debug('POST $path parse await complete');
    return result;
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    _debug('PATCH $path headers await start');
    final headers = await _headers(json: true);
    _debug('PATCH $path headers await complete');
    _debug('PATCH $path send await start');
    final response = await _send(
      () => http.patch(
        _uri(path),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      label: 'PATCH $path',
    );
    _debug('PATCH $path send await complete');
    _debug('PATCH $path parse await start');
    final result = await _parse(response);
    _debug('PATCH $path parse await complete');
    return result;
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    _debug('PUT $path headers await start');
    final headers = await _headers(json: true);
    _debug('PUT $path headers await complete');
    _debug('PUT $path send await start');
    final response = await _send(
      () => http.put(_uri(path), headers: headers, body: jsonEncode(body)),
      label: 'PUT $path',
    );
    _debug('PUT $path send await complete');
    _debug('PUT $path parse await start');
    final result = await _parse(response);
    _debug('PUT $path parse await complete');
    return result;
  }

  Future<dynamic> _parse(
    http.Response response, {
    int? expectedStatusCode,
  }) async {
    _debug(
      'response parse start status=${response.statusCode} '
      'bodyLength=${response.body.length}',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body;
      final loggedBody =
          body.length <= 2000 ? body : '${body.substring(0, 2000)}...';
      _debug(
        'HTTP error response status=${response.statusCode} '
        'decodedBody=$loggedBody',
      );
    }
    if (expectedStatusCode != null &&
        response.statusCode != expectedStatusCode) {
      _debug('status handling start status=${response.statusCode}');
      await _handleStatus(response.statusCode);
      _debug('status handling complete status=${response.statusCode}');
      throw _exceptionFor(
        response.statusCode,
        responseMessage: _responseMessage(response.body),
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      final stopwatch = Stopwatch()..start();
      _debug('jsonDecode start bodyLength=${response.body.length}');
      try {
        final useIsolate = response.body.length >= _largeJsonThreshold;
        if (useIsolate) _debug('jsonDecode mode=isolate');
        final decoded = useIsolate
            ? await compute(_decodeJson, response.body)
            : jsonDecode(response.body);
        _debug('jsonDecode complete (${stopwatch.elapsedMilliseconds}ms)');
        return decoded;
      } catch (error) {
        _debug(
            'jsonDecode failed (${stopwatch.elapsedMilliseconds}ms): $error');
        rethrow;
      }
    }
    _debug('status handling start status=${response.statusCode}');
    await _handleStatus(response.statusCode);
    _debug('status handling complete status=${response.statusCode}');
    throw _exceptionFor(
      response.statusCode,
      responseMessage: _responseMessage(response.body),
    );
  }

  Future<void> _handleStatus(int statusCode) async {
    if (statusCode == 401) {
      _debug('401 token deletion start');
      await Session.instance.deleteToken();
      _debug('401 token deletion complete');
      _navigateTo(AppRoutes.welcome, arguments: {'sessionExpired': true});
    } else if (statusCode == 402) {
      _navigateTo(AppRoutes.subscriptionExpired);
    }
  }

  void _navigateTo(String route, {Object? arguments}) {
    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;
    unawaited(
      navigator.pushNamedAndRemoveUntil<void>(
        route,
        (_) => false,
        arguments: arguments,
      ),
    );
  }

  String? _responseMessage(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        for (final key in ['detail', 'error', 'message']) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) {
            return _limitErrorMessage(value.trim());
          }
          if (key == 'detail' && value is List) {
            final messages = <String>[];
            for (final item in value) {
              if (item is Map && item['msg'] is String) {
                messages.add((item['msg'] as String).trim());
              }
            }
            if (messages.isNotEmpty) {
              return _limitErrorMessage(messages.join('\n'));
            }
          }
        }
      } else if (decoded is String && decoded.trim().isNotEmpty) {
        return _limitErrorMessage(decoded.trim());
      }
    } on FormatException {
      return _limitErrorMessage(trimmed);
    }
    return _limitErrorMessage(trimmed);
  }

  String _limitErrorMessage(String message) => message.length <= 500
      ? message
      : '${message.substring(0, 500)}...';

  ApiException _exceptionFor(
    int statusCode, {
    String? responseMessage,
  }) =>
      switch (statusCode) {
        401 => UnauthorizedApiException(responseMessage: responseMessage),
        402 => SubscriptionExpiredApiException(
            responseMessage: responseMessage),
        403 => ForbiddenApiException(responseMessage: responseMessage),
        404 => NotFoundApiException(responseMessage: responseMessage),
        409 => ConflictApiException(responseMessage: responseMessage),
        422 => ValidationApiException(responseMessage: responseMessage),
        429 => TooManyRequestsApiException(responseMessage: responseMessage),
        _ => ApiException(
            statusCode,
            'api_error_generic',
            responseMessage: responseMessage,
          ),
      };

  /// GET /cows, returning the identifiers with stored sensor records.
  Future<dynamic> getCows() => get(
        '/cows',
        timeout: _cowListTimeout,
        retryOnTimeout: false,
        totalTimeout: _cowListTimeout,
      );

  /// Latest daily appetite class for each cow visible to the current user.
  Future<dynamic> getHomeAppetite({
    required void Function(int statusCode) onStatus,
  }) =>
      get(
        '/home/appetite',
        timeout: _cowListTimeout,
        retryOnTimeout: false,
        totalTimeout: _cowListTimeout,
        onStatus: onStatus,
      );

  /// Raw profile response; its model is defined once the API sample is available.
  Future<dynamic> getProfiles() => get(
        '/profiles',
        timeout: _cowListTimeout,
        retryOnTimeout: false,
        totalTimeout: _cowListTimeout,
      );

  /// Raw profile response; its model is defined once the API sample is available.
  Future<dynamic> getProfile(String cowId) => get('/profiles/${_id(cowId)}');

  /// Resolves an NFC UID to the cow profile visible to the current user.
  Future<dynamic> getProfileByNfc(String uid) =>
      get('/profiles/by-nfc/${_id(uid)}');

  /// GET /latest/{cow_id}, returning the most recent sensor record.
  Future<dynamic> getLatest(String cowId) => get('/latest/${_id(cowId)}');

  /// Raw response; its model is defined once the API sample is available.
  Future<dynamic> getDaily(String cowId) => get('/daily/${_id(cowId)}');

  /// Raw response; its model is defined once the API sample is available.
  Future<dynamic> getRealtime(String cowId) => get('/realtime/${_id(cowId)}');

  /// Raw response; its model is defined once the API sample is available.
  Future<dynamic> getDispatch(String cowId) => get('/dispatch/${_id(cowId)}');

  /// Prediction is optional until the backend exposes it.
  Future<dynamic> getPrediction(String cowId) async {
    try {
      _debug('prediction GET await start');
      final result = await get('/predict/${_id(cowId)}');
      _debug('prediction GET await complete');
      return result;
    } on ApiException catch (error) {
      if (error.statusCode == 501 || error.statusCode == 502) {
        throw PredictionUnavailableApiException(error.statusCode!);
      }
      rethrow;
    }
  }

  /// GET /alerts.
  Future<dynamic> getAlerts({String? status, int limit = 50}) =>
      get('/alerts', query: {'status': status, 'limit': limit});

  /// PATCH /alerts/{alert_id}/read.
  Future<dynamic> markAlertRead(String alertId) =>
      patch('/alerts/${_id(alertId)}/read');
}

String _tokenHint(String token) {
  if (token.length <= 8) return '[redacted-short-token]';
  return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
}

bool _isWrappedInQuotes(String token) =>
    token.length >= 2 &&
    ((token.startsWith('"') && token.endsWith('"')) ||
        (token.startsWith("'") && token.endsWith("'")));

String _jwtDiagnostics(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return 'jwt=false';

  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map<String, dynamic>) return 'jwtClaims=invalid';

    final role = payload['role'] ?? 'missing';
    final exp = payload['exp'];
    if (exp is! num) return 'jwtRole=$role jwtExp=missing';

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      exp.toInt() * 1000,
      isUtc: true,
    );
    final expired = !expiresAt.isAfter(DateTime.now().toUtc());
    return 'jwtRole=$role jwtExp=${expiresAt.toIso8601String()} expired=$expired';
  } on FormatException {
    return 'jwtClaims=invalid';
  } on ArgumentError {
    return 'jwtClaims=invalid-expiry';
  }
}

dynamic _decodeJson(String source) => jsonDecode(source);

class ApiException implements Exception {
  final int? statusCode;
  final String messageKey;
  final String? responseMessage;

  const ApiException(this.statusCode, this.messageKey, {this.responseMessage});

  @override
  String toString() => statusCode == null ? messageKey : 'API $statusCode';
}

class UnauthorizedApiException extends ApiException {
  const UnauthorizedApiException({super.responseMessage})
      : super(401, 'api_error_401');
}

class SubscriptionExpiredApiException extends ApiException {
  const SubscriptionExpiredApiException({super.responseMessage})
      : super(402, 'api_error_402');
}

class ForbiddenApiException extends ApiException {
  const ForbiddenApiException({super.responseMessage})
      : super(403, 'api_error_403');
}

class NotFoundApiException extends ApiException {
  const NotFoundApiException({super.responseMessage})
      : super(404, 'api_error_404');
}

class ConflictApiException extends ApiException {
  const ConflictApiException({super.responseMessage})
      : super(409, 'api_error_409');
}

class ValidationApiException extends ApiException {
  const ValidationApiException({super.responseMessage})
      : super(422, 'api_error_422');
}

class TooManyRequestsApiException extends ApiException {
  const TooManyRequestsApiException({super.responseMessage})
      : super(429, 'api_error_429');
}

class PredictionUnavailableApiException extends ApiException {
  const PredictionUnavailableApiException(int statusCode)
      : super(statusCode, 'prediction_unavailable');
}

class NetworkApiException extends ApiException {
  const NetworkApiException() : super(null, 'api_error_network');
}
