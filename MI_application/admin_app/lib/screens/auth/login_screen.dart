import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_icons.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/session.dart';
import '../../widgets/widgets.dart';
import '../subscription/subscription_screens.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.initialMessage,
    this.onAuthenticated,
  });

  final String? initialMessage;
  final VoidCallback? onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  late String? _errorMessage = widget.initialMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/auth/admin/login',
        authenticated: false,
        body: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
      );
      final token = response['token'];
      final user = response['user'];
      if (token is! String || token.isEmpty || user is! Map) {
        if (mounted) {
          setState(() => _errorMessage = AppStrings.invalidResponse);
        }
        return;
      }

      final currentUser = Map<String, dynamic>.from(user);
      if (currentUser['role'] != 'admin') {
        if (mounted) {
          setState(() => _errorMessage = AppStrings.invalidEmailOrPassword);
        }
        return;
      }

      await Session.instance.saveToken(token);
      Session.instance.setCurrentUser(currentUser);
      if (mounted) widget.onAuthenticated?.call();
    } on ApiException catch (error) {
      final message = error.statusCode == 429
          ? AppStrings.tooManyAttempts
          : error.isNetworkError
              ? AppStrings.networkError
              : AppStrings.invalidEmailOrPassword;
      if (mounted) setState(() => _errorMessage = message);
    } on PlatformException {
      if (mounted) {
        setState(() => _errorMessage = AppStrings.sessionStorageError);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openRequestAccess() => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const RequestScreen(),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
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
                    AppStrings.loginTitle,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? AppStrings.emailRequired
                                    : null,
                            decoration: const InputDecoration(
                              labelText: AppStrings.emailLabel,
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _signIn(),
                            validator: (value) => value == null || value.isEmpty
                                ? AppStrings.passwordRequired
                                : null,
                            decoration: InputDecoration(
                              labelText: AppStrings.passwordLabel,
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? AppStrings.showPassword
                                    : AppStrings.hidePassword,
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppTheme.warn,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          ValueListenableBuilder<bool>(
                            valueListenable:
                                ApiClient.instance.serverIsWakingUp,
                            builder: (context, isWaking, _) => isWaking
                                ? const Padding(
                                    padding: EdgeInsets.only(top: 14),
                                    child: Text(
                                      AppStrings.serverWakingUp,
                                      style: TextStyle(
                                        color: AppTheme.textGrey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _isLoading ? null : _signIn,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.onPrimary,
                                    ),
                                  )
                                : const Text(AppStrings.signIn),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading ? null : _openRequestAccess,
                    child: const Text(AppStrings.requestAccess),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
