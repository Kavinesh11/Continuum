import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RegistrationStorageService {
  static const _key = 'continuum_registrations_json';

  Future<void> saveRegistration(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final currentRaw = prefs.getString(_key);
    final List<dynamic> current = currentRaw == null
        ? <dynamic>[]
        : jsonDecode(currentRaw) as List<dynamic>;
    current.add(data);
    await prefs.setString(_key, jsonEncode(current));
  }
}
