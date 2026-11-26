import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../core/theme.dart';
import '../core/strings.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const AppCard(
      {super.key,
      required this.child,
      this.onTap,
      this.padding = const EdgeInsets.all(AppTheme.cardPadding),
      this.color});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          boxShadow: const [
            BoxShadow(
              color: AppTheme.shadow,
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final Color? backgroundColor;
  const Pill(this.text, this.color,
      {super.key, this.icon, this.backgroundColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: backgroundColor ?? color.withAlpha(30),
            borderRadius: BorderRadius.circular(AppTheme.pillRadius)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4)
          ],
          Text(text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          2,
          AppTheme.sectionSpacing,
          2,
          10,
        ),
        child: Row(children: [
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Fiche de données : une ligne = icône, libellé, valeur.
class DataSheet extends StatelessWidget {
  final List<(IconData, String, String)> rows;
  const DataSheet(this.rows, {super.key});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(children: [
                Icon(rows[i].$1, size: 18, color: AppTheme.textGrey),
                const SizedBox(width: 10),
                Expanded(
                    flex: 5,
                    child: Text(rows[i].$2,
                        style: const TextStyle(
                            fontSize: 14, color: AppTheme.textGrey))),
                Expanded(
                    flex: 6,
                    child: Text(rows[i].$3,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark))),
              ]),
            ),
          ],
        ]),
      );
}

class KpiTile extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  final VoidCallback? onTap;
  final double? height;
  const KpiTile(
    this.icon,
    this.value,
    this.label, {
    super.key,
    this.color = AppTheme.primary,
    this.onTap,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tile = AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTheme.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: AppTheme.space8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleLarge?.copyWith(
              color: AppTheme.textDark,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelMedium?.copyWith(color: AppTheme.textGrey),
          ),
        ],
      ),
    );
    return height == null ? tile : SizedBox(height: height, child: tile);
  }
}

class CowAvatar extends StatelessWidget {
  final Cow cow;
  final Color? ring;
  const CowAvatar(this.cow, {super.key, this.ring});

  @override
  Widget build(BuildContext context) {
    final color = ring ?? AppTheme.primary;
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 3),
      ),
      child: Semantics(
        label: '${cow.id} · ${cow.type.label}',
        child: const Text('🐄', style: TextStyle(fontSize: 27)),
      ),
    );
  }
}

class PersonAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool dim;
  const PersonAvatar(this.name, {super.key, this.size = 46, this.dim = false});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dim ? AppTheme.border : AppTheme.primarySoft),
        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
            style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w800,
                color: dim ? AppTheme.textGrey : AppTheme.primary)),
      );
}

class DonutChart extends StatelessWidget {
  final List<int> counts;
  final String? centerValue;
  final String? centerLabel;
  final double size;
  const DonutChart(
    this.counts, {
    super.key,
    this.centerValue,
    this.centerLabel,
    this.size = 124,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(counts),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              centerValue ?? '${counts.fold<int>(0, (a, b) => a + b)}',
              style: textTheme.headlineSmall?.copyWith(
                color: AppTheme.textDark,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              centerLabel ?? AppStrings.dashboardCowCount,
              style: textTheme.labelSmall?.copyWith(color: AppTheme.textGrey),
            ),
          ]),
        ),
      ),
    );
  }
}

Widget chevron(BuildContext context, {Color? color}) => Icon(
      Directionality.of(context) == TextDirection.rtl
          ? Icons.chevron_left_rounded
          : Icons.chevron_right_rounded,
      color: color ?? AppTheme.textGrey,
    );

class _DonutPainter extends CustomPainter {
  final List<int> counts;
  _DonutPainter(this.counts);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(9);
    final total = counts.fold<int>(0, (a, b) => a + b);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..color = AppTheme.border;
    if (total == 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, track);
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < counts.length; i++) {
      if (counts[i] == 0) continue;
      final sweep = counts[i] / total * math.pi * 2;
      final gap = counts.where((c) => c > 0).length > 1 ? 0.07 : 0.0;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(sweep - gap, 0.01),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round
          ..color = Appetite.values[i].color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) => o.counts != counts;
}
