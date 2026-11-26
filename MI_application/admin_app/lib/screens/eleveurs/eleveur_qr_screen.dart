import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/eleveur_service.dart';
import '../../services/invite_service.dart';
import '../../widgets/widgets.dart';
import '../invites/invite_screen.dart';

class EleveurQrScreen extends StatefulWidget {
  const EleveurQrScreen({super.key});

  @override
  State<EleveurQrScreen> createState() => _EleveurQrScreenState();
}

class _EleveurQrScreenState extends State<EleveurQrScreen> {
  Timer? _countdownTimer;
  List<EleveurRecord> _eleveurs = [];
  LoginQr? _currentQr;
  String? _selectedEleveurId;
  String? _error;
  String? _loadError;
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
    _loadEleveurs();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEleveurs() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final eleveurs = await EleveurService.instance.listEleveurs();
      if (!mounted) return;
      setState(() {
        _eleveurs = eleveurs;
        _selectedEleveurId ??= eleveurs.isEmpty ? null : eleveurs.first.id;
      });
    } on ApiException {
      if (mounted) setState(() => _loadError = 'Unable to load éleveurs.');
    } on FormatException {
      if (mounted) setState(() => _loadError = 'The éleveur list is invalid.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateQr() async {
    final eleveurId = _selectedEleveurId;
    if (_creating || eleveurId == null) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final qr = await InviteService.instance.createLoginQr(eleveurId);
      if (mounted) setState(() => _currentQr = qr);
    } on ApiException {
      if (mounted) setState(() => _error = 'Unable to generate the QR code.');
    } on FormatException {
      if (mounted) setState(() => _error = 'The QR response is invalid.');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Duration _remaining(DateTime expiry) {
    final remaining = expiry.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String _countdown(DateTime expiry) {
    final remaining = _remaining(expiry);
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds =
        remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final qr = _currentQr;
    final expired = qr != null && _remaining(qr.expiresAt) == Duration.zero;
    return Scaffold(
      appBar: AppBar(title: const Text('QR de connexion')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_loadError != null)
            Column(
              children: [
                Text(
                  _loadError!,
                  style: const TextStyle(color: AppTheme.warn),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _loadEleveurs,
                  child: const Text(AppStrings.retry),
                ),
              ],
            )
          else if (_eleveurs.isEmpty)
            const Text(
              'No éleveur accounts are available yet.',
              style: TextStyle(color: AppTheme.textGrey),
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedEleveurId,
              decoration: const InputDecoration(labelText: 'Éleveur'),
              items: [
                for (final eleveur in _eleveurs)
                  DropdownMenuItem(
                    value: eleveur.id,
                    child: Text(eleveur.name),
                  ),
              ],
              onChanged: _creating
                  ? null
                  : (value) => setState(() {
                        _selectedEleveurId = value;
                        _currentQr = null;
                      }),
            ),
            const SizedBox(height: 16),
            if (qr != null && !expired)
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      qr.eleveurName ?? 'Éleveur',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    QrImageView(
                      data: qr.qrPayload,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: AppTheme.surface,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Expires in ${_countdown(qr.expiresAt)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              )
            else if (expired)
              const Center(
                child: Text(
                  'Expired',
                  style: TextStyle(
                    color: AppTheme.warn,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.warn)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed:
                  _creating || _selectedEleveurId == null ? null : _generateQr,
              child: _creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.onPrimary,
                      ),
                    )
                  : const Text('Générer un nouveau QR'),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const InviteScreen(),
              ),
            ),
            child: const Text('Inviter un nouvel éleveur'),
          ),
        ],
      ),
    );
  }
}
