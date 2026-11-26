import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_icons.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/alert.dart';
import '../../models/models.dart';
import '../../native/canaux.dart';
import '../../services/alert_service.dart';
import '../../services/api_client.dart';
import '../../services/cow_service.dart';
import '../../services/eleveur_service.dart';
import '../../services/task_service.dart';
import '../../widgets/async_state.dart';
import '../../widgets/task_form_dialog.dart';
import '../../widgets/widgets.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({
    super.key,
    this.isActive = true,
    this.onUnreadCountChanged,
    this.initialAlertId,
    this.onInitialAlertHandled,
    this.alertService,
  });

  final bool isActive;
  final ValueChanged<int>? onUnreadCountChanged;
  final String? initialAlertId;
  final ValueChanged<String>? onInitialAlertHandled;
  final AlertService? alertService;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with WidgetsBindingObserver {
  AlertService get _alertService =>
      widget.alertService ?? AlertService.instance;
  Timer? _pollTimer;
  List<Alert>? _alerts;
  String? _statusFilter;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isFetching = false;
  final Set<String> _sendingTaskIds = {};
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _alertKeys = {};
  String? _handledInitialAlertId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadAlerts(showLoading: true));
    _syncPolling();
  }

  @override
  void didUpdateWidget(covariant AlertsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) _syncPolling(refreshNow: true);
    if (oldWidget.initialAlertId != widget.initialAlertId &&
        widget.initialAlertId != null &&
        _alerts != null) {
      _handledInitialAlertId = null;
      _focusInitialAlert(_alerts!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncPolling(refreshNow: state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _isForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  void _syncPolling({bool refreshNow = false}) {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!widget.isActive || !_isForeground) return;
    if (refreshNow) unawaited(_loadAlerts());
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_loadAlerts()),
    );
  }

  Future<void> _loadAlerts({
    bool showLoading = false,
    bool force = false,
  }) async {
    if (_isFetching && !force) return;
    _isFetching = true;
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final alerts = await _alertService.listAlerts();
      if (!mounted) return;
      setState(() {
        _alerts = alerts.where((alert) => alert.source == 'system').toList();
        _errorMessage = null;
        _isLoading = false;
      });
      _focusInitialAlert(_alerts!);
      _markVisibleAlertsAsNotified();
      widget.onUnreadCountChanged?.call(
        alerts
            .where((alert) => alert.source == 'system' && !alert.isRead)
            .length,
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on FormatException {
      if (mounted) setState(() => _errorMessage = AppStrings.alertLoadError);
    } finally {
      _isFetching = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _focusInitialAlert(List<Alert> alerts) {
    final alertId = widget.initialAlertId;
    if (alertId == null || _handledInitialAlertId == alertId) return;
    Alert? target;
    for (final alert in alerts) {
      if (alert.id == alertId) {
        target = alert;
        break;
      }
    }
    if (target == null) {
      debugPrint('[MI_NOTIF] Alert target found=false alertId=$alertId');
      _handledInitialAlertId = alertId;
      widget.onInitialAlertHandled?.call(alertId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.alertNotFound)),
        );
      }
      return;
    }
    debugPrint('[MI_NOTIF] Alert target found=true alertId=$alertId');
    _handledInitialAlertId = alertId;
    _statusFilter = null;
    widget.onInitialAlertHandled?.call(alertId);
    if (!target.isRead) unawaited(_markRead(target));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _alertKeys[alertId]?.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 250),
          alignment: 0.15,
        );
      }
    });
  }

  void _markVisibleAlertsAsNotified() {
    if (!widget.isActive ||
        defaultTargetPlatform != TargetPlatform.android ||
        !_isForeground) {
      return;
    }
    final ids = (_alerts ?? [])
        .where(
          (alert) => _statusFilter == null || alert.status == _statusFilter,
        )
        .map((alert) => alert.id)
        .toList(growable: false);
    if (ids.isEmpty) return;
    unawaited(_markAsNotified(ids));
  }

  Future<void> _markAsNotified(List<String> ids) async {
    try {
      await CanauxNatifs.marquerCommeNotifie(ids);
    } on PlatformException catch (error) {
      FlutterError.reportError(FlutterErrorDetails(exception: error));
    } on MissingPluginException catch (error) {
      FlutterError.reportError(FlutterErrorDetails(exception: error));
    }
  }

  Future<void> _markRead(Alert alert) async {
    try {
      await _alertService.markRead(alert.id);
      await _loadAlerts(force: true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  Future<bool> _confirmDeleteAlert() async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(AppStrings.deleteAlertTitle),
          content: const Text(AppStrings.deleteAlertConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(AppStrings.delete),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _deleteAlert(Alert alert) async {
    if (!await _confirmDeleteAlert() || !mounted) return;
    final previousAlerts = _alerts;
    setState(() {
      _alerts =
          _alerts?.where((item) => item.id != alert.id).toList(growable: false);
    });
    widget.onUnreadCountChanged?.call(
      (_alerts ?? [])
          .where((item) => item.source == 'system' && !item.isRead)
          .length,
    );
    try {
      await _alertService.deleteAlert(alert.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.alertDeleted)),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 404) {
        widget.onUnreadCountChanged?.call(
          (_alerts ?? [])
              .where((item) => item.source == 'system' && !item.isRead)
              .length,
        );
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.alertDeletedOrMissing),
          ),
        );
        return;
      }
      setState(() => _alerts = previousAlerts);
      widget.onUnreadCountChanged?.call(
        (previousAlerts ?? [])
            .where((item) => item.source == 'system' && !item.isRead)
            .length,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          action: SnackBarAction(
            label: AppStrings.retry,
            onPressed: () => unawaited(_deleteAlert(alert)),
          ),
        ),
      );
    } on FormatException {
      if (!mounted) return;
      setState(() => _alerts = previousAlerts);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(AppStrings.invalidResponse),
          action: SnackBarAction(
            label: AppStrings.retry,
            onPressed: () => unawaited(_deleteAlert(alert)),
          ),
        ),
      );
    }
  }

  Future<void> _sendTask(Alert alert, String taskType) async {
    if (_sendingTaskIds.contains(alert.id)) return;
    setState(() => _sendingTaskIds.add(alert.id));
    try {
      final eleveurs = await EleveurService.instance.listEleveurs();
      final cows = await CowService.instance.listProfiles();
      if (!mounted) return;
      if (eleveurs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun éleveur disponible.')),
        );
        return;
      }
      final draft = await showDialog<TaskFormDraft>(
        context: context,
        builder: (_) => TaskFormDialog(
          eleveurs: eleveurs,
          cows: cows,
          initialCowId: alert.cowId,
          initialTaskType: taskType,
          initialEleveurId: _eleveurForCow(cows, alert.cowId),
          alertId: alert.id,
        ),
      );
      if (draft == null || !mounted) return;
      await TaskService.instance.createTask(
        eleveurId: draft.eleveurId,
        title: draft.title,
        description: draft.description,
        cowId: draft.cowId ?? alert.cowId,
        dueAt: draft.dueAt,
        taskType: draft.taskType,
        plan: draft.plan,
        alertId: alert.id,
      );
      await _loadAlerts(force: true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La réponse des tâches est invalide.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingTaskIds.remove(alert.id));
    }
  }

  String? _eleveurForCow(List<Cow> cows, String? cowId) {
    for (final cow in cows) {
      if (cow.id == cowId) return cow.eleveurId;
    }
    return null;
  }

  String _formatDate(DateTime dateTime) {
    final date = dateTime.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _filterChip(String? status, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _statusFilter == status,
          showCheckmark: false,
          onSelected: (_) {
            setState(() => _statusFilter = status);
            _markVisibleAlertsAsNotified();
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final alerts = (_alerts ?? []).where((alert) {
      return _statusFilter == null || alert.status == _statusFilter;
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.alertsTitle)),
      body: RefreshIndicator(
        onRefresh: () => _loadAlerts(),
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageSpacing,
            4,
            AppTheme.pageSpacing,
            24,
          ),
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
              AppCard(
                color: AppTheme.amberSoft,
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.warn),
                ),
              ),
            ],
            if (_isLoading && _alerts == null)
              const AppLoadingState(height: 180)
            else if (alerts.isEmpty)
              const AppEmptyState(
                message: AppStrings.alertEmpty,
                icon: AppIcons.alert,
              )
            else
              for (final alert in alerts) ...[
                AlertCard(
                  key: _alertKeys.putIfAbsent(alert.id, () => GlobalKey()),
                  alert: alert,
                  dateLabel: _formatDate(alert.createdAt),
                  sendingTask: _sendingTaskIds.contains(alert.id),
                  onSendTask: (taskType) => _sendTask(alert, taskType),
                  onMarkRead: () => _markRead(alert),
                  onDelete: () => _deleteAlert(alert),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.alert,
    required this.dateLabel,
    required this.sendingTask,
    required this.onSendTask,
    required this.onMarkRead,
    required this.onDelete,
  });

  final Alert alert;
  final String dateLabel;
  final bool sendingTask;
  final ValueChanged<String> onSendTask;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  AppetiteTrend get _appetiteTrend =>
      AppetiteTrendStyle.parse(alert.appetiteClass) ??
      (alert.type == 'appetite_high'
          ? AppetiteTrend.increasing
          : AppetiteTrend.decreasing);
  Color get _color =>
      alert.isTaskCompleted ? AppTheme.primary : _appetiteTrend.color;
  Color get _lightColor =>
      alert.isTaskCompleted ? AppTheme.primarySoft : _appetiteTrend.lightColor;
  IconData get _icon =>
      alert.isTaskCompleted ? AppIcons.task : _appetiteTrend.icon;

  String get _kindLabel =>
      alert.isTaskCompleted ? 'Tâche terminée' : _appetiteTrend.labelFr;

  @override
  Widget build(BuildContext context) => AppCard(
        color: alert.isRead ? AppTheme.surface : _lightColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, color: _color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _kindLabel,
                    style: TextStyle(
                      color: _color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Pill(
                  alert.isRead
                      ? AppStrings.alertStatusRead
                      : AppStrings.alertStatusUnread,
                  alert.isRead ? AppTheme.textGrey : AppTheme.primary,
                ),
                IconButton(
                  tooltip: AppStrings.delete,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              alert.message,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            if (alert.cowId != null) ...[
              const SizedBox(height: 8),
              Text('${AppStrings.alertCowLabel}: ${alert.cowId}'),
            ],
            if (alert.completedWeightKg != null) ...[
              const SizedBox(height: 8),
              Text(
                alert.previousWeightKg == null
                    ? 'Poids relevé : ${alert.completedWeightKg} kg'
                    : 'Ancien poids : ${alert.previousWeightKg} kg → '
                        '${alert.completedWeightKg} kg',
              ),
            ],
            if (alert.completionNote?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text('Note : ${alert.completionNote}'),
            ],
            const SizedBox(height: 8),
            Text(
              '${AppStrings.alertCreatedAtLabel}: $dateLabel',
              style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
            ),
            if (alert.isAppetite && alert.handled)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Pill('Tâche envoyée', AppTheme.primary),
              )
            else if (alert.isAppetite)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed:
                          sendingTask ? null : () => onSendTask('check_weight'),
                      icon: sendingTask
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.onPrimary,
                              ),
                            )
                          : const Icon(AppIcons.weight),
                      label: const Text('Peser'),
                    ),
                    OutlinedButton.icon(
                      onPressed: sendingTask ? null : () => onSendTask('vet'),
                      icon: const Icon(AppIcons.vet),
                      label: const Text('Vétérinaire'),
                    ),
                    OutlinedButton.icon(
                      onPressed: sendingTask ? null : () => onSendTask('sell'),
                      icon: const Icon(AppIcons.sell),
                      label: const Text('Vendre'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          sendingTask ? null : () => onSendTask('butcher'),
                      icon: const Icon(AppIcons.butcher),
                      label: const Text('Boucher'),
                    ),
                  ],
                ),
              ),
            if (!alert.isRead)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onMarkRead,
                  child: const Text('Marquer comme lu'),
                ),
              ),
          ],
        ),
      );
}
