import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  static const requestTimeout = Duration(seconds: 12);

  ApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _httpClient;
  final String baseUrl;
  String? accessToken;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (accessToken != null) 'Authorization': 'Bearer ' + accessToken!,
  };

  Future<dynamic> getJson(String path) async {
    final response = await _withTimeout(
      _httpClient.get(Uri.parse(baseUrl + path), headers: _headers),
    );
    return _handle(response);
  }

  Future<dynamic> postJson(String path, Map<String, dynamic> body) async {
    final response = await _withTimeout(
      _httpClient.post(
        Uri.parse(baseUrl + path),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
    return _handle(response);
  }

  Future<dynamic> patchJson(String path, Map<String, dynamic> body) async {
    final response = await _httpClient.patch(
      Uri.parse(baseUrl + path),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handle(response);
  }

  Future<dynamic> putJson(String path, Map<String, dynamic> body) async {
    final response = await _httpClient.put(
      Uri.parse(baseUrl + path),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handle(response);
  }

  Future<dynamic> deleteJson(String path) async {
    final response = await _httpClient.delete(
      Uri.parse(baseUrl + path),
      headers: _headers,
    );
    return _handle(response);
  }

  Future<http.Response> _withTimeout(Future<http.Response> request) {
    return request.timeout(
      requestTimeout,
      onTimeout: () {
        throw ApiException(
          'Tiempo de espera agotado al conectar con la API.',
          408,
        );
      },
    );
  }

  dynamic _handle(http.Response response) {
    final decoded = response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    var message = 'No se pudo completar la operación.';
    if (decoded is Map && decoded['detail'] != null) {
      message = decoded['detail'].toString();
    }
    throw ApiException(message, response.statusCode);
  }
}
