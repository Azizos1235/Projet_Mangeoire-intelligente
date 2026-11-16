import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/cow_profile.dart';
import '../../services/nfc_service.dart';
import '../../services/api_client.dart';
import '../../services/cow_service.dart';
import '../../widgets/widgets.dart';

class AddCowScreen extends StatefulWidget {
  final String? nfcUid;
  final bool tagAlreadyChecked;

  const AddCowScreen({
    super.key,
    this.nfcUid,
    this.tagAlreadyChecked = false,
  });

  @override
  State<AddCowScreen> createState() => _AddCowScreenState();
}

class _AddCowScreenState extends State<AddCowScreen> {
  // The type is no longer shown in the UI. The backend still requires it,
  // so it is derived from the selected breed.
  // Same breeds and order as the mock (without "baladi").
  static const Map<String, String> _typeByBreed = {
    'holstein': 'dairy',
    'montbeliarde': 'dual',
    'brune': 'dairy',
    'frisonne': 'dairy',
  };

  static final List<String> _breeds = _typeByBreed.keys.toList();

  final _formKey = GlobalKey<FormState>();
  final _cowIdController = TextEditingController();

  String _breed = _breeds.first;
  bool _inYears = true;
  int _ageValue = 3; // in the chosen unit (months or years)
  double _weight = 500;
  bool _submitting = false;
  bool _checkingTag = false;
  bool _tagReady = false;
  String? _nfcUid;
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    if (widget.nfcUid != null && widget.tagAlreadyChecked) {
      try {
        _nfcUid = NfcService.normalizeUid(widget.nfcUid!);
        _tagReady = true;
      } on FormatException {
        _errorKey = 'nfc_read_failed';
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.nfcUid != null) {
          unawaited(_lookupBeforeShowingForm(widget.nfcUid!));
        } else {
          unawaited(_scanForNewCow());
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

  /// The backend only accepts capitalized breed names (e.g. "Holstein").
  static String _apiBreed(String b) => b[0].toUpperCase() + b.substring(1);

  void _toggleUnit(int i) {
    final toYears = i == 1;
    if (toYears == _inYears) return;
    setState(() {
      _ageValue =
          toYears ? (_ageValue / 12).round().clamp(1, 30) : _ageValue * 12;
      _inYears = toYears;
    });
  }

  void _changeAge(int d) => setState(() {
        _ageValue = (_ageValue + d).clamp(1, _inYears ? 30 : 360);
      });

  /// The backend expects a birth date, so it is computed from the age.
  DateTime _birthDateFromAge() {
    final today = DateUtils.dateOnly(DateTime.now());
    final months = _inYears ? _ageValue * 12 : _ageValue;
    final total = today.year * 12 + (today.month - 1) - months;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final day = math.min(today.day, DateUtils.getDaysInMonth(year, month));
    return DateTime(year, month, day);
  }

  String? _validateCowId(String? value) => value == null || value.trim().isEmpty
      ? context.tr('cow_id_required')
      : null;

  Future<void> _scanForNewCow() async {
    if (_checkingTag || !mounted) return;
    setState(() {
      _checkingTag = true;
      _errorKey = null;
    });
    try {
      final result = await Navigator.pushNamed<NfcScanResult?>(
        context,
        AppRoutes.nfcScanner,
        arguments: NfcScanMode.add,
      );
      if (!mounted) return;
      if (result == null) {
        setState(() => _errorKey = 'nfc_cancelled');
        return;
      }
      await _lookupBeforeShowingForm(result.uid);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorKey = error.messageKey);
    } on FormatException {
      if (mounted) setState(() => _errorKey = 'nfc_read_failed');
    } finally {
      if (mounted) setState(() => _checkingTag = false);
    }
  }

  Future<void> _lookupBeforeShowingForm(String uid) async {
    setState(() {
      _checkingTag = true;
      _errorKey = null;
    });
    try {
      final result = await NfcService.instance.lookupTag(
        uid,
        mode: NfcScanMode.add,
      );
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
      if (mounted) setState(() => _errorKey = error.messageKey);
    } on FormatException {
      if (mounted) setState(() => _errorKey = 'nfc_read_failed');
    } finally {
      if (mounted) setState(() => _checkingTag = false);
    }
  }

  Future<void> _showAlreadyRegistered(CowReference cow) async {
    final openProfile = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(dialogContext.tr('nfc_tag_registered')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('open_profile')),
          ),
        ],
      ),
    );
    if (openProfile == true && mounted) {
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.cowDetail,
        arguments: cow,
      );
    }
  }

  Future<void> _showRegisteredElsewhere() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(dialogContext.tr('nfc_tag_elsewhere')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('got_it')),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePostConflict() async {
    try {
      final result = await NfcService.instance.lookupTag(
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
          setState(() => _errorKey = 'api_error_409');
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorKey = error.messageKey);
    }
  }

  Future<void> _submit() async {
    if (_submitting || !_tagReady) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cowId = _cowIdController.text.trim().toUpperCase();
    setState(() {
      _errorKey = null;
      _submitting = true;
    });
    try {
      final profile = await CowService.instance.createProfile(
        cowId: cowId,
        birthDate: _birthDateFromAge(),
        weightKg: _weight,
        type: _type,
        breed: _apiBreed(_breed),
        nfcUid: _nfcUid!,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.cowDetail,
        arguments: profile.reference,
      );
    } on ConflictApiException {
      await _handlePostConflict();
    } on ValidationApiException {
      if (mounted) setState(() => _errorKey = 'api_error_422');
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorKey = error.messageKey);
    } on FormatException {
      if (mounted) setState(() => _errorKey = 'api_error_generic');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('new_cow')),
        actions: const [LangToggle(), SizedBox(width: 16)],
      ),
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
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(context.tr('save')),
                ),
              ),
            )
          : null,
      body: !_tagReady
          ? _buildNfcPrompt(context)
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  // Preview + cow ID
                  Center(
                    child: Column(children: [
                      Container(
                        width: 104,
                        height: 104,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primarySoft),
                        child: const Text('🐄', style: TextStyle(fontSize: 54)),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 220,
                        child: TextFormField(
                          controller: _cowIdController,
                          enabled: !_submitting,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          validator: _validateCowId,
                          cursorColor: Colors.white,
                          style: const TextStyle(
                              fontSize: 22,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w900,
                              color: Colors.white),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: AppTheme.primary,
                            hintText: context.tr('cow_id'),
                            hintStyle: const TextStyle(
                                fontSize: 16,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            border: _pillBorder,
                            enabledBorder: _pillBorder,
                            focusedBorder: _pillBorder,
                            disabledBorder: _pillBorder,
                            errorBorder: _pillBorder,
                            focusedErrorBorder: _pillBorder,
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 22),

                  // NFC tag (already scanned)
                  _Card(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                            color: AppTheme.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('nfc_linked'),
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textDark)),
                            Text(_nfcUid!,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textGrey)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // Breed
                  _title(context.tr('breed')),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final b in _breeds)
                      ChoiceChip(
                        label: Text(context.tr(b)),
                        selected: _breed == b,
                        showCheckmark: false,
                        selectedColor: AppTheme.primary,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                _breed == b ? Colors.white : AppTheme.textDark),
                        onSelected: _submitting
                            ? null
                            : (_) => setState(() => _breed = b),
                      ),
                  ]),
                  const SizedBox(height: 24),

                  // Age
                  _title(context.tr('age')),
                  _Card(
                    child: Column(children: [
                      _UnitSwitch(
                        labels: [context.tr('months'), context.tr('years')],
                        index: _inYears ? 1 : 0,
                        onChanged: _submitting ? (_) {} : _toggleUnit,
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        _RoundBtn(Icons.remove,
                            _submitting ? null : () => _changeAge(-1)),
                        Expanded(
                          child: Column(children: [
                            Text('$_ageValue',
                                style: const TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.textDark)),
                            Text(
                                _inYears
                                    ? context.tr('years')
                                    : context.tr('months'),
                                style:
                                    const TextStyle(color: AppTheme.textGrey)),
                          ]),
                        ),
                        _RoundBtn(Icons.add,
                            _submitting ? null : () => _changeAge(1)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // Weight
                  _title(context.tr('weight')),
                  _Card(
                    child: Column(children: [
                      Text('${_weight.round()} ${context.tr('kg')}',
                          style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary)),
                      Slider(
                        value: _weight,
                        min: 30,
                        max: 1000,
                        divisions: 194, // 5 kg steps
                        activeColor: AppTheme.primary,
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _weight = v),
                      ),
                      const Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('30',
                                style: TextStyle(color: AppTheme.textGrey)),
                            Text('1000',
                                style: TextStyle(color: AppTheme.textGrey)),
                          ],
                        ),
                      ),
                    ]),
                  ),

                  if (_errorKey != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      context.tr(_errorKey!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.error),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildNfcPrompt(BuildContext context) => Center(
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
                _errorKey == null
                    ? context.tr('nfc_step')
                    : context.tr(_errorKey!),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _errorKey == null ? AppTheme.textDark : AppTheme.error,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _checkingTag ? null : _scanForNewCow,
                icon: const Icon(Icons.nfc_rounded),
                label: Text(context.tr('quick_nfc')),
              ),
            ],
          ),
        ),
      );

  static final OutlineInputBorder _pillBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(24),
    borderSide: BorderSide.none,
  );

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark)),
      );
}

/// White rounded card with a soft shadow (same look as the mock's AppCard).
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

/// Pill-shaped switch (months / years).
class _UnitSwitch extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const _UnitSwitch({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDDE5DF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: i == index ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(labels[i],
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: i == index ? Colors.white : AppTheme.textGrey)),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundBtn(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primarySoft,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: AppTheme.primary, size: 28)),
      ),
    );
  }
}
