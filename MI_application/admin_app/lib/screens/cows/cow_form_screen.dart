import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/cow_service.dart';

class CowFormScreen extends StatefulWidget {
  const CowFormScreen({super.key, this.cow, this.service});

  final Cow? cow;
  final CowService? service;

  @override
  State<CowFormScreen> createState() => _CowFormScreenState();
}

class _CowFormScreenState extends State<CowFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final CowService _service;
  late final TextEditingController _idController;
  late final TextEditingController _weightController;
  late final TextEditingController _nfcController;
  late CowType _type;
  late String _breed;
  DateTime? _birthDate;
  bool _clearNfcUid = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.cow != null;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CowService.instance;
    final cow = widget.cow;
    _idController = TextEditingController(text: cow?.id ?? '');
    _weightController =
        TextEditingController(text: cow?.weightKg.toString() ?? '');
    _nfcController = TextEditingController(text: cow?.nfcUid ?? '');
    _type = cow?.type ?? CowType.dairy;
    final breeds = breedsByType[_type]!;
    _breed = breeds.contains(cow?.breed) ? cow!.breed : breeds.first;
    _birthDate = cow?.birthDate;
  }

  @override
  void dispose() {
    _idController.dispose();
    _weightController.dispose();
    _nfcController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final initialDate =
        _birthDate ?? DateTime(now.year - 1, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: DateUtils.dateOnly(now),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  String? _validateId(String? value) {
    if (_isEditing) return null;
    if (value == null || value.trim().isEmpty) return AppStrings.cowIdRequired;
    return null;
  }

  String? _validateWeight(String? value) {
    final weight = double.tryParse(value?.trim() ?? '');
    if (weight == null || !weight.isFinite || weight <= 0) {
      return AppStrings.cowWeightInvalid;
    }
    if (weight > 1500) return AppStrings.cowWeightRange;
    return null;
  }

  String? _validateNfc(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return null;
    if (!RegExp(r'^[0-9a-fA-F:\-\s]+$').hasMatch(input)) {
      return AppStrings.cowNfcInvalid;
    }
    final cleaned = input.replaceAll(RegExp(r'[:\-\s]'), '');
    if (cleaned.length < 8 || cleaned.length > 32) {
      return AppStrings.cowNfcInvalid;
    }
    return null;
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    final birthDate = _birthDate;
    final today = DateUtils.dateOnly(DateTime.now());
    if (birthDate == null || DateUtils.dateOnly(birthDate).isAfter(today)) {
      setState(() => _error = birthDate == null
          ? AppStrings.cowBirthDateRequired
          : AppStrings.cowFutureBirthDate);
      return;
    }
    if (!valid) return;

    final weight = double.parse(_weightController.text.trim());
    final cleanedNfc = _nfcController.text
        .trim()
        .replaceAll(RegExp(r'[:\-\s]'), '')
        .toUpperCase();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await _service.updateProfile(
          id: widget.cow!.id,
          birthDate: birthDate,
          weightKg: weight,
          type: _type,
          breed: _breed,
          clearNfcUid: _clearNfcUid,
          nfcUid: cleanedNfc.isEmpty ? null : cleanedNfc,
        );
      } else {
        await _service.createProfile(
          id: _idController.text.trim().toUpperCase(),
          birthDate: birthDate,
          weightKg: weight,
          type: _type,
          breed: _breed,
          nfcUid: cleanedNfc.isEmpty ? null : cleanedNfc,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on CowConflictException {
      if (mounted) setState(() => _error = AppStrings.cowConflict);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error =
            error.isNetworkError ? AppStrings.networkError : error.message);
      }
    } on FormatException {
      if (mounted) setState(() => _error = AppStrings.invalidResponse);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? AppStrings.editCow : AppStrings.addCow),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              if (!_isEditing) ...[
                TextFormField(
                  controller: _idController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: AppStrings.cowIdLabel,
                  ),
                  validator: _validateId,
                ),
                const SizedBox(height: 14),
              ],
              InkWell(
                onTap: _saving ? null : _selectBirthDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: AppStrings.cowBirthDateLabel,
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _birthDate == null ? '—' : _formatDate(_birthDate!),
                    style: TextStyle(
                      color: _birthDate == null
                          ? AppTheme.textGrey
                          : AppTheme.textDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: AppStrings.cowWeightLabel,
                ),
                validator: _validateWeight,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<CowType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: AppStrings.cowTypeLabel,
                ),
                items: [
                  for (final type in CowType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: _saving
                    ? null
                    : (type) {
                        if (type == null) return;
                        setState(() {
                          _type = type;
                          _breed = breedsByType[type]!.first;
                        });
                      },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey(_type),
                initialValue: _breed,
                decoration: const InputDecoration(
                  labelText: AppStrings.cowBreedLabel,
                ),
                items: [
                  for (final breed in breedsByType[_type]!)
                    DropdownMenuItem(value: breed, child: Text(breed)),
                ],
                onChanged: _saving
                    ? null
                    : (breed) {
                        if (breed != null) setState(() => _breed = breed);
                      },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nfcController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: AppStrings.cowNfcLabel,
                  helperText: 'Hex UID; separators and spaces are accepted.',
                ),
                validator: _validateNfc,
                onChanged: (_) {
                  if (_clearNfcUid) setState(() => _clearNfcUid = false);
                },
              ),
              if (_isEditing && widget.cow!.nfcUid != null) ...[
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _clearNfcUid = true;
                            _nfcController.clear();
                          }),
                  child: const Text(AppStrings.cowClearNfc),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.warn),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(AppStrings.cowSave),
              ),
            ],
          ),
        ),
      );

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
