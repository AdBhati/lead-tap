/// ApiService — single class for all HTTP communication with the Django backend.
///
/// - Stores JWT access token in flutter_secure_storage.
/// - 10-second timeout on every request.
/// - Throws descriptive exceptions for error handling in UI.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:stall_capture/models/models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  // ── Configuration ──────────────────────────────────────────────────────────
  // Change this to your backend URL when deploying.
  static const String _baseUrl = 'http://localhost:8000/api';
  static const Duration _timeout = Duration(seconds: 10);

  static const _storage = FlutterSecureStorage(
    // iOS Keychain options
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    // Android Keystore options
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _tokenKey = 'jwt_access_token';
  static const String _refreshKey = 'jwt_refresh_token';

  static String? _memAccessToken;
  static String? _memRefreshToken;

  // ── Token management ───────────────────────────────────────────────────────
  Future<void> saveTokens(String access, String refresh) async {
    _memAccessToken = access;
    _memRefreshToken = refresh;
    try {
      await Future.wait([
        _storage.write(key: _tokenKey, value: access),
        _storage.write(key: _refreshKey, value: refresh),
      ]);
    } catch (e) {
      debugPrint('Failed to save tokens to secure storage: $e');
    }
  }

  Future<String?> getAccessToken() async {
    if (_memAccessToken != null) return _memAccessToken;
    try {
      _memAccessToken = await _storage.read(key: _tokenKey);
      return _memAccessToken;
    } catch (e) {
      debugPrint('Failed to read token from secure storage: $e');
      return null;
    }
  }

  Future<void> clearTokens() async {
    _memAccessToken = null;
    _memRefreshToken = null;
    try {
      await Future.wait([
        _storage.delete(key: _tokenKey),
        _storage.delete(key: _refreshKey),
      ]);
    } catch (_) {}
  }

  // ── HTTP helpers ───────────────────────────────────────────────────────────
  Future<Map<String, String>> _authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _parseBody(http.Response response) {
    if (response.body.isEmpty) return {};
    try {
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'detail': response.body};
    }
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final body = _parseBody(response);
    final detail = body['detail'] ??
        body['non_field_errors']?.toString() ??
        'Request failed (${response.statusCode})';
    throw ApiException(detail.toString(), statusCode: response.statusCode);
  }

  Future<http.Response> _get(String path) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_baseUrl$path');
    debugPrint('[API] GET $uri');
    final response = await http.get(uri, headers: headers).timeout(_timeout);
    _checkStatus(response);
    return response;
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body,
      {bool auth = true}) async {
    final headers = auth
        ? await _authHeaders()
        : {'Content-Type': 'application/json'};
    final uri = Uri.parse('$_baseUrl$path');
    debugPrint('[API] POST $uri');
    final response = await http
        .post(uri, headers: headers, body: json.encode(body))
        .timeout(_timeout);
    _checkStatus(response);
    return response;
  }

  Future<http.Response> _put(String path, Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_baseUrl$path');
    debugPrint('[API] PUT $uri');
    final response = await http
        .put(uri, headers: headers, body: json.encode(body))
        .timeout(_timeout);
    _checkStatus(response);
    return response;
  }

  Future<http.Response> _delete(String path) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_baseUrl$path');
    debugPrint('[API] DELETE $uri');
    final response = await http.delete(uri, headers: headers).timeout(_timeout);
    _checkStatus(response);
    return response;
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  /// Sign in with Google. Returns user data and whether to show WhatsApp setup.
  Future<Map<String, dynamic>> googleAuth({
    required String idToken,
    String accessToken = '',
    String refreshToken = '',
  }) async {
    final response = await _post(
      '/auth/google/',
      {
        'id_token': idToken,
        'access_token': accessToken,
        'refresh_token': refreshToken,
      },
      auth: false,
    );
    final data = _parseBody(response);
    await saveTokens(data['access'] as String, data['refresh'] as String);
    return data;
  }

  Future<AppUser> saveWhatsAppNumber(String number) async {
    final response = await _post('/auth/whatsapp/', {'whatsapp_number': number});
    return AppUser.fromJson(_parseBody(response));
  }

  Future<AppUser> getMe() async {
    final response = await _get('/me/');
    return AppUser.fromJson(_parseBody(response));
  }

  // ── Events ─────────────────────────────────────────────────────────────────

  Future<List<Event>> getEvents({int page = 1}) async {
    final response = await _get('/events/?page=$page');
    final data = _parseBody(response);
    final results = data['results'] as List<dynamic>;
    return results.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Event> createEvent({
    required String name,
    required String whatsappMessage,
    String mediaUrl = '',
  }) async {
    final response = await _post('/events/', {
      'name': name,
      'whatsapp_message': whatsappMessage,
      'media_url': mediaUrl,
    });
    return Event.fromJson(_parseBody(response));
  }

  Future<Event> updateEvent(
      String eventId, Map<String, dynamic> updates) async {
    final response = await _put('/events/$eventId/', updates);
    return Event.fromJson(_parseBody(response));
  }

  Future<void> deleteEvent(String eventId) async {
    await _delete('/events/$eventId/');
  }

  // ── Leads ──────────────────────────────────────────────────────────────────

  Future<List<Lead>> getLeads(String eventId, {int page = 1}) async {
    final response = await _get('/events/$eventId/leads/?page=$page');
    final data = _parseBody(response);
    final results = data['results'] as List<dynamic>;
    return results.map((e) => Lead.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Lead> createLead({
    required String eventId,
    required String name,
    required String mobileNumber,
    String email = '',
    String comment = '',
  }) async {
    final response = await _post('/events/$eventId/leads/', {
      'name': name,
      'mobile_number': mobileNumber,
      'email': email,
      'comment': comment,
    });
    return Lead.fromJson(_parseBody(response));
  }
}
