import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/cow_profile.dart';
import '../../services/api_client.dart';
import '../../services/cow_service.dart';
import '../../widgets/widgets.dart';

/// Edit the profile of an existing cow. Same design as the add-cow screen.
/// Pops with `true` when the profile was saved.
class EditProfileScreen extends StatefulWidget {
  final CowProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // The type is not shown; the backend still needs it, so it is derived
  // from the breed.
  static const Map<String, String> _typeByBreed = {
    'holstein': 'dairy',
    'montbeliarde': 'dual',
    'brune': 'dairy',
    'frisonne': 'dairy',
  };

  late final List<String> _breeds;
  String? _breed; // null when the stored breed is no longer supported
  late bool _inYears;
  late int _ageValue;
  late double _weight;
  bool _ageTouched = false;
  bool _weightTouched = false;
  bool _submitting = false;
  String? _errorKey;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final current = widget.profile.breed.trim().toLowerCase();
    _breeds = _typeByBreed.keys.toList();
    _breed = _typeByBreed.containsKey(current) ? current : null;

    final months = widget.profile.ageMonths.round();
    _inYears = months >= 24;
    _ageValue =
        _inYears ? (months / 12).round().clamp(1, 30) : months.clamp(1, 360);
    _weight =
        ((widget.profile.weightKg / 5).round() * 5).clamp(30, 1000).toDouble();
  }

  String get _type => _typeByBreed[_breed]!;

  void _toggleUnit(int i) {
    final toYears = i == 1;
    if (toYears == _inYears) return;
    setState(() {
      _ageTouched = true;
      _ageValue =
          toYears ? (_ageValue / 12).round().clamp(1, 30) : _ageValue * 12;
      _inYears = toYears;
    });
  }

  void _changeAge(int d) => setState(() {
        _ageTouched = true;
        _ageValue = (_ageValue + d).clamp(1, _inYears ? 30 : 360);
      });

  DateTime _birthDateFromAge() {
    final today = DateUtils.dateOnly(DateTime.now());
    final months = _inYears ? _ageValue * 12 : _ageValue;
    final total = today.year * 12 + (today.month - 1) - months;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final day = math.min(today.day, DateUtils.getDaysInMonth(year, month));
    return DateTime(year, month, day);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_breed == null) {
      setState(() {
        _errorKey = 'select_breed';
        _errorMessage = null;
      });
      return;
    }
    setState(() {
      _errorKey = null;
      _errorMessage = null;
      _submitting = true;
    });

    // Keep the original values for anything the user did not touch.
    final birthDate =
        _ageTouched ? _birthDateFromAge() : widget.profile.birthDate;
    final weight = _weightTouched ? _weight : widget.profile.weightKg;
    // The backend only accepts capitalized breed names (e.g. "Holstein").
    final selected = _breed!;
    final breed = selected[0].toUpperCase() + selected.substring(1);

    try {
      await CowService.instance.updateProfile(
        cowId: widget.profile.cowId,
        birthDate: birthDate,
        weightKg: weight,
        type: _type,
        breed: breed,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _errorKey = error.messageKey;
          _errorMessage = error.responseMessage;
        });
      }
    } on FormatException {
      if (mounted) {
        setState(() {
          _errorKey = 'api_error_generic';
          _errorMessage = null;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nfcUid = widget.profile.nfcUid;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('edit_profile')),
        actions: const [LangToggle(), SizedBox(width: 16)],
      ),
      bottomNavigationBar: SafeArea(
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
      ),
      body: ListView(
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
                    shape: BoxShape.circle, color: AppTheme.primarySoft),
                child: const Text('🐄', style: TextStyle(fontSize: 54)),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(widget.profile.cowId,
                    style: const TextStyle(
                        fontSize: 22,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ),
            ]),
          ),
          const SizedBox(height: 22),

          // NFC tag (not editable)
          if (nfcUid != null) ...[
            _Card(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: AppTheme.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Colors.white),
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
                      Text(nfcUid,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textGrey)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),
          ],

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
                    color: _breed == b ? Colors.white : AppTheme.textDark),
                onSelected:
                    _submitting ? null : (_) => setState(() => _breed = b),
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
                _RoundBtn(
                    Icons.remove, _submitting ? null : () => _changeAge(-1)),
                Expanded(
                  child: Column(children: [
                    Text('$_ageValue',
                        style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textDark)),
                    Text(_inYears ? context.tr('years') : context.tr('months'),
                        style: const TextStyle(color: AppTheme.textGrey)),
                  ]),
                ),
                _RoundBtn(Icons.add, _submitting ? null : () => _changeAge(1)),
              ]),
            ]),
          ),
          const SizedBox(height: 24),

          // Weight
          _title(context.tr('weight')),
          _Card(
            child: Column(children: [
              Text(
                  '${(_weightTouched ? _weight : widget.profile.weightKg).round()} ${context.tr('kg')}',
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
                    : (v) => setState(() {
                          _weight = v;
                          _weightTouched = true;
                        }),
              ),
              const Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('30', style: TextStyle(color: AppTheme.textGrey)),
                    Text('1000', style: TextStyle(color: AppTheme.textGrey)),
                  ],
                ),
              ),
            ]),
          ),

          if (_errorKey != null) ...[
            const SizedBox(height: 20),
            Text(
              _errorMessage ?? context.tr(_errorKey!),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark)),
      );
}

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
