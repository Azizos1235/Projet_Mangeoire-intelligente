import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/nfc_service.dart';

class NfcScanScreen extends StatefulWidget {
  const NfcScanScreen({
    super.key,
    required this.mode,
    this.service,
  });

  final NfcScanMode mode;
  final NfcService? service;

  @override
  State<NfcScanScreen> createState() => _NfcScanScreenState();
}

class _NfcScanScreenState extends State<NfcScanScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _scanning = false;
  String? _error;
  String? _errorCode;

  NfcService get _service => widget.service ?? NfcService.instance;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scan();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _scanning) {
      unawaited(_service.cancelScan());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_scanning) unawaited(_service.cancelScan());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _error = null;
      _errorCode = null;
    });

    try {
      final tag = await _service.readTag();
      if (!mounted) return;
      if (tag == null) {
        setState(() => _error = AppStrings.nfcCancelled);
        return;
      }
      final uid = NfcService.normalizeUid(tag.uid);
      Navigator.pop<NfcScanResult?>(
        context,
        NfcScanResult(mode: widget.mode, uid: uid),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorCode = error.code;
        _error = _platformErrorMessage(error);
      });
    } on FormatException {
      if (!mounted) return;
      setState(() => _error = AppStrings.nfcReadFailed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppStrings.nfcReadFailed);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  String _platformErrorMessage(PlatformException error) => switch (error.code) {
        'NFC_ABSENT' => AppStrings.nfcAbsent,
        'NFC_DESACTIVE' => AppStrings.nfcDisabled,
        'DELAI_DEPASSE' => AppStrings.nfcTimeout,
        'DEJA_EN_COURS' => AppStrings.nfcBusy,
        _ => error.message?.isNotEmpty == true
            ? error.message!
            : AppStrings.nfcReadFailed,
      };

  Future<void> _cancel() async {
    try {
      await _service.cancelScan();
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _error = _platformErrorMessage(error));
    }
  }

  Future<void> _openSettings() async {
    try {
      await _service.openSettings();
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _error = _platformErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      AppStrings.nfcTitle,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (_, __) => CustomPaint(
                        painter: _RipplePainter(_controller.value),
                        child: Center(
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.nfc_rounded,
                              color: AppTheme.onPrimary,
                              size: 56,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    AppStrings.nfcStep,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    AppStrings.nfcHelp,
                    style: TextStyle(color: AppTheme.textGrey),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _scanning ? AppStrings.nfcWaiting : AppStrings.nfcReady,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  if (_scanning) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _cancel,
                      icon: const Icon(Icons.close),
                      label: const Text(AppStrings.nfcCancel),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (_errorCode == 'NFC_DESACTIVE' && !_scanning) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings),
                      label: const Text(AppStrings.nfcOpenSettings),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (!_scanning)
                    FilledButton(
                      onPressed: _scan,
                      child: const Text(AppStrings.nfcRetry),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _RipplePainter extends CustomPainter {
  const _RipplePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var index = 0; index < 3; index++) {
      final phase = (progress + index / 3) % 1;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppTheme.primary.withValues(alpha: (1 - phase) * 0.45);
      canvas.drawCircle(center, 52 + phase * 88, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) => old.progress != progress;
}
