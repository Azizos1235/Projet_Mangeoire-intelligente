import 'package:flutter/material.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/cow_profile.dart';

/// Displays an explicit unavailable state until feeding endpoints are provided.
class FeedingScreen extends StatelessWidget {
  final CowReference cow;

  const FeedingScreen({super.key, required this.cow});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text('${context.tr('feeding')} · ${cow.displayId}')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 56,
                color: AppTheme.textGrey,
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('feature_unavailable'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
