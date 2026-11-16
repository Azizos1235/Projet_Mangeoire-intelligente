import 'package:flutter/material.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/subscription_expired_screen.dart';
import 'screens/shell.dart';
import 'services/api_client.dart';
import 'services/session.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() => runApp(const AdminApp());

class MyApp extends AdminApp {
  const MyApp({super.key}) : super();
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late Future<Widget> _screenFuture;

  @override
  void initState() {
    super.initState();
    ApiClient.instance.onAuthError = _handleApiError;
    _screenFuture = _resolveScreen();
  }

  Widget _loginScreen({String? message}) => LoginScreen(
        key: ValueKey(message),
        initialMessage: message,
        onAuthenticated: _refreshScreen,
      );

  Widget _changePasswordScreen() => ChangePasswordScreen(
        onLogout: _logout,
        onPasswordChanged: _routeForUser,
      );

  Widget _subscriptionExpiredScreen() => SubscriptionExpiredScreen(
        onLogout: _logout,
        onAuthError: _handleApiError,
        onUserRefreshed: _routeForUser,
      );

  Future<Widget> _resolveScreen() async {
    final token = await Session.instance.readToken();
    if (token == null || token.isEmpty) return _loginScreen();

    try {
      final user = await ApiClient.instance.get<Map<String, dynamic>>(
        '/auth/me',
        handleAuthErrors: false,
      );
      Session.instance.setCurrentUser(user);
      return _screenForUser(user);
    } on ApiException catch (error) {
      return _screenForStartupError(error);
    }
  }

  Future<Widget> _screenForUser(Map<String, dynamic> user) async {
    if (user['role'] != 'admin') {
      await Session.instance.clear();
      return _loginScreen(message: AppStrings.invalidEmailOrPassword);
    }

    if (user['must_change_password'] == true) {
      return _changePasswordScreen();
    }

    final subscription = await ApiClient.instance.get<Map<String, dynamic>>(
      '/subscription/me',
      handleAuthErrors: false,
    );
    if (subscription['status'] == 'expired') {
      return _subscriptionExpiredScreen();
    }

    return Shell(onLogout: _logout);
  }

  Future<Widget> _screenForStartupError(ApiException error) async {
    if (error.statusCode == 401) {
      await Session.instance.clear();
      return _loginScreen(message: AppStrings.sessionExpired);
    }
    if (error.statusCode == 402) return _subscriptionExpiredScreen();
    if (_isPasswordChangeRequired(error)) return _changePasswordScreen();
    return _StartupErrorScreen(
      message: error.message,
      onRetry: _refreshScreen,
    );
  }

  bool _isPasswordChangeRequired(ApiException error) =>
      error.statusCode == 403 &&
      error.detail?.trim().toLowerCase() == 'password change required';

  Future<void> _handleApiError(ApiException error) async {
    if (error.statusCode == 401) {
      await Session.instance.clear();
      _redirectToRoot();
      _showScreen(_loginScreen(message: AppStrings.sessionExpired));
      return;
    }
    if (error.statusCode == 402 &&
        Session.instance.currentUser.value?['role'] == 'admin') {
      _redirectToRoot();
      _showScreen(_subscriptionExpiredScreen());
      return;
    }
    if (_isPasswordChangeRequired(error)) {
      _redirectToRoot();
      _showScreen(_changePasswordScreen());
    }
  }

  void _redirectToRoot() {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  Future<void> _routeForUser(Map<String, dynamic> user) async {
    try {
      final screen = await _screenForUser(user);
      if (!mounted) return;
      _showScreen(screen);
    } on ApiException catch (error) {
      await _handleApiError(error);
      if (error.statusCode != 401 &&
          error.statusCode != 402 &&
          !_isPasswordChangeRequired(error)) {
        _showScreen(
          _StartupErrorScreen(
            message: error.message,
            onRetry: _refreshScreen,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await Session.instance.clear();
    _refreshScreen();
  }

  void _showScreen(Widget screen) {
    if (!mounted) return;
    final screenFuture = Future<Widget>.value(screen);
    setState(() {
      _screenFuture = screenFuture;
    });
  }

  Future<void> _refreshScreen() async {
    late final Widget screen;
    try {
      screen = await _resolveScreen();
    } catch (error, stackTrace) {
      if (!mounted) return;
      final failedScreenFuture = Future<Widget>.error(error, stackTrace);
      setState(() {
        _screenFuture = failedScreenFuture;
      });
      return;
    }
    if (!mounted) return;
    _showScreen(screen);
  }

  @override
  void dispose() {
    ApiClient.instance.onAuthError = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Smart Élevage',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: FutureBuilder<Widget>(
          future: _screenFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _StartupErrorScreen(
                message: AppStrings.startupError,
                onRetry: _refreshScreen,
              );
            }
            return snapshot.data ??
                _StartupErrorScreen(
                  message: AppStrings.startupError,
                  onRetry: _refreshScreen,
                );
          },
        ),
      );
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text(AppStrings.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
