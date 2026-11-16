import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/appetite_analysis.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/cow_telemetry.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/cow_service.dart';
import '../../services/ws_service.dart';
import '../../widgets/instruction_sheet.dart';
import '../../widgets/widgets.dart';
import 'cow_form_screen.dart';

class CowDetailScreen extends StatefulWidget {
  const CowDetailScreen({super.key, required this.cowId});

  final String cowId;

  @override
  State<CowDetailScreen> createState() => _CowDetailScreenState();
}

class _CowDetailData {
  const _CowDetailData({
    required this.cow,
    required this.latest,
    required this.daily,
    required this.dailyDocuments,
    required this.dailyIndex,
    required this.newestDate,
    required this.trendDays,
    required this.trend,
    required this.probabilities,
    required this.currentAppetite,
    required this.realtime,
    required this.dispatch,
    required this.prediction,
    required this.predictionUnavailable,
  });

  final Cow cow;
  final DailySummary? latest;
  final List<DailySummary> daily;
  final List<dynamic> dailyDocuments;
  final Map<String, Map<String, dynamic>> dailyIndex;
  final DateTime newestDate;
  final List<DateTime> trendDays;
  final List<CowAppetiteClass?> trend;
  final Map<CowAppetiteClass, double>? probabilities;
  final CowAppetiteClass? currentAppetite;
  final List<RealtimeReading> realtime;
  final List<DispatchRecord> dispatch;
  final Object? prediction;
  final bool predictionUnavailable;
}

class _PredictionResult {
  const _PredictionResult(this.value, this.unavailable);

  final Object? value;
  final bool unavailable;
}

class _CowDetailScreenState extends State<CowDetailScreen> {
  final _service = CowService.instance;
  _CowDetailData? _data;
  bool _loading = true;
  String? _error;
  bool _deleting = false;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  Map<String, dynamic>? _latestReading;
  bool _live = false;
  bool _liveError = false;
  DateTime? _pickedDay;
  Map<String, dynamic>? _dayRecord;
  CowTelemetry? _dayTelemetry;
  bool _dayLoading = false;
  String? _dayError;

  @override
  void initState() {
    super.initState();
    _wsSubscription = WsService.instance.events.listen(_onSocketEvent);
    _refresh();
  }

  @override
  void dispose() {
    unawaited(_wsSubscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  void _onSocketEvent(Map<String, dynamic> event) {
    if (event['type'] == 'error') {
      if (mounted) {
        setState(() {
          _live = false;
          _liveError = true;
        });
      }
      return;
    }
    final cowId = event['cow_id'];
    final data = event['data'];
    final profileId = _data?.cow.internalId;
    if ((cowId != widget.cowId && cowId != profileId) ||
        data is! Map<String, dynamic>) {
      return;
    }
    setState(() {
      _latestReading = {...?_latestReading, ...data};
      _live = true;
      _liveError = false;
    });
  }

  Future<_PredictionResult> _loadPrediction() async {
    try {
      return _PredictionResult(
        await _service.predict(widget.cowId),
        false,
      );
    } on PredictionUnavailableException {
      return const _PredictionResult(null, true);
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
      final cow = await _service.profile(widget.cowId);
      final results = await Future.wait<Object?>([
        _service.latest(widget.cowId),
        _service.daily(widget.cowId, limit: 7),
        _service.dailyDocuments(widget.cowId, limit: 366),
        _service.realtime(widget.cowId, limit: 10),
        _service.dispatch(widget.cowId, limit: 10),
        _loadPrediction(),
      ]);
      final documents = results[2] as List<dynamic>;
      final index = AppetiteAnalysis.indexDaily(documents);
      final newestDate = AppetiteAnalysis.newestRecordDate(documents);
      final trendDays = AppetiteAnalysis.trendWindow(documents);
      final trend = [
        for (final day in trendDays)
          AppetiteAnalysis.appetiteOf(index[AppetiteAnalysis.dayKey(day)]),
      ];
      final newestDocument = index[AppetiteAnalysis.dayKey(newestDate)];
      final probabilities = newestDocument == null
          ? null
          : AppetiteAnalysis.probabilitiesOf(newestDocument);
      final currentAppetite = AppetiteAnalysis.appetiteOf(newestDocument);
      final prediction = results[5] as _PredictionResult;
      if (!mounted) return;
      final realtime = results[3] as List<RealtimeReading>;
      if (!_live && realtime.isNotEmpty) {
        _latestReading = _readingMap(realtime.first);
      }
      setState(() {
        _data = _CowDetailData(
          cow: cow,
          latest: results[0] as DailySummary?,
          daily: results[1] as List<DailySummary>,
          dailyDocuments: documents,
          dailyIndex: index,
          newestDate: newestDate,
          trendDays: trendDays,
          trend: trend,
          probabilities: probabilities,
          currentAppetite: currentAppetite,
          realtime: realtime,
          dispatch: results[4] as List<DispatchRecord>,
          prediction: prediction.value,
          predictionUnavailable: prediction.unavailable,
        );
        _pickedDay = null;
        _dayRecord = null;
        _dayTelemetry = null;
        _dayError = null;
        _dayLoading = false;
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

  Future<void> _edit(Cow cow) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CowFormScreen(cow: cow)),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _delete(Cow cow) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteCow),
        content: const Text(AppStrings.deleteCowConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.deleteCow),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await _service.deleteProfile(cow.id);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.isNetworkError ? AppStrings.networkError : error.message,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _openAlert(Cow cow, String action) {
    showInstructionSheet(context, cow: cow, presetAction: action);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: Text(data?.cow.id ?? widget.cowId),
        actions: [
          if (data != null) ...[
            IconButton(
              onPressed: _deleting ? null : () => _edit(data.cow),
              tooltip: AppStrings.editCow,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: _deleting ? null : () => _delete(data.cow),
              tooltip: AppStrings.deleteCow,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            if (_loading && data == null)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && data == null)
              _messageState(
                _error!,
                TextButton(
                  onPressed: () => _refresh(),
                  child: const Text(AppStrings.retry),
                ),
              )
            else if (data != null) ...[
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.warn),
                  ),
                ),
              _profile(data.cow),
              const SectionTitle(AppStrings.appetiteVerdictTitle),
              _verdictCard(data),
              const SectionTitle(AppStrings.appetiteConfidenceTitle),
              _confidenceCard(data),
              const SectionTitle(AppStrings.appetiteTrendTitle),
              _trendCard(data),
              const SectionTitle(AppStrings.pickDay),
              _daySearchSection(data),
              const SectionTitle(AppStrings.cowLatestTitle),
              if (data.latest == null)
                const AppCard(child: Text(AppStrings.noLatestCowData))
              else
                _dailySummary(data.latest!),
              const SectionTitle(AppStrings.cowLatestReadingTitle),
              _latestReadingCard(),
              const SectionTitle(AppStrings.cowHistoryTitle),
              if (data.daily.isEmpty)
                const AppCard(child: Text(AppStrings.emptyCowHistory))
              else
                for (final summary in data.daily.where(
                  (item) =>
                      data.latest == null ||
                      !_sameDate(item.date, data.latest!.date),
                )) ...[
                  _dailySummary(summary),
                  const SizedBox(height: 8),
                ],
              const SectionTitle(AppStrings.cowRealtimeTitle),
              if (data.realtime.isEmpty)
                const AppCard(child: Text(AppStrings.emptyCowRealtime))
              else
                for (final reading in data.realtime) ...[
                  _realtimeReading(reading),
                  const SizedBox(height: 8),
                ],
              const SectionTitle(AppStrings.cowDispatchTitle),
              if (data.dispatch.isEmpty)
                const AppCard(child: Text(AppStrings.emptyCowDispatch))
              else
                for (final record in data.dispatch) ...[
                  AppCard(
                    child: Text(
                      '${record.date} · ${record.foodG.toStringAsFixed(1)} g · ${record.servedAt}',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              const SectionTitle(AppStrings.cowPredictionTitle),
              AppCard(
                child: data.predictionUnavailable
                    ? const Text(AppStrings.predictionUnavailable)
                    : SelectableText(
                        const JsonEncoder.withIndent('  ')
                            .convert(data.prediction),
                      ),
              ),
              const SectionTitle(AppStrings.alertsTitle),
              OutlinedButton.icon(
                onPressed: () => _openAlert(data.cow, 'sell'),
                icon: const Icon(Icons.sell_outlined),
                label: const Text(AppStrings.alertActionSell),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openAlert(data.cow, 'vet'),
                icon: const Icon(Icons.medical_services_outlined),
                label: const Text(AppStrings.alertActionVet),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openAlert(data.cow, 'butcher'),
                icon: const Icon(Icons.storefront_outlined),
                label: const Text(AppStrings.alertActionButcher),
              ),
              if (_deleting)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _verdictCard(_CowDetailData data) {
    final probabilities = data.probabilities;
    if (probabilities == null) {
      final appetite = data.currentAppetite;
      return AppCard(
        child: Text(
          appetite == null
              ? AppStrings.appetiteDataUnavailable
              : '${_classLabel(appetite)} · ${AppStrings.appetiteDataUnavailable}',
        ),
      );
    }
    final top = AppetiteAnalysis.topOf(probabilities);
    final probability = probabilities[top] ?? 0;
    final advice = switch (top) {
      CowAppetiteClass.increasing => AppStrings.appetiteAdviceIncreasing,
      CowAppetiteClass.stable => AppStrings.appetiteAdviceStable,
      CowAppetiteClass.decreasing => AppStrings.appetiteAdviceDecreasing,
    };
    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 82,
            height: 82,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: probability,
                  strokeWidth: 8,
                  backgroundColor: AppTheme.line,
                  color: _classColor(top),
                ),
                Text(
                  AppetiteAnalysis.pct(probability),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _classLabel(top),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _classColor(top),
                  ),
                ),
                const SizedBox(height: 6),
                Text(advice),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _confidenceCard(_CowDetailData data) {
    final probabilities = data.probabilities;
    if (probabilities == null) {
      return const AppCard(child: Text(AppStrings.appetiteDataUnavailable));
    }
    return AppCard(
      child: Column(
        children: _probabilityRows(probabilities),
      ),
    );
  }

  List<Widget> _probabilityRows(
    Map<CowAppetiteClass, double> probabilities,
  ) =>
      [
        for (final appetite in const [
          CowAppetiteClass.decreasing,
          CowAppetiteClass.stable,
          CowAppetiteClass.increasing,
        ]) ...[
          Row(
            children: [
              Expanded(child: Text(_confidenceLabel(appetite))),
              Text(
                AppetiteAnalysis.pct(probabilities[appetite] ?? 0),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: probabilities[appetite] ?? 0,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: _classColor(appetite),
            backgroundColor: AppTheme.line,
          ),
          if (appetite != CowAppetiteClass.increasing)
            const SizedBox(height: 12),
        ],
      ];

  Widget _trendCard(_CowDetailData data) {
    if (data.dailyDocuments.isEmpty) {
      return const AppCard(child: Text(AppStrings.appetiteDataUnavailable));
    }
    return AppCard(
      child: Column(
        children: [
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _TrendPainter(data.trend),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_date(data.trendDays.first)),
              Text(_date(data.newestDate)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _legend(
                AppStrings.trendIncreasing,
                _classColor(CowAppetiteClass.increasing),
              ),
              _legend(
                AppStrings.trendStable,
                _classColor(CowAppetiteClass.stable),
              ),
              _legend(
                AppStrings.trendDecreasing,
                _classColor(CowAppetiteClass.decreasing),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );

  Widget _daySearchSection(_CowDetailData data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: () => _pickDay(data),
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              _pickedDay == null
                  ? AppStrings.pickDay
                  : AppetiteAnalysis.dayKey(_pickedDay!),
            ),
          ),
          if (_pickedDay != null) ...[
            const SizedBox(height: 10),
            if (_dayLoading)
              const Center(child: CircularProgressIndicator())
            else if (_dayError != null)
              AppCard(child: Text(_dayError!))
            else if (_dayRecord == null)
              const AppCard(child: Text(AppStrings.daySearchNoData))
            else
              _dayResult(),
          ],
        ],
      );

  Future<void> _pickDay(_CowDetailData data) async {
    final newest = data.newestDate;
    final firstDate = DateTime(newest.year - 1, newest.month, newest.day);
    final requestedInitial = _pickedDay ?? newest;
    final initialDate = requestedInitial.isBefore(firstDate)
        ? firstDate
        : requestedInitial.isAfter(newest)
            ? newest
            : requestedInitial;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: newest,
      helpText: AppStrings.pickDay,
    );
    if (picked == null || !mounted) return;
    final day = DateTime(picked.year, picked.month, picked.day);
    final record = data.dailyIndex[AppetiteAnalysis.dayKey(day)];
    setState(() {
      _pickedDay = day;
      _dayRecord = record;
      _dayTelemetry = null;
      _dayError = null;
      _dayLoading = record != null;
    });
    if (record == null) return;

    try {
      final telemetry = CowTelemetry.fromJson(record);
      if (!mounted) return;
      setState(() {
        _dayTelemetry = telemetry;
        _dayLoading = false;
      });
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('CowTelemetry.fromJson failed: $error\n$stackTrace');
      }
      if (!mounted) return;
      setState(() {
        _dayError = AppStrings.daySearchDataError;
        _dayLoading = false;
      });
    }
  }

  Widget _dayResult() {
    final record = _dayRecord;
    final telemetry = _dayTelemetry;
    if (record == null || telemetry == null) {
      return const AppCard(child: Text(AppStrings.daySearchNoData));
    }
    final appetite = AppetiteAnalysis.appetiteOf(record);
    final probabilities = AppetiteAnalysis.probabilitiesOf(record);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appetite == null
                ? AppStrings.appetiteDataUnavailable
                : _classLabel(appetite),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (probabilities != null) ...[
            const SizedBox(height: 12),
            ..._probabilityRows(probabilities),
          ],
          const Divider(height: 24),
          _statLine(
            AppStrings.foodConsumedLabel,
            '${telemetry.totalFoodConsumedG} g',
          ),
          _statLine(
            AppStrings.feedOfferedLabel,
            '${telemetry.totalFeedOfferedG} g',
          ),
          _statLine(
            AppStrings.eatingTimeLabel,
            '${telemetry.totalEatingMinutes} min',
          ),
          _statLine(AppStrings.visitsLabel, '${telemetry.visits}'),
          _statLine(
            AppStrings.noFoodVisitsLabel,
            '${telemetry.noFoodVisits}',
          ),
          _statLine(
            AppStrings.averageMealLabel,
            '${telemetry.averageMealDurationMin} min',
          ),
          _statLine(
            AppStrings.firstVisitLabel,
            _displayValue(telemetry.firstVisitHour),
          ),
          _statLine(
            AppStrings.lastVisitLabel,
            _displayValue(telemetry.lastVisitHour),
          ),
        ],
      ),
    );
  }

  Widget _latestReadingCard() {
    final reading = _latestReading;
    if (reading == null) {
      return AppCard(
        child: Text(
          _liveError
              ? AppStrings.liveUpdatesUnavailable
              : AppStrings.emptyCowRealtime,
        ),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatRawTimestamp(reading['timestamp']),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (_live) const Pill(AppStrings.liveBadge, AppTheme.primary),
            ],
          ),
          if (_liveError) ...[
            const SizedBox(height: 8),
            const Text(
              AppStrings.liveUpdatesUnavailable,
              style: TextStyle(color: AppTheme.textGrey),
            ),
          ],
          const SizedBox(height: 8),
          _statLine(AppStrings.visitsLabel, _displayValue(reading['visits'])),
          _statLine(
            AppStrings.foodConsumedLabel,
            _displayValue(reading['food_consumed_g']),
          ),
          _statLine(
            AppStrings.feedOfferedLabel,
            _displayValue(reading['feed_offered_g']),
          ),
          _statLine(
            AppStrings.eatingTimeLabel,
            _displayValue(reading['eating_minutes']),
          ),
          _statLine(
            AppStrings.noFoodVisitsLabel,
            _displayValue(reading['no_food_visits']),
          ),
        ],
      ),
    );
  }

  String _classLabel(CowAppetiteClass appetite) => switch (appetite) {
        CowAppetiteClass.increasing => AppStrings.trendIncreasing,
        CowAppetiteClass.stable => AppStrings.trendStable,
        CowAppetiteClass.decreasing => AppStrings.trendDecreasing,
      };

  String _confidenceLabel(CowAppetiteClass appetite) => switch (appetite) {
        CowAppetiteClass.increasing => AppStrings.appetiteHigh,
        CowAppetiteClass.stable => AppStrings.appetiteNormal,
        CowAppetiteClass.decreasing => AppStrings.appetiteLow,
      };

  Color _classColor(CowAppetiteClass appetite) => switch (appetite) {
        CowAppetiteClass.increasing => Appetite.high.color,
        CowAppetiteClass.stable => Appetite.normal.color,
        CowAppetiteClass.decreasing => Appetite.low.color,
      };

  Map<String, dynamic> _readingMap(RealtimeReading reading) => {
        'cow_id': reading.cowId,
        'timestamp': reading.timestamp.toIso8601String(),
        'visits': reading.visits,
        'food_consumed_g': reading.foodConsumedG,
        'feed_offered_g': reading.feedOfferedG,
        'eating_minutes': reading.eatingMinutes,
        'no_food_visits': reading.noFoodVisits,
      };

  String _formatRawTimestamp(Object? value) {
    if (value is! String || value.isEmpty) return '—';
    final parsed = DateTime.tryParse(value);
    return parsed == null ? value : _dateTime(parsed.toLocal());
  }

  Widget _profile(Cow cow) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(AppStrings.profileTitle),
          DataSheet([
            (Icons.tag_rounded, AppStrings.cowIdLabel, cow.id),
            (Icons.category_outlined, AppStrings.cowTypeLabel, cow.type.label),
            (Icons.pets_outlined, AppStrings.cowBreedLabel, cow.breed),
            (
              Icons.cake_outlined,
              AppStrings.cowBirthDateLabel,
              _date(cow.birthDate)
            ),
            (
              Icons.monitor_weight_outlined,
              AppStrings.cowWeightLabel,
              '${cow.weightKg.toStringAsFixed(1)} kg'
            ),
            (
              Icons.timelapse_outlined,
              AppStrings.cowAgeLabel,
              '${cow.ageMonths} mo'
            ),
            (Icons.nfc_rounded, AppStrings.cowNfcLabel, cow.nfcUid ?? '—'),
          ]),
        ],
      );

  Widget _dailySummary(DailySummary summary) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _date(summary.date),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _statLine(
              AppStrings.foodConsumedLabel,
              '${summary.totalFoodConsumedG} g',
            ),
            _statLine(
              AppStrings.feedOfferedLabel,
              '${summary.totalFeedOfferedG} g',
            ),
            _statLine(
              AppStrings.eatingTimeLabel,
              '${summary.totalEatingMinutes} min',
            ),
            _statLine(AppStrings.visitsLabel, '${summary.visits}'),
            _statLine(
              AppStrings.noFoodVisitsLabel,
              '${summary.noFoodVisits}',
            ),
            _statLine(
              AppStrings.averageMealLabel,
              '${summary.averageMealDurationMin} min',
            ),
            if (summary.appetite != null) ...[
              const Divider(height: 18),
              Row(
                children: [
                  Expanded(child: Text(summary.appetite!.label)),
                  if (summary.appetitePct != null)
                    Text(
                      summary.appetitePct!.entries
                          .map((entry) =>
                              '${entry.key}: ${entry.value.toStringAsFixed(1)}%')
                          .join(' · '),
                    ),
                ],
              ),
            ],
          ],
        ),
      );

  Widget _realtimeReading(RealtimeReading reading) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_dateTime(reading.timestamp)),
            const SizedBox(height: 8),
            _statLine('Visits', _displayValue(reading.visits)),
            _statLine('Food consumed', _displayValue(reading.foodConsumedG)),
            _statLine('Feed offered', _displayValue(reading.feedOfferedG)),
            _statLine('Eating time', _displayValue(reading.eatingMinutes)),
            _statLine(
                'Visits without food', _displayValue(reading.noFoodVisits)),
          ],
        ),
      );

  Widget _statLine(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppTheme.textGrey),
              ),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  Widget _messageState(String message, Widget action) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            action,
          ],
        ),
      );

  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _dateTime(DateTime value) =>
      '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  String _displayValue(Object? value) => value?.toString() ?? '—';

  bool _sameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.values);

  final List<CowAppetiteClass?> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const horizontalInset = 10.0;
    const verticalInset = 12.0;
    final width = size.width - horizontalInset * 2;
    final height = size.height - verticalInset * 2;
    final points = [
      for (var index = 0; index < values.length; index++)
        Offset(
          horizontalInset +
              width * index / (values.length > 1 ? values.length - 1 : 1),
          verticalInset + height * _verticalPosition(values[index]),
        ),
    ];

    for (var index = 1; index < values.length; index++) {
      final previous = values[index - 1];
      final current = values[index];
      if (previous == null || current == null) continue;
      canvas.drawLine(
        points[index - 1],
        points[index],
        Paint()
          ..color = AppTheme.textGrey.withAlpha(100)
          ..strokeWidth = 2,
      );
    }

    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      final color = value == null ? AppTheme.line : _trendColor(value);
      if (index == values.length - 1) {
        canvas.drawCircle(
          points[index],
          9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppTheme.primary,
        );
      }
      canvas.drawCircle(points[index], 5, Paint()..color = color);
    }
  }

  double _verticalPosition(CowAppetiteClass? appetite) => switch (appetite) {
        CowAppetiteClass.increasing => 0.18,
        CowAppetiteClass.stable => 0.5,
        CowAppetiteClass.decreasing => 0.82,
        null => 0.5,
      };

  Color _trendColor(CowAppetiteClass appetite) => switch (appetite) {
        CowAppetiteClass.increasing => Appetite.high.color,
        CowAppetiteClass.stable => Appetite.normal.color,
        CowAppetiteClass.decreasing => Appetite.low.color,
      };

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) => oldDelegate.values != values;
}
