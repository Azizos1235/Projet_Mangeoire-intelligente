part of 'home_screen.dart';

const double _appetiteIconBox = 36;
const double _appetiteBarHeight = 6;

/// Appetite summary: donut on top, then one tappable row per trend.
/// The rows (icon + color + label) already act as the legend, so there is no
/// separate legend line.
class _HomeAppetiteCard extends StatelessWidget {
  const _HomeAppetiteCard({
    required this.counts,
    required this.cowCount,
    required this.hasAppetiteData,
    required this.onSelect,
  });

  final List<int> counts;
  final int cowCount;
  final bool hasAppetiteData;
  final ValueChanged<Appetite?> onSelect;

  static const _order = [Appetite.high, Appetite.normal, Appetite.low];

  int get _classifiedCount => counts.fold(0, (total, count) => total + count);

  int _countFor(Appetite appetite) => counts[Appetite.values.indexOf(appetite)];

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: hasAppetiteData
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: DonutChart(
                      counts,
                      centerValue: '$cowCount',
                      centerLabel: AppStrings.dashboardCowCount,
                      size: AppTheme.homeDonutSize,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space16),
                  for (final appetite in _order)
                    _AppetiteRow(
                      appetite: appetite,
                      count: _countFor(appetite),
                      total: _classifiedCount,
                      onTap: () => onSelect(appetite),
                    ),
                ],
              )
            : const _AppetiteEmptyState(),
      );
}

class _AppetiteRow extends StatelessWidget {
  const _AppetiteRow({
    required this.appetite,
    required this.count,
    required this.total,
    required this.onTap,
  });

  final Appetite appetite;
  final int count;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trend = appetite.trend;
    final share = total == 0 ? 0.0 : count / total;
    final percentage = (share * 100).round();
    final soft = trend.color.withValues(alpha: 0.12);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
          child: Row(
            children: [
              Container(
                width: _appetiteIconBox,
                height: _appetiteIconBox,
                decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
                child: Icon(trend.icon, color: trend.color, size: 20),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trend.labelFr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppTheme.space8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(_appetiteBarHeight),
                      child: LinearProgressIndicator(
                        value: share,
                        minHeight: _appetiteBarHeight,
                        color: trend.color,
                        backgroundColor: soft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$count', style: textTheme.titleMedium),
                  Text(
                    '$percentage %',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppTheme.textGrey,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppTheme.textGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppetiteEmptyState extends StatelessWidget {
  const _AppetiteEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              AppStrings.appetiteDataUnavailable,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
}

class _HomeErrorBanner extends StatelessWidget {
  const _HomeErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space8,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }
}