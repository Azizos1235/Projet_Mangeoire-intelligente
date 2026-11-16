import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/alert.dart';
import '../../models/models.dart';
import '../../services/alert_service.dart';
import '../../services/api_client.dart';
import '../../services/cow_service.dart';
import '../../services/eleveur_service.dart';
import '../../services/session.dart';
import '../../widgets/widgets.dart';
import '../alerts/alerts_screen.dart';
import '../cows/cows_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenCows});

  final void Function(Appetite? appetite) onOpenCows;

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
    required this.unreadAlerts,
    required this.eleveurCount,
  });

  final List<_DashboardCow> cows;
  final List<Alert> unreadAlerts;
  final int eleveurCount;
}

class _HomeScreenState extends State<HomeScreen> {
  _DashboardData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
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
          unreadAlerts: result[1] as List<Alert>,
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

  void _openAlerts() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const AlertsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Session.instance.currentUser.value;
    final name = user?['name'];
    final adminName = name is String ? name : '';
    final data = _data;
    final watch = data?.cows
            .where((entry) => entry.appetite == Appetite.low)
            .toList(growable: false) ??
        const <_DashboardCow>[];
    final counts = [
      for (final appetite in Appetite.values)
        data?.cows.where((entry) => entry.appetite == appetite).length ?? 0,
    ];
    final hasAppetiteData =
        data?.cows.any((entry) => entry.appetite != null) ?? false;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _header(adminName, watch.length, data?.unreadAlerts.length ?? 0),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: _loading && data == null
                  ? const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : data == null
                      ? _dashboardError(_error ?? AppStrings.requestFailed)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_loading) const LinearProgressIndicator(),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              _errorBanner(_error!),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: KpiTile(
                                    Icons.pets_rounded,
                                    '${data.cows.length}',
                                    AppStrings.dashboardCowCount,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: KpiTile(
                                    Icons.notifications_none_rounded,
                                    '${data.unreadAlerts.length}',
                                    AppStrings.dashboardAlerts,
                                    color: data.unreadAlerts.isEmpty
                                        ? AppTheme.primary
                                        : AppTheme.warn,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: KpiTile(
                                    Icons.groups_rounded,
                                    '${data.eleveurCount}',
                                    AppStrings.dashboardEleveurs,
                                  ),
                                ),
                              ],
                            ),
                            SectionTitle(
                              AppStrings.appetiteSummaryTitle,
                              trailing: TextButton(
                                onPressed: () => _goCows(null),
                                child: const Text(AppStrings.cowsTitle),
                              ),
                            ),
                            AppCard(
                              child: hasAppetiteData
                                  ? Row(
                                      children: [
                                        DonutChart(counts),
                                        const SizedBox(width: 18),
                                        Expanded(
                                          child: Column(
                                            children: [
                                              for (var index = 0;
                                                  index <
                                                      Appetite.values.length;
                                                  index++)
                                                _appetiteCount(
                                                  Appetite.values[index],
                                                  counts[index],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      AppStrings.appetiteDataUnavailable,
                                    ),
                            ),
                            SectionTitle(
                              AppStrings.cowsToWatchTitle,
                              trailing: TextButton(
                                onPressed: () => _goCows(Appetite.low),
                                child: const Text(AppStrings.cowsTitle),
                              ),
                            ),
                            if (watch.isEmpty)
                              const AppCard(
                                child: Text(
                                  AppStrings.noCowsToWatch,
                                  style: TextStyle(color: AppTheme.textGrey),
                                ),
                              ),
                            for (final entry in watch.take(3)) ...[
                              CowRow(
                                entry.cow,
                                latestAppetite: entry.appetite,
                                onChanged: () => _refresh(),
                              ),
                              const SizedBox(height: 10),
                            ],
                            OutlinedButton.icon(
                              onPressed: _openAlerts,
                              icon:
                                  const Icon(Icons.notifications_none_rounded),
                              label: Text(
                                '${AppStrings.alertsTitle} · ${data.unreadAlerts.length}',
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String adminName, int watchCount, int alertCount) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        adminName.isEmpty ? 'A' : adminName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Smart Élevage',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            adminName.isEmpty
                                ? 'Administrateur'
                                : 'Administrateur · $adminName',
                            style: TextStyle(
                              color: Colors.white.withAlpha(180),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _openAlerts,
                      tooltip: AppStrings.alertsTitle,
                      icon: Badge(
                        isLabelVisible: alertCount > 0,
                        label: Text('$alertCount'),
                        backgroundColor: AppTheme.warn,
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(24),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        watchCount == 0
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded,
                        color: watchCount == 0
                            ? Colors.white
                            : const Color(0xFFFFB380),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          watchCount == 0
                              ? AppStrings.noCowsToWatch
                              : '$watchCount low-appetite cow${watchCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _appetiteCount(Appetite appetite, int count) => InkWell(
        onTap: () => _goCows(appetite),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: appetite.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(appetite.trendLabel)),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppTheme.textGrey,
              ),
            ],
          ),
        ),
      );

  Widget _dashboardError(String message) => AppCard(
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            TextButton(
              onPressed: () => _refresh(),
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      );

  Widget _errorBanner(String message) => AppCard(
        color: AppTheme.amberSoft,
        child: Column(
          children: [
            Text(message, style: const TextStyle(color: AppTheme.warn)),
            TextButton(
              onPressed: () => _refresh(),
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      );
}
