import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import 'user_model.dart';

class AuthRepository {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  final bool useMock;

  AuthRepository({
    required this.apiClient,
    required this.tokenStorage,
    this.useMock = true,
  });

  // Login request
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 900));

      await tokenStorage.saveTokens(
        accessToken: 'mock_access_jwt_token_12345',
        refreshToken: 'mock_refresh_jwt_token_12345',
      );

      // Derive dynamic name from email prefix (e.g. "aoun@customer.com" -> "Aoun")
      final namePart = email.split('@').first;
      final displayName = namePart.isNotEmpty
          ? '${namePart[0].toUpperCase()}${namePart.substring(1)}'
          : 'Customer';

      return UserModel(id: 'user_001', name: displayName, email: email);
    }

    try {
      final response = await apiClient.dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final data = response.data;
      final accessToken = data['access_token'] ?? '';
      final refreshToken = data['refresh_token'] ?? '';

      await tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      return UserModel.fromJson(data['user']);
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['message'] ??
          'Login failed. Please check credentials.';
      throw Exception(errorMessage);
    }
  }

  // Register request
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 900));

      await tokenStorage.saveTokens(
        accessToken: 'mock_access_jwt_token_12345',
        refreshToken: 'mock_refresh_jwt_token_12345',
      );

      return UserModel(
        id: 'user_001',
        name: name.isNotEmpty ? name : 'Customer',
        email: email,
      );
    }

    try {
      final response = await apiClient.dio.post(
        '/auth/register',
        data: {'name': name, 'email': email, 'password': password},
      );

      final data = response.data;
      final accessToken = data['access_token'] ?? '';
      final refreshToken = data['refresh_token'] ?? '';

      await tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      return UserModel.fromJson(data['user']);
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['message'] ?? 'Registration failed.';
      throw Exception(errorMessage);
    }
  }

  Future<bool> isAuthenticated() async {
    final token = await tokenStorage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    await tokenStorage.clearTokens();
  }
}
