import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_elevage_admin/core/strings.dart';
import 'package:smart_elevage_admin/screens/cows/add_cow_screen.dart';
import 'package:smart_elevage_admin/services/api_client.dart';
import 'package:smart_elevage_admin/services/cow_service.dart';
import 'package:smart_elevage_admin/services/nfc_service.dart';

void main() {
  const profile = {
    'cow_id': 'COW-17',
    'internal_id': 'COW-17',
    'admin_id': 'admin-1',
    'breed': 'Holstein',
    'type': 'dairy',
    'weight_kg': 500,
    'birth_date': '2021-01-01',
    'age_months': 70,
    'nfc_uid': '01AB23CD',
  };

  NfcService unknownTagService() => NfcService.forTesting(
        isAvailable: () async => true,
        readTag: (_) async => null,
        findCow: (_) => Future.error(
          const ApiException(statusCode: 404, message: 'not found'),
        ),
        cancelScan: () async {},
        openSettings: () async {},
      );

  Future<void> openAddForm(WidgetTester tester, CowService service,
      NfcService nfcService, ValueChanged<bool?> onResult) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddCowScreen(
                      nfcUid: '01:AB:23:CD',
                      tagAlreadyChecked: true,
                      service: service,
                      nfcService: nfcService,
                    ),
                  ),
                );
                onResult(result);
              },
              child: const Text('Open add form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open add form'));
    await tester.pumpAndSettle();
  }

  testWidgets('validates cow ID and submits the scanned UID', (tester) async {
    Map<String, dynamic>? submitted;
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/profiles');
        submitted = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(profile),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
      tokenProvider: () async => 'test-token',
    );
    final service = CowService(apiClient: api);
    bool? result;

    await openAddForm(tester, service, unknownTagService(), (value) {
      result = value;
    });

    await tester.tap(find.text(AppStrings.cowSave));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.cowIdRequired), findsOneWidget);
    expect(submitted, isNull);

    await tester.enterText(find.byType(TextFormField), 'cow-17');
    await tester.tap(find.text(AppStrings.cowSave));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(submitted?['cow_id'], 'COW-17');
    expect(submitted?['nfc_uid'], '01AB23CD');
    expect(submitted?['type'], 'dairy');
    expect(submitted?['breed'], 'Holstein');
    api.dispose();
  });

  testWidgets('shows a clear duplicate message after a 409', (tester) async {
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'detail': 'Cow ID already exists'}),
            409,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'detail': 'No profile for NFC UID'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      }),
      tokenProvider: () async => 'test-token',
    );
    final service = CowService(apiClient: api);

    await openAddForm(tester, service, unknownTagService(), (_) {});
    await tester.enterText(find.byType(TextFormField), 'cow-17');
    await tester.tap(find.text(AppStrings.cowSave));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.cowConflict), findsOneWidget);
    api.dispose();
  });
}
