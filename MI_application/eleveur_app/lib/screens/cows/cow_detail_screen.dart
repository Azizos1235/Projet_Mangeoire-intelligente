import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/cow_appetite.dart';
import '../../models/cow_profile.dart';
import '../../models/cow_telemetry.dart';
import '../../services/api_client.dart';
import '../../services/cow_service.dart';
import '../../services/ws_service.dart';
import '../../widgets/async_state.dart';
import '../../widgets/widgets.dart';
import 'edit_profile_screen.dart';

class CowDetailScreen extends StatefulWidget {
  final CowReference cow;

  const CowDetailScreen({super.key, required this.cow});

  @override
  State<CowDetailScreen> createState() => _CowDetailScreenState();
}

class _CowDetailScreenState extends State<CowDetailScreen> {
  static const int _trendDays = 14;

  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

  // Profile
  CowProfile? _profile;
  Object? _profileError;

  // Latest realtime reading (REST first, then live via websocket)
  Map<String, dynamic>? _reading;
  Object? _readingError;
  bool _readingLoading = true;
  bool _live = false;

  // Appetite trend (last 14 days)
  List<CowAppetiteClass?> _trend = const [];
  List<DateTime> _days = const [];
  CowAppetiteClass? _currentAppetite;
  Object? _trendError;
  bool _trendLoading = true;

  // AI verdict: percentage of each appetite class, read from the latest
  // daily summary (sums to 1)
  Map<CowAppetiteClass, double>? _probs;

  // Calendar search
  DateTime? _pickedDay;
  bool _dayLoading = false;
  Object? _dayError;
  Map<String, dynamic>? _dayRecord;
  Map<String, Map<String, dynamic>>? _allDaily;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadReading();
    _loadTrend();
    _wsSubscription = WsService.instance.events.listen(_onWsEvent);
  }

  @override
  void dispose() {
    final subscription = _wsSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }

  // ------------------------------------------------------------ loading

  Future<void> _loadProfile() async {
    try {
      final profile =
          await CowService.instance.getProfile(widget.cow.internalId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _profileError = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _profileError = error);
    } on FormatException catch (error) {
      if (mounted) setState(() => _profileError = error);
    }
  }

  void _retryProfile() {
    setState(() => _profileError = null);
    _loadProfile();
  }

  Future<void> _loadReading() async {
    try {
      final response =
          await CowService.instance.getRealtime(widget.cow.internalId);
      Map<String, dynamic>? latest;
      if (response is List &&
          response.isNotEmpty &&
          response.first is Map<String, dynamic>) {
        latest = response.first as Map<String, dynamic>;
      }
      if (!mounted) return;
      setState(() {
        // Live websocket values received meanwhile stay on top of the REST ones.
        _reading = _live ? {...?latest, ...?_reading} : latest;
        _readingError = null;
        _readingLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _readingError = error;
        _readingLoading = false;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _readingError = error;
        _readingLoading = false;
      });
    }
  }

  void _retryReading() {
    setState(() {
      _readingLoading = true;
      _readingError = null;
    });
    _loadReading();
  }

  void _onWsEvent(Map<String, dynamic> event) {
    if (!mounted || event['type'] != 'update') return;
    final id = event['cow_id'];
    if (id != widget.cow.internalId && id != widget.cow.cowId) return;
    final data = event['data'];
    if (data is! Map<String, dynamic>) return;
    setState(() {
      _reading = {...?_reading, ...data};
      _readingError = null;
      _readingLoading = false;
      _live = true;
    });
  }

  Future<void> _loadTrend() async {
    try {
      final response =
          await CowService.instance.getDaily(widget.cow.internalId);
      final index = _indexDaily(response);
      final today = DateUtils.dateOnly(DateTime.now());
      final days = <DateTime>[
        for (var i = 0; i < _trendDays; i++)
          DateTime(today.year, today.month, today.day - (_trendDays - 1 - i)),
      ];
      final values = <CowAppetiteClass?>[
        for (final day in days) _appetiteOf(index[_dayKey(day)]),
      ];

      // Most recent daily record that has an appetite class.
      CowAppetiteClass? current;
      if (response is List) {
        for (final item in response) {
          if (item is! Map<String, dynamic>) continue;
          final appetite = _appetiteOf(item);
          if (appetite != null) {
            current = appetite;
            break;
          }
        }
      }

      // Percentages of the most recent daily record that has them.
      Map<CowAppetiteClass, double>? probs;
      if (response is List) {
        for (final item in response) {
          if (item is! Map<String, dynamic>) continue;
          final found = _probabilitiesOf(item);
          if (found != null) {
            probs = found;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _probs = probs;
        _days = days;
        _trend = values;
        _currentAppetite = current;
        _trendError = null;
        _trendLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _trendError = error;
        _trendLoading = false;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _trendError = error;
        _trendLoading = false;
      });
    }
  }

  void _retryTrend() {
    setState(() {
      _trendLoading = true;
      _trendError = null;
    });
    _loadTrend();
  }

  Future<void> _pickDay() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDay ?? today,
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: today,
      helpText: context.tr('pick_day'),
    );
    if (picked == null || !mounted) return;
    final day = DateUtils.dateOnly(picked);
    setState(() {
      _pickedDay = day;
      _dayLoading = true;
      _dayError = null;
      _dayRecord = null;
    });
    try {
      var all = _allDaily;
      if (all == null) {
        final response = await ApiClient.instance.get(
          '/daily/${Uri.encodeComponent(widget.cow.internalId)}',
          query: {'limit': 366},
        );
        all = _indexDaily(response);
        _allDaily = all;
      }
      if (!mounted) return;
      setState(() {
        _dayRecord = all![_dayKey(day)];
        _dayLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _dayError = error;
        _dayLoading = false;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _dayError = error;
        _dayLoading = false;
      });
    }
  }

  Future<void> _openEdit(CowProfile profile) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)),
    );
    if (changed != true || !mounted) return;
    await _loadProfile();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.tr('profile_saved'))));
  }

  // ------------------------------------------------------------ helpers

  static String _dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Daily documents indexed by calendar day (newest document wins).
  static Map<String, Map<String, dynamic>> _indexDaily(dynamic response) {
    final result = <String, Map<String, dynamic>>{};
    if (response is! List) return result;
    for (final item in response) {
      if (item is! Map<String, dynamic>) continue;
      final date = item['date'];
      if (date is! String || date.length < 10) continue;
      result.putIfAbsent(date.substring(0, 10), () => item);
    }
    return result;
  }

  /// Reads the appetite class stored in a daily document. The backend stores
  /// low / normal / high (or increasing / stable / decreasing).
  static CowAppetiteClass? _appetiteOf(Map<String, dynamic>? doc) {
    if (doc == null) return null;
    Object? value = doc['appetite_class'] ?? doc['appetite'];
    if (value is Map) {
      value = value['label'] ??
          value['class'] ??
          value['value'] ??
          value['appetite'];
    }
    if (value is! String) {
      // No label stored: use the class with the highest percentage.
      final probs = _probabilitiesOf(doc);
      return probs == null ? null : _topOf(probs);
    }
    return _classFromLabel(value);
  }

  static CowAppetiteClass? _classFromLabel(String label) =>
      switch (AppetiteTrendStyle.parse(label)) {
        AppetiteTrend.increasing => CowAppetiteClass.increasing,
        AppetiteTrend.stable => CowAppetiteClass.stable,
        AppetiteTrend.decreasing => CowAppetiteClass.decreasing,
        _ => null,
      };

  /// Reads the class percentages stored in a daily_summaries document.
  /// Looks first for a map of class -> number (low/normal/high or
  /// increasing/stable/decreasing), then for flat fields such as
  /// "appetite_pct_low". Values are normalised so they sum to 1, which also
  /// handles 0-100 percentages.
  static Map<CowAppetiteClass, double>? _probabilitiesOf(
      Map<String, dynamic> doc) {
    final hint = RegExp(r'appetite|prob|pct|percent|score|confidence');
    final maps = <Map>[
      for (final e in doc.entries)
        if (e.value is Map && hint.hasMatch(e.key.toLowerCase()))
          e.value as Map,
      for (final e in doc.entries)
        if (e.value is Map && !hint.hasMatch(e.key.toLowerCase()))
          e.value as Map,
    ];
    for (final source in maps) {
      final raw = <CowAppetiteClass, double>{};
      for (final entry in source.entries) {
        final key = entry.key;
        final value = entry.value;
        final cls = key is String ? _classFromLabel(key) : null;
        if (cls != null && value is num && value.isFinite && value >= 0) {
          raw[cls] = value.toDouble();
        }
      }
      final result = _normalise(raw);
      if (result != null) return result;
    }

    // Flat fields, e.g. appetite_pct_low / appetite_prob_high.
    final flatHint = RegExp(r'pct|prob|percent|score');
    final raw = <CowAppetiteClass, double>{};
    for (final entry in doc.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;
      if (value is! num ||
          !value.isFinite ||
          value < 0 ||
          !flatHint.hasMatch(key)) {
        continue;
      }
      for (final token in key.split(RegExp(r'[_\-\s]'))) {
        final cls = _classFromLabel(token);
        if (cls != null) {
          raw[cls] = value.toDouble();
          break;
        }
      }
    }
    return _normalise(raw);
  }

  static Map<CowAppetiteClass, double>? _normalise(
      Map<CowAppetiteClass, double> raw) {
    final sum = raw.values.fold<double>(0, (a, b) => a + b);
    if (raw.length < 2 || sum <= 0) return null;
    return {for (final c in CowAppetiteClass.values) c: (raw[c] ?? 0) / sum};
  }

  static CowAppetiteClass _topOf(Map<CowAppetiteClass, double> probs) {
    var best = CowAppetiteClass.values.first;
    for (final c in CowAppetiteClass.values) {
      if (probs[c]! > probs[best]!) best = c;
    }
    return best;
  }

  static String _pct(double p) => '${(p * 100).round()}%';

  static String _fmt(Object? v) {
    if (v == null) return '—';
    if (v is num) {
      return v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
    }
    return v.toString();
  }

  static String _formatTimestamp(Object? value) {
    if (value is! String || value.isEmpty) return '—';
    var text = value;
    if (!RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(text)) text = '${text}Z';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static String _ageText(BuildContext c, int m) {
    if (m < 24) return '$m ${c.tr('months')}';
    final y = m ~/ 12, r = m % 12;
    return r == 0
        ? '$y ${c.tr('years')}'
        : '$y ${c.tr('years')} $r ${c.tr('months')}';
  }

  static String _breedLabel(BuildContext c, String breed) {
    final key = breed.trim().toLowerCase();
    final translated = c.tr(key);
    return translated == key ? breed : translated;
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🐄', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(widget.cow.displayId),
        ]),
        actions: const [LangToggle(), SizedBox(width: 16)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // 1) Verdict
          _verdictCard(context),
          const SizedBox(height: 14),

          // 2) Modifier le profil
          _editCard(context),
          const SizedBox(height: 14),

          // 2b) Confiance du modèle : pourcentage de chaque classe
          _confidenceCard(context),
          const SizedBox(height: 14),

          // 3) Dernières données (realtime_readings, live via websocket)
          _latestCard(context),
          const SizedBox(height: 14),

          // 4) Tendance de l'appétit sur 14 jours
          _trendCard(context),
          const SizedBox(height: 14),

          // 5) Recherche par jour
          _calendarCard(context),
          const SizedBox(height: 22),

          // 6) Profil
          Text(context.tr('profile'),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark)),
          const SizedBox(height: 12),
          _profileSection(context),
        ],
      ),
    );
  }

  Widget _verdictCard(BuildContext context) {
    // The AI verdict wins; without it, fall back to the latest daily class.
    var a = _currentAppetite;
    double? conf;
    final probs = _probs;
    if (probs != null) {
      var best = CowAppetiteClass.values.first;
      for (final c in CowAppetiteClass.values) {
        if (probs[c]! > probs[best]!) best = c;
      }
      a = best;
      conf = probs[best];
    }
    final color = a?.color ?? AppTheme.textGrey;
    return AppCard(
      color: a?.lightColor ?? Colors.white,
      child: Row(children: [
        SizedBox(
          width: 112,
          height: 112,
          child: _trendLoading
              ? const Center(child: CircularProgressIndicator())
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: conf ?? (a == null ? 0.0 : 1.0)),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: v,
                          strokeWidth: 11,
                          color: color,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      if (conf != null)
                        Text(_pct(v),
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: color))
                      else
                        Icon(a?.icon ?? Icons.help_outline_rounded,
                            size: 44, color: color),
                    ],
                  ),
                ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('appetite'),
                  style:
                      const TextStyle(fontSize: 14, color: AppTheme.textGrey)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(a?.icon ?? Icons.help_outline_rounded,
                    color: color, size: 30),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(context.tr(a?.labelKey ?? 'appetite_no_data'),
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: color)),
                ),
              ]),
              if (a != null) ...[
                const SizedBox(height: 6),
                Text(context.tr('advice_${a.name}'),
                    style: const TextStyle(
                        fontSize: 14, height: 1.4, color: AppTheme.textDark)),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _editCard(BuildContext context) {
    final profile = _profile;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: AppTheme.primarySoft, shape: BoxShape.circle),
            child: const Icon(Icons.edit_outlined, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(context.tr('edit_profile'),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark)),
          ),
        ]),
        const SizedBox(height: 14),
        Text(context.tr('edit_profile_hint'),
            style: const TextStyle(fontSize: 14, color: AppTheme.textGrey)),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: profile == null ? null : () => _openEdit(profile),
          child: Text(context.tr('modify')),
        ),
      ]),
    );
  }

  Widget _confidenceCard(BuildContext context) {
    final probs = _probs;
    var top = CowAppetiteClass.values.first;
    if (probs != null) {
      for (final c in CowAppetiteClass.values) {
        if (probs[c]! > probs[top]!) top = c;
      }
    }
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.psychology_alt_outlined, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.tr('confidence'),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark)),
          ),
        ]),
        const SizedBox(height: 14),
        if (_trendLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_trendError != null)
          AppLoadError(error: _trendError!, onRetry: _retryTrend)
        else if (probs == null)
          Text(context.tr('appetite_data_unavailable'),
              style: const TextStyle(color: AppTheme.textGrey))
        else ...[
          for (final a in CowAppetiteClass.values) ...[
            _probRow(context, a, probs[a]!, a == top),
            if (a != CowAppetiteClass.values.last) const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          Text(context.tr('model_note'),
              style: const TextStyle(fontSize: 12, color: AppTheme.textGrey)),
        ],
      ]),
    );
  }

  Widget _probRow(
      BuildContext context, CowAppetiteClass a, double p, bool top) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: top ? a.lightColor : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(a.icon, color: a.color, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(context.tr(a.labelKey),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: top ? FontWeight.w800 : FontWeight.w500,
                          color: AppTheme.textDark)),
                ),
                Text(_pct(p),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: a.color)),
              ]),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: p),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 10,
                    color: a.color,
                    backgroundColor: a.lightColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _latestCard(BuildContext context) {
    final r = _reading;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: AppTheme.primarySoft, shape: BoxShape.circle),
            child: const Icon(Icons.sensors_rounded, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(context.tr('telemetry_title'),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark)),
          ),
          if (_live) _liveBadge(context),
        ]),
        const SizedBox(height: 10),
        if (_readingLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_readingError != null && r == null)
          AppLoadError(error: _readingError!, onRetry: _retryReading)
        else if (r == null)
          Text(context.tr('no_reading'),
              style: const TextStyle(color: AppTheme.textGrey))
        else ...[
          _TelemetryValue(
              label: context.tr('telemetry_date'),
              value: _formatTimestamp(r['timestamp'])),
          _TelemetryValue(
              label: context.tr('visits'), value: _fmt(r['visits'])),
          _TelemetryValue(
              label: context.tr('food_consumed'),
              value: _fmt(r['food_consumed_g'])),
          _TelemetryValue(
              label: context.tr('feed_offered'),
              value: _fmt(r['feed_offered_g'])),
          _TelemetryValue(
              label: context.tr('eating_minutes'),
              value: _fmt(r['eating_minutes'])),
          _TelemetryValue(
              label: context.tr('no_food_visits'),
              value: _fmt(r['no_food_visits'])),
        ],
      ]),
    );
  }

  Widget _liveBadge(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: AppTheme.primarySoft,
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: AppTheme.primary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(context.tr('live_now'),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary)),
        ]),
      );

  Widget _trendCard(BuildContext context) {
    final hasData = _trend.any((v) => v != null);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.tr('trend_14d'),
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark)),
        const SizedBox(height: 14),
        if (_trendLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_trendError != null)
          AppLoadError(error: _trendError!, onRetry: _retryTrend)
        else if (!hasData)
          Text(context.tr('no_trend_data'),
              style: const TextStyle(color: AppTheme.textGrey))
        else ...[
          SizedBox(
            height: 190,
            width: double.infinity,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: CustomPaint(painter: _TrendPainter(_trend, _days)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 14, runSpacing: 6, children: [
            for (final a in CowAppetiteClass.values)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(a.icon, size: 16, color: a.color),
                const SizedBox(width: 4),
                Text(context.tr(a.labelKey),
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textGrey)),
              ]),
          ]),
        ],
      ]),
    );
  }

  Widget _calendarCard(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: AppTheme.primarySoft, shape: BoxShape.circle),
            child: const Icon(Icons.calendar_month_outlined,
                color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(context.tr('search_by_day'),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark)),
          ),
        ]),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _pickDay,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(_pickedDay == null
              ? context.tr('pick_day')
              : _dayKey(_pickedDay!)),
        ),
        if (_pickedDay != null) ...[
          const SizedBox(height: 14),
          _dayResult(context),
        ],
      ]),
    );
  }

  Widget _dayResult(BuildContext context) {
    if (_dayLoading) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = _dayError;
    if (error != null) {
      return Text(
          context.tr(
              error is ApiException ? error.messageKey : 'api_error_generic'),
          style: const TextStyle(color: AppTheme.error));
    }
    final record = _dayRecord;
    if (record == null) {
      return Text(context.tr('no_data_day'),
          style: const TextStyle(color: AppTheme.textGrey));
    }
    final CowTelemetry t;
    try {
      t = CowTelemetry.fromJson(record);
    } on FormatException {
      return Text(context.tr('api_error_generic'),
          style: const TextStyle(color: AppTheme.error));
    }
    final appetite = _appetiteOf(record);
    final dayProbs = _probabilitiesOf(record);
    return Column(children: [
      if (appetite != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Expanded(
              child: Text(context.tr('appetite'),
                  style: const TextStyle(color: AppTheme.textGrey)),
            ),
            Icon(appetite.icon, size: 18, color: appetite.color),
            const SizedBox(width: 4),
            Text(context.tr(appetite.labelKey),
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: appetite.color)),
          ]),
        ),
      if (dayProbs != null) ...[
        const SizedBox(height: 4),
        for (final a in CowAppetiteClass.values) ...[
          _probRow(context, a, dayProbs[a]!, a == _topOf(dayProbs)),
          const SizedBox(height: 6),
        ],
      ],
      _TelemetryValue(
          label: context.tr('telemetry_age'),
          value: t.ageMonths?.toString() ?? '—'),
      _TelemetryValue(
          label: context.tr('food_consumed'), value: '${t.foodConsumedGrams}'),
      _TelemetryValue(
          label: context.tr('feed_offered'), value: '${t.feedOfferedGrams}'),
      _TelemetryValue(label: context.tr('visits'), value: '${t.visits}'),
      _TelemetryValue(
          label: context.tr('eating_minutes'), value: '${t.eatingMinutes}'),
      _TelemetryValue(
          label: context.tr('meal_duration'),
          value: t.averageMealDurationMinutes.toString()),
      _TelemetryValue(
          label: context.tr('no_food_visits'), value: '${t.visitsWithoutFood}'),
      _TelemetryValue(
          label: context.tr('first_visit'),
          value: t.firstVisitHour?.toString() ?? '—'),
      _TelemetryValue(
          label: context.tr('last_visit'),
          value: t.lastVisitHour?.toString() ?? '—'),
    ]);
  }

  Widget _profileSection(BuildContext context) {
    final p = _profile;
    if (p == null) {
      final error = _profileError;
      if (error != null) {
        return AppLoadError(error: error, onRetry: _retryProfile);
      }
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(children: [
      Row(children: [
        Expanded(
            child: _Info(Icons.cake_outlined, context.tr('age'),
                _ageText(context, p.ageMonths.round()))),
        const SizedBox(width: 12),
        Expanded(
            child: _Info(Icons.monitor_weight_outlined, context.tr('weight'),
                '${p.weightKg.round()} ${context.tr('kg')}')),
      ]),
      const SizedBox(height: 12),
      _Info(Icons.pets_outlined, context.tr('breed'),
          _breedLabel(context, p.breed)),
      if (p.nfcUid != null) ...[
        const SizedBox(height: 12),
        _Info(Icons.nfc_rounded, context.tr('rfid'), p.nfcUid!),
      ],
    ]);
  }
}

/// Appetite trend: one dot per day, higher = eats more. Days without data are
/// left empty.
class _TrendPainter extends CustomPainter {
  final List<CowAppetiteClass?> values;
  final List<DateTime> days;

  _TrendPainter(this.values, this.days);

  static const _levels = [
    CowAppetiteClass.increasing,
    CowAppetiteClass.stable,
    CowAppetiteClass.decreasing,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const left = 12.0, right = 12.0, top = 14.0, bottom = 28.0;
    final n = values.length;
    if (n == 0) return;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    double xAt(int i) => left + (n == 1 ? w / 2 : w * i / (n - 1));
    double yAt(CowAppetiteClass c) => top + h * _levels.indexOf(c) / 2;

    final grid = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 1;
    for (final level in _levels) {
      final y = yAt(level);
      canvas.drawLine(Offset(left, y), Offset(left + w, y), grid);
    }

    final line = Paint()
      ..color = AppTheme.textGrey.withValues(alpha: 0.45)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < n; i++) {
      final a = values[i - 1], b = values[i];
      if (a == null || b == null) continue;
      canvas.drawLine(Offset(xAt(i - 1), yAt(a)), Offset(xAt(i), yAt(b)), line);
    }

    for (var i = 0; i < n; i++) {
      final v = values[i];
      final isToday = i == n - 1;
      if (v != null) {
        final c = Offset(xAt(i), yAt(v));
        canvas.drawCircle(c, isToday ? 9 : 7, Paint()..color = Colors.white);
        canvas.drawCircle(c, isToday ? 6.5 : 5, Paint()..color = v.color);
      }
      final tp = TextPainter(
        text: TextSpan(
          text: '${days[i].day}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
            color: isToday ? AppTheme.textDark : AppTheme.textGrey,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(xAt(i) - tp.width / 2, size.height - bottom + 10));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values != values || old.days != days;
}

class _TelemetryValue extends StatelessWidget {
  final String label;
  final String value;

  const _TelemetryValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child:
                Text(label, style: const TextStyle(color: AppTheme.textGrey)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppTheme.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Info(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
              color: AppTheme.primarySoft, shape: BoxShape.circle),
          child: Icon(icon, color: AppTheme.primary, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.textGrey)),
              Text(value,
                  maxLines: 2,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark)),
            ],
          ),
        ),
      ]),
    );
  }
}
