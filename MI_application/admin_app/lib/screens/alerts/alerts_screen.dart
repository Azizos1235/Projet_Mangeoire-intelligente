import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/alert.dart';
import '../../services/alert_service.dart';
import '../../services/api_client.dart';
import '../../widgets/widgets.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  List<Alert>? _alerts;
  String? _statusFilter;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isFetching = false;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAlerts(showLoading: true, force: true);
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAlerts(force: true);
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  @override
  void dispose() {
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final lifecycleState = WidgetsBinding.instance.lifecycleState;
      if (lifecycleState == null ||
          lifecycleState == AppLifecycleState.resumed) {
        _loadAlerts();
      } else {
        _stopPolling();
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _loadAlerts({
    bool showLoading = false,
    bool force = false,
  }) async {
    if (_isFetching && !force) return;
    _isFetching = true;
    final requestVersion = ++_requestVersion;
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final alerts = await AlertService.instance.listAlerts(
        status: _statusFilter,
      );
      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          _alerts = alerts;
          _errorMessage = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _errorMessage = error.message);
      }
    } on FormatException {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _errorMessage = AppStrings.alertLoadError);
      }
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          _isLoading = false;
          _isFetching = false;
        });
      }
    }
  }

  void _selectFilter(String? status) {
    if (_statusFilter == status) return;
    setState(() => _statusFilter = status);
    _loadAlerts(showLoading: true, force: true);
  }

  String _severityLabel(AlertSeverity severity) => switch (severity) {
        AlertSeverity.info => AppStrings.alertSeverityInfo,
        AlertSeverity.warning => AppStrings.alertSeverityWarning,
        AlertSeverity.critical => AppStrings.alertSeverityCritical,
      };

  String _actionLabel(String action) => switch (action) {
        'sell' => AppStrings.alertActionSell,
        'vet' => AppStrings.alertActionVet,
        'butcher' => AppStrings.alertActionButcher,
        _ => action,
      };

  String _appetiteLabel(String appetiteClass) => switch (appetiteClass) {
        'low' => AppStrings.alertAppetiteLow,
        'normal' => AppStrings.alertAppetiteNormal,
        'high' => AppStrings.alertAppetiteHigh,
        _ => appetiteClass,
      };

  String _formatDate(DateTime dateTime) {
    final date = dateTime.toLocal();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} $hour:$minute';
  }

  Widget _filterChip(String? status, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _statusFilter == status,
          showCheckmark: false,
          selectedColor: AppTheme.primary,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: _statusFilter == status ? AppTheme.primary : AppTheme.line,
          ),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: _statusFilter == status ? Colors.white : AppTheme.textDark,
          ),
          onSelected: (_) => _selectFilter(status),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(AppStrings.alertsTitle)),
        body: RefreshIndicator(
          onRefresh: () => _loadAlerts(force: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(null, AppStrings.alertFilterAll),
                    _filterChip('unread', AppStrings.alertFilterUnread),
                    _filterChip('read', AppStrings.alertFilterRead),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.warn),
                ),
                if (_alerts == null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          _loadAlerts(showLoading: true, force: true),
                      child: const Text(AppStrings.retry),
                    ),
                  ),
              ],
              if (_isLoading && _alerts == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_alerts?.isEmpty ?? false)
                const Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(
                    child: Text(
                      AppStrings.alertEmpty,
                      style: TextStyle(color: AppTheme.textGrey),
                    ),
                  ),
                )
              else
                for (final alert in _alerts ?? []) ...[
                  _AlertCard(
                    alert: alert,
                    severityLabel: _severityLabel(alert.severity),
                    actionLabel: alert.action == null
                        ? null
                        : _actionLabel(alert.action!),
                    appetiteLabel: alert.appetiteClass == null
                        ? null
                        : _appetiteLabel(alert.appetiteClass!),
                    formatDate: _formatDate,
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.severityLabel,
    required this.actionLabel,
    required this.appetiteLabel,
    required this.formatDate,
  });

  final Alert alert;
  final String severityLabel;
  final String? actionLabel;
  final String? appetiteLabel;
  final String Function(DateTime) formatDate;

  String _formatPercentage(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();

  @override
  Widget build(BuildContext context) => AppCard(
        color: alert.isRead ? Colors.white : alert.severity.color.withAlpha(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    alert.message,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Pill(severityLabel, alert.severity.color),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Pill(
                  alert.isRead
                      ? AppStrings.alertStatusRead
                      : AppStrings.alertStatusUnread,
                  alert.isRead ? AppTheme.textGrey : AppTheme.primary,
                ),
                if (actionLabel != null) Pill(actionLabel!, AppTheme.accent),
                Pill('${AppStrings.alertTypeLabel}: ${alert.type}',
                    AppTheme.textGrey),
              ],
            ),
            if (alert.cowId != null) ...[
              const SizedBox(height: 8),
              Text(
                '${AppStrings.alertCowLabel}: ${alert.cowId}',
                style: const TextStyle(color: AppTheme.textGrey),
              ),
            ],
            if (appetiteLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                '${AppStrings.alertAppetiteClassLabel}: $appetiteLabel',
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (alert.appetitePct?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(
                '${AppStrings.alertAppetitePercentagesLabel}: '
                '${alert.appetitePct!.entries.map((entry) => '${entry.key}: ${_formatPercentage(entry.value)}%').join(' · ')}',
                style: const TextStyle(color: AppTheme.textGrey),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${AppStrings.alertCreatedAtLabel}: ${formatDate(alert.createdAt)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textGrey,
              ),
            ),
            if (alert.readAt != null)
              Text(
                '${AppStrings.alertReadAtLabel}: ${formatDate(alert.readAt!)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textGrey,
                ),
              ),
          ],
        ),
      );
}
