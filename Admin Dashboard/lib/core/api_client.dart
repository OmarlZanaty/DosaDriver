import 'package:dio/dio.dart';
import 'api_config.dart';

class ApiClient {
  ApiClient._();

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl, // ✅ no /v1 here
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: const {'Accept': 'application/json'},
      responseType: ResponseType.json,
    ),
  );
}