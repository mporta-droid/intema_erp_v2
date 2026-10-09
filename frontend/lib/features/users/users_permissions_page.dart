import 'package:flutter/material.dart';

import '../../core/auth/session_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/intema_theme.dart';
import 'users_models.dart';
import 'users_repository.dart';

class UsersPermissionsPage extends StatefulWidget {
  const UsersPermissionsPage({super.key, required this.session});

  final SessionController session;

  @override
  State<UsersPermissionsPage> createState() => _UsersPermissionsPageState();
}

class _UsersPermissionsPageState extends State<UsersPermissionsPage> {
  late final UsersRepository _repository;
  var _loading = true;
  String? _error;
  List<UserItem> _users = [];
  List<RoleItem> _roles = [];
  List<PermissionItem> _permissions = [];

  bool get _canManage => widget.session.can('users_permissions.manage_users');

  @override
  void initState() {
    super.initState();
    _repository = UsersRepository(widget.session.apiClient);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _repository.fetchUsers();
      final roles = await _repository.fetchRoles();
      final permissions = await _repository.fetchPermissions();
      setState(() {
        _users = users;
        _roles = roles;
        _permissions = permissions;
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'No se pudo cargar usuarios, roles y permisos.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createUser() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _UserDialog(roles: _roles),
    );
    if (payload == null) return;
    try {
      await _repository.createUser(payload);
      await _load();
      _showMessage('Usuario creado correctamente.');
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    }
  }

  Future<void> _editUserAccess(UserItem user) async {
    final result = await showDialog<_UserAccessResult>(
      context: context,
      builder: (_) => _UserAccessDialog(
        user: user,
        roles: _roles,
        permissions: _permissions,
      ),
    );
    if (result == null) return;
    try {
      await _repository.setUserRoles(user.id, result.roleIds);
      await _repository.setUserPermissions(user.id, result.overrides);
      await _load();
      _showMessage('Accesos actualizados correctamente.');
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    }
  }

  Future<void> _editRolePermissions(RoleItem role) async {
    final permissionIds = await showDialog<List<String>>(
      context: context,
      builder: (_) =>
          _RolePermissionsDialog(role: role, permissions: _permissions),
    );
    if (permissionIds == null) return;
    try {
      await _repository.setRolePermissions(role.id, permissionIds);
      await _load();
      _showMessage('Permisos del rol actualizados.');
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : IntemaColors.navy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Usuarios y permisos',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Roles base editables, permisos por rol y excepciones individuales.',
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Actualizar',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
                if (_canManage) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _createUser,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Nuevo usuario'),
                  ),
                ],
              ],
            ),
          ),
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'Usuarios'),
              Tab(icon: Icon(Icons.badge_outlined), text: 'Roles'),
              Tab(icon: Icon(Icons.key_outlined), text: 'Permisos'),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : TabBarView(
                    children: [
                      _UsersTab(
                        users: _users,
                        canManage: _canManage,
                        onEditAccess: _editUserAccess,
                      ),
                      _RolesTab(
                        roles: _roles,
                        canManage: _canManage,
                        onEditPermissions: _editRolePermissions,
                      ),
                      _PermissionsTab(permissions: _permissions),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({
    required this.users,
    required this.canManage,
    required this.onEditAccess,
  });

  final List<UserItem> users;
  final bool canManage;
  final ValueChanged<UserItem> onEditAccess;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Nombre')),
                DataColumn(label: Text('Usuario')),
                DataColumn(label: Text('Área / cargo')),
                DataColumn(label: Text('Roles')),
                DataColumn(label: Text('Estado')),
                DataColumn(label: Text('Acciones')),
              ],
              rows: users
                  .map(
                    (user) => DataRow(
                      cells: [
                        DataCell(Text(user.fullName)),
                        DataCell(Text(user.username)),
                        DataCell(Text(user.positionArea ?? '-')),
                        DataCell(
                          _RoleChips(
                            roles: user.roles.map((role) => role.name).toList(),
                          ),
                        ),
                        DataCell(_StatusChip(active: user.isActive)),
                        DataCell(
                          IconButton(
                            tooltip: canManage
                                ? 'Editar accesos'
                                : 'Solo consulta',
                            onPressed: canManage
                                ? () => onEditAccess(user)
                                : null,
                            icon: const Icon(
                              Icons.admin_panel_settings_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _RolesTab extends StatelessWidget {
  const _RolesTab({
    required this.roles,
    required this.canManage,
    required this.onEditPermissions,
  });

  final List<RoleItem> roles;
  final bool canManage;
  final ValueChanged<RoleItem> onEditPermissions;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: roles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final role = roles[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: IntemaColors.yellow.withOpacity(0.25),
              foregroundColor: IntemaColors.navy,
              child: const Icon(Icons.badge_outlined),
            ),
            title: Text(
              role.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              (role.description ?? '') +
                  ' · ' +
                  role.permissions.length.toString() +
                  ' permisos',
            ),
            trailing: IconButton(
              tooltip: canManage ? 'Editar permisos del rol' : 'Solo consulta',
              onPressed: canManage ? () => onEditPermissions(role) : null,
              icon: const Icon(Icons.tune_outlined),
            ),
          ),
        );
      },
    );
  }
}

class _PermissionsTab extends StatelessWidget {
  const _PermissionsTab({required this.permissions});

  final List<PermissionItem> permissions;

  @override
  Widget build(BuildContext context) {
    final byModule = <String, List<PermissionItem>>{};
    for (final permission in permissions) {
      byModule.putIfAbsent(permission.module, () => []).add(permission);
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: byModule.entries.map((entry) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              _moduleLabel(entry.key),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(entry.value.length.toString() + ' permisos'),
            children: entry.value
                .map(
                  (permission) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.key_outlined),
                    title: Text(permission.description),
                    subtitle: Text(permission.code),
                  ),
                )
                .toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _UserDialog extends StatefulWidget {
  const _UserDialog({required this.roles});

  final List<RoleItem> roles;

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _area = TextEditingController();
  final _password = TextEditingController(text: 'Cambiar123!');
  final _selectedRoles = <String>{};

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _area.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo usuario'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'Usuario'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _area,
                  decoration: const InputDecoration(labelText: 'Cargo o área'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña inicial',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Roles base',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ...widget.roles.map(
                  (role) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(role.name),
                    value: _selectedRoles.contains(role.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedRoles.add(role.id);
                        } else {
                          _selectedRoles.remove(role.id);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              'full_name': _name.text.trim(),
              'username': _username.text.trim(),
              'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
              'position_area': _area.text.trim().isEmpty
                  ? null
                  : _area.text.trim(),
              'password': _password.text,
              'role_ids': _selectedRoles.toList(),
              'permission_overrides': [],
              'is_active': true,
            });
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('Crear'),
        ),
      ],
    );
  }
}

class _UserAccessDialog extends StatefulWidget {
  const _UserAccessDialog({
    required this.user,
    required this.roles,
    required this.permissions,
  });

  final UserItem user;
  final List<RoleItem> roles;
  final List<PermissionItem> permissions;

  @override
  State<_UserAccessDialog> createState() => _UserAccessDialogState();
}

class _UserAccessDialogState extends State<_UserAccessDialog> {
  late final Set<String> _roleIds;
  late final Map<String, String> _permissionState;

  @override
  void initState() {
    super.initState();
    _roleIds = widget.user.roles.map((role) => role.id).toSet();
    _permissionState = {
      for (final permission in widget.permissions) permission.id: 'inherit',
    };
    for (final override in widget.user.permissionOverrides) {
      _permissionState[override.permissionId] = override.allowed
          ? 'grant'
          : 'deny';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Accesos de ' + widget.user.fullName),
      content: SizedBox(
        width: 760,
        height: 620,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Roles'),
                  Tab(text: 'Permisos individuales'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      children: widget.roles
                          .map(
                            (role) => CheckboxListTile(
                              title: Text(role.name),
                              subtitle: Text(role.description ?? ''),
                              value: _roleIds.contains(role.id),
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _roleIds.add(role.id);
                                  } else {
                                    _roleIds.remove(role.id);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    ListView.builder(
                      itemCount: widget.permissions.length,
                      itemBuilder: (context, index) {
                        final permission = widget.permissions[index];
                        return ListTile(
                          title: Text(permission.description),
                          subtitle: Text(permission.code),
                          trailing: DropdownButton<String>(
                            value: _permissionState[permission.id],
                            items: const [
                              DropdownMenuItem(
                                value: 'inherit',
                                child: Text('Heredar'),
                              ),
                              DropdownMenuItem(
                                value: 'grant',
                                child: Text('Permitir'),
                              ),
                              DropdownMenuItem(
                                value: 'deny',
                                child: Text('Denegar'),
                              ),
                            ],
                            onChanged: (value) => setState(
                              () => _permissionState[permission.id] =
                                  value ?? 'inherit',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final overrides = <Map<String, dynamic>>[];
            for (final permission in widget.permissions) {
              final state = _permissionState[permission.id];
              if (state == 'grant' || state == 'deny') {
                overrides.add({
                  'permission_id': permission.id,
                  'allowed': state == 'grant',
                  'reason': state == 'grant'
                      ? 'Permiso individual concedido'
                      : 'Permiso individual restringido',
                });
              }
            }
            Navigator.pop(
              context,
              _UserAccessResult(_roleIds.toList(), overrides),
            );
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar accesos'),
        ),
      ],
    );
  }
}

class _RolePermissionsDialog extends StatefulWidget {
  const _RolePermissionsDialog({required this.role, required this.permissions});

  final RoleItem role;
  final List<PermissionItem> permissions;

  @override
  State<_RolePermissionsDialog> createState() => _RolePermissionsDialogState();
}

class _RolePermissionsDialogState extends State<_RolePermissionsDialog> {
  late final Set<String> _selectedPermissionIds;

  @override
  void initState() {
    super.initState();
    _selectedPermissionIds = widget.permissions
        .where(
          (permission) => widget.role.permissions.contains(permission.code),
        )
        .map((permission) => permission.id)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final byModule = <String, List<PermissionItem>>{};
    for (final permission in widget.permissions) {
      byModule.putIfAbsent(permission.module, () => []).add(permission);
    }
    return AlertDialog(
      title: Text('Permisos de ' + widget.role.name),
      content: SizedBox(
        width: 740,
        height: 620,
        child: ListView(
          children: byModule.entries.map((entry) {
            return ExpansionTile(
              title: Text(
                _moduleLabel(entry.key),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              initiallyExpanded:
                  entry.key == 'dashboard' || entry.key == 'users_permissions',
              children: entry.value
                  .map(
                    (permission) => CheckboxListTile(
                      dense: true,
                      title: Text(permission.description),
                      subtitle: Text(permission.code),
                      value: _selectedPermissionIds.contains(permission.id),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedPermissionIds.add(permission.id);
                          } else {
                            _selectedPermissionIds.remove(permission.id);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: () =>
              Navigator.pop(context, _selectedPermissionIds.toList()),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _UserAccessResult {
  _UserAccessResult(this.roleIds, this.overrides);

  final List<String> roleIds;
  final List<Map<String, dynamic>> overrides;
}

class _RoleChips extends StatelessWidget {
  const _RoleChips({required this.roles});

  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) return const Text('-');
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: roles
          .map(
            (role) =>
                Chip(label: Text(role), visualDensity: VisualDensity.compact),
          )
          .toList(),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(active ? 'Activo' : 'Inactivo'),
      backgroundColor: active
          ? const Color(0xFFE7F6EC)
          : const Color(0xFFFFECEC),
      side: BorderSide(
        color: active ? const Color(0xFF3BA55D) : const Color(0xFFE57373),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Campo obligatorio.' : null;

String _moduleLabel(String module) {
  const labels = {
    'dashboard': 'Dashboard',
    'quotations': 'Cotizaciones',
    'clients': 'Clientes',
    'work_orders': 'Órdenes de Trabajo',
    'design': 'Diseño',
    'warehouse_inventory': 'Almacén / Inventario',
    'inventory_movements': 'Movimientos de inventario',
    'kardex': 'Kardex',
    'production': 'Producción',
    'quality_control': 'Control de Calidad',
    'reports': 'Reportes',
    'users_permissions': 'Usuarios y permisos',
    'settings': 'Configuración',
  };
  return labels[module] ?? module;
}
