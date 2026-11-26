import 'package:flutter/material.dart';

import '../core/theme.dart';

class CowFormCard extends StatelessWidget {
  const CowFormCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: AppTheme.shadow,
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}

class CowRoundButton extends StatelessWidget {
  const CowRoundButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filled(
        onPressed: onPressed,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: AppTheme.primarySoft,
          foregroundColor: AppTheme.primary,
        ),
      );
}

class CowAgeUnitSwitch extends StatelessWidget {
  const CowAgeUnitSwitch({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => ToggleButtons(
        isSelected: [for (var i = 0; i < labels.length; i++) i == index],
        onPressed: onChanged,
        borderRadius: BorderRadius.circular(24),
        selectedColor: Colors.white,
        color: AppTheme.textDark,
        fillColor: AppTheme.primary,
        constraints: const BoxConstraints(minHeight: 40, minWidth: 96),
        children: [for (final label in labels) Text(label)],
      );
}
