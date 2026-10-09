import 'package:flutter/material.dart';

import '../../core/auth/session_controller.dart';
import '../../core/theme/intema_theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final user = session.currentUser!;
    final cards = [
      ('OIT pendientes', 'Fase 3', Icons.assignment_outlined),
      ('Producción en curso', 'Fase 4', Icons.precision_manufacturing_outlined),
      ('Stock mínimo', 'Fase 2', Icons.inventory_2_outlined),
      (
        'Usuarios activos',
        user.roles.length.toString(),
        Icons.verified_user_outlined,
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Dashboard',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Bienvenido, ' + user.fullName + '.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards
              .map(
                (card) => SizedBox(
                  width: 250,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: IntemaColors.yellow.withOpacity(
                              0.25,
                            ),
                            foregroundColor: IntemaColors.navy,
                            child: Icon(card.$3),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  card.$1,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(card.$2),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
