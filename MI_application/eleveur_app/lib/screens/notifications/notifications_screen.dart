import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/l10n.dart';
import '../../models/alert.dart';
import '../../services/api_client.dart';
import '../../services/alert_service.dart';
import '../../core/theme.dart';
import '../../widgets/async_state.dart';
import '../../widgets/widgets.dart';

/// Displays alerts returned by the backend.
class NotificationsScreen extends StatefulWidget {
  final bool isActive;

  const NotificationsScreen({super.key, this.isActive = true});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  final _service = AlertService.instance;
  List<Alert>? _alerts;
  Object? _loadError;
  bool _loading = true;
  Timer? _pollTimer;
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadAlerts(showLoading: true));
    _syncPolling();
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncPolling(refreshNow: widget.isActive);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncPolling(refreshNow: true);
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _syncPolling({bool refreshNow = false}) {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!widget.isActive || !_isForeground) return;

    if (refreshNow) unawaited(_pollSilently());
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_pollSilently()),
    );
  }

  bool get _isForeground {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    return lifecycleState == null ||
        lifecycleState == AppLifecycleState.resumed;
  }

  Future<void> _loadAlerts({required bool showLoading}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final alerts = await _service.getAlerts();
      if (!mounted) return;
      setState(() {
        if (!_sameAlerts(_alerts, alerts)) _alerts = alerts;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  Future<void> _pollSilently() async {
    if (!mounted || !widget.isActive || !_isForeground) return;
    try {
      final alerts = await _service.getAlerts();
      if (!mounted || !widget.isActive || !_isForeground) return;
      if (_sameAlerts(_alerts, alerts) && _loadError == null) return;
      setState(() {
        if (!_sameAlerts(_alerts, alerts)) _alerts = alerts;
        _loadError = null;
      });
    } catch (_) {
      // Keep the current list and retry on the next poll.
    }
  }

  void _reload() => unawaited(_loadAlerts(showLoading: true));

  Future<void> _refresh() => _loadAlerts(showLoading: false);

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _errorMessage(Object error) =>
      error is ApiException ? context.tr(error.messageKey) : error.toString();

  Future<void> _markAllRead(List<Alert> alerts) async {
    try {
      await Future.wait([
        for (final alert in alerts.where((value) => !value.isRead))
          _service.markRead(alert.id),
      ]);
      if (mounted) _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error))),
      );
    }
  }

  Future<void> _open(Alert alert) async {
    if (!alert.isRead) {
      try {
        await _service.markRead(alert.id);
        if (mounted) _reload();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(error))),
        );
      }
    }

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    alert.cowId == null
                        ? Icons.admin_panel_settings_outlined
                        : Icons.pets_outlined,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    alert.cowId ?? sheetContext.tr('from_admin'),
                    style: const TextStyle(color: AppTheme.textGrey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                alert.message,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              if (alert.action != null ||
                  alert.appetiteClass != null ||
                  alert.appetitePct != null) ...[
                const SizedBox(height: 12),
                _AlertMetadata(alert: alert),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text(sheetContext.tr('got_it')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return AppLoadError(error: _loadError!, onRetry: _reload);
    }
    if (_loading || _alerts == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final all = _alerts!;
    final filtered = all.where((alert) {
      if (_filter == 1) return alert.cowId != null;
      if (_filter == 2) return alert.cowId == null;
      return true;
    }).toList(growable: false);
    final unread = all.where((alert) => !alert.isRead).length;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('alerts_title'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                if (unread > 0)
                  TextButton.icon(
                    onPressed: () => _markAllRead(all),
                    icon: const Icon(Icons.done_all_rounded, size: 20),
                    label: Text(context.tr('mark_all')),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: PillSwitch(
                labels: [
                  context.tr('f_all'),
                  context.tr('f_cows'),
                  context.tr('f_admin'),
                ],
                index: _filter,
                onChanged: (value) => setState(() => _filter = value),
              ),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              AppEmptyState(message: context.tr('no_notifs'))
            else
              for (final alert in filtered) ...[
                _AlertCard(alert: alert, onTap: () => _open(alert)),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

bool _sameAlerts(List<Alert>? previous, List<Alert> next) {
  if (previous == null || previous.length != next.length) return false;
  for (var index = 0; index < previous.length; index++) {
    final oldAlert = previous[index];
    final newAlert = next[index];
    if (oldAlert.id != newAlert.id ||
        oldAlert.message != newAlert.message ||
        oldAlert.severity != newAlert.severity ||
        oldAlert.cowId != newAlert.cowId ||
        oldAlert.adminId != newAlert.adminId ||
        oldAlert.action != newAlert.action ||
        oldAlert.type != newAlert.type ||
        oldAlert.appetiteClass != newAlert.appetiteClass ||
        !mapEquals(oldAlert.appetitePct, newAlert.appetitePct) ||
        oldAlert.status != newAlert.status ||
        oldAlert.createdAt != newAlert.createdAt ||
        oldAlert.readAt != newAlert.readAt) {
      return false;
    }
  }
  return true;
}

class _AlertCard extends StatelessWidget {
  final Alert alert;
  final VoidCallback onTap;

  const _AlertCard({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = alert.severity.color;
    return AppCard(
      onTap: onTap,
      color: alert.isRead ? Colors.white : color.withValues(alpha: 0.1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            alert.cowId == null
                ? Icons.admin_panel_settings_outlined
                : Icons.pets_outlined,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.message,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                if (alert.action != null ||
                    alert.appetiteClass != null ||
                    alert.appetitePct != null) ...[
                  const SizedBox(height: 8),
                  _AlertMetadata(alert: alert),
                ],
                const SizedBox(height: 8),
                Text(
                  alert.cowId ?? context.tr('from_admin'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _relativeTime(context, alert.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertMetadata extends StatelessWidget {
  final Alert alert;

  const _AlertMetadata({required this.alert});

  @override
  Widget build(BuildContext context) {
    final actionLabel = switch (alert.action) {
      'sell' => context.tr('alert_action_sell'),
      'vet' => context.tr('alert_action_vet'),
      'butcher' => context.tr('alert_action_butcher'),
      _ => null,
    };
    final appetiteClass = switch (alert.appetiteClass) {
      'low' => context.tr('appetite_low'),
      'normal' => context.tr('appetite_normal'),
      'high' => context.tr('appetite_high'),
      final value => value,
    };
    final percentages = alert.appetitePct?.entries.map((entry) {
      final label = switch (entry.key) {
        'low' => context.tr('appetite_low'),
        'normal' => context.tr('appetite_normal'),
        'high' => context.tr('appetite_high'),
        _ => entry.key,
      };
      final value = entry.value % 1 == 0
          ? entry.value.toInt().toString()
          : entry.value.toString();
      return '$label: $value%';
    }).join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (actionLabel != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (appetiteClass != null || percentages?.isNotEmpty == true) ...[
          if (actionLabel != null) const SizedBox(height: 6),
          Text(
            [
              if (appetiteClass != null)
                '${context.tr('alert_appetite')}: $appetiteClass',
              if (percentages?.isNotEmpty == true) percentages!,
            ].join(' · '),
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textGrey,
            ),
          ),
        ],
      ],
    );
  }
}

String _relativeTime(BuildContext context, DateTime date) {
  final elapsed = DateTime.now().difference(date);
  final value = elapsed.inMinutes < 60
      ? '${elapsed.inMinutes} ${context.tr('u_min')}'
      : elapsed.inHours < 24
          ? '${elapsed.inHours} ${context.tr('u_h')}'
          : '${elapsed.inDays} ${context.tr('u_d')}';
  return context.tr('ago').replaceAll('{t}', value);
}
