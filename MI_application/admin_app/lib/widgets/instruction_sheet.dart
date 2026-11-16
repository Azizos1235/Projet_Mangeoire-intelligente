import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/alert_service.dart';
import '../services/api_client.dart';

Future<void> showInstructionSheet(
  BuildContext context, {
  Cow? cow,
  String? presetAction,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _Sheet(cow: cow, presetAction: presetAction),
    );

class _Sheet extends StatefulWidget {
  const _Sheet({required this.cow, required this.presetAction});

  final Cow? cow;
  final String? presetAction;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  final _messageController = TextEditingController();
  String _severity = 'info';
  late String _action = widget.presetAction ?? 'none';
  bool _isSending = false;
  bool _sent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _messageController.text.trim();
    if (_isSending) return;
    if (message.isEmpty) {
      setState(() => _errorMessage = AppStrings.alertMessageRequired);
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await AlertService.instance.createAlert(
        message: message,
        severity: _severity,
        cowId: widget.cow?.id,
        action: _action == 'none' ? null : _action,
      );
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            error.isNetworkError ? AppStrings.networkError : error.message;
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppStrings.alertsTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              if (widget.cow != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${AppStrings.alertCowLabel}: ${widget.cow!.id}',
                  style: const TextStyle(color: AppTheme.textGrey),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                minLines: 2,
                maxLines: 4,
                readOnly: _isSending || _sent,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: AppStrings.alertMessageLabel,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _severity,
                decoration: const InputDecoration(
                  labelText: AppStrings.alertSeverityLabel,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'info',
                    child: Text(AppStrings.alertSeverityInfo),
                  ),
                  DropdownMenuItem(
                    value: 'warning',
                    child: Text(AppStrings.alertSeverityWarning),
                  ),
                  DropdownMenuItem(
                    value: 'critical',
                    child: Text(AppStrings.alertSeverityCritical),
                  ),
                ],
                onChanged: _isSending || _sent
                    ? null
                    : (value) {
                        if (value != null) setState(() => _severity = value);
                      },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _action,
                decoration: const InputDecoration(
                  labelText: AppStrings.alertActionLabel,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'none',
                    child: Text(AppStrings.alertActionNone),
                  ),
                  DropdownMenuItem(
                    value: 'sell',
                    child: Text(AppStrings.alertActionSell),
                  ),
                  DropdownMenuItem(
                    value: 'vet',
                    child: Text(AppStrings.alertActionVet),
                  ),
                  DropdownMenuItem(
                    value: 'butcher',
                    child: Text(AppStrings.alertActionButcher),
                  ),
                ],
                onChanged: _isSending || _sent
                    ? null
                    : (value) {
                        if (value != null) setState(() => _action = value);
                      },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.warn),
                ),
              ],
              if (_sent) ...[
                const SizedBox(height: 14),
                const Text(
                  AppStrings.alertSent,
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(AppStrings.done),
                ),
              ] else ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isSending ? null : _send,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                  label: Text(
                    _isSending ? AppStrings.sending : AppStrings.alertSend,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}
