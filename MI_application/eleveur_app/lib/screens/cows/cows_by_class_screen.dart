import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/cow_appetite.dart';
import '../../services/cow_service.dart';
import '../../widgets/async_state.dart';
import '../../widgets/cow_tile.dart';

class CowsByClassScreen extends StatefulWidget {
  final List<CowAppetiteEntry> initialEntries;
  final CowAppetiteFilter initialFilter;

  const CowsByClassScreen({
    super.key,
    required this.initialEntries,
    required this.initialFilter,
  });

  @override
  State<CowsByClassScreen> createState() => _CowsByClassScreenState();
}

class _CowsByClassScreenState extends State<CowsByClassScreen> {
  late List<CowAppetiteEntry> _entries;
  late CowAppetiteFilter _filter;

  @override
  void initState() {
    super.initState();
    _entries = widget.initialEntries;
    _filter = widget.initialFilter;
  }

  List<CowAppetiteEntry> get _filteredEntries => _entries
      .where((entry) => matchesCowAppetiteFilter(entry, _filter))
      .toList(growable: false);

  Future<void> _refresh() async {
    final cowsFuture = CowService.instance.getCows();
    final appetiteFuture = CowService.instance.getAppetite(onStatus: (_) {});
    try {
      await Future.wait<void>([
        cowsFuture.then<void>((_) {}),
        appetiteFuture.then<void>((_) {}),
      ]);
      final cows = await cowsFuture;
      final appetite = await appetiteFuture;
      final entries = cowAppetiteEntries(cows, appetite.appetiteByInternalId);
      if (!mounted) return;
      setState(() {
        _entries = entries;
      });
    } catch (error, stackTrace) {
      debugPrint('[DBG] cows-by-class refresh failed: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('api_error_generic'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries;
    final counts = {
      for (final filter in CowAppetiteFilter.values)
        filter: _entries
            .where((entry) => matchesCowAppetiteFilter(entry, filter))
            .length,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${context.tr(_filter.labelKey)} (${entries.length})',
          key: const ValueKey('cows-by-class-count'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(_filter.descriptionKey),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final filter in CowAppetiteFilter.values) ...[
                          ChoiceChip(
                            key:
                                ValueKey('cows-by-class-filter-${filter.name}'),
                            label: Text(
                              '${context.tr(filter.labelKey)} (${counts[filter]})',
                            ),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: entries.isEmpty
                      ? [
                          AppEmptyState(
                            message: context.tr('appetite_class_empty'),
                          ),
                        ]
                      : [
                          for (final entry in entries) ...[
                            CowTile(
                              cow: entry.cow,
                              appetite: entry.appetite,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
