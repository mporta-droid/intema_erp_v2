import 'package:flutter/material.dart';

import '../../core/auth/session_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/intema_theme.dart';
import '../../shared/widgets/intema_logo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});

  final SessionController session;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.session.login(
        _userController.text.trim(),
        _passwordController.text,
      );
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(
        () => _error =
            'No se pudo conectar con la API. Verifica la red local y el servidor.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 900;
    return Scaffold(
      backgroundColor: IntemaColors.navy,
      body: Stack(
        children: [
          const _BrandBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 20 : 48,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: compact
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _WelcomePanel(compact: true),
                            const SizedBox(height: 24),
                            _LoginCard(
                              formKey: _formKey,
                              userController: _userController,
                              passwordController: _passwordController,
                              loading: _loading,
                              obscure: _obscure,
                              error: _error,
                              onSubmit: _submit,
                              onTogglePassword: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Expanded(child: _WelcomePanel()),
                            const SizedBox(width: 48),
                            SizedBox(
                              width: 500,
                              child: _LoginCard(
                                formKey: _formKey,
                                userController: _userController,
                                passwordController: _passwordController,
                                loading: _loading,
                                obscure: _obscure,
                                error: _error,
                                onSubmit: _submit,
                                onTogglePassword: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandBackdrop extends StatelessWidget {
  const _BrandBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF051747), Color(0xFF082471), Color(0xFF0F3C8F)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -120,
              top: -80,
              child: Opacity(
                opacity: 0.08,
                child: Image.asset(
                  AppConfig.logoAsset,
                  width: 620,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              right: -180,
              bottom: -130,
              child: Opacity(
                opacity: 0.09,
                child: Image.asset(
                  AppConfig.logoAsset,
                  width: 760,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        IntemaLogo(height: compact ? 124 : 172),
        const SizedBox(height: 30),
        Text(
          'ERP/MES INTEMA',
          textAlign: compact ? TextAlign.center : TextAlign.left,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Text(
            'Control operativo para órdenes de trabajo, diseño, producción, almacén y calidad.',
            textAlign: compact ? TextAlign.center : TextAlign.left,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withOpacity(0.82),
                  height: 1.35,
                ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 34),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _FeaturePill(icon: Icons.assignment_outlined, label: 'OIT'),
              _FeaturePill(
                icon: Icons.design_services_outlined,
                label: 'Diseño',
              ),
              _FeaturePill(
                icon: Icons.precision_manufacturing_outlined,
                label: 'Producción',
              ),
              _FeaturePill(icon: Icons.inventory_2_outlined, label: 'Almacén'),
              _FeaturePill(icon: Icons.fact_check_outlined, label: 'Calidad'),
            ],
          ),
        ],
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: IntemaColors.yellow, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.userController,
    required this.passwordController,
    required this.loading,
    required this.obscure,
    required this.error,
    required this.onSubmit,
    required this.onTogglePassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController userController;
  final TextEditingController passwordController;
  final bool loading;
  final bool obscure;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onTogglePassword;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.96),
      child: Padding(
        padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 420 ? 20 : 32),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const IntemaLogo(height: 112),
              const SizedBox(height: 22),
              Text(
                'Ingreso seguro',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: IntemaColors.navy,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'ERP/MES INTEMA S.A.C.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: IntemaColors.text.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: userController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Usuario o correo',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa tu usuario o correo.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: obscure,
                onFieldSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip:
                        obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                    onPressed: onTogglePassword,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Ingresa tu contraseña.'
                    : null,
              ),
              if (error != null) ...[
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE57373)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Color(0xFFB71C1C)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: loading ? null : onSubmit,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: const Text('Ingresar'),
              ),
              const SizedBox(height: 16),
              Text(
                AppConfig.apiBaseUrl,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: IntemaColors.text.withOpacity(0.55),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
