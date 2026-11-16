import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final sessionExpired =
        arguments is Map && arguments['sessionExpired'] == true;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: LangToggle()),
              const Spacer(flex: 2),
              Container(
                width: 150,
                height: 150,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppTheme.primarySoft),
                child: const Text('🐄', style: TextStyle(fontSize: 80)),
              ),
              const SizedBox(height: 24),
              const Text('MANGEOIRE',
                  style: TextStyle(
                      fontSize: 34,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary)),
              const SizedBox(height: 20),
              Text(context.tr('scan_prompt'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, height: 1.5, color: AppTheme.textDark)),
              if (sessionExpired) ...[
                const SizedBox(height: 16),
                Text(
                  context.tr('session_expired_message'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.error),
                ),
              ],
              const Spacer(flex: 3),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.qrScanner),
                icon: const Icon(Icons.qr_code_scanner, size: 28),
                label: Text(context.tr('join_with_qr')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
