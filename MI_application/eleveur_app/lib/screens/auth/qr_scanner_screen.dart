import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_routes.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../native/canaux.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _scanning = false;
  String? _message;
  bool _invalidInvitation = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _message = null;
      _invalidInvitation = false;
    });

    try {
      final value = await CanauxNatifs.scannerQr();
      if (!mounted) return;
      if (value == null || value.isEmpty) {
        setState(() => _message = context.tr('qr_cancelled'));
        return;
      }

      final loginToken = _loginToken(value);
      if (loginToken != null) {
        unawaited(
          Navigator.pushReplacementNamed<void, void>(
            context,
            AppRoutes.nameEntry,
            arguments: {'token': loginToken},
          ),
        );
        return;
      }

      final code = _invitationCode(value);
      if (code == null) {
        setState(() {
          _message = context.tr('qr_unknown');
          _invalidInvitation = true;
        });
        return;
      }

      final invitation = await AuthService.instance.checkInvite(code);
      if (!mounted) return;
      if (!invitation.valid) {
        _showInvalidInvitation();
        return;
      }
      final adminName = invitation.adminName?.trim();
      if (adminName == null || adminName.isEmpty) {
        setState(() => _message = context.tr('api_error_generic'));
        return;
      }

      unawaited(
        Navigator.pushReplacementNamed<void, void>(
          context,
          AppRoutes.registration,
          arguments: {'code': code, 'admin_name': adminName},
        ),
      );
    } on NotFoundApiException {
      if (!mounted) return;
      _showInvalidInvitation();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _message = context.tr(error.messageKey));
    } on FormatException {
      if (!mounted) return;
      setState(() => _message = context.tr('api_error_generic'));
    } on PlatformException {
      if (!mounted) return;
      setState(() => _message = context.tr('qr_scanner_error'));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _showInvalidInvitation() {
    setState(() {
      _message = context.tr('invite_invalid_or_expired');
      _invalidInvitation = true;
    });
  }

  String? _invitationCode(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'cowfarm' ||
        uri.host.toLowerCase() != 'invite') {
      return null;
    }
    final code = uri.queryParameters['code'];
    return code == null || code.trim().isEmpty ? null : code.trim();
  }

  String? _loginToken(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'cowfarm' ||
        uri.host.toLowerCase() != 'login') {
      return null;
    }
    final token = uri.queryParameters['token'];
    return token == null || token.trim().isEmpty ? null : token.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                iconSize: 30,
                color: Colors.white,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('scan_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox(width: 270, height: 270, child: _Frame()),
                    if (_scanning) const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  if (_message != null)
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _invalidInvitation
                            ? AppTheme.error
                            : AppTheme.textGrey,
                      ),
                    ),
                  if (!_scanning) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _scan,
                      child: Text(context.tr('scan_again')),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _FramePainter());
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.scanAccent
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const length = 52.0;
    final width = size.width;
    final height = size.height;
    Path corner(
            double x1, double y1, double x2, double y2, double x3, double y3) =>
        Path()
          ..moveTo(x1, y1)
          ..lineTo(x2, y2)
          ..lineTo(x3, y3);
    canvas.drawPath(corner(0, length, 0, 0, length, 0), paint);
    canvas.drawPath(corner(width - length, 0, width, 0, width, length), paint);
    canvas.drawPath(
        corner(0, height - length, 0, height, length, height), paint);
    canvas.drawPath(
      corner(width - length, height, width, height, width, height - length),
      paint,
    );
    canvas.drawLine(
      Offset(16, height / 2),
      Offset(width - 16, height / 2),
      paint
        ..color = AppTheme.scanAccentSoft
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
