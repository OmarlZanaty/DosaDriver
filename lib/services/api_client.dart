import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Uri _uri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${AppConfig.baseUrl}${AppConfig.apiPrefix}$p');
  }

  Future<Map<String, String>> _authHeaders({bool forceRefreshToken = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not authenticated (Firebase user is null)');
    }

    final token = await user.getIdToken(forceRefreshToken);
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  /// Sends request, and if 401 happens it will refresh token once and retry.
  Future<http.Response> request(
      String method,
      String path, {
        Map<String, dynamic>? jsonBody,
      }) async {
    http.Response res = await _send(method, path, jsonBody: jsonBody);

    if (res.statusCode == 401) {
      // Token might be expired - refresh once
      res = await _send(method, path, jsonBody: jsonBody, forceRefreshToken: true);
    }

    return res;
  }

  Future<http.Response> _send(
      String method,
      String path, {
        Map<String, dynamic>? jsonBody,
        bool forceRefreshToken = false,
      }) async {
    final headers = await _authHeaders(forceRefreshToken: forceRefreshToken);
    final uri = _uri(path);

    switch (method.toUpperCase()) {
      case 'GET':
        return _http.get(uri, headers: headers);

      case 'POST':
        return _http.post(
          uri,
          headers: headers,
          body: json.encode(jsonBody ?? const {}),
        );

      case 'PATCH':
        return _http.patch(
          uri,
          headers: headers,
          body: json.encode(jsonBody ?? const {}),
        );

      case 'PUT':
        return _http.put(
          uri,
          headers: headers,
          body: json.encode(jsonBody ?? const {}),
        );

      case 'DELETE':
        return _http.delete(uri, headers: headers);

      default:
        throw Exception('Unsupported HTTP method: $method');
    }
  }
}
