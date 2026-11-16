import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';
import '../../core/app_routes.dart';
import '../../screens/home/eleveur_home_screen.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';

class EleveurRegistrationScreen extends StatefulWidget {
  final String invitationCode;
  final String adminName;

  const EleveurRegistrationScreen({
    super.key,
    required this.invitationCode,
    required this.adminName,
  });

  @override
  State<EleveurRegistrationScreen> createState() =>
      _EleveurRegistrationScreenState();
}

class _EleveurRegistrationScreenState extends State<EleveurRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _submitting = false;
  bool _invitationRejected = false;
  String? _errorKey;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting ||
        _invitationRejected ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorKey = null;
    });
    try {
      await AuthService.instance.register(
        widget.invitationCode,
        _nameController.text.trim(),
      );
      if (!mounted) return;
      unawaited(
        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(
            builder: (_) => const EleveurHomeScreen(),
          ),
          (_) => false,
        ),
      );
    } on NotFoundApiException {
      if (!mounted) return;
      setState(() {
        _invitationRejected = true;
        _errorKey = 'registration_invite_rejected';
      });
    } on TooManyRequestsApiException {
      if (!mounted) return;
      setState(() => _errorKey = 'api_error_429');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorKey = error.messageKey);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorKey = 'api_error_generic');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validateName(String? value) {
    final length = value?.trim().length ?? 0;
    if (length < 2 || length > 60) {
      return context.tr('registration_name_invalid');
    }
    return null;
  }

  void _scanAgain() {
    unawaited(
      Navigator.pushReplacementNamed<void, void>(context, AppRoutes.qrScanner),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('registration')),
        actions: const [LangToggle(), SizedBox(width: 16)],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context
                      .tr('join_admin_farm')
                      .replaceAll('{admin}', widget.adminName),
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  enabled: !_submitting && !_invitationRejected,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: _validateName,
                  decoration: InputDecoration(
                    labelText: context.tr('registration_name'),
                  ),
                ),
                if (_errorKey != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    context.tr(_errorKey!),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.error),
                  ),
                ],
                if (_invitationRejected) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _scanAgain,
                    child: Text(context.tr('scan_again')),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(context.tr('registration_submit')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
