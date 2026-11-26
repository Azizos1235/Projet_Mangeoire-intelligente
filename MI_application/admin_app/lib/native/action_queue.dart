import 'package:flutter/foundation.dart';

abstract interface class NativeActionChannel {
  Future<void> startListening(ValueChanged<Map<String, dynamic>> onAction);
  Future<Map<String, dynamic>?> actionInitiale();
}

class PendingNotificationTarget extends ChangeNotifier {
  PendingNotificationTarget(this._channel);

  final NativeActionChannel _channel;
  final List<Map<String, dynamic>> _pendingActions = [];
  Future<void>? _initialization;
  bool _sessionRestored = false;
  bool _loggedIn = false;
  bool _navigatorReady = false;
  bool _shellReady = false;

  Map<String, dynamic>? get pendingAction =>
      _pendingActions.isEmpty ? null : _pendingActions.first;

  bool get canNavigate =>
      _sessionRestored && _loggedIn && _navigatorReady && _shellReady;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    debugPrint('[MI_NOTIF] Installing the single notification action handler');
    await _channel.startListening(enqueue);
    final initialAction = await _channel.actionInitiale();
    debugPrint(
      '[MI_NOTIF] actionInitiale returned '
      '${initialAction == null ? "no target" : _describe(initialAction)}',
    );
    if (initialAction != null) enqueue(initialAction);
  }

  void setReadiness({
    required bool sessionRestored,
    required bool loggedIn,
    required bool navigatorReady,
    required bool shellReady,
  }) {
    _sessionRestored = sessionRestored;
    _loggedIn = loggedIn;
    _navigatorReady = navigatorReady;
    _shellReady = shellReady;
    debugPrint(
      '[MI_NOTIF] Navigation readiness: restored=$sessionRestored '
      'loggedIn=$loggedIn navigator=$navigatorReady shell=$shellReady '
      'pending=${_pendingActions.length}',
    );
    notifyListeners();
  }

  void enqueue(Map<String, dynamic> action) {
    debugPrint('[MI_NOTIF] Received action ${_describe(action)}');
    _pendingActions.add(Map<String, dynamic>.unmodifiable(action));
    notifyListeners();
  }

  Map<String, dynamic>? take() {
    if (!canNavigate) {
      debugPrint(
        '[MI_NOTIF] Keeping pending target: navigation is not ready '
        '(restored=$_sessionRestored loggedIn=$_loggedIn '
        'navigator=$_navigatorReady shell=$_shellReady)',
      );
      return null;
    }
    if (_pendingActions.isEmpty) return null;
    final action = _pendingActions.removeAt(0);
    debugPrint('[MI_NOTIF] Routing action ${_describe(action)}');
    notifyListeners();
    return action;
  }

  String _describe(Map<String, dynamic> action) =>
      'action=${action['action']} type=${action['type']} '
      'id=${action['id']} task_id=${action['task_id']} '
      'alert_id=${action['alert_id']}';
}

enum AlertNotificationDecision {
  ignored,
  openedAlerts,
  openedTargetAlert,
}

class AlertsNotificationRouter {
  const AlertsNotificationRouter();

  AlertNotificationDecision route(
    Map<String, dynamic> action, {
    required ValueChanged<String> openAlert,
    required VoidCallback openAlerts,
  }) {
    if (action['action'] != 'voir') {
      debugPrint('[MI_NOTIF] Ignored unsupported action ${action['action']}');
      return AlertNotificationDecision.ignored;
    }
    if (action['scope'] == 'alerts') {
      debugPrint('[MI_NOTIF] Routing summary to the Alerts tab');
      openAlerts();
      return AlertNotificationDecision.openedAlerts;
    }
    final alertId = action['alert_id'] ?? action['id'];
    debugPrint(
      '[MI_NOTIF] Alert target found=${alertId is String && alertId.isNotEmpty} '
      'alertId=$alertId',
    );
    if (alertId is String && alertId.isNotEmpty) {
      openAlert(alertId);
      return AlertNotificationDecision.openedTargetAlert;
    }
    openAlerts();
    return AlertNotificationDecision.openedAlerts;
  }
}
