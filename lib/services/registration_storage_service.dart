/// Lightweight in-session storage for registration data.
/// Persists for the app lifetime; cleared on cold restart.
class RegistrationStorageService {
  RegistrationStorageService._();
  static final RegistrationStorageService _instance =
      RegistrationStorageService._();
  factory RegistrationStorageService() => _instance;

  Map<String, dynamic>? _registration;

  Future<void> saveRegistration(Map<String, dynamic> payload) async {
    _registration = payload;
  }

  Map<String, dynamic>? getRegistration() => _registration;

  void clear() => _registration = null;
}
