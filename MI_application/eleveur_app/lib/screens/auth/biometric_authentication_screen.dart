import 'package:flutter/material.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Shows the biometric sign-in state without claiming a fingerprint succeeded.
class BiometricAuthenticationScreen extends StatelessWidget {
  const BiometricAuthenticationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: const [LangToggle(), SizedBox(width: 16)]),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.fingerprint,
                size: 96,
                color: AppTheme.textGrey,
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('biometric_unavailable'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.4,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
