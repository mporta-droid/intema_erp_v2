import 'package:flutter_test/flutter_test.dart';
import 'package:intema_erp_frontend/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('muestra login cuando no hay sesión guardada', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const IntemaApp());
    await tester.pumpAndSettle();

    expect(find.text('Ingreso al ERP/MES'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
