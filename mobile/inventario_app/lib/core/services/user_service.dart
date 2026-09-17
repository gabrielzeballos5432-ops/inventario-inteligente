import '../models/role_option.dart';
import '../models/user_account.dart';
import '../network/api_client.dart';

class UserService {
  final ApiClient _apiClient;

  UserService(this._apiClient);

  Future<List<UserAccount>> fetchUsers() async {
    final json =
        await _apiClient.getJson('/api/usuarios/') as List<dynamic>;
    return json
        .map((item) => UserAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<RoleOption>> fetchRoles() async {
    final json =
        await _apiClient.getJson('/api/usuarios/roles') as List<dynamic>;
    return json
        .map((item) => RoleOption.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserAccount> createUser(Map<String, dynamic> payload) async {
    final json = await _apiClient.postJson('/api/usuarios/', payload);
    return UserAccount.fromJson(json as Map<String, dynamic>);
  }

  Future<UserAccount> updateUser(
      int userId, Map<String, dynamic> payload) async {
    final json = await _apiClient.putJson('/api/usuarios/$userId', payload);
    return UserAccount.fromJson(json as Map<String, dynamic>);
  }

  Future<UserAccount> deactivateUser(int userId) async {
    final json = await _apiClient.deleteJson('/api/usuarios/$userId');
    return UserAccount.fromJson(json as Map<String, dynamic>);
  }

  Future<UserAccount> activateUser(int userId) async {
    final json =
        await _apiClient.postJson('/api/usuarios/$userId/activar', {});
    return UserAccount.fromJson(json as Map<String, dynamic>);
  }
}