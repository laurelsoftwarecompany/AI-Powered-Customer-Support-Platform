import 'package:dio/dio.dart';
import '../storage/token_storage.dart';

class ApiClient {
  // 10.0.2.2 is standard for Android Emulator to talk to localhost.
  // We can change this URL when the backend is hosted or if using a real phone.
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

  final Dio dio;
  final TokenStorage tokenStorage;

  ApiClient({required this.tokenStorage})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
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
