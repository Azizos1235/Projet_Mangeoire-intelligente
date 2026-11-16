import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/l10n.dart';
import '../../services/nfc_service.dart';
import '../../core/theme.dart';

/// Reads one physical NFC tag and returns it to the caller.
class NfcScanScreen extends StatefulWidget {
  final NfcScanMode mode;

  const NfcScanScreen({super.key, required this.mode});

  @override
  State<NfcScanScreen> createState() => _NfcScanScreenState();
}

class _NfcScanScreenState extends State<NfcScanScreen>
    with SingleTickerProviderStateMixin {
  bool _scanning = false;
  String? _error;
  String? _errorCode;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    if (_scanning) unawaited(NfcService.instance.cancelScan());
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
      final tag = await NfcService.instance.readTag();
      if (!mounted) return;
      if (tag == null) {
        setState(() => _error = context.tr('nfc_cancelled'));
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
      setState(() => _error = context.tr('nfc_read_failed'));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = context.tr('nfc_read_failed'));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  String _platformErrorMessage(PlatformException error) {
    switch (error.code) {
      case 'NFC_ABSENT':
        return context.tr('nfc_absent');
      case 'NFC_DESACTIVE':
        return context.tr('nfc_disabled');
      case 'DELAI_DEPASSE':
        return context.tr('nfc_timeout');
      case 'DEJA_EN_COURS':
        return context.tr('nfc_busy');
      default:
        return error.message?.isNotEmpty == true
            ? error.message!
            : context.tr('nfc_read_failed');
    }
  }

  Future<void> _cancel() async {
    try {
      await NfcService.instance.cancelScan();
      if (!mounted) return;
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _error = _platformErrorMessage(error));
    }
  }

  Future<void> _openSettings() async {
    try {
      await NfcService.instance.openSettings();
      if (!mounted) return;
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _error = _platformErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  context.tr('nfc_title'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              const Spacer(),
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
                          color: Colors.white,
                          size: 56,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                context.tr('nfc_step'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('nfc_help'),
                style: const TextStyle(color: AppTheme.textGrey),
              ),
              const SizedBox(height: 14),
              Text(
                context.tr('nfc_wait'),
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
                  label: Text(context.tr('cancel')),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.error),
                ),
              ],
              if (_errorCode == 'NFC_DESACTIVE' && !_scanning) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings),
                  label: Text(context.tr('nfc_open_settings')),
                ),
              ],
              const Spacer(),
              if (!_scanning)
                FilledButton(
                  onPressed: _scan,
                  child: Text(context.tr('nfc_retry')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;

  const _RipplePainter(this.progress);

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
