import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/session.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  bool _loading = true;
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorKey = null;
      });
    }

    try {
      final token = await Session.instance.readToken();
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        _navigate(AppRoutes.welcome);
        return;
      }

      await AuthService.instance.me();
      if (!mounted) return;
      _navigate(AppRoutes.home);
    } on TimeoutException {
      if (mounted) setState(() => _errorKey = 'api_error_network');
    } on UnauthorizedApiException {
      // ApiClient clears the session and routes to the welcome screen.
    } on SubscriptionExpiredApiException {
      // ApiClient routes to the subscription-expired screen.
    } on NetworkApiException {
      if (mounted) setState(() => _errorKey = 'api_error_network');
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'api_error_generic');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigate(String route) {
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr(_errorKey ?? 'api_error_generic'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textGrey),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _restoreSession,
                      child: Text(context.tr('try_again')),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
