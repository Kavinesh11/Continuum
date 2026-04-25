import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'demo_backend.dart';

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

  // ── Base URLs ──────────────────────────────────────────────────────────────
  static bool get _useNginx {
    final envVal = dotenv.env['USE_NGINX'];
    if (envVal != null) {
      return envVal.toLowerCase() == 'true';
    }
    return const bool.fromEnvironment('USE_NGINX', defaultValue: true);
  }

  static String get _apiHostOverride {
    final envVal = dotenv.env['API_HOST'];
    if (envVal != null && envVal.isNotEmpty) {
      return envVal;
    }
    return const String.fromEnvironment('API_HOST', defaultValue: '57.159.30.7');
  }

  // For physical phones, pass --dart-define=API_HOST=<laptop-lan-ip>
  // Example: --dart-define=API_HOST=192.168.1.23
  static String get _resolvedHost {
    if (_apiHostOverride.isNotEmpty) return _apiHostOverride;
    if (kIsWeb) return 'localhost';
    if (Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }

  static String get _coreUrl {
    if (_useNginx) return 'http://$_resolvedHost/api';
    return 'http://$_resolvedHost:3000';
  }

  static String get _fastapiUrl {
    if (_useNginx) return 'http://$_resolvedHost/ml';
    return 'http://$_resolvedHost:8000';
  }

  // ── Storage ────────────────────────────────────────────────────────────────
  final _secureStorage = const FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _expiryKey = 'token_expiry';

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
  }

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

  String? _decodeWorkerIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final map = jsonDecode(payload) as Map<String, dynamic>;
      return map['worker_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String> getCurrentWorkerId() async {
    final token = await getToken();
    final id = token != null ? _decodeWorkerIdFromToken(token) : null;
    return id ?? 'current_worker';
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
      final decoded = jsonDecode(response.body);
      final result = _toListOfMaps(decoded);
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
            return decoded;
          }
        } catch (_) {}
      }
    }
    return {};
  }

  List<Map<String, dynamic>> _fallbackList(String? cacheKey) {
    if (cacheKey != null) {
      final cached = _cache.get(cacheKey);
      if (cached != null) {
        try {
          final decoded = jsonDecode(cached as String);
          return _toListOfMaps(decoded);
        } catch (_) {}
      }
    }
    return [];
  }

  List<Map<String, dynamic>> _toListOfMaps(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (decoded is Map) {
      for (final key in const [
        'items',
        'data',
        'results',
        'payouts',
        'claims',
      ]) {
        final value = decoded[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }

    return [];
  }

  // ── Public API methods — delegated to DemoBackend ─────────────────────────

  final DemoBackend _mock = DemoBackend.instance;

  Future<Map<String, dynamic>> login(String workerId, String password) =>
      _mock.login(workerId, password);

  Future<Map<String, dynamic>> fetchRiskProfile(
    Map<String, dynamic> payload,
  ) =>
      _mock.fetchRiskProfile(payload);

  Future<Map<String, dynamic>> submitClaim(Map<String, dynamic> payload) =>
      _mock.submitClaim(payload);

  Future<Map<String, dynamic>> getClaimStatus(String claimId) =>
      _mock.getClaimStatus(claimId);

  Future<List<Map<String, dynamic>>> getClaims() => _mock.getClaims();

  Future<Map<String, dynamic>> getWorkerProfile(String workerId) =>
      _mock.getWorkerProfile(workerId);

  Future<Map<String, dynamic>> getWorkerProfileCurrent() =>
      _mock.getWorkerProfile(_mock.activeDriver.partnerId);

  Future<Map<String, dynamic>> updateWorkerProfile(
    String workerId,
    Map<String, dynamic> data,
  ) =>
      _mock.updateWorkerProfile(workerId, data);

  Future<Map<String, dynamic>> updateWorkerProfileCurrent(
    Map<String, dynamic> data,
  ) =>
      _mock.updateWorkerProfile(_mock.activeDriver.partnerId, data);

  Future<Map<String, dynamic>> createPolicy(Map<String, dynamic> payload) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {'status': 'ok', 'policy_id': 'POL-${DateTime.now().millisecondsSinceEpoch}'};
  }

  Future<Map<String, dynamic>> getPolicyContent() => _mock.getPolicyContent();

  Future<void> registerFcmToken(String workerId, String fcmToken) async {}

  Future<List<Map<String, dynamic>>> getPayouts() => _mock.getPayouts();

  Future<List<Map<String, dynamic>>> getAssistMessages() =>
      _mock.getAssistMessages();

  Future<Map<String, dynamic>> sendAssistMessage(String message) =>
      _mock.sendAssistMessage(message);

  Future<void> clearAssistHistory() => _mock.clearAssistHistory();

  Future<void> requestOtp({
    required String phone,
    required String email,
  }) =>
      _mock.requestOtp(phone: phone, email: email);

  Future<void> verifyOtp(String otp) => _mock.verifyOtp(otp);

  Future<String> completeRegistration({
    required String fullName,
    required String phone,
    required String email,
    required String platform,
    required String city,
    required String partnerId,
    required String vehicleType,
    required String plan,
    required String upiId,
    required bool acceptedTerms,
  }) =>
      _mock.completeRegistration(
        fullName: fullName,
        phone: phone,
        email: email,
        platform: platform,
        city: city,
        partnerId: partnerId,
        vehicleType: vehicleType,
        plan: plan,
        upiId: upiId,
        acceptedTerms: acceptedTerms,
      );
}
