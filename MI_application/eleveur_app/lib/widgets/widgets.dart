import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/theme.dart';

/// White rounded surface used throughout the application.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsets padding;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: AppTheme.shadow,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Compact selector for two or more labels.
class PillSwitch extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final bool forceLtr;

  const PillSwitch({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.forceLtr = false,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: i == index ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: i == index ? Colors.white : AppTheme.textGrey,
                ),
              ),
            ),
          ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: forceLtr
          ? Directionality(textDirection: TextDirection.ltr, child: row)
          : row,
    );
  }
}

/// Toggles the application language between French and Arabic.
class LangToggle extends StatelessWidget {
  const LangToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return PillSwitch(
      forceLtr: true,
      labels: const ['FR', 'عربي'],
      index: context.isAr ? 1 : 0,
      onChanged: (index) => context.lang.set(index == 1 ? 'ar' : 'fr'),
    );
  }
}

/// Cow avatar with a colored outline.
class CowAvatar extends StatelessWidget {
  final String emoji;
  final Color ring;
  final double size;

  const CowAvatar({
    super.key,
    required this.emoji,
    required this.ring,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring.withValues(alpha: 0.12),
        border: Border.all(color: ring, width: 3),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

/// Trailing chevron that follows the current text direction.
Widget chevron(BuildContext context, {Color? color}) => Icon(
      context.isAr ? Icons.chevron_left : Icons.chevron_right,
      color: color ?? AppTheme.textGrey,
    );
