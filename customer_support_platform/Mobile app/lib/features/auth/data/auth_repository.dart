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
    this.useMock = false,
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
      // The backend's /auth/login is an OAuth2 password-flow endpoint: it
      // expects form-encoded `username` + `password`, not JSON.
      final response = await apiClient.dio.post(
        '/auth/login',
        data: {'username': email, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      return await _persistSession(response.data);
    } on DioException catch (e) {
      throw Exception(
        _errorMessage(e, 'Login failed. Please check your credentials.'),
      );
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

      return await _persistSession(response.data);
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Registration failed.'));
    }
  }

  /// Restore the signed-in user from a stored token (app relaunch).
  /// Returns null when there is no valid session.
  Future<UserModel?> getCurrentUser() async {
    final token = await tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;

    if (useMock) {
      return UserModel(
        id: 'user_001',
        name: 'Customer',
        email: 'customer@example.com',
      );
    }

    try {
      final response = await apiClient.dio.get('/auth/me');
      return UserModel.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      // Token expired or revoked - drop it so the user is sent back to login.
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        await tokenStorage.clearTokens();
      }
      return null;
    }
  }

  Future<bool> isAuthenticated() async {
    final token = await tokenStorage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<UserModel> updateProfile({
    String? name,
    String? phone,
    String? location,
    String? organization,
  }) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      final current = await getCurrentUser() ??
          UserModel(id: 'user_001', name: 'Customer', email: 'user@test.com');
      return current.copyWith(
        name: name,
        phone: phone,
        location: location,
        organization: organization,
      );
    }

    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (phone != null) data['phone'] = phone;
      if (location != null) data['location'] = location;
      if (organization != null) data['organization'] = organization;

      final response = await apiClient.dio.put('/auth/profile', data: data);
      return UserModel.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to update profile.'));
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    try {
      await apiClient.dio.post(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to change password.'));
    }
  }

  Future<void> logout() async {
    await tokenStorage.clearTokens();
  }

  // ---------------------------------------------------------------- helpers

  /// Save the tokens from an auth response and return the user it describes.
  /// The backend issues access tokens only; `refresh_token` is absent and the
  /// stored value stays empty until a refresh flow exists.
  Future<UserModel> _persistSession(dynamic data) async {
    final body = Map<String, dynamic>.from(data as Map);

    await tokenStorage.saveTokens(
      accessToken: body['access_token'] ?? '',
      refreshToken: body['refresh_token'] ?? '',
    );

    final user = body['user'];
    if (user == null) {
      throw Exception('Sign-in succeeded but the server returned no profile.');
    }

    return UserModel.fromJson(Map<String, dynamic>.from(user as Map));
  }

  /// FastAPI reports errors as {"detail": "..."}; fall back gracefully for
  /// validation errors (detail is a list) and for network failures.
  String _errorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'] ?? data['message'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) return first['msg'];
      }
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach the support server. Is the backend running?';
    }
    return fallback;
  }
}
