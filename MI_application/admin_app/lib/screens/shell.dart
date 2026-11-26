import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/navigation.dart';
import '../core/strings.dart';
import '../native/action_queue.dart';
import '../native/canaux.dart';
import '../native/notification_settings.dart';
import '../services/session.dart';
import '../core/app_icons.dart';
import 'alerts/alerts_screen.dart';
import 'home/home_screen.dart';
import 'cows/cows_screen.dart';
import 'eleveurs/eleveurs_screen.dart';
import 'more/more_screen.dart';

abstract final class ShellTab {
  static const home = 0;
  static const cows = 1;
  static const alerts = 2;
  static const eleveurs = 3;
  static const more = 4;
  static const count = 5;
}

class Shell extends StatefulWidget {
  const Shell({super.key, this.onLogout});

  final Future<void> Function()? onLogout;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _i = ShellTab.home;
  final GlobalKey<CowsScreenState> _cowsKey = GlobalKey<CowsScreenState>();
  int _unreadAlerts = 0;
  String? _requestedAlertId;
  Timer? _nativeSessionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CanauxNatifs.actions.addListener(_consumeNativeAction);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshNotificationReadiness());
      if (CanauxNatifs.actions.pendingAction == null) {
        unawaited(requestNotificationPermissionAfterLogin(context));
      }
      _consumeNativeAction();
    });
    _nativeSessionTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_checkNativeSessionExpired()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshNotificationReadiness());
      unawaited(_checkNativeSessionExpired());
    }
  }

  Future<void> _refreshNotificationReadiness() async {
    try {
      final token = await Session.instance.readToken();
      pendingNotificationTarget.setReadiness(
        sessionRestored: true,
        loggedIn: token != null &&
            token.isNotEmpty &&
            Session.instance.currentUser.value != null,
        navigatorReady: navigatorKey.currentState?.mounted ?? false,
        shellReady: mounted,
      );
    } catch (error) {
      debugPrint('[MI_NOTIF] Unable to check restored session: $error');
    }
  }

  Future<void> _checkNativeSessionExpired() async {
    if (!mounted) return;
    try {
      if (!await CanauxNatifs.consommerSessionExpiree() || !mounted) return;
      debugPrint('[MI_NOTIF] Worker cleared an expired native session');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(AppStrings.notificationsSessionExpired),
          action: SnackBarAction(
            label: AppStrings.reconnect,
            onPressed: () => unawaited(widget.onLogout?.call()),
          ),
        ),
      );
    } on PlatformException catch (error) {
      debugPrint('[MI_NOTIF] Unable to read native session status: $error');
    } on MissingPluginException catch (error) {
      debugPrint('[MI_NOTIF] Native notification channel unavailable: $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nativeSessionTimer?.cancel();
    pendingNotificationTarget.setReadiness(
      sessionRestored: true,
      loggedIn: false,
      navigatorReady: false,
      shellReady: false,
    );
    CanauxNatifs.actions.removeListener(_consumeNativeAction);
    super.dispose();
  }

  void _consumeNativeAction() {
    if (!mounted) return;
    if (!pendingNotificationTarget.canNavigate) return;
    final action = CanauxNatifs.actions.take();
    if (action == null) return;
    debugPrint(
      '[MI_NOTIF] Admin navigation: loggedIn=true '
      'navigatorReady=${navigatorKey.currentState?.mounted ?? false} '
      'target=${action['alert_id'] ?? action['id']}',
    );
    const AlertsNotificationRouter().route(
      action,
      openAlert: (alertId) => setState(() {
        _i = ShellTab.alerts;
        _requestedAlertId = alertId;
      }),
      openAlerts: () => setState(() {
        _i = ShellTab.alerts;
        _requestedAlertId = null;
      }),
    );
  }

  void _initialAlertHandled(String alertId) {
    if (!mounted || _requestedAlertId != alertId) return;
    setState(() => _requestedAlertId = null);
  }

  void _updateUnreadAlerts(int count) {
    if (!mounted || count == _unreadAlerts) return;
    setState(() => _unreadAlerts = count);
  }

  Future<void> _openAddCow() async {
    setState(() => _i = ShellTab.cows);
    await _cowsKey.currentState?.openAddCow();
  }

  Future<void> _scanCow() async {
    setState(() => _i = ShellTab.cows);
    await _cowsKey.currentState?.scanCow();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _i, children: [
          HomeScreen(
            onOpenCows: (_) => setState(() => _i = ShellTab.cows),
            onOpenAlerts: () => setState(() => _i = ShellTab.alerts),
            onOpenEleveurs: () => setState(() => _i = ShellTab.eleveurs),
            onAddCow: _openAddCow,
            onScanCow: _scanCow,
          ),
          CowsScreen(key: _cowsKey),
          AlertsScreen(
            initialAlertId: _requestedAlertId,
            onInitialAlertHandled: _initialAlertHandled,
            isActive: _i == ShellTab.alerts,
            onUnreadCountChanged: _updateUnreadAlerts,
          ),
          const EleveursScreen(),
          MoreScreen(onLogout: widget.onLogout),
        ]),
        bottomNavigationBar: ShellNavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          unreadAlerts: _unreadAlerts,
        ),
      );
}

class ShellNavigationBar extends StatelessWidget {
  const ShellNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.unreadAlerts = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int unreadAlerts;

  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(AppIcons.home),
            label: AppStrings.navHome,
          ),
          const NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(AppIcons.cows),
            label: AppStrings.navCows,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadAlerts > 0,
              label: Text('$unreadAlerts'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadAlerts > 0,
              label: Text('$unreadAlerts'),
              child: const Icon(AppIcons.alert),
            ),
            label: AppStrings.navAlerts,
          ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(AppIcons.eleveur),
            label: AppStrings.navEleveurs,
          ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.settings_rounded),
            label: AppStrings.navMore,
          ),
        ],
      );
}
