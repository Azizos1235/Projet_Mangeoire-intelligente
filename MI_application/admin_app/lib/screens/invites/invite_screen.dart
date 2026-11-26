import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/invite_service.dart';
import '../../widgets/async_state.dart';
import '../../widgets/widgets.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _service = InviteService.instance;
  final Set<String> _revokingIds = {};
  Invite? _currentInvite;
  List<InviteRecord> _invites = [];
  Timer? _countdownTimer;
  bool _isInitialLoading = true;
  bool _isCreating = false;
  bool _isLoadingInvites = false;
  String? _currentInviteError;
  String? _inviteListError;
  String? _revokeError;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
    _loadInitialData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait<void>([_createInvite(), _loadInvites()]);
    if (mounted) setState(() => _isInitialLoading = false);
  }

  Future<void> _createInvite() async {
    setState(() {
      _isCreating = true;
      _currentInviteError = null;
    });
    try {
      final invite = await _service.createInvite();
      if (mounted) setState(() => _currentInvite = invite);
    } on ApiException catch (error) {
      if (mounted) setState(() => _currentInviteError = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _currentInviteError = error.message);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _loadInvites() async {
    setState(() {
      _isLoadingInvites = true;
      _inviteListError = null;
    });
    try {
      final invites = await _service.listInvites();
      if (mounted) setState(() => _invites = invites);
    } on ApiException catch (error) {
      if (mounted) setState(() => _inviteListError = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _inviteListError = error.message);
    } finally {
      if (mounted) setState(() => _isLoadingInvites = false);
    }
  }

  Future<void> _newInvitation() async {
    await _createInvite();
    await _loadInvites();
  }

  Future<void> _revokeInvite(InviteRecord invite) async {
    setState(() {
      _revokingIds.add(invite.id);
      _revokeError = null;
    });
    try {
      await _service.revokeInvite(invite.id);
      if (_currentInvite?.id == invite.id && mounted) {
        setState(() => _currentInvite = null);
      }
      await _loadInvites();
    } on ApiException catch (error) {
      if (mounted) setState(() => _revokeError = error.message);
    } finally {
      if (mounted) {
        setState(() => _revokingIds.remove(invite.id));
      }
    }
  }

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} $hour:$minute';
  }

  String _countdown(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) return '00:00';
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds =
        remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Color _statusColor(String status) => switch (status) {
        'active' => AppTheme.primary,
        'used' => AppTheme.textGrey,
        'expired' => AppTheme.warn,
        _ => AppTheme.amber,
      };

  @override
  Widget build(BuildContext context) {
    final currentInvite = _currentInvite;
    return Scaffold(
      appBar: AppBar(title: const Text('Inviter un éleveur')),
      body: RefreshIndicator(
        onRefresh: _loadInvites,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageSpacing,
            4,
            AppTheme.pageSpacing,
            32,
          ),
          children: [
            if (_isInitialLoading && currentInvite == null)
              const AppLoadingState(height: 180)
            else if (currentInvite != null) ...[
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Invitation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Single use. Share it only in person.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppTheme.warn,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (currentInvite.expiresAt.isAfter(DateTime.now()))
                      QrImageView(
                        data: currentInvite.qrPayload,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: AppTheme.surface,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppTheme.primary,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppTheme.primary,
                        ),
                      )
                    else
                      const Text(
                        'Expired',
                        style: TextStyle(
                          color: AppTheme.warn,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      !currentInvite.expiresAt.isAfter(DateTime.now())
                          ? 'Expired'
                          : 'Expires in ${_countdown(currentInvite.expiresAt)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_currentInviteError != null)
                Text(
                  _currentInviteError!,
                  style: const TextStyle(color: AppTheme.warn),
                ),
              FilledButton(
                onPressed: _isCreating ? null : _newInvitation,
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.onPrimary,
                        ),
                      )
                    : Text(
                        !currentInvite.expiresAt.isAfter(DateTime.now())
                            ? 'Generate new QR'
                            : 'New invitation',
                      ),
              ),
            ] else ...[
              if (_currentInviteError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _currentInviteError!,
                    style: const TextStyle(color: AppTheme.warn),
                  ),
                ),
              FilledButton(
                onPressed: _isCreating ? null : _newInvitation,
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.onPrimary,
                        ),
                      )
                    : const Text('Nouvelle invitation'),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Invitations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 10),
            if (_inviteListError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _inviteListError!,
                  style: const TextStyle(color: AppTheme.warn),
                ),
              ),
            if (_isLoadingInvites && _invites.isEmpty)
              const AppLoadingState(height: 100)
            else if (_invites.isEmpty && _inviteListError == null)
              const AppEmptyState(
                message: 'No invitations yet.',
                icon: Icons.qr_code_2_rounded,
              ),
            if (_revokeError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _revokeError!,
                  style: const TextStyle(color: AppTheme.warn),
                ),
              ),
            for (final invite in _invites) ...[
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Created ${_formatDate(invite.createdAt)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        Pill(invite.status, _statusColor(invite.status)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Expires ${_formatDate(invite.expiresAt)}',
                      style: const TextStyle(color: AppTheme.textGrey),
                    ),
                    if (invite.usedByName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Used by ${invite.usedByName}',
                        style: const TextStyle(color: AppTheme.textGrey),
                      ),
                    ],
                    if (invite.status == 'active') ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _revokingIds.contains(invite.id)
                              ? null
                              : () => _revokeInvite(invite),
                          child: _revokingIds.contains(invite.id)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Révoquer'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
