import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';

class SubscriptionExpiredScreen extends StatefulWidget {
  const SubscriptionExpiredScreen({super.key});

  @override
  State<SubscriptionExpiredScreen> createState() =>
      _SubscriptionExpiredScreenState();
}

class _SubscriptionExpiredScreenState
    extends State<SubscriptionExpiredScreen> {
  bool _loading = false;
  String? _errorKey;

  Future<void> _retry() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _errorKey = null;
    });

    try {
      await AuthService.instance.me();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (_) => false,
      );
    } on UnauthorizedApiException {
      // ApiClient clears the session and routes to the welcome screen.
    } on SubscriptionExpiredApiException {
      // ApiClient keeps this screen active while the subscription is expired.
    } on NetworkApiException {
      if (mounted) setState(() => _errorKey = 'api_error_network');
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'api_error_generic');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('subscription_expired_message'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.4,
                    color: AppTheme.textDark,
                  ),
                ),
                if (_errorKey != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.tr(_errorKey!),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _retry,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(context.tr('try_again')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
