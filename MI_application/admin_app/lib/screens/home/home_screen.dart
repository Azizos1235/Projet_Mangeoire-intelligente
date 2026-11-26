import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_icons.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/alert.dart';
import '../../models/models.dart';
import '../../services/alert_service.dart';
import '../../services/api_client.dart';
import '../../services/cow_service.dart';
import '../../services/eleveur_service.dart';
import '../../services/session.dart';
import '../../widgets/async_state.dart';
import '../../widgets/widgets.dart';
import '../cows/cows_screen.dart';

part 'home_widgets.dart';
part 'home_appetite_widgets.dart';

/// Height reserved for the background-refresh bar, so the layout never jumps.
const double _progressHeight = 3;

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenCows,
    required this.onOpenAlerts,
    this.onOpenEleveurs,
    this.onAddCow,
    this.onScanCow,
    @visibleForTesting this.dashboardFixture,
    @visibleForTesting this.skipInitialLoad = false,
  });

  final void Function(Appetite? appetite) onOpenCows;
  final VoidCallback onOpenAlerts;
  final VoidCallback? onOpenEleveurs;
  final Future<void> Function()? onAddCow;
  final Future<void> Function()? onScanCow;
  @visibleForTesting
  final HomeDashboardFixture? dashboardFixture;
  @visibleForTesting
  final bool skipInitialLoad;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _DashboardCow {
  const _DashboardCow(this.cow, this.appetite);

  final Cow cow;
  final Appetite? appetite;
}

class _DashboardData {
  const _DashboardData({
    required this.cows,
    required this.unreadAlertCount,
    required this.eleveurCount,
  });

  final List<_DashboardCow> cows;
  final int unreadAlertCount;
  final int eleveurCount;
}

@visibleForTesting
class HomeDashboardFixture {
  const HomeDashboardFixture({
    required this.cows,
    required this.unreadAlertCount,
    required this.eleveurCount,
  });

  final List<(Cow, Appetite?)> cows;
  final int unreadAlertCount;
  final int eleveurCount;
}

class _HomeScreenState extends State<HomeScreen> {
  _DashboardData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final fixture = widget.dashboardFixture;
    if (fixture != null) {
      _data = _DashboardData(
        cows: [
          for (final (cow, appetite) in fixture.cows)
            _DashboardCow(cow, appetite),
        ],
        unreadAlertCount: fixture.unreadAlertCount,
        eleveurCount: fixture.eleveurCount,
      );
      _loading = false;
    } else if (widget.skipInitialLoad) {
      _loading = false;
    } else {
      _refresh();
    }
  }

  Future<void> _refresh({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await Future.wait<Object?>([
        CowService.instance.listProfiles(),
        AlertService.instance.listAlerts(status: 'unread'),
        EleveurService.instance.listEleveurs(),
        CowService.instance.homeAppetite(),
      ]);
      final cows = result[0] as List<Cow>;
      final appetite = (result[3] as HomeAppetiteResponse).appetiteByInternalId;
      final entries = [
        for (final cow in cows) _DashboardCow(cow, appetite[cow.internalId]),
      ];
      if (!mounted) return;
      setState(() {
        _data = _DashboardData(
          cows: entries,
          unreadAlertCount: (result[1] as List<Alert>).length,
          eleveurCount: (result[2] as List<EleveurRecord>).length,
        );
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppStrings.invalidResponse;
      });
    }
  }

  void _goCows(Appetite? appetite) {
    cowsFilter.value = appetite;
    widget.onOpenCows(appetite);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final counts = [
      for (final appetite in Appetite.values)
        data?.cows.where((entry) => entry.appetite == appetite).length ?? 0,
    ];
    final hasAppetiteData =
        data?.cows.any((entry) => entry.appetite != null) ?? false;

    return Scaffold(
      // Light status-bar icons: the header behind them is the brand color.
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: RefreshIndicator(
          // The pull-to-refresh spinner is enough: no second progress bar.
          onRefresh: () => _refresh(showLoading: false),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _HomeHeader(
                alertCount: data?.unreadAlertCount ?? 0,
                onOpenAlerts: widget.onOpenAlerts,
              ),
              SizedBox(
                height: _progressHeight,
                child: _loading && data != null
                    ? const LinearProgressIndicator()
                    : null,
              ),
              if (_loading && data == null)
                const AppLoadingState()
              else if (data == null)
                AppErrorState(
                  message: _error ?? AppStrings.requestFailed,
                  retryLabel: AppStrings.retry,
                  onRetry: () => _refresh(),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space16,
                    AppTheme.space16,
                    AppTheme.space16,
                    AppTheme.space24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) ...[
                        _HomeErrorBanner(
                          message: _error!,
                          onRetry: () => _refresh(),
                        ),
                        const SizedBox(height: AppTheme.space16),
                      ],
                      _HomeKpiRow(
                        cowCount: data.cows.length,
                        alertCount: data.unreadAlertCount,
                        eleveurCount: data.eleveurCount,
                        onOpenCows: () => _goCows(null),
                        onOpenAlerts: widget.onOpenAlerts,
                        onOpenEleveurs: widget.onOpenEleveurs,
                      ),
                      if (widget.onAddCow != null ||
                          widget.onScanCow != null) ...[
                        const SizedBox(height: AppTheme.space16),
                        _HomeQuickActions(
                          onAddCow: widget.onAddCow,
                          onScanCow: widget.onScanCow,
                        ),
                      ],
                      const SizedBox(height: AppTheme.space8),
                      SectionTitle(
                        AppStrings.appetiteSummaryTitle,
                        trailing: TextButton.icon(
                          onPressed: () => _goCows(null),
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: const Text(AppStrings.seeAll),
                        ),
                      ),
                      _HomeAppetiteCard(
                        counts: counts,
                        cowCount: data.cows.length,
                        hasAppetiteData: hasAppetiteData,
                        onSelect: _goCows,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}