import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/eleveur_service.dart';

class EleveurDetailScreen extends StatefulWidget {
  const EleveurDetailScreen({super.key, required this.eleveurId});

  final String eleveurId;

  @override
  State<EleveurDetailScreen> createState() => _EleveurDetailScreenState();
}

class _EleveurDetailScreenState extends State<EleveurDetailScreen> {
  EleveurRecord? _eleveur;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadEleveur();
  }

  Future<void> _loadEleveur() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final eleveurs = await EleveurService.instance.listEleveurs();
      final matches = eleveurs.where((e) => e.id == widget.eleveurId);
      if (mounted) {
        setState(() {
          _eleveur = matches.isEmpty ? null : matches.first;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _confirmDelete(String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Retirer $name ?'),
        content: Text('L’accès de $name sera supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Retirer',
              style: TextStyle(color: AppTheme.warn),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteEleveur() async {
    final eleveur = _eleveur;
    if (eleveur == null || _isDeleting) return;
    if (!await _confirmDelete(eleveur.name) || !mounted) return;

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });
    try {
      await EleveurService.instance.deleteEleveur(eleveur.id);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_eleveur?.name ?? 'Éleveur')),
        body: RefreshIndicator(
          onRefresh: _loadEleveur,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              if (_isLoading && _eleveur == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
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
                        onPressed: _loadEleveur,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (_eleveur == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Cet éleveur est introuvable.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textGrey),
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _eleveur!.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Membre depuis ${_eleveur!.joinedDate}',
                        style: const TextStyle(color: AppTheme.textGrey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.warn,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _isDeleting ? null : _deleteEleveur,
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_remove_outlined, size: 20),
                  label: const Text('Retirer l’éleveur'),
                ),
              ],
            ],
          ),
        ),
      );
}
