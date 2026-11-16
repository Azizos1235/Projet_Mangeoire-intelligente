import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/session.dart';
import '../../widgets/widgets.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key, this.onLogout});

  final Future<void> Function()? onLogout;

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final _messageController = TextEditingController();

  Map<String, dynamic>? _subscription;
  String? _errorMessage;
  String? _renewalError;
  String? _renewalSuccess;
  bool _isLoading = true;
  bool _isRequestingRenewal = false;

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
      );
      final status = result['status'];
      final expiresAt = result['expires_at'];
      final daysLeft = result['days_left'];
      if (status is! String ||
          !result.containsKey('expires_at') ||
          !result.containsKey('days_left') ||
          (expiresAt != null && expiresAt is! String) ||
          (daysLeft != null && daysLeft is! num)) {
        throw const FormatException('Invalid subscription response.');
      }
      if (expiresAt is String && DateTime.tryParse(expiresAt) == null) {
        throw const FormatException('Invalid subscription expiry.');
      }
      if (mounted) setState(() => _subscription = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on FormatException {
      if (mounted) {
        setState(
          () => _errorMessage = AppStrings.subscriptionLoadError,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestRenewal() async {
    if (_isRequestingRenewal) return;
    setState(() {
      _isRequestingRenewal = true;
      _renewalError = null;
      _renewalSuccess = null;
    });

    final message = _messageController.text.trim();
    try {
      await ApiClient.instance.post<Object?>(
        '/subscription/renewal-request',
        body: message.isEmpty ? const {} : {'message': message},
      );
      if (mounted) {
        setState(() => _renewalSuccess = AppStrings.renewalRequested);
      }
    } on ApiException catch (error) {
      final message = switch (error.statusCode) {
        409 => AppStrings.renewalPending,
        _ => error.isNetworkError ? AppStrings.networkError : error.message,
      };
      if (mounted) setState(() => _renewalError = message);
    } finally {
      if (mounted) setState(() => _isRequestingRenewal = false);
    }
  }

  String _expiryText(Object? value) {
    if (value is! String) return AppStrings.expirationUnavailable;
    final date = DateTime.parse(value).toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _statusText(Object? value) {
    if (value is! String || value.isEmpty) return '—';
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await widget.onLogout?.call();
    } on PlatformException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.logoutError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Session.instance.currentUser.value;
    final name = user?['name'];
    final email = user?['email'];
    final subscription = _subscription;
    final daysLeft = subscription?['days_left'];

    return Scaffold(
      appBar: AppBar(title: const Text('Plus')),
      body: RefreshIndicator(
        onRefresh: _loadSubscription,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            const SectionTitle('Compte'),
            DataSheet([
              (
                Icons.person_outline,
                'Administrateur',
                name is String ? name : '—',
              ),
              (
                Icons.mail_outline,
                AppStrings.emailLabel,
                email is String ? email : '—',
              ),
            ]),
            const SectionTitle('Abonnement'),
            if (_isLoading && subscription == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null && subscription == null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.warn),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _loadSubscription,
                      child: const Text(AppStrings.retry),
                    ),
                  ],
                ),
              )
            else if (subscription != null)
              DataSheet([
                (
                  Icons.workspace_premium_outlined,
                  AppStrings.subscriptionStatusLabel,
                  _statusText(subscription['status']),
                ),
                (
                  Icons.event_outlined,
                  AppStrings.renewalExpiryLabel,
                  _expiryText(subscription['expires_at']),
                ),
                (
                  Icons.timelapse_rounded,
                  AppStrings.daysLeftLabel,
                  daysLeft is num ? '${daysLeft.toInt()}' : '—',
                ),
              ]),
            if (_errorMessage != null && subscription != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.warn),
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
            if (_renewalError != null) ...[
              const SizedBox(height: 12),
              Text(
                _renewalError!,
                style: const TextStyle(color: AppTheme.warn),
              ),
            ],
            if (_renewalSuccess != null) ...[
              const SizedBox(height: 12),
              Text(
                _renewalSuccess!,
                style: const TextStyle(color: AppTheme.accent),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _isRequestingRenewal ? null : _requestRenewal,
              child: _isRequestingRenewal
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(AppStrings.requestRenewal),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed:
                  widget.onLogout == null ? null : () => _logout(context),
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text(AppStrings.logout),
            ),
          ],
        ),
      ),
    );
  }
}
