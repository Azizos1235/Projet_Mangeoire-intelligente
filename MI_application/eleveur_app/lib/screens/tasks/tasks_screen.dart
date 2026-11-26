import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/farm_task.dart';
import '../../services/api_client.dart';
import '../../services/cow_service.dart';
import '../../services/task_service.dart';
import '../../widgets/task_type_style.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    this.isActive = true,
    this.onTasksChanged,
    this.onLoadingChanged,
    this.onErrorChanged,
    this.cowService,
    this.taskService,
  });

  final bool isActive;
  final ValueChanged<List<FarmTask>>? onTasksChanged;
  final ValueChanged<bool>? onLoadingChanged;
  final ValueChanged<Object?>? onErrorChanged;
  final CowProfileService? cowService;
  final TaskServiceApi? taskService;

  @override
  TasksScreenState createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen> with WidgetsBindingObserver {
  List<FarmTask> _tasks = [];
  String? _errorKey;
  String? _busyTaskId;
  bool _loading = true;
  Future<bool>? _loadInFlight;
  Timer? _pollTimer;

  CowProfileService get _cowService => widget.cowService ?? CowService.instance;
  TaskServiceApi get _taskService => widget.taskService ?? TaskService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
    _syncPolling();
  }

  @override
  void didUpdateWidget(covariant TasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) _syncPolling(refreshNow: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncPolling(refreshNow: state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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
    if (refreshNow) unawaited(_load(showLoading: false));
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_load(showLoading: false)),
    );
  }

  Future<bool> refreshFromHome() => _load(showLoading: false);

  Future<void> openWeightTaskFromHome(FarmTask task) => _openWeightTask(task);

  Future<bool> _load({bool showLoading = true}) {
    final existing = _loadInFlight;
    if (existing != null) return existing;
    late final Future<bool> tracked;
    tracked = _performLoad(showLoading: showLoading).whenComplete(() {
      if (identical(_loadInFlight, tracked)) _loadInFlight = null;
    });
    _loadInFlight = tracked;
    return tracked;
  }

  Future<bool> _performLoad({required bool showLoading}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _errorKey = null;
      });
      widget.onLoadingChanged?.call(true);
      widget.onErrorChanged?.call(null);
    }
    try {
      final tasks = await _taskService.listMyPendingTasks();
      if (!mounted) return false;
      setState(() {
        _tasks = tasks;
        _errorKey = null;
      });
      widget.onTasksChanged?.call(List.unmodifiable(_tasks));
      widget.onErrorChanged?.call(null);
      return true;
    } on ApiException catch (error) {
      widget.onErrorChanged?.call(error);
      if (mounted && _tasks.isEmpty) {
        setState(() => _errorKey = error.messageKey);
      }
      return false;
    } on FormatException catch (error) {
      widget.onErrorChanged?.call(error);
      if (mounted && _tasks.isEmpty) {
        setState(() => _errorKey = 'tasks_load_error');
      }
      return false;
    } catch (error) {
      widget.onErrorChanged?.call(error);
      if (mounted && _tasks.isEmpty) {
        setState(() => _errorKey = 'tasks_load_error');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (showLoading) widget.onLoadingChanged?.call(false);
      }
    }
  }

  Future<void> _confirmTask(FarmTask task) async {
    final completion = await showDialog<_TaskCompletionInput>(
      context: context,
      builder: (_) => _CompletionDialog(
        checkWeight: task.taskType == 'check_weight',
      ),
    );
    if (completion == null || _busyTaskId != null) return;

    setState(() => _busyTaskId = task.id);
    try {
      await _taskService.markDone(
        task.id,
        completedWeightKg: completion.weightKg,
        completionNote: completion.note,
      );
      if (!mounted) return;
      _removeCompletedTask(task);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busyTaskId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(error.messageKey))),
      );
    } on FormatException {
      if (!mounted) return;
      setState(() => _busyTaskId = null);
      _showTaskError();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyTaskId = null);
      _showTaskError();
    }
  }

  Future<void> _openWeightTask(FarmTask task) async {
    final cowId = task.cowId;
    if (cowId == null || cowId.trim().isEmpty) {
      await _confirmTask(task);
      return;
    }
    if (_busyTaskId != null) return;

    setState(() => _busyTaskId = task.id);
    try {
      final profile = await _cowService.getProfile(cowId);
      if (!mounted) return;
      final completed = await Navigator.of(context).pushNamed<bool>(
        AppRoutes.editCowProfile,
        arguments: EditProfileRouteArguments(profile: profile, task: task),
      );
      if (!mounted) return;
      if (completed == true) {
        _removeCompletedTask(task);
      } else {
        setState(() => _busyTaskId = null);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyTaskId = null);
      final confirmWithoutProfile = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.tr('task_profile_load_title')),
          content: Text(context.tr('task_profile_load_error')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('task_fallback_confirm')),
            ),
          ],
        ),
      );
      if (confirmWithoutProfile == true && mounted) {
        await _confirmTask(task);
      }
    }
  }

  void _removeCompletedTask(FarmTask task) {
    setState(() {
      _tasks.removeWhere((item) => item.id == task.id);
      _busyTaskId = null;
    });
    widget.onTasksChanged?.call(List.unmodifiable(_tasks));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('task_completed_success'))),
    );
  }

  void _showTaskError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('task_update_error'))),
    );
  }

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('tasks_title'))),
        body: RefreshIndicator(
          onRefresh: () async {
            await _load();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (_loading && _tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorKey != null && _tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        context.tr(_errorKey!),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.error),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _load,
                        child: Text(context.tr('tasks_retry')),
                      ),
                    ],
                  ),
                )
              else if (_tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(36),
                  child: Center(
                    child: Text(
                      context.tr('tasks_empty'),
                      style: const TextStyle(color: AppTheme.textGrey),
                    ),
                  ),
                )
              else
                for (final task in _tasks)
                  _TaskCard(
                    task: task,
                    busy: _busyTaskId == task.id,
                    formatDate: _formatDate,
                    onConfirm: task.taskType == 'check_weight' &&
                            task.cowId?.trim().isNotEmpty == true
                        ? () => _openWeightTask(task)
                        : () => _confirmTask(task),
                    onTap: task.taskType == 'check_weight' &&
                            task.cowId?.trim().isNotEmpty == true
                        ? () => _openWeightTask(task)
                        : null,
                  ),
            ],
          ),
        ),
      );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.busy,
    required this.formatDate,
    required this.onConfirm,
    this.onTap,
  });

  final FarmTask task;
  final bool busy;
  final String Function(DateTime) formatDate;
  final VoidCallback onConfirm;
  final VoidCallback? onTap;

  String get _taskType =>
      _supportedTaskTypes.contains(task.taskType) ? task.taskType : 'custom';

  String _localizedTitle(BuildContext context) =>
      task.title == _defaultTaskTitle(_taskType)
          ? context.tr('task_title_$_taskType')
          : task.title;

  String _localizedPlan(BuildContext context) {
    final defaultPlan = _defaultTaskPlan(_taskType);
    if (defaultPlan.isEmpty) return task.plan;
    return task.plan == defaultPlan
        ? context.tr('task_plan_$_taskType')
        : task.plan;
  }

  @override
  Widget build(BuildContext context) {
    final dueAt = task.dueAt;
    final overdue = dueAt != null && dueAt.isBefore(DateTime.now().toUtc());
    final plan = _localizedPlan(context);
    final steps = plan
        .split('\n')
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList(growable: false);

    final opensWeightEditor = task.taskType == 'check_weight' &&
        task.cowId?.trim().isNotEmpty == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    TaskTypeStyle.iconFor(_taskType),
                    color: TaskTypeStyle.colorFor(_taskType),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('task_type_$_taskType'),
                      style: TextStyle(
                        color: TaskTypeStyle.colorFor(_taskType),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _localizedTitle(context),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              if (plan.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  context.tr('task_plan'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                for (final step in steps)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_box_outline_blank_rounded,
                          size: 19,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(step)),
                      ],
                    ),
                  ),
              ],
              if (task.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Text(task.description!),
              ],
              if (task.cowId != null) ...[
                const SizedBox(height: 10),
                Text('${context.tr('task_cow')}: ${task.cowId}'),
              ],
              if (dueAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${context.tr(overdue ? 'task_overdue' : 'task_due_at')}: '
                  '${formatDate(dueAt)}',
                  style: TextStyle(
                    color: overdue ? AppTheme.error : AppTheme.textGrey,
                    fontWeight: overdue ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  onPressed: busy ? null : onConfirm,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          context.tr(
                            opensWeightEditor
                                ? 'task_weigh_cow'
                                : 'task_confirm',
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _supportedTaskTypes = {
  'sell',
  'vet',
  'butcher',
  'check_weight',
  'custom',
};

String _defaultTaskTitle(String type) => switch (type) {
      'sell' => 'Vendre la vache',
      'vet' => 'Emmener la vache chez le vétérinaire',
      'butcher' => 'Envoyer la vache à la boucherie',
      'check_weight' => 'Vérifier le poids de la vache',
      _ => 'Nouvelle tâche',
    };

String _defaultTaskPlan(String type) => switch (type) {
      'sell' => 'Préparer la vache pour la vente.\n'
          'Vérifier son état et ses documents.\n'
          'Informer l’administrateur une fois la vente effectuée.',
      'vet' => 'Emmener la vache chez le vétérinaire.\n'
          'Expliquer les symptômes ou le motif de consultation.\n'
          'Suivre les recommandations du vétérinaire et faire un compte rendu.',
      'butcher' => 'Organiser le transport de la vache à la boucherie.\n'
          'Vérifier les documents nécessaires.\n'
          'Informer l’administrateur une fois la démarche effectuée.',
      'check_weight' => 'Peser la vache.\n'
          'Noter son poids.\n'
          'Vérifier son état corporel.\n'
          'Signaler toute anomalie.',
      _ => '',
    };

class _TaskCompletionInput {
  const _TaskCompletionInput({this.weightKg, this.note});

  final double? weightKg;
  final String? note;
}

class _CompletionDialog extends StatefulWidget {
  const _CompletionDialog({required this.checkWeight});

  final bool checkWeight;

  @override
  State<_CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<_CompletionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    final rawWeight = _weightController.text.trim();
    final note = _noteController.text.trim();
    Navigator.pop(
      context,
      _TaskCompletionInput(
        weightKg: rawWeight.isEmpty ? null : double.parse(rawWeight),
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(context.tr('task_confirm_title')),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('task_confirm_message')),
              if (widget.checkWeight) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: context.tr('task_weight_optional'),
                    suffixText: 'kg',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final weight = double.tryParse(value.trim());
                    return weight != null && weight > 0 && weight <= 1500
                        ? null
                        : context.tr('task_weight_invalid');
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.tr('task_note_optional'),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: _confirm,
            child: Text(context.tr('task_confirm')),
          ),
        ],
      );
}
