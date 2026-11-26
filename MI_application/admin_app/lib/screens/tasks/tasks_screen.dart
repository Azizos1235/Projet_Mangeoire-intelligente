import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/farm_task.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/cow_service.dart';
import '../../services/eleveur_service.dart';
import '../../services/task_service.dart';
import '../../widgets/async_state.dart';
import '../../widgets/widgets.dart';
import '../../widgets/task_form_dialog.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static const _pageSize = 100;

  List<FarmTask> _tasks = [];
  List<EleveurRecord> _eleveurs = [];
  List<Cow> _cows = [];
  String? _eleveurFilter;
  String _statusFilter = 'all';
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _skip = 0;
  bool _optionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _skip = 0;
      _hasMore = false;
    });
    try {
      if (!_optionsLoaded) {
        final eleveurs = await EleveurService.instance.listEleveurs();
        final cows = await CowService.instance.listProfiles();
        if (!mounted) return;
        _eleveurs = eleveurs;
        _cows = cows;
        _optionsLoaded = true;
      }
      final tasks = await TaskService.instance.listTasks(
        eleveurId: _eleveurFilter,
        status: _statusFilter == 'all' ? null : _statusFilter,
        limit: _pageSize,
        skip: 0,
      );
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _skip = tasks.length;
          _hasMore = tasks.length == _pageSize;
        });
      }
    } on ApiException {
      if (mounted) setState(() => _error = 'Unable to load tasks.');
    } on FormatException {
      if (mounted) setState(() => _error = 'The task response is invalid.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = await TaskService.instance.listTasks(
        eleveurId: _eleveurFilter,
        status: _statusFilter == 'all' ? null : _statusFilter,
        limit: _pageSize,
        skip: _skip,
      );
      if (mounted) {
        setState(() {
          _tasks = [..._tasks, ...nextPage];
          _skip += nextPage.length;
          _hasMore = nextPage.length == _pageSize;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _createTask() async {
    final draft = await showDialog<TaskFormDraft>(
      context: context,
      builder: (_) => TaskFormDialog(
        eleveurs: _eleveurs,
        cows: _cows,
      ),
    );
    if (draft == null || !mounted) return;
    try {
      await TaskService.instance.createTask(
        eleveurId: draft.eleveurId,
        title: draft.title,
        description: draft.description,
        cowId: draft.cowId,
        dueAt: draft.dueAt,
        taskType: draft.taskType,
        plan: draft.plan,
        alertId: draft.alertId,
      );
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.taskInvalidResponse)),
      );
    }
  }

  Future<void> _deleteTask(FarmTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.deleteTaskTitle),
        content: Text(
          '${AppStrings.deleteTaskConfirmation}\n« ${task.title} »',
        ),
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
    );
    if (confirmed != true) return;
    try {
      await TaskService.instance.deleteTask(task.id);
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Color _taskColor(String type) => switch (type) {
        'sell' => AppTheme.taskSell,
        'vet' => AppTheme.taskVet,
        'butcher' => AppTheme.taskButcher,
        'check_weight' => AppTheme.taskWeight,
        _ => AppTheme.primary,
      };

  IconData _taskIcon(String type) => switch (type) {
        'sell' => AppIcons.sell,
        'vet' => AppIcons.vet,
        'butcher' => AppIcons.butcher,
        'check_weight' => AppIcons.weight,
        _ => Icons.assignment_outlined,
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(AppStrings.tasksTitle)),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _eleveurs.isEmpty || _loading ? null : _createTask,
          icon: const Icon(Icons.add_task_rounded),
          label: const Text(AppStrings.assignTask),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pageSpacing,
              12,
              AppTheme.pageSpacing,
              100,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      key: ValueKey('eleveur-$_eleveurFilter'),
                      initialValue: _eleveurFilter ?? 'all',
                      decoration: const InputDecoration(
                        labelText: AppStrings.taskEleveurLabel,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text(AppStrings.allEleveurs),
                        ),
                        for (final eleveur in _eleveurs)
                          DropdownMenuItem(
                            value: eleveur.id,
                            child: Text(eleveur.name),
                          ),
                      ],
                      onChanged: _loading || _loadingMore
                          ? null
                          : (value) {
                              setState(() {
                                _eleveurFilter = value == 'all' ? null : value;
                                _tasks = [];
                              });
                              _load();
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      key: ValueKey('status-$_statusFilter'),
                      initialValue: _statusFilter,
                      decoration: const InputDecoration(
                        labelText: AppStrings.statusLabel,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(AppStrings.statusAll),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text(AppStrings.taskStatusPending),
                        ),
                        DropdownMenuItem(
                          value: 'done',
                          child: Text(AppStrings.taskStatusDone),
                        ),
                      ],
                      onChanged: _loading || _loadingMore
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _statusFilter = value;
                                _tasks = [];
                              });
                              _load();
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_loading && _tasks.isEmpty)
                const AppLoadingState(height: 180)
              else if (_error != null)
                AppErrorState(
                  message: _error!,
                  onRetry: _load,
                  retryLabel: 'Retry',
                )
              else if (_tasks.isEmpty)
                const AppEmptyState(
                  message: AppStrings.noTasks,
                  icon: AppIcons.task,
                )
              else
                for (final task in _tasks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: 10,
                                  top: 2,
                                ),
                                child: Icon(
                                  _taskIcon(task.taskType),
                                  color: _taskColor(task.taskType),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: const TextStyle(
                                    color: AppTheme.textDark,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Pill(
                                task.status == 'done'
                                    ? AppStrings.taskStatusDone
                                    : AppStrings.taskStatusPending,
                                task.status == 'done'
                                    ? AppTheme.primary
                                    : AppTheme.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Éleveur: ${task.eleveurName ?? task.eleveurId}',
                            style: const TextStyle(color: AppTheme.textGrey),
                          ),
                          if (task.description?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 8),
                            Text(task.description!),
                          ],
                          if (task.plan.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Plan :\n${task.plan}',
                              style: const TextStyle(
                                color: AppTheme.textDark,
                                height: 1.4,
                              ),
                            ),
                          ],
                          if (task.cowId != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${AppStrings.taskCowLabel} : ${task.cowId}',
                            ),
                          ],
                          if (task.dueAt != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${AppStrings.taskDueLabel} : '
                              '${_formatDate(task.dueAt!)}',
                            ),
                          ],
                          if (task.completedAt != null) ...[
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                final completedBy =
                                    task.completedByName ?? task.completedBy;
                                return Text(
                                  '${AppStrings.taskCompletedLabel} '
                                  '${_formatDate(task.completedAt!)}'
                                  '${completedBy == null ? '' : ' ${AppStrings.taskCompletedBy} $completedBy'}',
                                  style: const TextStyle(
                                    color: AppTheme.textGrey,
                                  ),
                                );
                              },
                            ),
                          ],
                          if (task.taskType == 'check_weight' &&
                              task.completedWeightKg != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              task.previousWeightKg == null
                                  ? 'Poids relevé : '
                                      '${task.completedWeightKg!.toStringAsFixed(1)} kg'
                                  : 'Ancien poids : '
                                      '${task.previousWeightKg!.toStringAsFixed(1)} kg → '
                                      '${task.completedWeightKg!.toStringAsFixed(1)} kg',
                            ),
                          ],
                          if (task.completionNote?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 8),
                            Text('Note : ${task.completionNote}'),
                          ],
                          const SizedBox(height: 10),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: IconButton(
                              tooltip: AppStrings.deleteTaskTooltip,
                              onPressed: () => _deleteTask(task),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppTheme.warn,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (_hasMore)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: _loadingMore
                        ? const CircularProgressIndicator()
                        : OutlinedButton(
                            onPressed: _loadMore,
                            child: const Text(AppStrings.loadMore),
                          ),
                  ),
                ),
            ],
          ),
        ),
      );
}
