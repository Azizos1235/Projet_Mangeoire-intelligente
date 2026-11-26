import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/cow_search.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/cow_service.dart';
import '../../services/nfc_service.dart';
import '../../screens/scan/nfc_scan_screen.dart';
import '../../widgets/async_state.dart';
import '../../widgets/widgets.dart';
import 'cow_detail_screen.dart';
import 'add_cow_screen.dart';

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
          CowAvatar(cow, ring: appetite?.color),
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
            Pill(
              appetite.trendLabel,
              appetite.color,
              icon: appetite.icon,
              backgroundColor: appetite.lightColor,
            ),
          const SizedBox(width: 4),
          chevron(context),
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
  const CowsScreen({
    super.key,
    this.service,
    this.nfcService,
  });

  final CowService? service;
  final NfcService? nfcService;

  @override
  State<CowsScreen> createState() => CowsScreenState();
}

class CowsScreenState extends State<CowsScreen> {
  late final CowService _service;
  late final NfcService _nfcService;
  final _searchController = TextEditingController();
  List<_CowEntry> _entries = [];
  String _query = '';
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CowService.instance;
    _nfcService = widget.nfcService ?? NfcService.instance;
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
    return _entries.where((entry) {
      return matchesCowSearch(
        entry.cow,
        _query,
        appetite: entry.appetite,
        appetiteFilter: appetiteFilter,
      );
    }).toList(growable: false);
  }

  Future<void> openAddCow() => _openAddCow();

  Future<void> scanCow() => _scanCow();

  Future<void> _openAddCow({
    String? nfcUid,
    bool tagAlreadyChecked = false,
  }) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCowScreen(
          nfcUid: nfcUid,
          tagAlreadyChecked: tagAlreadyChecked,
          service: _service,
          nfcService: _nfcService,
        ),
      ),
    );
    if (!mounted) return;
    await _refresh(showLoading: saved == true);
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.cowCreateSuccess)),
      );
    }
  }

  Future<NfcScanResult?> _readNfcTag() => Navigator.push<NfcScanResult?>(
        context,
        MaterialPageRoute(
          builder: (_) => NfcScanScreen(
            mode: NfcScanMode.view,
            service: _nfcService,
          ),
        ),
      );

  Future<void> _scanCow() async {
    final scan = await _readNfcTag();
    if (!mounted || scan == null) return;

    try {
      final result = await _nfcService.lookupTag(
        scan.uid,
        mode: NfcScanMode.view,
      );
      if (!mounted) return;
      switch (result.status) {
        case NfcLookupStatus.found:
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => CowDetailScreen(cowId: result.cow!.id),
            ),
          );
          if (mounted) await _refresh(showLoading: false);
        case NfcLookupStatus.notFound:
          await _offerAddForUnknownTag(result.uid);
        case NfcLookupStatus.registeredElsewhere:
          await _showNfcMessage(AppStrings.nfcTagElsewhere);
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.isNetworkError
                  ? AppStrings.networkError
                  : AppStrings.cowCreateError,
            ),
          ),
        );
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.nfcReadFailed)),
        );
      }
    }
  }

  Future<void> _offerAddForUnknownTag(String uid) async {
    final add = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text(AppStrings.nfcTagNotFound),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.nfcCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.addCow),
          ),
        ],
      ),
    );
    if (add == true && mounted) {
      await _openAddCow(nfcUid: uid, tagAlreadyChecked: true);
    }
  }

  Future<void> _showNfcMessage(String message) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(AppStrings.nfcGotIt),
            ),
          ],
        ),
      );

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.cowsTitle),
          actions: [
            IconButton(
              onPressed: _openAddCow,
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
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pageSpacing,
                  4,
                  AppTheme.pageSpacing,
                  24,
                ),
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: AppStrings.cowSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: SizedBox(
                        width: _query.isEmpty ? 48 : 96,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_query.isNotEmpty)
                              IconButton(
                                tooltip: AppStrings.clearSearch,
                                onPressed: _clearSearch,
                                icon: const Icon(Icons.close),
                              ),
                            IconButton(
                              tooltip: AppStrings.quickNfc,
                              onPressed: _scanCow,
                              icon: const Icon(Icons.nfc_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFilters(appetiteFilter),
                  const SizedBox(height: 14),
                  if (!_loading && _error == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${entries.length} ${entries.length == 1 ? AppStrings.cowResultSingular : AppStrings.cowResultPlural}',
                        style: const TextStyle(color: AppTheme.textGrey),
                      ),
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    AppErrorState(
                      message: _error!,
                      onRetry: () => _refresh(),
                      retryLabel: AppStrings.retry,
                    )
                  else if (_entries.isEmpty)
                    const AppEmptyState(message: AppStrings.cowEmpty)
                  else if (entries.isEmpty)
                    const AppEmptyState(message: AppStrings.cowNoResults)
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
                  label: AppStrings.alertFilterAll,
                  selected: appetiteFilter == null,
                  onTap: () => cowsFilter.value = null,
                ),
                for (final appetite in Appetite.values)
                  _filterChip(
                    label: appetite.trendLabel,
                    selected: appetiteFilter == appetite,
                    color: appetite.color,
                    icon: appetite.icon,
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
    IconData? icon,
  }) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: icon == null
              ? null
              : Icon(icon,
                  size: 17, color: selected ? AppTheme.onPrimary : color),
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          selectedColor: color,
          backgroundColor: AppTheme.surface,
          side: BorderSide(color: selected ? color : AppTheme.border),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? AppTheme.onPrimary : AppTheme.textDark,
          ),
          onSelected: (_) => onTap(),
        ),
      );
}
