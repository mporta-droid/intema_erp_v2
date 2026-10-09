class PermissionItem {
  PermissionItem({
    required this.id,
    required this.module,
    required this.action,
    required this.code,
    required this.description,
  });

  final String id;
  final String module;
  final String action;
  final String code;
  final String description;

  factory PermissionItem.fromJson(Map<String, dynamic> json) => PermissionItem(
    id: json['id'].toString(),
    module: json['module'].toString(),
    action: json['action'].toString(),
    code: json['code'].toString(),
    description: json['description'].toString(),
  );
}

class RoleItem {
  RoleItem({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.isSystem,
    required this.permissions,
  });

  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final bool isSystem;
  final List<String> permissions;

  factory RoleItem.fromJson(Map<String, dynamic> json) => RoleItem(
    id: json['id'].toString(),
    name: json['name'].toString(),
    description: json['description']?.toString(),
    isActive: json['is_active'] == true,
    isSystem: json['is_system'] == true,
    permissions: (json['permissions'] as List? ?? [])
        .map((item) => item.toString())
        .toList(),
  );
}

class RoleSummary {
  RoleSummary({required this.id, required this.name});

  final String id;
  final String name;

  factory RoleSummary.fromJson(Map<String, dynamic> json) =>
      RoleSummary(id: json['id'].toString(), name: json['name'].toString());
}

class PermissionOverrideItem {
  PermissionOverrideItem({
    required this.permissionId,
    required this.code,
    required this.allowed,
    this.reason,
  });

  final String permissionId;
  final String code;
  final bool allowed;
  final String? reason;

  factory PermissionOverrideItem.fromJson(Map<String, dynamic> json) =>
      PermissionOverrideItem(
        permissionId: json['permission_id'].toString(),
        code: json['code'].toString(),
        allowed: json['allowed'] == true,
        reason: json['reason']?.toString(),
      );
}

class UserItem {
  UserItem({
    required this.id,
    required this.fullName,
    required this.username,
    this.email,
    this.positionArea,
    required this.isActive,
    this.photoUrl,
    required this.roles,
    required this.permissionOverrides,
    required this.effectivePermissions,
    this.lastLoginAt,
  });

  final String id;
  final String fullName;
  final String username;
  final String? email;
  final String? positionArea;
  final bool isActive;
  final String? photoUrl;
  final List<RoleSummary> roles;
  final List<PermissionOverrideItem> permissionOverrides;
  final List<String> effectivePermissions;
  final DateTime? lastLoginAt;

  bool can(String code) => effectivePermissions.contains(code);

  factory UserItem.fromJson(Map<String, dynamic> json) => UserItem(
    id: json['id'].toString(),
    fullName: json['full_name'].toString(),
    username: json['username'].toString(),
    email: json['email']?.toString(),
    positionArea: json['position_area']?.toString(),
    isActive: json['is_active'] == true,
    photoUrl: json['photo_url']?.toString(),
    roles: (json['roles'] as List? ?? [])
        .map(
          (item) =>
              RoleSummary.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    permissionOverrides: (json['permission_overrides'] as List? ?? [])
        .map(
          (item) => PermissionOverrideItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(),
    effectivePermissions: (json['effective_permissions'] as List? ?? [])
        .map((item) => item.toString())
        .toList(),
    lastLoginAt: json['last_login_at'] == null
        ? null
        : DateTime.tryParse(json['last_login_at'].toString()),
  );
}
