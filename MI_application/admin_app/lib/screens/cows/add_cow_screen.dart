import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/cow_service.dart';
import '../../services/nfc_service.dart';
import '../../screens/scan/nfc_scan_screen.dart';
import '../../widgets/cow_form_controls.dart';
import 'cow_detail_screen.dart';

class AddCowScreen extends StatefulWidget {
  const AddCowScreen({
    super.key,
    this.nfcUid,
    this.tagAlreadyChecked = false,
    this.service,
    this.nfcService,
  });

  final String? nfcUid;
  final bool tagAlreadyChecked;
  final CowService? service;
  final NfcService? nfcService;

  @override
  State<AddCowScreen> createState() => _AddCowScreenState();
}

class _AddCowScreenState extends State<AddCowScreen> {
  static const Map<String, String> _typeByBreed = {
    'Holstein': 'dairy',
    'Montbeliarde': 'dual',
    'Brune': 'dairy',
    'Frisonne': 'dairy',
  };
  static const _maxAgeMonths = 240;

  final _formKey = GlobalKey<FormState>();
  final _cowIdController = TextEditingController();
  late final CowService _service = widget.service ?? CowService.instance;
  late final NfcService _nfcService = widget.nfcService ?? NfcService.instance;

  String _breed = _typeByBreed.keys.first;
  bool _inYears = true;
  int _ageValue = 3;
  double _weight = 500;
  bool _submitting = false;
  bool _checkingTag = false;
  bool _tagReady = false;
  String? _nfcUid;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.nfcUid != null && widget.tagAlreadyChecked) {
      try {
        _nfcUid = NfcService.normalizeUid(widget.nfcUid!);
        _tagReady = true;
      } on FormatException {
        _error = AppStrings.nfcReadFailed;
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.nfcUid == null) {
          unawaited(_scanForNewCow());
        } else {
          unawaited(_lookupBeforeShowingForm(widget.nfcUid!));
        }
      });
    }
  }

  @override
  void dispose() {
    _cowIdController.dispose();
    super.dispose();
  }

  String get _type => _typeByBreed[_breed]!;

  int get _maximumAge => _inYears ? _maxAgeMonths ~/ 12 : _maxAgeMonths;

  DateTime _birthDateFromAge() {
    final today = DateUtils.dateOnly(DateTime.now());
    final months = _inYears ? _ageValue * 12 : _ageValue;
    final total = today.year * 12 + today.month - 1 - months;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final day = math.min(today.day, DateUtils.getDaysInMonth(year, month));
    return DateTime(year, month, day);
  }

  String? _validateCowId(String? value) =>
      value == null || value.trim().isEmpty ? AppStrings.cowIdRequired : null;

  void _toggleAgeUnit(int index) {
    final toYears = index == 1;
    if (toYears == _inYears) return;
    setState(() {
      _ageValue = toYears
          ? (_ageValue / 12).round().clamp(1, _maxAgeMonths ~/ 12)
          : (_ageValue * 12).clamp(1, _maxAgeMonths);
      _inYears = toYears;
    });
  }

  void _changeAge(int delta) {
    setState(() => _ageValue = (_ageValue + delta).clamp(1, _maximumAge));
  }

  Future<NfcScanResult?> _readNfcTag(NfcScanMode mode) =>
      Navigator.push<NfcScanResult?>(
        context,
        MaterialPageRoute(
          builder: (_) => NfcScanScreen(mode: mode, service: _nfcService),
        ),
      );

  Future<void> _scanForNewCow() async {
    if (_checkingTag || !mounted) return;
    setState(() {
      _checkingTag = true;
      _error = null;
    });
    try {
      final result = await _readNfcTag(NfcScanMode.add);
      if (!mounted) return;
      if (result == null) {
        setState(() => _error = AppStrings.nfcCancelled);
        return;
      }
      await _lookupBeforeShowingForm(result.uid);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _error = error.message ?? AppStrings.nfcReadFailed);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _apiMessage(error));
    } on FormatException {
      if (mounted) setState(() => _error = AppStrings.nfcReadFailed);
    } finally {
      if (mounted) setState(() => _checkingTag = false);
    }
  }

  Future<void> _lookupBeforeShowingForm(String uid) async {
    if (mounted) {
      setState(() {
        _checkingTag = true;
        _error = null;
      });
    }
    try {
      final result = await _nfcService.lookupTag(uid, mode: NfcScanMode.add);
      if (!mounted) return;
      switch (result.status) {
        case NfcLookupStatus.found:
          await _showAlreadyRegistered(result.cow!);
        case NfcLookupStatus.notFound:
          setState(() {
            _nfcUid = result.uid;
            _tagReady = true;
          });
        case NfcLookupStatus.registeredElsewhere:
          await _showRegisteredElsewhere();
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _apiMessage(error));
    } on FormatException {
      if (mounted) setState(() => _error = AppStrings.nfcReadFailed);
    } finally {
      if (mounted) setState(() => _checkingTag = false);
    }
  }

  Future<void> _showAlreadyRegistered(Cow cow) async {
    final openProfile = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text(AppStrings.nfcTagRegistered),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.nfcCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.nfcOpenProfile),
          ),
        ],
      ),
    );
    if (openProfile == true && mounted) {
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => CowDetailScreen(cowId: cow.id),
        ),
      );
    }
  }

  Future<void> _showRegisteredElsewhere() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text(AppStrings.nfcTagElsewhere),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(AppStrings.nfcGotIt),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePostConflict() async {
    try {
      final result = await _nfcService.lookupTag(
        _nfcUid!,
        mode: NfcScanMode.add,
      );
      if (!mounted) return;
      switch (result.status) {
        case NfcLookupStatus.found:
          await _showAlreadyRegistered(result.cow!);
        case NfcLookupStatus.registeredElsewhere:
          await _showRegisteredElsewhere();
        case NfcLookupStatus.notFound:
          setState(() => _error = AppStrings.cowConflict);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _apiMessage(error));
    }
  }

  String _apiMessage(ApiException error) {
    if (error.statusCode == 409) return AppStrings.cowConflict;
    if (error.statusCode == 422) return AppStrings.cowValidationFailed;
    if (error.isNetworkError) return AppStrings.networkError;
    return AppStrings.cowCreateError;
  }

  Future<void> _submit() async {
    if (_submitting || !_tagReady) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await _service.createProfile(
        id: _cowIdController.text.trim().toUpperCase(),
        birthDate: _birthDateFromAge(),
        weightKg: _weight,
        type: CowTypeX.parse(_type),
        breed: _breed,
        nfcUid: _nfcUid!,
      );
      if (mounted) Navigator.pop(context, true);
    } on CowConflictException {
      await _handlePostConflict();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _apiMessage(error));
    } on FormatException {
      if (mounted) setState(() => _error = AppStrings.invalidResponse);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(AppStrings.newCow)),
        bottomNavigationBar: _tagReady
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _submitting ? AppStrings.cowSaving : AppStrings.cowSave,
                    ),
                  ),
                ),
              )
            : null,
        body: !_tagReady
            ? _buildNfcPrompt()
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    if (_error != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primarySoft,
                            ),
                            child: const Text('🐄',
                                style: TextStyle(fontSize: 54)),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 260,
                            child: TextFormField(
                              controller: _cowIdController,
                              enabled: !_submitting,
                              textAlign: TextAlign.center,
                              textCapitalization: TextCapitalization.characters,
                              validator: _validateCowId,
                              style: const TextStyle(
                                fontSize: 22,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.onPrimary,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: AppTheme.primary,
                                hintText: AppStrings.cowIdLabel,
                                hintStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.onPrimaryMuted,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                border: _pillBorder,
                                enabledBorder: _pillBorder,
                                focusedBorder: _pillBorder,
                                disabledBorder: _pillBorder,
                                errorBorder: _pillBorder,
                                focusedErrorBorder: _pillBorder,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    CowFormCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: AppTheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  AppStrings.nfcLinked,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                Text(
                                  _nfcUid!,
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
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle(AppStrings.cowBreedLabel),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final breed in _typeByBreed.keys)
                          ChoiceChip(
                            label: Text(_breedLabel(breed)),
                            selected: _breed == breed,
                            showCheckmark: false,
                            selectedColor: AppTheme.primary,
                            backgroundColor: AppTheme.surface,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _breed == breed
                                  ? AppTheme.onPrimary
                                  : AppTheme.textDark,
                            ),
                            onSelected: _submitting
                                ? null
                                : (_) => setState(() => _breed = breed),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle(AppStrings.cowAgeLabel),
                    CowFormCard(
                      child: Column(
                        children: [
                          CowAgeUnitSwitch(
                            labels: const [
                              AppStrings.months,
                              AppStrings.years,
                            ],
                            index: _inYears ? 1 : 0,
                            onChanged: _submitting ? (_) {} : _toggleAgeUnit,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              CowRoundButton(
                                icon: Icons.remove,
                                onPressed:
                                    _submitting ? null : () => _changeAge(-1),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '$_ageValue',
                                      style: const TextStyle(
                                        fontSize: 44,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    Text(
                                      _inYears
                                          ? AppStrings.years
                                          : AppStrings.months,
                                      style: const TextStyle(
                                        color: AppTheme.textGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              CowRoundButton(
                                icon: Icons.add,
                                onPressed:
                                    _submitting ? null : () => _changeAge(1),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle(AppStrings.cowWeightLabel),
                    CowFormCard(
                      child: Column(
                        children: [
                          Text(
                            '${_weight.round()} ${AppStrings.kilograms}',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                            ),
                          ),
                          Slider(
                            value: _weight,
                            min: 30,
                            max: 1000,
                            divisions: 194,
                            activeColor: AppTheme.primary,
                            onChanged: _submitting
                                ? null
                                : (value) => setState(() => _weight = value),
                          ),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('30'),
                              Text('1000'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      );

  Widget _buildNfcPrompt() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_checkingTag) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
              ],
              Text(
                _error ?? AppStrings.nfcStep,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _error == null
                      ? AppTheme.textDark
                      : Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _checkingTag ? null : _scanForNewCow,
                icon: const Icon(Icons.nfc_rounded),
                label: const Text(AppStrings.quickNfc),
              ),
            ],
          ),
        ),
      );

  static String _breedLabel(String breed) =>
      breed == 'Montbeliarde' ? 'Montbéliarde' : breed;

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.textDark,
          ),
        ),
      );

  static final _pillBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(24),
    borderSide: BorderSide.none,
  );
}
