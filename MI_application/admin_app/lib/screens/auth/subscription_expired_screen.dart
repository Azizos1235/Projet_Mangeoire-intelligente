import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/session.dart';
import '../../widgets/widgets.dart';

class SubscriptionExpiredScreen extends StatefulWidget {
  const SubscriptionExpiredScreen({
    super.key,
    required this.onLogout,
    required this.onAuthError,
    required this.onUserRefreshed,
  });

  final Future<void> Function() onLogout;
  final Future<void> Function(ApiException error) onAuthError;
  final Future<void> Function(Map<String, dynamic> user) onUserRefreshed;

  @override
  State<SubscriptionExpiredScreen> createState() =>
      _SubscriptionExpiredScreenState();
}

class _SubscriptionExpiredScreenState extends State<SubscriptionExpiredScreen> {
  final _messageController = TextEditingController();

  Map<String, dynamic>? _subscription;
  String? _errorMessage;
  String? _successMessage;
  bool _isLoading = true;
  bool _isRequestingRenewal = false;
  bool _isCheckingAgain = false;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscription() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await ApiClient.instance.get<Map<String, dynamic>>(
        '/subscription/me',
        handleAuthErrors: false,
      );
      if (mounted) setState(() => _subscription = result);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || _isPasswordChangeRequired(error)) {
        await widget.onAuthError(error);
      } else if (error.statusCode != 402 && mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestRenewal() async {
    if (_isRequestingRenewal) return;
    setState(() {
      _isRequestingRenewal = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final message = _messageController.text.trim();
    try {
      await ApiClient.instance.post<Map<String, dynamic>>(
        '/subscription/renewal-request',
        body: message.isEmpty ? const {} : {'message': message},
        handleAuthErrors: false,
      );
      if (mounted) {
        setState(() => _successMessage = AppStrings.renewalRequested);
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401 ||
          error.statusCode == 402 ||
          _isPasswordChangeRequired(error)) {
        await widget.onAuthError(error);
      } else if (mounted) {
        setState(() {
          _errorMessage = error.statusCode == 409
              ? AppStrings.renewalPending
              : error.message;
        });
      }
    } finally {
      if (mounted) setState(() => _isRequestingRenewal = false);
    }
  }

  Future<void> _checkAgain() async {
    if (_isCheckingAgain) return;
    setState(() {
      _isCheckingAgain = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final user = await ApiClient.instance.get<Map<String, dynamic>>(
        '/auth/me',
        handleAuthErrors: false,
      );
      Session.instance.setCurrentUser(user);
      await widget.onUserRefreshed(user);
    } on ApiException catch (error) {
      if (error.statusCode == 401 ||
          error.statusCode == 402 ||
          _isPasswordChangeRequired(error)) {
        await widget.onAuthError(error);
      } else if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) setState(() => _isCheckingAgain = false);
    }
  }

  bool _isPasswordChangeRequired(ApiException error) =>
      error.statusCode == 403 &&
      error.detail?.trim().toLowerCase() == 'password change required';

  String _expirationText() {
    final expiresAt = _subscription?['expires_at'];
    if (expiresAt is String && expiresAt.isNotEmpty) return expiresAt;
    return AppStrings.expirationUnavailable;
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(title: const Text(AppStrings.subscriptionExpired)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pageSpacing,
                4,
                AppTheme.pageSpacing,
                28,
              ),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppStrings.renewalExpiryLabel}: ${_isLoading ? AppStrings.loading : _expirationText()}',
                        style: const TextStyle(
                          color: AppTheme.textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _messageController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: AppStrings.renewalMessageLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.warn),
                  ),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _successMessage!,
                    style: const TextStyle(color: AppTheme.primary),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _isRequestingRenewal ? null : _requestRenewal,
                  child: _isRequestingRenewal
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.onPrimary,
                          ),
                        )
                      : const Text(AppStrings.requestRenewal),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _isCheckingAgain ? null : _checkAgain,
                  child: _isCheckingAgain
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(AppStrings.checkAgain),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(AppStrings.logout),
                ),
              ],
            ),
          ),
        ),
      );
}
