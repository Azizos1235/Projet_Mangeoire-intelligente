import 'package:eleveur_app/models/eleveur_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin email is the display name when the response has no name', () {
    final user = EleveurUser.fromJson({
      'id': 'admin-1',
      'name': null,
      'role': 'admin',
      'email': 'admin@example.com',
    });

    expect(user.displayName, 'admin@example.com');
    expect(user.adminId, '');
  });

  test('a non-empty user name takes precedence over email', () {
    final user = EleveurUser.fromJson({
      'id': 'eleveur-1',
      'name': 'Amina',
      'role': 'eleveur',
      'admin_id': 'admin-1',
      'email': 'amina@example.com',
    });

    expect(user.displayName, 'Amina');
    expect(user.adminId, 'admin-1');
  });
}
