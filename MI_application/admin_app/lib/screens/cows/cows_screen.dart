import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/cow_service.dart';
import '../../widgets/widgets.dart';
import 'cow_detail_screen.dart';
import 'cow_form_screen.dart';

final cowsFilter = ValueNotifier<Appetite?>(null);

class CowRow extends StatelessWidget {
  const CowRow(
    this.cow, {
    super.key,
    this.summary,
    this.latestAppetite,
    this.onChanged,
  });

  final Cow cow;
  final DailySummary? summary;
  final Appetite? latestAppetite;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final appetite = latestAppetite ?? summary?.appetite;
    return AppCard(
      onTap: () async {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => CowDetailScreen(cowId: cow.id),
          ),
        );
        onChanged?.call();
      },
      child: Row(
        children: [
          CowAvatar(cow),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cow.id,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${cow.type.label} · ${cow.breed}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${cow.weightKg.toStringAsFixed(1)} kg · ${cow.ageMonths} mo',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (appetite != null)
            Pill(appetite.label, appetite.color)
          else
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textGrey,
            ),
        ],
      ),
    );
  }
}

class _CowEntry {
  const _CowEntry(this.cow, this.appetite);

  final Cow cow;
  final Appetite? appetite;
}

class CowsScreen extends StatefulWidget {
  const CowsScreen({super.key});

  @override
  State<CowsScreen> createState() => _CowsScreenState();
}

class _CowsScreenState extends State<CowsScreen> {
  final _service = CowService.instance;
  final _searchController = TextEditingController();
  List<_CowEntry> _entries = [];
  CowType? _typeFilter;
  String _query = '';
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait<Object>([
        _service.listProfiles(),
        _service.homeAppetite(),
      ]);
      final cows = results[0] as List<Cow>;
      final appetite =
          (results[1] as HomeAppetiteResponse).appetiteByInternalId;
      final entries = [
        for (final cow in cows) _CowEntry(cow, appetite[cow.internalId]),
      ];
      if (!mounted) return;
      setState(() {
        _entries = List.unmodifiable(entries);
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppStrings.invalidResponse;
      });
    }
  }

  List<_CowEntry> _filteredEntries(Appetite? appetiteFilter) {
    final query = _query.trim().toLowerCase();
    return _entries.where((entry) {
      final cow = entry.cow;
      final matchesQuery = query.isEmpty ||
          cow.id.toLowerCase().contains(query) ||
          cow.breed.toLowerCase().contains(query) ||
          cow.type.name.toLowerCase().contains(query);
      final matchesType = _typeFilter == null || cow.type == _typeFilter;
      final matchesAppetite =
          appetiteFilter == null || entry.appetite == appetiteFilter;
      return matchesQuery && matchesType && matchesAppetite;
    }).toList(growable: false);
  }

  Future<void> _openForm() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CowFormScreen()),
    );
    if (saved == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.cowsTitle),
          actions: [
            IconButton(
              onPressed: _openForm,
              tooltip: AppStrings.addCow,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: ValueListenableBuilder<Appetite?>(
          valueListenable: cowsFilter,
          builder: (context, appetiteFilter, _) {
            final entries = _filteredEntries(appetiteFilter);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: AppStrings.cowSearchHint,
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFilters(appetiteFilter),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    _MessageState(
                      message: _error!,
                      action: TextButton(
                        onPressed: () => _refresh(),
                        child: const Text(AppStrings.retry),
                      ),
                    )
                  else if (_entries.isEmpty)
                    const _MessageState(message: AppStrings.cowEmpty)
                  else if (entries.isEmpty)
                    const _MessageState(message: AppStrings.cowNoResults)
                  else
                    for (final entry in entries) ...[
                      CowRow(
                        entry.cow,
                        latestAppetite: entry.appetite,
                        onChanged: () => _refresh(),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            );
          },
        ),
      );

  Widget _buildFilters(Appetite? appetiteFilter) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  label: AppStrings.cowTypeFilterAll,
                  selected: _typeFilter == null,
                  onTap: () => setState(() => _typeFilter = null),
                ),
                for (final type in CowType.values)
                  _filterChip(
                    label: type.label,
                    selected: _typeFilter == type,
                    onTap: () => setState(() => _typeFilter = type),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  label: AppStrings.alertFilterAll,
                  selected: appetiteFilter == null,
                  onTap: () => cowsFilter.value = null,
                ),
                for (final appetite in Appetite.values)
                  _filterChip(
                    label: appetite.label,
                    selected: appetiteFilter == appetite,
                    color: appetite.color,
                    onTap: () => cowsFilter.value = appetite,
                  ),
              ],
            ),
          ),
        ],
      );

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color color = AppTheme.primary,
  }) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          selectedColor: color,
          backgroundColor: Colors.white,
          side: BorderSide(color: selected ? color : AppTheme.line),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppTheme.textDark,
          ),
          onSelected: (_) => onTap(),
        ),
      );
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textGrey),
            ),
            if (action != null) action!,
          ],
        ),
      );
}
