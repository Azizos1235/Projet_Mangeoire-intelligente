part of 'home_screen.dart';

/// Rounded bottom corners of the header.
const double _headerRadius = 28;

/// Full-width brand header: avatar, greeting, name, email and alerts bell.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.alertCount,
    required this.onOpenAlerts,
  });

  final int alertCount;
  final VoidCallback onOpenAlerts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final softOnPrimary = onPrimary.withValues(alpha: 0.8);
    final tint = onPrimary.withValues(alpha: 0.18);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(_headerRadius),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space16,
            AppTheme.space16,
            AppTheme.space16,
            AppTheme.space24,
          ),
          // Listens to the session, so name and email appear as soon as the
          // user is loaded instead of staying empty.
          child: ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: Session.instance.currentUser,
            builder: (context, user, _) {
              final name = user?['name'];
              final email = user?['email'];
              final adminName = name is String ? name.trim() : '';
              final adminEmail = email is String ? email.trim() : '';
              return Row(
                children: [
                  CircleAvatar(
                    radius: AppTheme.homeAvatarSize / 2,
                    backgroundColor: tint,
                    child: Text(
                      _initials(adminName),
                      style: textTheme.titleMedium?.copyWith(
                        color: onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (adminName.isNotEmpty)
                          Text(
                            AppStrings.greeting,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: softOnPrimary,
                            ),
                          ),
                        Text(
                          adminName.isEmpty ? AppStrings.greeting : adminName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleLarge?.copyWith(
                            color: onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (adminEmail.isNotEmpty)
                          Text(
                            adminEmail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: softOnPrimary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  IconButton(
                    onPressed: onOpenAlerts,
                    tooltip: AppStrings.alertsTitle,
                    style: IconButton.styleFrom(
                      backgroundColor: tint,
                      foregroundColor: onPrimary,
                    ),
                    icon: Badge(
                      isLabelVisible: alertCount > 0,
                      label: Text('$alertCount'),
                      child: const Icon(AppIcons.alert),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return 'A';
    final words = name.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }
}

class _HomeKpiRow extends StatelessWidget {
  const _HomeKpiRow({
    required this.cowCount,
    required this.alertCount,
    required this.eleveurCount,
    required this.onOpenCows,
    required this.onOpenAlerts,
    required this.onOpenEleveurs,
  });

  final int cowCount;
  final int alertCount;
  final int eleveurCount;
  final VoidCallback onOpenCows;
  final VoidCallback onOpenAlerts;
  final VoidCallback? onOpenEleveurs;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: KpiTile(
              AppIcons.cow,
              '$cowCount',
              AppStrings.dashboardCowCount,
              height: AppTheme.homeKpiHeight,
              onTap: onOpenCows,
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: KpiTile(
              AppIcons.alert,
              '$alertCount',
              AppStrings.dashboardAlerts,
              height: AppTheme.homeKpiHeight,
              // Red only when something needs attention.
              color: alertCount == 0
                  ? AppTheme.primary
                  : Theme.of(context).colorScheme.error,
              onTap: onOpenAlerts,
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: KpiTile(
              AppIcons.eleveur,
              '$eleveurCount',
              AppStrings.dashboardEleveurs,
              height: AppTheme.homeKpiHeight,
              onTap: onOpenEleveurs,
            ),
          ),
        ],
      );
}

class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions({
    required this.onAddCow,
    required this.onScanCow,
  });

  final Future<void> Function()? onAddCow;
  final Future<void> Function()? onScanCow;

  @override
  Widget build(BuildContext context) {
    final add = onAddCow;
    final scan = onScanCow;
    return Row(
      children: [
        if (add != null)
          Expanded(
            child: _ActionButton(
              filled: true,
              icon: Icons.add_circle_outline_rounded,
              label: AppStrings.addCow,
              onPressed: () => add(),
            ),
          ),
        if (add != null && scan != null)
          const SizedBox(width: AppTheme.space8),
        if (scan != null)
          Expanded(
            child: _ActionButton(
              filled: false,
              icon: Icons.nfc_rounded,
              label: AppStrings.scanTag,
              onPressed: () => scan(),
            ),
          ),
      ],
    );
  }
}

/// One button for both quick actions, so they always share size and layout.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.filled,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool filled;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon),
        const SizedBox(width: AppTheme.space8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    return SizedBox(
      height: AppTheme.homeActionHeight,
      child: filled
          ? FilledButton(onPressed: onPressed, child: content)
          : OutlinedButton(onPressed: onPressed, child: content),
    );
  }
}