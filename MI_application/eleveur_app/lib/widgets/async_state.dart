import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../services/api_client.dart';

/// Waits for refresh completion while FutureBuilder presents expected failures.
Future<void> waitForRefreshRequest<T>(Future<T> request) =>
    request.then<void>((_) {}, onError: (Object error, StackTrace stackTrace) {
      if (error is ApiException || error is FormatException) return;
      Error.throwWithStackTrace(error, stackTrace);
    });

/// Shared error presentation for requests that can be retried.
class AppLoadError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const AppLoadError({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final currentError = error;
    final details = currentError is ApiException
        ? context.tr(currentError.messageKey)
        : currentError.toString();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${context.tr('api_load_error')}\n$details',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textGrey),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(context.tr('retry')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared empty-result presentation.
class AppEmptyState extends StatelessWidget {
  final String message;

  const AppEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textGrey),
        ),
      ),
    );
  }
}
