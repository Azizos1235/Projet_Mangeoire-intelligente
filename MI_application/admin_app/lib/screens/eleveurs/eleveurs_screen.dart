import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/eleveur_service.dart';
import '../invites/invite_screen.dart';
import 'eleveur_detail_screen.dart';

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
        appBar: AppBar(title: const Text('Éleveurs')),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.qr_code_2_rounded),
          label: const Text(
            'Inviter un éleveur',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const InviteScreen(),
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadEleveurs,
          child: _isLoading && _eleveurs == null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppTheme.warn),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _loadEleveurs,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    else if (_eleveurs?.isEmpty ?? false)
                      const Padding(
                        padding: EdgeInsets.all(36),
                        child: Center(
                          child: Text(
                            'Aucun éleveur.',
                            style: TextStyle(color: AppTheme.textGrey),
                          ),
                        ),
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
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.line),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primarySoft,
                  child: Text(
                    eleveur.name.isEmpty ? '?' : eleveur.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textGrey,
                ),
              ],
            ),
          ),
        ),
      );
}
