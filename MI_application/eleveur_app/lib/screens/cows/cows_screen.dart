import 'package:flutter/material.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/cow_appetite.dart';
import '../../models/cow_profile.dart';
import '../../services/cow_service.dart';
import '../../widgets/async_state.dart';
import '../../widgets/cow_tile.dart';
import '../../widgets/widgets.dart';

class _CowRow {
  final CowReference ref;
  final CowAppetiteClass? appetite;
  final CowProfile? profile;
  const _CowRow(this.ref, this.appetite, this.profile);
}

/// Cows tab: all cows, search by number, appetite filters.
class CowsTab extends StatefulWidget {
  final VoidCallback onScanCow;
  const CowsTab({super.key, required this.onScanCow});

  @override
  State<CowsTab> createState() => _CowsTabState();
}

class _CowsTabState extends State<CowsTab> {
  List<_CowRow>? _rows;
  Object? _error;
  String _query = '';
  CowAppetiteClass? _filter;
  bool _noDataOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cows = await CowService.instance.getCows();

      // Appetite: optional, a failure must not break the list.
      var appetiteByIdentifier = <String, CowAppetiteClass>{};
      try {
        final response = await CowService.instance.getAppetite(
          onStatus: (_) {},
        );
        appetiteByIdentifier =
            appetiteClassesByIdentifier(response.appetiteByInternalId);
      } catch (e) {
        debugPrint('[DBG] cows appetite failed (ignored): $e');
      }

      // Profiles (breed, age): optional.
      final Map<String, CowProfile> profiles = {};
      try {
        final list = await CowService.instance.getProfiles(); // ADAPT or delete
        for (final p in list) {
          profiles[normalizeCowIdentifier(p.internalId)] = p;
          profiles[normalizeCowIdentifier(p.cowId)] = p;
        }
      } catch (e) {
        debugPrint('[DBG] cows profiles failed (ignored): $e');
      }

      final rows = [
        for (final c in cows)
          _CowRow(
            c,
            appetiteForCow(c, appetiteByIdentifier),
            profiles[normalizeCowIdentifier(c.internalId)] ??
                profiles[normalizeCowIdentifier(c.displayId)],
          ),
      ];
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_rows == null) setState(() => _error = e);
    }
  }

  void _retry() {
    setState(() {
      _rows = null;
      _error = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.nfc_rounded),
        label: Text(context.tr('quick_nfc'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        onPressed: widget.onScanCow,
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final rows = _rows;
    if (rows == null) {
      if (_error != null) {
        return AppLoadError(error: _error!, onRetry: _retry);
      }
      return const Center(child: CircularProgressIndicator());
    }

    final q = _query.trim().toLowerCase();
    final list = rows.where((r) {
      if (_noDataOnly && r.appetite != null) return false;
      if (_filter != null && r.appetite != _filter) return false;
      return r.ref.displayId.toLowerCase().contains(q);
    }).toList(growable: false);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        children: [
          Row(children: [
            Expanded(
              child: Text('${context.tr('my_cows')} (${rows.length})',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textDark)),
            ),
            const LangToggle(),
          ]),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: context.tr('search_hint'),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip(context, null, context.tr('all'),
                selected: _filter == null && !_noDataOnly,
                color: AppTheme.primary,
                onTap: () => setState(() {
                      _filter = null;
                      _noDataOnly = false;
                    })),
            for (final a in CowAppetiteClass.values)
              _chip(context, a.icon, context.tr(a.labelKey),
                  selected: _filter == a,
                  color: a.color,
                  onTap: () => setState(() {
                        _filter = a;
                        _noDataOnly = false;
                      })),
          ]),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            AppEmptyState(message: context.tr('no_cows'))
          else if (list.isEmpty)
            AppEmptyState(message: context.tr('empty_search'))
          else
            for (final r in list) ...[
              CowTile(cow: r.ref, appetite: r.appetite, profile: r.profile),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, IconData? icon, String label,
      {required bool selected,
      required Color color,
      required VoidCallback onTap}) {
    return ChoiceChip(
      avatar: icon == null
          ? null
          : Icon(icon, size: 18, color: selected ? Colors.white : color),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: color,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppTheme.textDark),
      onSelected: (_) => onTap(),
    );
  }
}
