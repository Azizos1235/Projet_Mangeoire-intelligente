import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../widgets/widgets.dart';

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isLoading = false;
  bool _isSubmitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return AppStrings.requestEmailRequired;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
        ? null
        : AppStrings.invalidEmail;
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = _phoneController.text.trim();
    final message = _messageController.text.trim();
    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/subscription-requests',
        authenticated: false,
        expectedStatusCode: 201,
        body: {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          if (phone.isNotEmpty) 'phone': phone,
          if (message.isNotEmpty) 'message': message,
        },
      );
      if (response['id'] == null || response['status'] is! String) {
        throw const ApiException(
          statusCode: 201,
          message: AppStrings.invalidResponse,
        );
      }
      if (mounted) setState(() => _isSubmitted = true);
    } on ApiException catch (error) {
      final message = switch (error.statusCode) {
        409 => AppStrings.requestAlreadyExists,
        422 => AppStrings.requestValidationFailed,
        429 => AppStrings.tooManyAttempts,
        _ => error.isNetworkError ? AppStrings.networkError : error.message,
      };
      if (mounted) setState(() => _errorMessage = message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _confirmation() => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 72,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 20),
                const Text(
                  AppStrings.requestSentConfirmation,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(AppStrings.backToLogin),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: _isSubmitted
            ? _confirmation()
            : SafeArea(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.pageSpacing,
                      24,
                      AppTheme.pageSpacing,
                      28,
                    ),
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          AppIcons.cow,
                          color: AppTheme.surface,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        AppStrings.requestAccess,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        AppStrings.requestAccessDescription,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.45,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppCard(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? AppStrings.requestNameRequired
                                      : null,
                              decoration: const InputDecoration(
                                labelText: AppStrings.requestNameLabel,
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: _validateEmail,
                              decoration: const InputDecoration(
                                labelText: AppStrings.emailLabel,
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: AppStrings.requestPhoneLabel,
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _messageController,
                              minLines: 2,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                              decoration: const InputDecoration(
                                labelText: AppStrings.requestMessageLabel,
                                prefixIcon: Icon(Icons.message_outlined),
                                alignLabelWithHint: true,
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: AppTheme.warn),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: _isLoading ? null : _submit,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.onPrimary,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, size: 20),
                              label: Text(
                                _isLoading
                                    ? AppStrings.requestSending
                                    : AppStrings.sendRequest,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      );
}
