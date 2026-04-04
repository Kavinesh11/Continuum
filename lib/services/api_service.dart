class ApiService {
  Future<void> requestOtp({
    required String phone,
    required String email,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (phone.trim().length < 10 || !email.contains('@')) {
      throw Exception('Please enter a valid phone number and email.');
    }
  }

  Future<void> verifyOtp(String otp) async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (otp.trim() != '123456') {
      throw Exception('Invalid OTP. Please try again.');
    }
  }

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
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!acceptedTerms) {
      throw Exception('Please accept terms and conditions.');
    }
    if (fullName.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        platform.isEmpty ||
        city.isEmpty ||
        partnerId.isEmpty ||
        vehicleType.isEmpty ||
        plan.isEmpty ||
        upiId.isEmpty) {
      throw Exception('Please complete all required details.');
    }
    final now = DateTime.now();
    return 'POL-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecond.toString().padLeft(3, '0')}';
  }
}
