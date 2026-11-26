import 'package:smart_elevage_admin/native/action_queue.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNativeActionChannel implements NativeActionChannel {
  Map<String, dynamic>? initial;
  ValueChanged<Map<String, dynamic>>? listener;

  @override
  Future<Map<String, dynamic>?> actionInitiale() async => initial;

  @override
  Future<void> startListening(
    ValueChanged<Map<String, dynamic>> onAction,
  ) async {
    listener = onAction;
  }
}

void main() {
  test('cold-start alert remains pending until login and shell are ready',
      () async {
    final channel = _FakeNativeActionChannel()
      ..initial = {
        'action': 'voir',
        'type': 'task_completed',
        'id': 'alert-1',
        'alert_id': 'alert-1',
      };
    final target = PendingNotificationTarget(channel);
    await target.initialize();
    expect(target.take(), isNull);
    expect(target.pendingAction?['alert_id'], 'alert-1');
    target.setReadiness(
      sessionRestored: true,
      loggedIn: true,
      navigatorReady: true,
      shellReady: true,
    );
    String? openedAlertId;
    var openedAlerts = false;

    final decision = const AlertsNotificationRouter().route(
      target.take()!,
      openAlert: (id) => openedAlertId = id,
      openAlerts: () => openedAlerts = true,
    );

    expect(openedAlertId, 'alert-1');
    expect(openedAlerts, isFalse);
    expect(decision, AlertNotificationDecision.openedTargetAlert);
  });

  test('warm channel action is retained until the shell is ready', () async {
    final channel = _FakeNativeActionChannel();
    final target = PendingNotificationTarget(channel);
    await target.initialize();
    channel.listener!({
      'action': 'voir',
      'type': 'appetite_low',
      'alert_id': 'alert-2',
    });
    expect(target.take(), isNull);
    target.setReadiness(
      sessionRestored: true,
      loggedIn: true,
      navigatorReady: true,
      shellReady: true,
    );
    String? openedAlertId;

    const AlertsNotificationRouter().route(
      target.take()!,
      openAlert: (id) => openedAlertId = id,
      openAlerts: () {},
    );

    expect(openedAlertId, 'alert-2');
  });
}
