import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

/// Thrown when the server returns an HTTP 5xx response.
class ServerException implements Exception {
  final int statusCode;
  final String message;
  const ServerException(this.statusCode, this.message);

  @override
  String toString() => 'ServerException($statusCode): $message';
}

class ApiService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ── Base URLs (configurable via --dart-define) ────────────────────────────
  static const String _coreUrl = String.fromEnvironment(
    'CORE_API_URL',
    defaultValue: 'http://localhost:3000',
  );
  static const String _fastapiUrl = String.fromEnvironment(
    'FASTAPI_URL',
    defaultValue: 'http://localhost:8000',
  );

  // ── Storage ────────────────────────────────────────────────────────────────
  final _secureStorage = const FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _expiryKey = 'token_expiry';
  static const _workerIdKey = 'worker_id';

  Box get _cache => Hive.box('api_cache');

  // ── Token helpers ──────────────────────────────────────────────────────────

  Future<String?> getToken() => _secureStorage.read(key: _tokenKey);

  Future<void> saveToken(String token, String expiresAt) async {
    await _secureStorage.write(key: _tokenKey, value: token);
    await _secureStorage.write(key: _expiryKey, value: expiresAt);
  }

  Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _expiryKey);
    await _secureStorage.delete(key: _workerIdKey);
  }

  Future<void> saveWorkerId(String workerId) async {
    await _secureStorage.write(key: _workerIdKey, value: workerId);
  }

  Future<String?> getWorkerId() => _secureStorage.read(key: _workerIdKey);

  Future<bool> isTokenValid() async {
    final token = await getToken();
    if (token == null) return false;
    final expiry = await _secureStorage.read(key: _expiryKey);
    if (expiry == null) return false;
    try {
      final expiryDate = DateTime.parse(expiry);
      return DateTime.now().isBefore(expiryDate);
    } catch (_) {
      return false;
    }
  }

  // ── HTTP helpers ───────────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Performs a POST request. Throws [ServerException] on 5xx.
  Future<Map<String, dynamic>> _post(
    String url,
    Map<String, dynamic> body, {
    String? cacheKey,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 500) {
        throw ServerException(response.statusCode, response.body);
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (cacheKey != null) _cache.put(cacheKey, response.body);
      return data;
    } on SocketException {
      return _fallbackMap(cacheKey);
    } on TimeoutException {
      return _fallbackMap(cacheKey);
    }
  }

  /// Performs a GET request. Throws [ServerException] on 5xx.
  Future<Map<String, dynamic>> _get(String url, {String? cacheKey}) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 500) {
        throw ServerException(response.statusCode, response.body);
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (cacheKey != null) _cache.put(cacheKey, response.body);
      return data;
    } on SocketException {
      return _fallbackMap(cacheKey);
    } on TimeoutException {
      return _fallbackMap(cacheKey);
    }
  }

  /// Performs a PUT request. Throws [ServerException] on 5xx.
  Future<Map<String, dynamic>> _put(
    String url,
    Map<String, dynamic> body, {
    String? cacheKey,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .put(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 500) {
        throw ServerException(response.statusCode, response.body);
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (cacheKey != null) _cache.put(cacheKey, response.body);
      return data;
    } on SocketException {
      return _fallbackMap(cacheKey);
    } on TimeoutException {
      return _fallbackMap(cacheKey);
    }
  }

  /// Performs a GET that returns a list. Throws [ServerException] on 5xx.
  Future<List<Map<String, dynamic>>> _getList(
    String url, {
    String? cacheKey,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 500) {
        throw ServerException(response.statusCode, response.body);
      }
      final data = jsonDecode(response.body) as List<dynamic>;
      final result = data.cast<Map<String, dynamic>>();
      if (cacheKey != null) _cache.put(cacheKey, response.body);
      return result;
    } on SocketException {
      return _fallbackList(cacheKey);
    } on TimeoutException {
      return _fallbackList(cacheKey);
    }
  }

  Map<String, dynamic> _fallbackMap(String? cacheKey) {
    if (cacheKey != null) {
      final cached = _cache.get(cacheKey);
      if (cached != null) {
        try {
          final decoded = jsonDecode(cached as String);
          if (decoded is Map<String, dynamic>) {
            return {...decoded, '_isOffline': true};
          }
        } catch (_) {}
      }
    }
    return {'_isOffline': true};
  }

  List<Map<String, dynamic>> _fallbackList(String? cacheKey) {
    if (cacheKey != null) {
      final cached = _cache.get(cacheKey);
      if (cached != null) {
        try {
          final decoded = jsonDecode(cached as String);
          if (decoded is List) {
            return decoded.cast<Map<String, dynamic>>();
          }
        } catch (_) {}
      }
    }
    return [];
  }

  // ── Public API methods ─────────────────────────────────────────────────────

  /// POST /auth/login → Core Backend
  /// Persists JWT token and worker_id on success.
  Future<Map<String, dynamic>> login(String workerId, String password) async {
    final result = await _post('$_coreUrl/auth/login', {
      'worker_id': workerId,
      'password': password,
    });
    final token = result['token'] as String?;
    final expiresAt = result['expires_at'] as String?;
    if (token != null && expiresAt != null) {
      await saveToken(token, expiresAt);
      final id = result['worker_id'] as String? ?? workerId;
      await saveWorkerId(id);
    }
    return result;
  }

  /// POST /onboard → FastAPI Gateway
  Future<Map<String, dynamic>> fetchRiskProfile(
    Map<String, dynamic> payload,
  ) async {
    return _post(
      '$_fastapiUrl/onboard',
      payload,
      cacheKey: 'risk_profile_${payload['worker_id']}',
    );
  }

  /// POST /claims/submit → FastAPI Gateway
  Future<Map<String, dynamic>> submitClaim(Map<String, dynamic> payload) async {
    return _post('$_fastapiUrl/claims/submit', payload);
  }

  /// GET /claims/:id/status → Core Backend
  Future<Map<String, dynamic>> getClaimStatus(String claimId) async {
    return _get(
      '$_coreUrl/claims/$claimId/status',
      cacheKey: 'claim_status_$claimId',
    );
  }

  /// GET /claims → Core Backend (worker's claims list)
  Future<List<Map<String, dynamic>>> getClaims() async {
    return _getList('$_coreUrl/claims', cacheKey: 'claims_list');
  }

  /// GET /workers/:id → Core Backend
  Future<Map<String, dynamic>> getWorkerProfile(String workerId) async {
    return _get(
      '$_coreUrl/workers/$workerId',
      cacheKey: 'worker_profile_$workerId',
    );
  }

  /// PUT /workers/:id → Core Backend
  Future<Map<String, dynamic>> updateWorkerProfile(
    String workerId,
    Map<String, dynamic> data,
  ) async {
    return _put(
      '$_coreUrl/workers/$workerId',
      data,
      cacheKey: 'worker_profile_$workerId',
    );
  }

  /// POST /policies → Core Backend
  Future<Map<String, dynamic>> createPolicy(
    Map<String, dynamic> payload,
  ) async {
    return _post('$_coreUrl/policies', payload);
  }

  /// POST /workers/:id/fcm-token → Core Backend
  Future<void> registerFcmToken(String workerId, String fcmToken) async {
    try {
      final headers = await _authHeaders();
      await http
          .post(
            Uri.parse('$_coreUrl/workers/$workerId/fcm-token'),
            headers: headers,
            body: jsonEncode({'fcm_token': fcmToken}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // FCM registration is best-effort; never crash the app
    }
  }

  /// GET /payouts → Core Backend
  Future<List<Map<String, dynamic>>> getPayouts() async {
    return _getList('$_coreUrl/payouts', cacheKey: 'payouts_list');
  }

  /// POST /consent → Core Backend (DPDP consent receipt)
  Future<Map<String, dynamic>> submitConsent(Map<String, dynamic> payload) async {
    return _post('$_coreUrl/consent', payload);
  }

  /// POST /mandates → Core Backend (UPI eNACH mandate creation)
  Future<Map<String, dynamic>> createMandate(Map<String, dynamic> payload) async {
    return _post('$_coreUrl/mandates', payload);
  }

  /// GET /mandates/:workerId → Core Backend
  Future<Map<String, dynamic>> getMandateStatus(String workerId) async {
    return _get('$_coreUrl/mandates/$workerId', cacheKey: 'mandate_$workerId');
  }
}
