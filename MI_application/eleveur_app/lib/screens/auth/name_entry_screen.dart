import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/widgets.dart';

class NameEntryScreen extends StatefulWidget {
  const NameEntryScreen({super.key, this.qrToken});

  final String? qrToken;

  @override
  State<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends State<NameEntryScreen> {
  final _nameController = TextEditingController();
  bool _submitting = false;
  bool _sessionInvalid = false;
  String? _errorKey;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _nameController.text.trim();
    if (name.length < 2 || name.length > 60) {
      setState(() => _errorKey = 'registration_name_invalid');
      return;
    }

    setState(() {
      _submitting = true;
      _errorKey = null;
    });
    try {
      final qrToken = widget.qrToken;
      if (qrToken == null) {
        await AuthService.instance.verifyName(name);
      } else {
        await AuthService.instance.qrLogin(qrToken, name);
      }
      if (!mounted) return;
      unawaited(
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.home,
          (_) => false,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      final status = error.statusCode;
      if (status == 401 && error.responseMessage == 'Name does not match') {
        setState(() => _errorKey = 'qr_name_mismatch');
      } else if (widget.qrToken == null && status == 401) {
        try {
          await AuthService.instance.logout();
          if (mounted) {
            setState(() {
              _sessionInvalid = true;
              _errorKey = 'session_expired_message';
            });
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _sessionInvalid = true;
              _errorKey = 'api_error_generic';
            });
          }
        }
      } else {
        setState(() => _errorKey = switch (status) {
              410 => 'qr_expired',
              409 => 'qr_used',
              404 => 'qr_unknown',
              429 => 'api_error_429',
              _ => status == null ? 'api_error_network' : 'api_error_generic',
            });
      }
    } on FormatException {
      if (mounted) setState(() => _errorKey = 'api_error_generic');
    } on ArgumentError {
      if (mounted) setState(() => _errorKey = 'registration_name_invalid');
    } catch (_) {
      if (mounted) setState(() => _errorKey = 'api_error_generic');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _scanQr() {
    unawaited(
      Navigator.pushReplacementNamed<void, void>(
        context,
        AppRoutes.qrScanner,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr('name_entry_title')),
          actions: const [LangToggle(), SizedBox(width: 16)],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('name_entry_prompt'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    enabled: !_submitting,
                    textCapitalization: TextCapitalization.words,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
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
                        : Text(context.tr('continue')),
                  ),
                  if (widget.qrToken == null ||
                      _sessionInvalid ||
                      _errorKey != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _submitting ? null : _scanQr,
                      child: Text(context.tr('scan_btn')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}
