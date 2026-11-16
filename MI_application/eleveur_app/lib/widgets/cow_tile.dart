import 'package:flutter/material.dart';

import '../core/app_routes.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../models/cow_appetite.dart';
import '../models/cow_profile.dart';
import 'widgets.dart';

extension CowAppetiteClassStyle on CowAppetiteClass {
  String get labelKey => 'appetite_$name';

  Color get color => switch (this) {
        CowAppetiteClass.increasing => AppTheme.primary,
        CowAppetiteClass.stable => const Color(0xFF2F80ED),
        CowAppetiteClass.decreasing => const Color(0xFFE5484D),
      };

  IconData get icon => switch (this) {
        CowAppetiteClass.increasing => Icons.trending_up_rounded,
        CowAppetiteClass.stable => Icons.trending_flat_rounded,
        CowAppetiteClass.decreasing => Icons.trending_down_rounded,
      };
}

class CowTile extends StatelessWidget {
  final CowReference cow;
  final CowAppetiteClass? appetite;
  final CowProfile? profile;

  const CowTile({
    super.key,
    required this.cow,
    required this.appetite,
    this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final color = appetite?.color ?? AppTheme.textGrey;
    final subtitle = profile == null
        ? null
        : '${profile!.breed} · ${profile!.ageMonths.round()} ${context.tr('months_unit')}';

    return AppCard(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.cowDetail,
        arguments: cow,
      ),
      child: Row(children: [
        CowAvatar(emoji: '🐄', ring: color),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cow.displayId,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      const TextStyle(fontSize: 13, color: AppTheme.textGrey),
                ),
              ],
            ],
          ),
        ),
        if (appetite != null) _CowAppetiteBadge(appetite!),
        const SizedBox(width: 4),
        chevron(context),
      ]),
    );
  }
}

class _CowAppetiteBadge extends StatelessWidget {
  final CowAppetiteClass appetite;

  const _CowAppetiteBadge(this.appetite);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: appetite.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(appetite.icon, size: 16, color: appetite.color),
        const SizedBox(width: 4),
        Text(
          context.tr(appetite.labelKey),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: appetite.color,
          ),
        ),
      ]),
    );
  }
}
