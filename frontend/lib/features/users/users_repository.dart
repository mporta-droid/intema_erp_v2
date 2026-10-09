import '../../core/network/api_client.dart';
import 'users_models.dart';

class UsersRepository {
  UsersRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<UserItem>> fetchUsers() async {
    final data = await _apiClient.getJson('/users') as List;
    return data
        .map(
          (item) => UserItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<RoleItem>> fetchRoles() async {
    final data = await _apiClient.getJson('/roles') as List;
    return data
        .map(
          (item) => RoleItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<PermissionItem>> fetchPermissions() async {
    final data = await _apiClient.getJson('/permissions') as List;
    return data
        .map(
          (item) =>
              PermissionItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<UserItem> createUser(Map<String, dynamic> payload) async {
    final data = await _apiClient.postJson('/users', payload) as Map;
    return UserItem.fromJson(Map<String, dynamic>.from(data));
  }

  Future<UserItem> updateUser(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    final data = await _apiClient.patchJson('/users/' + userId, payload) as Map;
    return UserItem.fromJson(Map<String, dynamic>.from(data));
  }

  Future<UserItem> setUserRoles(String userId, List<String> roleIds) async {
    final data =
        await _apiClient.putJson('/users/' + userId + '/roles', {
              'role_ids': roleIds,
            })
            as Map;
    return UserItem.fromJson(Map<String, dynamic>.from(data));
  }

  Future<UserItem> setUserPermissions(
    String userId,
    List<Map<String, dynamic>> overrides,
  ) async {
    final data =
        await _apiClient.putJson('/users/' + userId + '/permissions', {
              'overrides': overrides,
            })
            as Map;
    return UserItem.fromJson(Map<String, dynamic>.from(data));
  }

  Future<RoleItem> setRolePermissions(
    String roleId,
    List<String> permissionIds,
  ) async {
    final data =
        await _apiClient.putJson('/roles/' + roleId + '/permissions', {
              'permission_ids': permissionIds,
            })
            as Map;
    return RoleItem.fromJson(Map<String, dynamic>.from(data));
  }
}
