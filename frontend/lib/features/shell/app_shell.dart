import 'package:flutter/material.dart';

import '../../core/auth/session_controller.dart';
import '../../core/theme/intema_theme.dart';
import '../../shared/widgets/intema_logo.dart';
import '../dashboard/dashboard_page.dart';
import '../mes/mes_page.dart';
import '../users/users_permissions_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.session});

  final SessionController session;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _sidebarCollapsed = false;

  List<_MenuItem> get _items => [
    _MenuItem(
      'Dashboard',
      Icons.dashboard_outlined,
      'dashboard.view',
      DashboardPage(session: widget.session),
    ),
    _MenuItem(
      'Cotizaciones',
      Icons.request_quote_outlined,
      'quotations.view',
      const _PendingPhasePage(title: 'Cotizaciones', phase: 'Fase 3'),
    ),
    _MenuItem(
      'Órdenes de Trabajo',
      Icons.assignment_outlined,
      'work_orders.view',
      MesPage(session: widget.session, initialTab: 'oit'),
    ),
    _MenuItem(
      'Diseño',
      Icons.design_services_outlined,
      'design.view',
      MesPage(session: widget.session, initialTab: 'design'),
    ),
    _MenuItem(
      'Almacén / Inventario',
      Icons.inventory_2_outlined,
      'warehouse_inventory.view',
      MesPage(session: widget.session, initialTab: 'warehouse'),
    ),
    _MenuItem(
      'Producción',
      Icons.precision_manufacturing_outlined,
      'production.view',
      MesPage(session: widget.session, initialTab: 'production'),
    ),
    _MenuItem(
      'Control de Calidad',
      Icons.fact_check_outlined,
      'quality_control.view',
      MesPage(session: widget.session, initialTab: 'quality'),
    ),
    _MenuItem(
      'Reportes',
      Icons.bar_chart_outlined,
      'reports.view',
      const _PendingPhasePage(title: 'Reportes', phase: 'Fase 5'),
    ),
    _MenuItem(
      'Usuarios y permisos',
      Icons.admin_panel_settings_outlined,
      'users_permissions.view',
      UsersPermissionsPage(session: widget.session),
    ),
    _MenuItem(
      'Configuración',
      Icons.settings_outlined,
      'settings.view',
      const _PendingPhasePage(title: 'Configuración', phase: 'Fase 1'),
    ),
  ].where((item) => widget.session.can(item.permission)).toList();

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (_selectedIndex >= items.length) _selectedIndex = 0;
    final selected = items.isEmpty ? null : items[_selectedIndex];
    final wide = MediaQuery.sizeOf(context).width >= 900;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              items: items,
              selectedIndex: _selectedIndex,
              onSelected: (index) => setState(() => _selectedIndex = index),
              onLogout: widget.session.logout,
              userName: widget.session.currentUser?.fullName ?? '',
              collapsed: _sidebarCollapsed,
              onToggleCollapsed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            ),
            Expanded(child: selected?.page ?? const _NoAccessPage()),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selected?.title ?? 'INTEMA',
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: IntemaColors.navy,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: _SidebarContent(
          items: items,
          selectedIndex: _selectedIndex,
          onSelected: (index) {
            Navigator.pop(context);
            setState(() => _selectedIndex = index);
          },
          onLogout: widget.session.logout,
          userName: widget.session.currentUser?.fullName ?? '',
        ),
      ),
      body: selected?.page ?? const _NoAccessPage(),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.onLogout,
    required this.userName,
    required this.collapsed,
    required this.onToggleCollapsed,
  });

  final List<_MenuItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  final String userName;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: collapsed ? 78 : 288,
      child: Material(
        color: IntemaColors.navy,
        child: _SidebarContent(
          items: items,
          selectedIndex: selectedIndex,
          onSelected: onSelected,
          onLogout: onLogout,
          userName: userName,
          collapsed: collapsed,
          onToggleCollapsed: onToggleCollapsed,
        ),
      ),
    );
  }
}

class _SidebarContent extends StatelessWidget {
  const _SidebarContent({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.onLogout,
    required this.userName,
    this.collapsed = false,
    this.onToggleCollapsed,
  });

  final List<_MenuItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  final String userName;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              collapsed ? 10 : 20,
              12,
              collapsed ? 10 : 12,
              collapsed ? 8 : 12,
            ),
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: [
                if (!collapsed)
                  const Flexible(child: IntemaLogo(height: 88))
                else
                  const IntemaLogo(height: 46),
                if (onToggleCollapsed != null && !collapsed)
                  IconButton(
                    tooltip: 'Contraer menú',
                    onPressed: onToggleCollapsed,
                    icon: const Icon(Icons.chevron_left),
                    color: Colors.white,
                  ),
              ],
            ),
          ),
          if (collapsed && onToggleCollapsed != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IconButton(
                tooltip: 'Desplegar menú',
                onPressed: onToggleCollapsed,
                icon: const Icon(Icons.chevron_right),
                color: Colors.white,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = index == selectedIndex;
                final tile = ListTile(
                  minLeadingWidth: 0,
                  horizontalTitleGap: collapsed ? 0 : 16,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: collapsed ? 14 : 16,
                  ),
                  selected: selected,
                  selectedTileColor: Colors.white.withOpacity(0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: Icon(
                    item.icon,
                    color: selected ? IntemaColors.yellow : Colors.white70,
                  ),
                  title: collapsed
                      ? null
                      : Text(
                          item.title,
                          style: const TextStyle(color: Colors.white),
                        ),
                  onTap: () => onSelected(index),
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  child: collapsed ? Tooltip(message: item.title, child: tile) : tile,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: collapsed
                ? IconButton(
                    tooltip: 'Salir',
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout),
                    color: Colors.white,
                  )
                : OutlinedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Salir'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PendingPhasePage extends StatelessWidget {
  const _PendingPhasePage({required this.title, required this.phase});

  final String title;
  final String phase;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.construction_outlined,
                  size: 44,
                  color: IntemaColors.navy,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Este módulo está reservado para $phase.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoAccessPage extends StatelessWidget {
  const _NoAccessPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No tienes módulos disponibles. Solicita permisos al administrador.',
      ),
    );
  }
}

class _MenuItem {
  _MenuItem(this.title, this.icon, this.permission, this.page);

  final String title;
  final IconData icon;
  final String permission;
  final Widget page;
}
