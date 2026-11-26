import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/session.dart';
import '../../widgets/widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    super.key,
    required this.onLogout,
    required this.onPasswordChanged,
  });

  final Future<void> Function() onLogout;
  final Future<void> Function(Map<String, dynamic> user) onPasswordChanged;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmationController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePasswords = true;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiClient.instance.post<Map<String, dynamic>>(
        '/auth/change-password',
        body: {
          'current_password': _currentPasswordController.text,
          'new_password': _newPasswordController.text,
        },
      );
      if (result['ok'] != true) {
        if (mounted) {
          setState(() => _errorMessage = AppStrings.invalidResponse);
        }
        return;
      }

      final user =
          await ApiClient.instance.get<Map<String, dynamic>>('/auth/me');
      Session.instance.setCurrentUser(user);
      await widget.onPasswordChanged(user);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateCurrentPassword(String? value) =>
      value == null || value.isEmpty
          ? AppStrings.currentPasswordRequired
          : null;

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) return AppStrings.newPasswordRequired;
    if (value.length < 8) return AppStrings.passwordTooShort;
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.passwordConfirmationRequired;
    }
    if (value != _newPasswordController.text) {
      return AppStrings.passwordConfirmationMismatch;
    }
    return null;
  }

  InputDecoration _passwordDecoration(String label) => InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _obscurePasswords
              ? AppStrings.showPassword
              : AppStrings.hidePassword,
          onPressed: () =>
              setState(() => _obscurePasswords = !_obscurePasswords),
          icon: Icon(
            _obscurePasswords
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => PopScope<void>(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(title: const Text(AppStrings.changePassword)),
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _currentPasswordController,
                          obscureText: _obscurePasswords,
                          textInputAction: TextInputAction.next,
                          validator: _validateCurrentPassword,
                          decoration: _passwordDecoration(
                              AppStrings.currentPasswordLabel),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: _obscurePasswords,
                          textInputAction: TextInputAction.next,
                          validator: _validateNewPassword,
                          decoration:
                              _passwordDecoration(AppStrings.newPasswordLabel),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmationController,
                          obscureText: _obscurePasswords,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          validator: _validateConfirmation,
                          decoration: _passwordDecoration(
                            AppStrings.passwordConfirmationLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.warn),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.onPrimary,
                          ),
                        )
                      : const Text(AppStrings.changePassword),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : widget.onLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(AppStrings.logout),
                ),
              ],
            ),
          ),
        ),
      );
}
