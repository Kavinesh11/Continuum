import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

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
    return const String.fromEnvironment(
      'API_HOST',
      defaultValue: '192.168.1.10',
    );
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

  // ── Public API methods ─────────────────────────────────────────────────────

  /// POST /auth/login → Core Backend
  Future<Map<String, dynamic>> login(String workerId, String password) async {
    return _post('$_coreUrl/auth/login', {
      'worker_id': workerId,
      'password': password,
    });
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
    return _post('$_coreUrl/claims', payload);
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

  Future<Map<String, dynamic>> getWorkerProfileCurrent() async {
    final workerId = await getCurrentWorkerId();
    return getWorkerProfile(workerId);
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

  Future<Map<String, dynamic>> updateWorkerProfileCurrent(
    Map<String, dynamic> data,
  ) async {
    final workerId = await getCurrentWorkerId();
    return updateWorkerProfile(workerId, data);
  }

  /// POST /policies → Core Backend
  Future<Map<String, dynamic>> createPolicy(
    Map<String, dynamic> payload,
  ) async {
    return _post('$_coreUrl/policies', payload);
  }

  Future<Map<String, dynamic>> getPolicyContent() async {
    return _get('$_coreUrl/policies/content', cacheKey: 'policy_content');
  }

  /// PUT /workers/fcm-token → Core Backend
  Future<void> registerFcmToken(String workerId, String fcmToken) async {
    try {
      await _put('$_coreUrl/workers/fcm-token', {'fcm_token': fcmToken});
    } catch (_) {
      // FCM registration is best-effort; never crash the app
    }
  }

  /// GET /payouts → Core Backend
  Future<List<Map<String, dynamic>>> getPayouts() async {
    return _getList('$_coreUrl/payouts', cacheKey: 'payouts_list');
  }

  /// GET /assist/messages → Core Backend
  Future<List<Map<String, dynamic>>> getAssistMessages() async {
    try {
      return _getList('$_coreUrl/assist/messages', cacheKey: 'assist_messages');
    } catch (_) {
      return [];
    }
  }

  /// POST /assist/chat → Core Backend
  Future<Map<String, dynamic>> sendAssistMessage(String message) async {
    try {
      return _post('$_coreUrl/assist/chat', {'message': message});
    } catch (_) {
      return {};
    }
  }

  /// DELETE /assist/messages → Core Backend
  Future<void> clearAssistHistory() async {
    try {
      final headers = await _authHeaders();
      await http
          .delete(Uri.parse('$_coreUrl/assist/messages'), headers: headers)
          .timeout(const Duration(seconds: 15));
      _cache.delete('assist_messages');
    } catch (_) {}
  }

  /// POST /documents/upload → Core Backend
  /// Uploads photos to Pinata IPFS via the backend.
  /// Returns list of {filename, cid} maps, or empty list on failure.
  /// Photos are named on the server using the JWT's worker_id + platform.
  Future<List<Map<String, dynamic>>> uploadPhotos(List<XFile> photos) async {
    if (photos.isEmpty) return [];
    try {
      final token = await getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_coreUrl/documents/upload'),
      );
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      for (final photo in photos) {
        final bytes = await photo.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'photos',
            bytes,
            filename: photo.name.isNotEmpty ? photo.name : 'photo.jpg',
          ),
        );
      }

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode >= 400) {
        throw ServerException(streamed.statusCode, body);
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final cids = decoded['cids'];
      if (cids is List) {
        return cids.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } on SocketException {
      return [];
    } on TimeoutException {
      return [];
    }
  }

}
