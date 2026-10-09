import 'package:flutter_test/flutter_test.dart';
import 'package:intema_erp_frontend/core/network/api_client.dart';

void main() {
  const runSmoke = bool.fromEnvironment('RUN_PHASE1_API_SMOKE');
  const adminPassword = String.fromEnvironment(
    'PHASE1_ADMIN_PASSWORD',
    defaultValue: 'Cambiar123!',
  );

  test(
    'Flutter ApiClient puede iniciar sesión contra la API real',
    () async {
      final api = ApiClient();
      final data =
          await api.postJson('/auth/login', {
                'username_or_email': 'admin',
                'password': adminPassword,
              })
              as Map;

      expect(data['access_token'], isNotEmpty);
      expect(data['user']['username'], 'admin');
      expect(
        data['user']['effective_permissions'],
        contains('users_permissions.manage_users'),
      );
    },
    skip: runSmoke
        ? false
        : 'Smoke test desactivado: requiere API y PostgreSQL reales.',
  );
}
