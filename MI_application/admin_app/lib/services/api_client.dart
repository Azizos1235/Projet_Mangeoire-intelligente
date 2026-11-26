import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/strings.dart';
import 'session.dart';

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.error,
    this.detail,
  });

  final int? statusCode;
  final String message;
  final String? error;
  final String? detail;

  bool get isNetworkError => statusCode == null;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

class ApiClient {
  ApiClient({
    http.Client? client,
    Future<String?> Function()? tokenProvider,
    Duration timeout = const Duration(seconds: 60),
    Duration longWaitThreshold = const Duration(seconds: 5),
  })  : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider ?? Session.instance.readToken,
        _timeout = timeout,
        _longWaitThreshold = longWaitThreshold;

  static final ApiClient instance = ApiClient();

  Future<void> Function(ApiException error)? onAuthError;

  final http.Client _client;
  final Future<String?> Function() _tokenProvider;
  final Duration _timeout;
  final Duration _longWaitThreshold;
  final Set<Object> _longWaitRequests = {};
  final ValueNotifier<bool> _serverIsWakingUp = ValueNotifier(false);

  ValueListenable<bool> get serverIsWakingUp => _serverIsWakingUp;

  Future<T> get<T>(
    String path, {
    bool authenticated = true,
    bool handleAuthErrors = true,
  }) =>
      _request<T>(
        'GET',
        path,
        authenticated: authenticated,
        handleAuthErrors: handleAuthErrors,
      );

  Future<T> post<T>(
    String path, {
    Object? body = const <String, dynamic>{},
    bool authenticated = true,
    bool handleAuthErrors = true,
    int? expectedStatusCode,
  }) =>
      _request<T>(
        'POST',
        path,
        body: body,
        authenticated: authenticated,
        handleAuthErrors: handleAuthErrors,
        expectedStatusCode: expectedStatusCode,
      );

  Future<T> put<T>(
    String path, {
    Object? body = const <String, dynamic>{},
    bool authenticated = true,
    bool handleAuthErrors = true,
  }) =>
      _request<T>(
        'PUT',
        path,
        body: body,
        authenticated: authenticated,
        handleAuthErrors: handleAuthErrors,
      );

  Future<T> patch<T>(
    String path, {
    Object? body = const <String, dynamic>{},
    bool authenticated = true,
    bool handleAuthErrors = true,
  }) =>
      _request<T>(
        'PATCH',
        path,
        body: body,
        authenticated: authenticated,
        handleAuthErrors: handleAuthErrors,
      );

  Future<T> delete<T>(
    String path, {
    Object? body,
    bool authenticated = true,
    bool handleAuthErrors = true,
  }) =>
      _request<T>(
        'DELETE',
        path,
        body: body,
        authenticated: authenticated,
        handleAuthErrors: handleAuthErrors,
      );

  Future<T> _request<T>(
    String method,
    String path, {
    Object? body,
    required bool authenticated,
    required bool handleAuthErrors,
    int? expectedStatusCode,
  }) async {
    final headers = await _headers(authenticated: authenticated);
    final uri = _buildUri(path);

    try {
      return await _sendWithRetry<T>(() async {
        final response = switch (method) {
          'GET' => await _client.get(uri, headers: headers),
          'POST' => await _client.post(
              uri,
              headers: headers,
              body: jsonEncode(body),
            ),
          'PUT' => await _client.put(
              uri,
              headers: headers,
              body: jsonEncode(body),
            ),
          'PATCH' => await _client.patch(
              uri,
              headers: headers,
              body: jsonEncode(body),
            ),
          'DELETE' => await _client.delete(
              uri,
              headers: headers,
              body: body == null ? null : jsonEncode(body),
            ),
          _ => throw ArgumentError.value(
              method,
              'method',
              'Unsupported method',
            ),
        };
        if (expectedStatusCode != null &&
            response.statusCode >= 200 &&
            response.statusCode < 300 &&
            response.statusCode != expectedStatusCode) {
          throw ApiException(
            statusCode: response.statusCode,
            message: AppStrings.invalidResponse,
          );
        }
        return _decodeResponse<T>(response);
      });
    } on ApiException catch (error) {
      if (authenticated && handleAuthErrors && _requiresAuthRouting(error)) {
        await onAuthError?.call(error);
      }
      rethrow;
    }
  }

  bool _requiresAuthRouting(ApiException error) =>
      error.statusCode == 401 ||
      error.statusCode == 402 ||
      (error.statusCode == 403 &&
          error.detail?.trim().toLowerCase() == 'password change required');

  Future<Map<String, String>> _headers({required bool authenticated}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (authenticated) {
      final token = await _tokenProvider();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Uri _buildUri(String path) {
    final baseUri = Uri.parse(API_BASE_URL);
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    return baseUri.resolve(relativePath);
  }

  Future<T> _sendWithRetry<T>(
    Future<T> Function() send,
  ) async {
    final requestId = Object();
    final wakingTimer = Timer(_longWaitThreshold, () {
      _longWaitRequests.add(requestId);
      _serverIsWakingUp.value = _longWaitRequests.isNotEmpty;
    });

    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          return await send().timeout(_timeout);
        } on TimeoutException {
          if (attempt == 1) {
            throw const ApiException(
              statusCode: null,
              message: AppStrings.networkError,
            );
          }
        }
      }
      throw const ApiException(
        statusCode: null,
        message: AppStrings.networkError,
      );
    } on ApiException {
      rethrow;
    } on Exception {
      throw const ApiException(
        statusCode: null,
        message: AppStrings.networkError,
      );
    } finally {
      wakingTimer.cancel();
      _longWaitRequests.remove(requestId);
      _serverIsWakingUp.value = _longWaitRequests.isNotEmpty;
    }
  }

  T _decodeResponse<T>(http.Response response) {
    if (response.statusCode == 204 && response.body.isEmpty && null is T) {
      return null as T;
    }

    Object? decodedBody;
    try {
      decodedBody = jsonDecode(response.body);
    } on FormatException {
      decodedBody = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = decodedBody is Map
          ? Map<String, dynamic>.from(decodedBody)
          : const <String, dynamic>{};
      final error = _nonEmptyString(errorBody['error']);
      final detail = _nonEmptyString(errorBody['detail']);
      throw ApiException(
        statusCode: response.statusCode,
        message: _mapErrorMessage(error, detail),
        error: error,
        detail: detail,
      );
    }

    if ((decodedBody is Map || decodedBody is List) && decodedBody is T) {
      return decodedBody;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: AppStrings.invalidResponse,
    );
  }

  Future<dynamic> markAlertRead(String alertId) =>
      patch('/alerts/${Uri.encodeComponent(alertId)}/read');

  String? _nonEmptyString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  String _mapErrorMessage(String? error, String? detail) {
    final raw = '${error ?? ''} ${detail ?? ''}'.trim().toLowerCase();
    if (raw.contains('invalid objectid') ||
        raw.contains('invalid id') ||
        raw.contains('object id')) {
      return 'Identifiant invalide.';
    }
    if (raw.contains('alert') && raw.contains('not found')) {
      return 'Alerte introuvable.';
    }
    if (raw.contains('task') && raw.contains('not found')) {
      return 'Tâche introuvable.';
    }
    if (raw.contains('cow') && raw.contains('not found')) {
      return 'Bovin introuvable.';
    }
    if (raw.contains('eleveur') && raw.contains('not found')) {
      return 'Éleveur introuvable.';
    }
    if (raw.contains('forbidden') || raw.contains('permission')) {
      return 'Vous n’avez pas l’autorisation de réaliser cette action.';
    }
    if (raw.contains('unauthorized') || raw.contains('not authenticated')) {
      return 'Votre session a expiré. Veuillez vous reconnecter.';
    }
    if (raw.contains('password change required')) {
      return 'Vous devez changer votre mot de passe.';
    }
    if (error == 'validation_error' ||
        raw.contains('validation') ||
        raw.contains('invalid')) {
      return 'Les informations saisies sont invalides.';
    }
    if (detail != null && detail.isNotEmpty) return detail;
    if (error != null && error.isNotEmpty) return error;
    return AppStrings.frenchUnknownError;
  }

  void dispose() {
    _client.close();
    _serverIsWakingUp.dispose();
  }
}
