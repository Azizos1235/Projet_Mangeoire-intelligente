import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/alert.dart';
import '../../models/cow_appetite.dart';
import '../../models/cow_profile.dart';
import '../../services/alert_service.dart';
import '../../services/cow_service.dart';
import '../../services/ws_service.dart';
import '../../widgets/async_state.dart';
import '../../widgets/widgets.dart';
import '../cows/cows_by_class_screen.dart';

extension on CowAppetiteClass {
  // Adapt these l10n keys to the ones your old appetite labels used (a.key).
  String get key => 'appetite_$name';
  Color get color => switch (this) {
        CowAppetiteClass.increasing => AppTheme.primary,
        CowAppetiteClass.stable => AlertSeverity.info.color,
        CowAppetiteClass.decreasing => AlertSeverity.critical.color,
      };
  IconData get icon => switch (this) {
        CowAppetiteClass.increasing => Icons.trending_up_rounded,
        CowAppetiteClass.stable => Icons.trending_flat_rounded,
        CowAppetiteClass.decreasing => Icons.trending_down_rounded,
      };
}

class HomeTab extends StatefulWidget {
  final ValueChanged<int> onGoTab;
  final VoidCallback onAddCow;
  final VoidCallback onLogout;
  final String? name; // pass the éleveur name from eleveur_home_screen.dart
  @visibleForTesting
  final List<CowReference>? initialCows;
  @visibleForTesting
  final Map<String, String?> initialAppetiteByInternalId;

  const HomeTab({
    super.key,
    required this.onGoTab,
    required this.onAddCow,
    required this.onLogout,
    this.name,
    this.initialCows,
    this.initialAppetiteByInternalId = const {},
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<CowReference>? _cows;
  List<Alert> _alerts = const [];
  Map<String, String?> _appetiteByInternalId = const {};
  Object? _error;
  DateTime? _lastUpdate;
  StreamSubscription<Map<String, dynamic>>? _ws;

  @override
  void initState() {
    super.initState();
    _log('API base URL=${AppConfig.apiBaseUrl}');
    if (widget.initialCows != null) {
      _cows = widget.initialCows;
      _appetiteByInternalId = widget.initialAppetiteByInternalId;
    } else {
      _load();
      _ws = WsService.instance.events.listen((e) {
        if (!mounted || e['type'] != 'update') return;
        setState(() => _lastUpdate = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _ws?.cancel();
    super.dispose();
  }

  void _log(String m) {
    if (kDebugMode) debugPrint('[DBG] home $m');
  }

  Future<void> _load() async {
    final sw = Stopwatch()..start();
    _log('load start');
    try {
      final cowsFuture = CowService.instance.getCows();
      final alertsFuture = _loadAlertsSafely();
      final appetiteFuture = _loadAppetiteSafely();
      final cows = await cowsFuture;
      _log(
        'cows internalIds first5=${cows.take(5).map((cow) => cow.internalId).toList()}',
      );
      final alerts = await alertsFuture;
      final appetite = await appetiteFuture;
      if (!mounted) return;
      setState(() {
        _cows = cows;
        _alerts = alerts;
        if (appetite != null) {
          _appetiteByInternalId = appetite.appetiteByInternalId;
        }
        _error = null;
        _lastUpdate = DateTime.now();
      });
    } catch (e) {
      _log('load failed: $e');
      if (!mounted) return;
      // Keep old data on a failed refresh; only show error if nothing to show.
      if (_cows == null) setState(() => _error = e);
    } finally {
      _log('load end (${sw.elapsedMilliseconds}ms)');
    }
  }

  Future<List<Alert>> _loadAlertsSafely() async {
    try {
      return await AlertService.instance.getAlerts();
    } catch (error) {
      _log('alerts failed (ignored): $error');
      return const [];
    }
  }

  Future<HomeAppetiteResponse?> _loadAppetiteSafely() async {
    final stopwatch = Stopwatch()..start();
    _log('appetite request start');
    int? statusCode;
    try {
      final response = await CowService.instance.getAppetite(
        onStatus: (status) => statusCode = status,
      );
      _log(
        'appetite map keys first5='
        '${response.appetiteByInternalId.keys.take(5).toList()}',
      );
      _log(
        'appetite HTTP status=$statusCode '
        'rawFirst5=${response.rawLabels.take(5).toList()}',
      );
      final appetite = response.appetiteByInternalId;
      final counts = <String, int>{
        'increasing': 0,
        'stable': 0,
        'decreasing': 0,
      };
      for (final value in appetite.values) {
        if (counts.containsKey(value)) counts[value!] = counts[value]! + 1;
      }
      final withData = counts.values.fold<int>(0, (sum, count) => sum + count);
      _log(
        'appetite cows=${appetite.length} withData=$withData '
        'increasing=${counts['increasing']} stable=${counts['stable']} '
        'decreasing=${counts['decreasing']} noData=${appetite.length - withData}',
      );
      return response;
    } catch (error, stackTrace) {
      _log(
        'appetite HTTP status=${statusCode ?? 'not received'} '
        'failed (keeping previous values): $error',
      );
      if (kDebugMode) debugPrint('[DBG] appetite stack=$stackTrace');
      return null;
    } finally {
      _log('appetite request end (${stopwatch.elapsedMilliseconds}ms)');
    }
  }

  void _retry() {
    setState(() {
      _error = null;
    });
    _load();
  }

  void _openCows() => widget.onGoTab(1);

  void _openAppetiteFilter(CowAppetiteFilter filter) {
    final cows = _cows;
    if (cows == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CowsByClassScreen(
          initialEntries: cowAppetiteEntries(cows, _appetiteByInternalId),
          initialFilter: filter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cows = _cows;
    if (cows == null) {
      if (_error != null) {
        return SafeArea(child: AppLoadError(error: _error!, onRetry: _retry));
      }
      return const Center(child: CircularProgressIndicator());
    }

    final entries = cowAppetiteEntries(cows, _appetiteByInternalId);
    final counts = cowAppetiteCounts(entries);
    final unread = _alerts.where((a) => !a.isRead).length;
    final low = counts[CowAppetiteClass.decreasing] ?? 0;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // ---- Header
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('hello'),
                        style: const TextStyle(
                            fontSize: 15, color: AppTheme.textGrey)),
                    Text(widget.name ?? context.tr('dashboard_title'),
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textDark)),
                  ],
                ),
              ),
              const LangToggle(),
              IconButton(
                tooltip: context.tr('logout'),
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout, color: AppTheme.textGrey),
              ),
            ]),
            const SizedBox(height: 18),

            HomeAppetiteSummary(
              entries: entries,
              lastUpdate: _lastUpdate,
              onSelectFilter: _openAppetiteFilter,
            ),
            const SizedBox(height: 16),

            // ---- What to do now
            _TodoCard(
              unread: unread,
              low: low,
              onAlerts: () => widget.onGoTab(2),
              onCows: _openCows,
            ),
            const SizedBox(height: 16),

            // ---- Quick actions
            Row(children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.nfc_rounded,
                  label: context.tr('quick_nfc'),
                  onTap: () => widget.onGoTab(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.add_circle_outline_rounded,
                  label: context.tr('add_cow'),
                  onTap: widget.onAddCow,
                ),
              )
            ]),
          ],
        ),
      ),
    );
  }
}

class HomeAppetiteSummary extends StatelessWidget {
  final List<CowAppetiteEntry> entries;
  final DateTime? lastUpdate;
  final ValueChanged<CowAppetiteFilter> onSelectFilter;

  const HomeAppetiteSummary({
    super.key,
    required this.entries,
    required this.lastUpdate,
    required this.onSelectFilter,
  });

  @override
  Widget build(BuildContext context) {
    final counts = cowAppetiteCounts(entries);
    final noDataCount = entries.where((entry) => entry.appetite == null).length;
    final values = [
      for (final appetite in CowAppetiteClass.values)
        (counts[appetite] ?? 0).toDouble(),
      noDataCount.toDouble(),
    ];

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(children: [
        Text(context.tr('herd_today'),
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primarySoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(context.tr('tap_hint'),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary)),
        ),
        const SizedBox(height: 22),
        GestureDetector(
          onTapUp: (details) {
            final index = homeAppetiteDonutSegmentAt(
              position: details.localPosition,
              size: const Size(250, 250),
              values: values,
            );
            if (index != null && index < CowAppetiteFilter.values.length) {
              onSelectFilter(CowAppetiteFilter.values[index]);
            }
          },
          child: SizedBox(
            width: 250,
            height: 250,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(
                key: const ValueKey('home-appetite-donut'),
                size: const Size(250, 250),
                painter: HomeAppetiteDonutPainter(
                  values: values,
                  colors: [
                    ...CowAppetiteClass.values.map((a) => a.color),
                    Colors.grey.shade300,
                  ],
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${entries.length}',
                    style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textDark)),
                Text(context.tr('cows_unit'),
                    style: const TextStyle(
                        fontSize: 15, color: AppTheme.textGrey)),
              ]),
            ]),
          ),
        ),
        if (noDataCount > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${context.tr('appetite_no_data')}: $noDataCount',
            style: const TextStyle(fontSize: 13, color: AppTheme.textGrey),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 10),
        Text(
          context.tr('last_update').replaceAll(
                '{time}',
                lastUpdate == null
                    ? '--:--'
                    : '${lastUpdate!.hour.toString().padLeft(2, '0')}:'
                        '${lastUpdate!.minute.toString().padLeft(2, '0')}',
              ),
          style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
        ),
        const SizedBox(height: 16),
        Row(children: [
          for (final appetite in CowAppetiteClass.values) ...[
            Expanded(
              child: _ClassTile(
                tileKey: ValueKey('home-appetite-tile-${appetite.name}'),
                a: appetite,
                count: counts[appetite] ?? 0,
                total: entries.length,
                onTap: () => onSelectFilter(
                  CowAppetiteFilter.values[appetite.index],
                ),
              ),
            ),
            if (appetite != CowAppetiteClass.decreasing)
              const SizedBox(width: 10),
          ],
        ]),
        const SizedBox(height: 10),
        _NoDataTile(
          tileKey: const ValueKey('home-appetite-tile-noData'),
          count: noDataCount,
          total: entries.length,
          onTap: () => onSelectFilter(CowAppetiteFilter.noData),
        ),
      ]),
    );
  }
}

class HomeAppetiteDonutSegment {
  final int index;
  final double startAngle;
  final double sweepAngle;
  final double paintedSweepAngle;

  const HomeAppetiteDonutSegment({
    required this.index,
    required this.startAngle,
    required this.sweepAngle,
    required this.paintedSweepAngle,
  });
}

List<HomeAppetiteDonutSegment> homeAppetiteDonutSegments(
  List<double> values,
) {
  final total = values.fold<double>(0, (sum, value) => sum + value);
  if (total <= 0) return const [];

  final segments = <HomeAppetiteDonutSegment>[];
  var startAngle = -math.pi / 2;
  for (var index = 0; index < values.length; index++) {
    final value = values[index];
    if (value <= 0) continue;
    final sweepAngle = value / total * math.pi * 2;
    segments.add(
      HomeAppetiteDonutSegment(
        index: index,
        startAngle: startAngle,
        sweepAngle: sweepAngle,
        paintedSweepAngle: math.max(sweepAngle - 0.03, 0.001),
      ),
    );
    startAngle += sweepAngle;
  }
  return segments;
}

int? homeAppetiteDonutSegmentAt({
  required Offset position,
  required Size size,
  required List<double> values,
  double strokeWidth = 28,
}) {
  final outerRadius = size.shortestSide / 2;
  final innerRadius = outerRadius - strokeWidth;
  final center = size.center(Offset.zero);
  final distance = (position - center).distance;
  if (distance < innerRadius || distance > outerRadius) return null;

  final angle = math.atan2(position.dy - center.dy, position.dx - center.dx);
  for (final segment in homeAppetiteDonutSegments(values)) {
    final offset = (angle - segment.startAngle + math.pi * 4) % (math.pi * 2);
    if (offset <= segment.paintedSweepAngle) return segment.index;
  }
  return null;
}

class HomeAppetiteDonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  HomeAppetiteDonutPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 28.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.grey.shade200;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base);
    for (final segment in homeAppetiteDonutSegments(values)) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = colors[segment.index];
      canvas.drawArc(
        arcRect,
        segment.startAngle,
        segment.paintedSweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(HomeAppetiteDonutPainter old) =>
      old.values != values || old.colors != colors;
}

class _ClassTile extends StatelessWidget {
  final Key tileKey;
  final CowAppetiteClass a;
  final int count;
  final int total;
  final VoidCallback onTap;
  const _ClassTile({
    required this.tileKey,
    required this.a,
    required this.count,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: tileKey,
      color: a.color.withValues(alpha: 0.12),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: SizedBox(
        width: double.infinity,
        child: Column(children: [
          Icon(a.icon, color: a.color, size: 30),
          const SizedBox(height: 6),
          Text('$count',
              key: ValueKey('appetite-count-${a.name}'),
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w900, color: a.color)),
          Text(context.tr(a.key),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark)),
          const SizedBox(height: 2),
          Text(total == 0 ? '0%' : '${(count * 100 / total).round()}%',
              key: ValueKey('appetite-percentage-${a.name}'),
              style: const TextStyle(fontSize: 12, color: AppTheme.textGrey)),
        ]),
      ),
    );
  }
}

class _NoDataTile extends StatelessWidget {
  final Key tileKey;
  final int count;
  final int total;
  final VoidCallback onTap;

  const _NoDataTile({
    required this.tileKey,
    required this.count,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppTheme.textGrey;
    return AppCard(
      key: tileKey,
      color: Colors.grey.shade100,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(children: [
        const Icon(Icons.help_outline_rounded, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            context.tr('appetite_no_data'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        Text(
          '$count',
          key: const ValueKey('appetite-count-noData'),
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          total == 0 ? '0%' : '${(count * 100 / total).round()}%',
          key: const ValueKey('appetite-percentage-noData'),
          style: const TextStyle(fontSize: 12, color: color),
        ),
      ]),
    );
  }
}

class _TodoCard extends StatelessWidget {
  final int unread;
  final int low;
  final VoidCallback onAlerts;
  final VoidCallback onCows;
  const _TodoCard(
      {required this.unread,
      required this.low,
      required this.onAlerts,
      required this.onCows});

  @override
  Widget build(BuildContext context) {
    final steps = <Widget>[];
    void add(IconData icon, Color color, String text, VoidCallback onTap) {
      steps.add(_Step(
          n: steps.length + 1,
          icon: icon,
          color: color,
          text: text,
          onTap: onTap));
    }

    if (unread > 0) {
      add(Icons.notifications_active_rounded, AlertSeverity.critical.color,
          context.tr('todo_alerts').replaceAll('{n}', '$unread'), onAlerts);
    }
    if (low > 0) {
      add(Icons.trending_down_rounded, CowAppetiteClass.decreasing.color,
          context.tr('todo_dec').replaceAll('{n}', '$low'), onCows);
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.tr('todo'),
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark)),
        const SizedBox(height: 6),
        if (steps.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(context.tr('todo_ok'),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary)),
          )
        else
          ...steps,
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;
  const _Step(
      {required this.n,
      required this.icon,
      required this.color,
      required this.text,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark)),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textGrey),
        ]),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: Column(children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
              color: AppTheme.primarySoft, shape: BoxShape.circle),
          child: Icon(icon, color: AppTheme.primary, size: 28),
        ),
        const SizedBox(height: 10),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark)),
      ]),
    );
  }
}
