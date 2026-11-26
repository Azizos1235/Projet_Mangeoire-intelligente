import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_elevage_admin/core/strings.dart';
import 'package:smart_elevage_admin/screens/scan/nfc_scan_screen.dart';
import 'package:smart_elevage_admin/services/nfc_service.dart';

const _nfcChannel = MethodChannel('nfc/tag');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(_nfcChannel, null);
  });

  Future<NfcScanResult?> openScanner(
    WidgetTester tester, {
    NfcScanMode mode = NfcScanMode.view,
  }) async {
    NfcScanResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.push<NfcScanResult?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NfcScanScreen(mode: mode),
                  ),
                );
              },
              child: const Text('Open scanner'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open scanner'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    return result;
  }

  testWidgets('reads and normalizes a tag using the NFC method channel',
      (tester) async {
    messenger.setMockMethodCallHandler(_nfcChannel, (call) async {
      if (call.method == 'lire') {
        return {'uid': '0a:b1:2c:3d', 'techs': <String>[], 'texte': null};
      }
      return null;
    });

    final result = await openScanner(tester, mode: NfcScanMode.add);

    expect(result?.mode, NfcScanMode.add);
    expect(result?.uid, '0AB12C3D');
  });

  testWidgets('shows the unsupported NFC state', (tester) async {
    messenger.setMockMethodCallHandler(_nfcChannel, (call) async {
      if (call.method == 'lire') {
        throw PlatformException(code: 'NFC_ABSENT');
      }
      return null;
    });

    await openScanner(tester);
    await tester.pump();
    expect(find.text(AppStrings.nfcAbsent), findsOneWidget);
  });

  testWidgets('shows the disabled NFC state and opens system settings',
      (tester) async {
    var settingsOpened = false;
    messenger.setMockMethodCallHandler(_nfcChannel, (call) async {
      if (call.method == 'lire') {
        throw PlatformException(code: 'NFC_DESACTIVE');
      }
      if (call.method == 'parametres') settingsOpened = true;
      return null;
    });

    await openScanner(tester);
    await tester.pump();
    expect(find.text(AppStrings.nfcDisabled), findsOneWidget);
    await tester.tap(find.text(AppStrings.nfcOpenSettings));
    await tester.pump();
    expect(settingsOpened, isTrue);
  });
}
