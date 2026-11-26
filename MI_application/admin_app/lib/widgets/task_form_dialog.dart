import 'package:flutter/material.dart';

import '../core/app_icons.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/eleveur_service.dart';

class TaskFormDraft {
  const TaskFormDraft({
    required this.eleveurId,
    required this.title,
    required this.taskType,
    required this.plan,
    this.description,
    this.cowId,
    this.dueAt,
    this.alertId,
  });

  final String eleveurId;
  final String title;
  final String taskType;
  final String plan;
  final String? description;
  final String? cowId;
  final DateTime? dueAt;
  final String? alertId;
}

class _TaskTypeDefinition {
  const _TaskTypeDefinition(this.label, this.title, this.plan);

  final String label;
  final String title;
  final String plan;
}

const _taskTypes = <String, _TaskTypeDefinition>{
  'sell': _TaskTypeDefinition(
    'Vendre',
    'Vendre la vache',
    'Préparer la vache pour la vente.\n'
        'Vérifier son état et ses documents.\n'
        'Informer l’administrateur une fois la vente effectuée.',
  ),
  'vet': _TaskTypeDefinition(
    'Vétérinaire',
    'Emmener la vache chez le vétérinaire',
    'Emmener la vache chez le vétérinaire.\n'
        'Expliquer les symptômes ou le motif de consultation.\n'
        'Suivre les recommandations du vétérinaire et faire un compte rendu.',
  ),
  'butcher': _TaskTypeDefinition(
    'Boucher',
    'Envoyer la vache à la boucherie',
    'Organiser le transport de la vache à la boucherie.\n'
        'Vérifier les documents nécessaires.\n'
        'Informer l’administrateur une fois la démarche effectuée.',
  ),
  'check_weight': _TaskTypeDefinition(
    'Peser',
    'Vérifier le poids de la vache',
    'Peser la vache.\n'
        'Noter son poids.\n'
        'Vérifier son état corporel.\n'
        'Signaler toute anomalie.',
  ),
  'custom': _TaskTypeDefinition('Personnalisée', 'Nouvelle tâche', ''),
};

class TaskFormDialog extends StatefulWidget {
  const TaskFormDialog({
    super.key,
    required this.eleveurs,
    required this.cows,
    this.initialCowId,
    this.initialEleveurId,
    this.initialTaskType = 'custom',
    this.alertId,
  });

  final List<EleveurRecord> eleveurs;
  final List<Cow> cows;
  final String? initialCowId;
  final String? initialEleveurId;
  final String initialTaskType;
  final String? alertId;

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(
    text: _taskTypes[widget.initialTaskType]?.title ??
        _taskTypes['custom']!.title,
  );
  final _descriptionController = TextEditingController();
  late final _planController = TextEditingController(
    text: _taskTypes[widget.initialTaskType]?.plan ?? '',
  );
  late String? _eleveurId = _initialEleveurId();
  late String? _cowId = widget.initialCowId;
  late String _taskType = _taskTypes.containsKey(widget.initialTaskType)
      ? widget.initialTaskType
      : 'custom';
  DateTime? _dueAt;

  String? _initialEleveurId() {
    final requested = widget.initialEleveurId;
    if (requested != null &&
        widget.eleveurs.any((eleveur) => eleveur.id == requested)) {
      return requested;
    }
    return widget.eleveurs.isEmpty ? null : widget.eleveurs.first.id;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _planController.dispose();
    super.dispose();
  }

  Future<void> _chooseDueAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _dueAt == null
          ? TimeOfDay.fromDateTime(now)
          : TimeOfDay.fromDateTime(_dueAt!),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dueAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _selectTaskType(String? value) {
    if (value == null) return;
    final definition = _taskTypes[value]!;
    setState(() {
      _taskType = value;
      _titleController.text = definition.title;
      _planController.text = definition.plan;
    });
  }

  void _selectCow(String? value) {
    final cowId = value?.isEmpty == true ? null : value;
    Cow? cow;
    for (final item in widget.cows) {
      if (item.id == cowId) {
        cow = item;
        break;
      }
    }
    setState(() {
      _cowId = cowId;
      if (cow?.eleveurId != null &&
          widget.eleveurs.any((item) => item.id == cow!.eleveurId)) {
        _eleveurId = cow!.eleveurId;
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final eleveurId = _eleveurId;
    if (eleveurId == null) return;
    Navigator.pop(
      context,
      TaskFormDraft(
        eleveurId: eleveurId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        cowId: _cowId,
        dueAt: _dueAt,
        taskType: _taskType,
        plan: _planController.text.trim(),
        alertId: widget.alertId,
      ),
    );
  }

  String _formatDueAt(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  IconData _taskIcon(String type) => switch (type) {
        'sell' => AppIcons.sell,
        'vet' => AppIcons.vet,
        'butcher' => AppIcons.butcher,
        'check_weight' => AppIcons.weight,
        _ => Icons.assignment_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final dialogWidth =
        (MediaQuery.sizeOf(context).width - 64).clamp(0.0, 440.0).toDouble();
    return AlertDialog(
      title: const Text('Assigner une tâche'),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _eleveurId,
                  decoration: const InputDecoration(labelText: 'Éleveur'),
                  items: [
                    for (final eleveur in widget.eleveurs)
                      DropdownMenuItem(
                        value: eleveur.id,
                        child: Text(eleveur.name),
                      ),
                  ],
                  validator: (value) =>
                      value == null ? 'Choisissez un éleveur.' : null,
                  onChanged: (value) => setState(() => _eleveurId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _taskType,
                  decoration: const InputDecoration(labelText: 'Type de tâche'),
                  items: [
                    for (final entry in _taskTypes.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value.label),
                      ),
                  ],
                  onChanged: _selectTaskType,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: 'Titre',
                    prefixIcon: Icon(
                      _taskIcon(_taskType),
                      color: AppTheme.primary,
                    ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Le titre est obligatoire.'
                      : null,
                ),
                TextFormField(
                  controller: _descriptionController,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: _taskType == 'vet'
                        ? 'Symptômes ou motif'
                        : 'Description',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _planController,
                  maxLength: 2000,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Plan / consignes',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey(_cowId),
                  initialValue: _cowId ?? '',
                  decoration:
                      const InputDecoration(labelText: 'Vache (facultatif)'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Aucune vache'),
                    ),
                    if (_cowId != null &&
                        !widget.cows.any((cow) => cow.id == _cowId))
                      DropdownMenuItem(value: _cowId, child: Text(_cowId!)),
                    for (final cow in widget.cows)
                      DropdownMenuItem(value: cow.id, child: Text(cow.id)),
                  ],
                  onChanged: _selectCow,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dueAt == null
                            ? 'Aucune échéance'
                            : 'À faire avant : ${_formatDueAt(_dueAt!)}',
                      ),
                    ),
                    TextButton(
                      onPressed: _chooseDueAt,
                      child: const Text('Choisir'),
                    ),
                    if (_dueAt != null)
                      IconButton(
                        tooltip: 'Effacer l’échéance',
                        onPressed: () => setState(() => _dueAt = null),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _save, child: const Text('Créer')),
      ],
    );
  }
}
