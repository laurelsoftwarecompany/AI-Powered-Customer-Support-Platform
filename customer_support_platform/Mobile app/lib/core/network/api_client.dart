import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../storage/token_storage.dart';

class ApiClient {
  /// Where the FastAPI backend lives.
  ///
  /// Override for a physical device / hosted backend without editing code:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000/api/v1
  ///
  /// Otherwise: the Android emulator reaches the host machine's localhost on
  /// the special address 10.0.2.2; web, desktop and iOS simulator use
  /// 127.0.0.1 directly.
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://127.0.0.1:8000/api/v1';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }

  final Dio dio;
  final TokenStorage tokenStorage;

  ApiClient({required this.tokenStorage})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          // Generous: an AI reply embeds the question, searches the knowledge
          // base and calls the language model before responding, which can
          // take far longer than a plain CRUD request.
          receiveTimeout: const Duration(seconds: 60),
          headers: {'Content-Type': 'application/json'},
        ),
      ) {
    // Interceptor: attaches Bearer token to every request automatically
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          // Pass the error forward to be handled by Bloc / Repository
          return handler.next(error);
        },
      ),
    );
  }
}
