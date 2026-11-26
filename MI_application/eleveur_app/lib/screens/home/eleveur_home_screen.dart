import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kDebugMode, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/l10n.dart';
import '../../core/app_routes.dart';
import '../../core/navigation.dart';
import '../../core/config.dart';
import '../../models/farm_task.dart';
import '../../native/action_queue.dart';
import '../../native/canaux.dart';
import '../../native/notification_settings.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/nfc_service.dart';
import '../../services/session.dart';
import '../../core/theme.dart';
import '../cows/cows_screen.dart';
import 'home_tab.dart';
import '../tasks/tasks_screen.dart';

/// Main application shell with dashboard, livestock, tasks, and NFC tabs.
class EleveurHomeScreen extends StatefulWidget {
  const EleveurHomeScreen({super.key});

  @override
  State<EleveurHomeScreen> createState() => _EleveurHomeScreenState();
}

class _EleveurHomeScreenState extends State<EleveurHomeScreen>
    with WidgetsBindingObserver {
  int _tab = 0;
  final GlobalKey<TasksScreenState> _tasksKey = GlobalKey<TasksScreenState>();
  List<FarmTask> _pendingTasks = const [];
  bool _tasksLoading = true;
  Object? _tasksError;
  bool _homeTaskCoveredByRoute = false;
  bool _openedFromNotification = false;
  bool _configuringNativeSession = false;
  bool _handlingNotificationAction = false;
  Map<String, dynamic>? _deferredNotificationAction;
  String? _nativeSessionUserId;
  String? _nativeSessionToken;
  String? _nativeSessionLanguage;
  String? _userName;
  LangController? _languageController;
  Timer? _nativeSessionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _userName = _currentUserName();
    Session.instance.currentUser.addListener(_onCurrentUserChanged);
    Session.instance.tokenRevision.addListener(_onNativeTokenChanged);
    CanauxNatifs.actions.addListener(_consumeNativeAction);
    if (_userName == null) unawaited(_loadCurrentUser());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshNotificationReadiness());
      unawaited(_configureNativeNotifications());
      unawaited(_checkNativeSessionExpired());
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
      unawaited(_configureNativeNotifications());
      unawaited(_checkNativeSessionExpired());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = LangScope.of(context);
    if (identical(controller, _languageController)) return;
    _languageController?.removeListener(_onLanguageChanged);
    _languageController = controller;
    controller.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) unawaited(_configureNativeNotifications());
  }

  Future<void> _configureNativeNotifications() async {
    if (defaultTargetPlatform != TargetPlatform.android ||
        _configuringNativeSession) {
      return;
    }
    _configuringNativeSession = true;
    final hadPendingAction = CanauxNatifs.actions.pendingAction != null;
    try {
      final token = await Session.instance.readToken();
      final user = Session.instance.currentUser.value;
      if (token == null || token.isEmpty || user == null) return;
      if (!mounted) return;
      final language = LangScope.of(context).lang;
      if (_nativeSessionUserId == user.id &&
          _nativeSessionToken == token &&
          _nativeSessionLanguage == language) {
        return;
      }
      final isNewSession = _nativeSessionUserId != user.id;
      await CanauxNatifs.setSession(
        token: token,
        baseUrl: AppConfig.apiBaseUrl,
        role: user.role,
        userId: user.id,
        language: language,
      );
      if (await CanauxNatifs.notificationsActivees()) {
        await CanauxNatifs.verifierMaintenant();
        await CanauxNatifs.planifier();
      }
      _nativeSessionUserId = user.id;
      _nativeSessionToken = token;
      _nativeSessionLanguage = language;
      if (isNewSession &&
          !hadPendingAction &&
          !_openedFromNotification &&
          mounted) {
        await requestNotificationPermissionAfterLogin(context);
      }
    } on TimeoutException catch (error) {
      debugPrint('Unable to restore the native notification session: $error');
    } on PlatformException catch (error) {
      debugPrint('Unable to configure native notifications: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Native notification channel is unavailable: $error');
    } finally {
      _configuringNativeSession = false;
      unawaited(_refreshNotificationReadiness());
      if (mounted &&
          Session.instance.currentUser.value != null &&
          _nativeSessionLanguage != LangScope.of(context).lang) {
        unawaited(_configureNativeNotifications());
      }
    }
  }

  String? _currentUserName() {
    final name = Session.instance.currentUser.value?.displayName?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  void _onCurrentUserChanged() {
    final name = _currentUserName();
    if (!mounted) return;
    if (name != _userName) setState(() => _userName = name);
    if (Session.instance.currentUser.value == null) {
      _nativeSessionUserId = null;
      _nativeSessionToken = null;
      _nativeSessionLanguage = null;
      unawaited(_refreshNotificationReadiness());
    } else {
      unawaited(_configureNativeNotifications());
      unawaited(_refreshNotificationReadiness());
    }
  }

  void _onNativeTokenChanged() {
    debugPrint(
      '[MI_NOTIF] Session token updated; synchronizing native session',
    );
    unawaited(_configureNativeNotifications());
  }

  Future<void> _refreshNotificationReadiness() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final token = await Session.instance.readToken();
      final user = Session.instance.currentUser.value;
      CanauxNatifs.actions.setReadiness(
        sessionRestored: true,
        loggedIn: token != null && token.isNotEmpty && user != null,
        navigatorReady: navigatorKey.currentState?.mounted ?? false,
        shellReady: mounted,
      );
    } on TimeoutException catch (error) {
      debugPrint('[MI_NOTIF] Unable to check restored session: $error');
    } on PlatformException catch (error) {
      debugPrint('[MI_NOTIF] Unable to check native session: $error');
    }
  }

  Future<void> _checkNativeSessionExpired() async {
    if (defaultTargetPlatform != TargetPlatform.android || !mounted) return;
    try {
      if (!await CanauxNatifs.consommerSessionExpiree() || !mounted) return;
      debugPrint('[MI_NOTIF] Worker cleared an expired native session');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('notifications_session_expired')),
          action: SnackBarAction(
            label: context.tr('reconnect'),
            onPressed: () {
              unawaited(Session.instance.deleteToken());
              navigatorKey.currentState?.pushNamedAndRemoveUntil(
                AppRoutes.welcome,
                (_) => false,
              );
            },
          ),
        ),
      );
    } on PlatformException catch (error) {
      debugPrint('[MI_NOTIF] Unable to read native session status: $error');
    } on MissingPluginException catch (error) {
      debugPrint('[MI_NOTIF] Native notification channel unavailable: $error');
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthService.instance.me();
      if (!mounted || !identical(Session.instance.currentUser.value, user)) {
        return;
      }
      final name = user.displayName?.trim();
      if (name != _userName) setState(() => _userName = name);
    } catch (error) {
      if (kDebugMode) debugPrint('[DBG] home user name unavailable: $error');
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
    Session.instance.currentUser.removeListener(_onCurrentUserChanged);
    Session.instance.tokenRevision.removeListener(_onNativeTokenChanged);
    CanauxNatifs.actions.removeListener(_consumeNativeAction);
    _languageController?.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == 3) {
      _scanCow();
      return;
    }
    setState(() => _tab = index);
  }

  void _updatePendingTasks(List<FarmTask> tasks) {
    if (!mounted) return;
    _tasksError = null;
    setState(() => _pendingTasks = List.unmodifiable(tasks));
    final deferred = _deferredNotificationAction;
    if (deferred != null) {
      _deferredNotificationAction = null;
      unawaited(_handleNativeAction(deferred, refreshTasks: false));
    } else {
      _consumeNativeAction();
    }
    if (defaultTargetPlatform != TargetPlatform.android ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    final Iterable<FarmTask> visibleTasks = _tab == 2
        ? tasks
        : _tab == 0
            ? tasks.take(3)
            : const <FarmTask>[];
    unawaited(_markTasksAsDisplayed(visibleTasks));
  }

  Future<void> _markTasksAsDisplayed(Iterable<FarmTask> tasks) async {
    final ids = tasks.map((task) => task.id).toList(growable: false);
    if (ids.isEmpty) return;
    try {
      await CanauxNatifs.marquerCommeNotifie(ids);
    } on PlatformException catch (error) {
      debugPrint('Unable to mark visible tasks as notified: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Native notification channel is unavailable: $error');
    }
  }

  void _consumeNativeAction() {
    if (!mounted ||
        _handlingNotificationAction ||
        _deferredNotificationAction != null) {
      return;
    }
    if (!pendingNotificationTarget.canNavigate) return;
    final action = CanauxNatifs.actions.take();
    if (action == null) return;
    _openedFromNotification = true;
    unawaited(_handleNativeAction(action));
  }

  Future<void> _handleNativeAction(
    Map<String, dynamic> action, {
    bool refreshTasks = true,
  }) async {
    if (_handlingNotificationAction) return;
    _handlingNotificationAction = true;
    try {
      if (action['task_id'] is String && refreshTasks) {
        _selectTab(2);
        final refreshed = await _refreshPendingTasks();
        if (!mounted) return;
        if (!refreshed) {
          debugPrint('[MI_NOTIF] Keeping task action until refresh succeeds');
          _deferredNotificationAction = action;
          return;
        }
      }
      if (!mounted) return;
      final decision = await const TaskNotificationRouter().route(
        action,
        pendingTasks: _pendingTasks,
        openTasks: () => _selectTab(2),
        openWeightTask: (task) async {
          final tasksScreen = _tasksKey.currentState;
          if (tasksScreen == null) {
            _selectTab(2);
            return;
          }
          await _openWeightTaskFromHome(task, tasksScreen);
        },
      );
      if (decision == TaskNotificationDecision.taskNotFound && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('task_already_done'))),
        );
      }
    } finally {
      _handlingNotificationAction = false;
      if (mounted && _deferredNotificationAction == null) {
        _consumeNativeAction();
      }
    }
  }

  void _updateTasksLoading(bool loading) {
    if (!mounted || loading == _tasksLoading) return;
    setState(() => _tasksLoading = loading);
  }

  void _updateTasksError(Object? error) {
    if (!mounted) return;
    setState(() => _tasksError = error);
  }

  Future<bool> _refreshPendingTasks() async {
    final tasksScreen = _tasksKey.currentState;
    if (tasksScreen == null) return false;
    return tasksScreen.refreshFromHome();
  }

  void _handleHomeTaskTap(FarmTask task) {
    final opensWeightEditor = task.taskType == 'check_weight' &&
        task.cowId?.trim().isNotEmpty == true;
    final tasksScreen = _tasksKey.currentState;
    if (!opensWeightEditor || tasksScreen == null) {
      _selectTab(2);
      return;
    }
    unawaited(_openWeightTaskFromHome(task, tasksScreen));
  }

  Future<void> _openWeightTaskFromHome(
    FarmTask task,
    TasksScreenState tasksScreen,
  ) async {
    setState(() => _homeTaskCoveredByRoute = true);
    try {
      await tasksScreen.openWeightTaskFromHome(task);
    } finally {
      if (mounted) setState(() => _homeTaskCoveredByRoute = false);
    }
  }

  Future<void> _scanCow() async {
    final scan = await Navigator.pushNamed<NfcScanResult?>(
      context,
      AppRoutes.nfcScanner,
      arguments: NfcScanMode.view,
    );
    if (!mounted || scan == null) return;

    try {
      final result = await NfcService.instance.lookupTag(
        scan.uid,
        mode: scan.mode,
      );
      if (!mounted) return;
      switch (result.status) {
        case NfcLookupStatus.found:
          await Navigator.pushNamed<void>(
            context,
            AppRoutes.cowDetail,
            arguments: result.cow!,
          );
        case NfcLookupStatus.notFound:
          await _offerAddForUnknownTag(result.uid);
        case NfcLookupStatus.registeredElsewhere:
          await _showNoCowFound();
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(error.messageKey))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('api_error_generic'))),
      );
    }
  }

  Future<void> _offerAddForUnknownTag(String uid) async {
    final add = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(dialogContext.tr('nfc_tag_not_found')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('add_cow')),
          ),
        ],
      ),
    );
    if (add == true && mounted) {
      await Navigator.pushNamed<void>(
        context,
        AppRoutes.addCow,
        arguments: uid,
      );
    }
  }

  Future<void> _showNoCowFound() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(dialogContext.tr('nfc_tag_not_found')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('got_it')),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('logout')),
        content: Text(dialogContext.tr('logout_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('logout')),
          ),
        ],
      ),
    );
    if (shouldLogout != true) return;
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.welcome,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingTaskCount = _pendingTasks.length;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeTab(
            onGoTab: _selectTab,
            onAddCow: () =>
                Navigator.pushNamed<void>(context, AppRoutes.addCow),
            onLogout: _logout,
            name: _userName,
            pendingTasks: _pendingTasks,
            tasksLoading: _tasksLoading,
            tasksError: _tasksError,
            onRefreshTasks: _refreshPendingTasks,
            onTaskTap: _handleHomeTaskTap,
            onViewAllTasks: () => _selectTab(2),
            isActive: _tab == 0 && !_homeTaskCoveredByRoute,
          ),
          CowsTab(onScanCow: _scanCow),
          TasksScreen(
            key: _tasksKey,
            isActive: _tab == 2,
            onTasksChanged: _updatePendingTasks,
            onLoadingChanged: _updateTasksLoading,
            onErrorChanged: _updateTasksError,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primarySoft,
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon:
                const Icon(Icons.home_rounded, color: AppTheme.primary),
            label: context.tr('nav_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            selectedIcon:
                const Icon(Icons.list_alt_rounded, color: AppTheme.primary),
            label: context.tr('nav_cows'),
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pendingTaskCount > 0,
              label: Text('$pendingTaskCount'),
              child: const Icon(Icons.task_alt_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: pendingTaskCount > 0,
              label: Text('$pendingTaskCount'),
              child: const Icon(
                Icons.task_alt_rounded,
                color: AppTheme.primary,
              ),
            ),
            label: context.tr('nav_tasks'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.nfc_rounded),
            selectedIcon:
                const Icon(Icons.nfc_rounded, color: AppTheme.primary),
            label: context.tr('nav_nfc'),
          ),
        ],
      ),
    );
  }
}
