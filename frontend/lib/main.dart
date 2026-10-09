import 'package:flutter/material.dart';

import 'core/auth/session_controller.dart';
import 'core/network/api_client.dart';
import 'core/theme/intema_theme.dart';
import 'features/auth/login_page.dart';
import 'features/shell/app_shell.dart';

void main() {
  runApp(const IntemaApp());
}

class IntemaApp extends StatefulWidget {
  const IntemaApp({super.key});

  @override
  State<IntemaApp> createState() => _IntemaAppState();
}

class _IntemaAppState extends State<IntemaApp> {
  late final ApiClient _apiClient;
  late final SessionController _session;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _session = SessionController(_apiClient)..restore();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        return MaterialApp(
          title: 'INTEMA ERP/MES',
          debugShowCheckedModeBanner: false,
          theme: IntemaTheme.light(),
          home: _session.isLoading
              ? const _LoadingPage()
              : _session.isAuthenticated
              ? AppShell(session: _session)
              : LoginPage(session: _session),
        );
      },
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
