import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/users/users_models.dart';
import '../network/api_client.dart';

class SessionController extends ChangeNotifier {
  SessionController(this.apiClient);

  final ApiClient apiClient;
  UserItem? currentUser;
  String? refreshToken;
  bool isLoading = true;

  bool get isAuthenticated =>
      currentUser != null && apiClient.accessToken != null;

  bool can(String permissionCode) => currentUser?.can(permissionCode) ?? false;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    apiClient.accessToken = prefs.getString('access_token');
    refreshToken = prefs.getString('refresh_token');
    if (apiClient.accessToken == null) {
      isLoading = false;
      notifyListeners();
      return;
    }
    try {
      final data = await apiClient.getJson('/auth/me') as Map;
      currentUser = UserItem.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      await logout();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String usernameOrEmail, String password) async {
    final data =
        await apiClient.postJson('/auth/login', {
              'username_or_email': usernameOrEmail,
              'password': password,
            })
            as Map;
    apiClient.accessToken = data['access_token'].toString();
    refreshToken = data['refresh_token'].toString();
    currentUser = UserItem.fromJson(
      Map<String, dynamic>.from(data['user'] as Map),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', apiClient.accessToken!);
    await prefs.setString('refresh_token', refreshToken!);
    notifyListeners();
  }

  Future<void> logout() async {
    apiClient.accessToken = null;
    refreshToken = null;
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    notifyListeners();
  }
}
