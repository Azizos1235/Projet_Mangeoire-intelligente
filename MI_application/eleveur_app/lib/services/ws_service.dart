import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../core/config.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'session.dart';

class WsService with WidgetsBindingObserver {
  WsService._();

  static final WsService instance = WsService._();

  static const _supportedTypes = {'update', 'cows', 'cow', 'ai', 'error'};
  static const _maximumBackoffSeconds = 30;
  static const _stableConnectionDuration = Duration(seconds: 30);

  late final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast(
    onListen: _startListening,
    onCancel: _stopListening,
  );
  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;
  Timer? _stableConnectionTimer;
  int _connectionGeneration = 0;
  int _reconnectAttempt = 0;
  bool _hasListeners = false;
  bool _isForeground = true;
  bool _isConnecting = false;
  bool _isValidatingEndedSession = false;
  String? _endedSessionToken;

  Stream<Map<String, dynamic>> get events => _events.stream;

  void _startListening() {
    if (_hasListeners) return;
    _hasListeners = true;
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    if (_isForeground) unawaited(_connect());
  }

  void _stopListening() {
    if (!_hasListeners) return;
    _hasListeners = false;
    WidgetsBinding.instance.removeObserver(this);
    _stopConnection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      unawaited(_connect());
    } else {
      _stopConnection();
    }
  }

  Future<void> _connect() async {
    if (!_hasListeners ||
        !_isForeground ||
        _isConnecting ||
        _isValidatingEndedSession ||
        _socket != null ||
        _reconnectTimer != null) {
      return;
    }

    _isConnecting = true;
    final generation = ++_connectionGeneration;
    try {
      final token = await Session.instance.readToken();
      if (!_isCurrentConnection(generation)) return;
      if (token == null || token.isEmpty) return;
      if (_endedSessionToken == token) return;
      _endedSessionToken = null;

      final socketUri = Uri.parse('${AppConfig.wsBaseUrl}/ws/cows')
          .replace(queryParameters: {'token': token});
      final socket = await WebSocket.connect(socketUri.toString());
      if (!_isCurrentConnection(generation)) {
        await socket.close();
        return;
      }

      _socket = socket;
      _stableConnectionTimer?.cancel();
      _stableConnectionTimer = Timer(_stableConnectionDuration, () {
        _reconnectAttempt = 0;
      });
      _socketSubscription = socket.listen(
        _onSocketMessage,
        onError: (Object error, StackTrace stackTrace) {
          scheduleMicrotask(() => _onSocketDone(socket));
        },
        onDone: () => _onSocketDone(socket),
        cancelOnError: true,
      );
    } catch (_) {
      if (_isCurrentConnection(generation)) _scheduleReconnect();
    } finally {
      if (generation == _connectionGeneration) _isConnecting = false;
    }
  }

  bool _isCurrentConnection(int generation) =>
      generation == _connectionGeneration && _hasListeners && _isForeground;

  void _onSocketMessage(dynamic message) {
    try {
      final String text;
      if (message is String) {
        text = message;
      } else if (message is List<int>) {
        text = utf8.decode(message);
      } else {
        return;
      }

      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic> ||
          !_supportedTypes.contains(decoded['type'])) {
        return;
      }
      _events.add(Map<String, dynamic>.unmodifiable(decoded));
    } on FormatException {
      // Ignore malformed JSON and invalid UTF-8 payloads.
    }
  }

  void _onSocketDone(WebSocket socket) {
    if (!identical(_socket, socket)) return;
    _socket = null;
    _socketSubscription = null;
    _stableConnectionTimer?.cancel();
    _stableConnectionTimer = null;

    if (socket.closeCode == 1008) {
      _isValidatingEndedSession = true;
      unawaited(_handleEndedSession());
      return;
    }
    _scheduleReconnect();
  }

  Future<void> _handleEndedSession() async {
    try {
      _endedSessionToken = await Session.instance.readToken();
      await AuthService.instance.me();
    } on UnauthorizedApiException {
      // ApiClient clears the session and routes to the welcome screen.
    } on SubscriptionExpiredApiException {
      // ApiClient routes to the subscription-expired screen.
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'ws_service',
          context:
              ErrorDescription('while validating an ended WebSocket session'),
        ),
      );
    } finally {
      _isValidatingEndedSession = false;
    }
  }

  void _scheduleReconnect() {
    if (!_hasListeners ||
        !_isForeground ||
        _reconnectTimer != null ||
        _socket != null) {
      return;
    }
    final delaySeconds =
        (1 << _reconnectAttempt).clamp(1, _maximumBackoffSeconds).toInt();
    if (_reconnectAttempt < 5) _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      unawaited(_connect());
    });
  }

  void _stopConnection() {
    _connectionGeneration++;
    _isConnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stableConnectionTimer?.cancel();
    _stableConnectionTimer = null;

    final subscription = _socketSubscription;
    _socketSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());

    final socket = _socket;
    _socket = null;
    if (socket != null) unawaited(socket.close());
  }
}
