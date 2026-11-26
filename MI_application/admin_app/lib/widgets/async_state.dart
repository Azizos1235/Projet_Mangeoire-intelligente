import 'package:flutter/material.dart';

import '../core/theme.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.height = 180});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 40, color: AppTheme.textGrey),
                const SizedBox(height: 12),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textGrey),
              ),
            ],
          ),
        ),
      );
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: theme.colorScheme.error,
              size: 40,
            ),
            const SizedBox(height: AppTheme.space12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
