import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_elevage_admin/models/models.dart';
import 'package:smart_elevage_admin/screens/cows/cow_form_screen.dart';
import 'package:smart_elevage_admin/services/api_client.dart';
import 'package:smart_elevage_admin/services/cow_service.dart';

void main() {
  testWidgets('shows the server message for a forbidden profile update', (
    tester,
  ) async {
    const serverMessage = 'You cannot edit this cow.';
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        return http.Response(
          jsonEncode({'detail': serverMessage}),
          403,
          headers: {'content-type': 'application/json'},
        );
      }),
      tokenProvider: () async => 'test-token',
    );
    final service = CowService(apiClient: api);
    final cow = Cow(
      id: 'COW001',
      internalId: '3C43FA39',
      breed: 'Holstein',
      type: CowType.dairy,
      weightKg: 500,
      birthDate: DateTime(2020, 1, 1),
      ageMonths: 75,
      adminId: 'admin-1',
      nfcUid: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CowFormScreen(cow: cow, service: service),
      ),
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text(serverMessage), findsOneWidget);
    api.dispose();
  });
}
