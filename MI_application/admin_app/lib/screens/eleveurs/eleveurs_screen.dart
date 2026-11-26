import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/eleveur_service.dart';
import 'eleveur_qr_screen.dart';
import 'eleveur_detail_screen.dart';
import '../tasks/tasks_screen.dart';
import '../../widgets/async_state.dart';
import '../../widgets/widgets.dart';

class EleveursScreen extends StatefulWidget {
  const EleveursScreen({super.key});

  @override
  State<EleveursScreen> createState() => _EleveursScreenState();
}

class _EleveursScreenState extends State<EleveursScreen> {
  List<EleveurRecord>? _eleveurs;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEleveurs();
  }

  Future<void> _loadEleveurs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final eleveurs = await EleveurService.instance.listEleveurs();
      if (mounted) setState(() => _eleveurs = eleveurs);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openDetail(EleveurRecord eleveur) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => EleveurDetailScreen(eleveurId: eleveur.id),
      ),
    );
    if (mounted && deleted == true) await _loadEleveurs();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Éleveurs'),
          actions: [
            IconButton(
              tooltip: AppStrings.tasksTitle,
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const TasksScreen(),
                ),
              ),
              icon: const Icon(Icons.task_alt_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppTheme.primary,
          foregroundColor: AppTheme.onPrimary,
          icon: const Icon(Icons.qr_code_2_rounded),
          label: const Text(
            'QR éleveur',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const EleveurQrScreen(),
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadEleveurs,
          child: _isLoading && _eleveurs == null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    AppLoadingState(),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.pageSpacing,
                    4,
                    AppTheme.pageSpacing,
                    100,
                  ),
                  children: [
                    if (_errorMessage != null)
                      AppErrorState(
                        message: _errorMessage!,
                        onRetry: _loadEleveurs,
                        retryLabel: 'Retry',
                      )
                    else if (_eleveurs?.isEmpty ?? false)
                      const AppEmptyState(
                        message: 'Aucun éleveur.',
                        icon: Icons.groups_rounded,
                      )
                    else
                      for (final eleveur in _eleveurs ?? [])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _EleveurRow(
                            eleveur: eleveur,
                            onTap: () => _openDetail(eleveur),
                          ),
                        ),
                  ],
                ),
        ),
      );
}

class _EleveurRow extends StatelessWidget {
  const _EleveurRow({required this.eleveur, required this.onTap});

  final EleveurRecord eleveur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        child: Row(
          children: [
            PersonAvatar(eleveur.name, size: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eleveur.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Membre depuis ${eleveur.joinedDate}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            chevron(context),
          ],
        ),
      );
}
