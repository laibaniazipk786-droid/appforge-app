import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  final String code;

  ApiException(this.message, {this.status = 0, this.code = ''});

  @override
  String toString() => message;
}

/// Thin HTTP client for the AppForge REST API.
class Api {
  Api._();
  static final Api instance = Api._();

  final http.Client _client = http.Client();
  String? token;

  /// Current app language, sent as ?lang= so WPML / Polylang return translated content.
  String lang = '';

  Map<String, String> _headers() => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-AppForge-Key': AppConfig.apiKey,
        'X-AppForge-Secret': AppConfig.apiSecret,
        if (token != null && token!.isNotEmpty) ...{
          'Authorization': 'Bearer $token',
          'X-AppForge-Token': token!,
        },
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{if (lang.isNotEmpty) 'lang': lang};
    query?.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) q[k] = v.toString();
    });
    final uri = Uri.parse('${AppConfig.apiBase}$path');
    return q.isEmpty ? uri : uri.replace(queryParameters: {...uri.queryParameters, ...q});
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    return _send(() => _client.get(_uri(path, query), headers: _headers()));
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    return _send(() => _client.post(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response res;
    try {
      res = await request().timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException('No internet connection. Please try again.');
    }
    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw ApiException('Unexpected server response (${res.statusCode}).', status: res.statusCode);
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (data is Map && data['message'] != null) {
      throw ApiException(_stripHtml(data['message'].toString()), status: res.statusCode, code: '${data['code'] ?? ''}');
    }
    throw ApiException('Request failed (${res.statusCode}).', status: res.statusCode);
  }

  static String _stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}
