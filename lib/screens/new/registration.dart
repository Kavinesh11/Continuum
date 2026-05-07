import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../routes/app_routes.dart';
import '../../sandbox/driver_provider.dart';
import '../../services/api_service.dart';
import '../../services/demo_backend.dart';
import '../../services/registration_storage_service.dart';
import '../../state/demo_orchestrator.dart';
import '../../theme/app_theme.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _api = ApiService();
  final _storage = RegistrationStorageService();
  final _imagePicker = ImagePicker();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _otpController = TextEditingController();
  final _partnerIdController = TextEditingController();
  final _swiggyPartnerIdController = TextEditingController();
  final _zomatoPartnerIdController = TextEditingController();
  final _cityController = TextEditingController();
  final _vehicleRegistrationController = TextEditingController();
  final _upiController = TextEditingController();

  XFile? _licenseFrontImage;
  XFile? _licenseBackImage;
  XFile? _profileImage;

  final _identityKey = GlobalKey<FormState>();
  final _otpKey = GlobalKey<FormState>();
  final _workKey = GlobalKey<FormState>();
  final _planKey = GlobalKey<FormState>();

  int _step = 0;
  bool _isBusy = false;
  Set<String> _selectedPlatforms = {'Swiggy'};
  String _vehicleType = 'Bike';
  String _plan = 'Silver';
  bool _acceptedTerms = false;
  bool _autoDebit = true;
  int _resendSeconds = 30;
  Timer? _otpTimer;
  bool _imageWarningShown = false;

  // Plan → weekly premium mapping (consistent with app tiers)
  static const _planPremiums = {'Silver': 49, 'Gold': 99, 'Platinum': 199};

  @override
  void dispose() {
    _otpTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _licenseNumberController.dispose();
    _otpController.dispose();
    _partnerIdController.dispose();
    _swiggyPartnerIdController.dispose();
    _zomatoPartnerIdController.dispose();
    _cityController.dispose();
    _vehicleRegistrationController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    FocusScope.of(context).unfocus();
    if (_isBusy) return;

    if (_step == 0) {
      if (!_identityKey.currentState!.validate()) return;
      if (_licenseFrontImage == null ||
          _licenseBackImage == null ||
          _profileImage == null) {
        if (!_imageWarningShown) {
          setState(() => _imageWarningShown = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Photos not uploaded — tap Continue again to proceed in demo mode.',
              ),
              backgroundColor: AppTheme.warningOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          return;
        }
        // Second tap bypasses photo requirement for demo
      }
      await _runTask(() async {
        await _api.requestOtp(
          phone: _phoneController.text,
          email: _emailController.text,
        );
        _startOtpTimer();
        setState(() => _step = 1);
      });
      return;
    }

    if (_step == 1) {
      if (!_otpKey.currentState!.validate()) return;
      await _runTask(() async {
        await _api.verifyOtp(_otpController.text);
        setState(() => _step = 2);
      });
      return;
    }

    if (_step == 2) {
      if (!_workKey.currentState!.validate()) return;
      if (_selectedPlatforms.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Please select at least one delivery platform.',
            ),
            backgroundColor: AppTheme.dangerRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }
      if (_selectedPlatforms.contains('Swiggy') &&
          _swiggyPartnerIdController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter your Swiggy Partner ID.'),
            backgroundColor: AppTheme.dangerRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }
      if (_selectedPlatforms.contains('Zomato') &&
          _zomatoPartnerIdController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter your Zomato Partner ID.'),
            backgroundColor: AppTheme.dangerRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }
      setState(() => _step = 3);
      return;
    }

    if (!_planKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please accept the terms and conditions.'),
          backgroundColor: AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    await _runTask(() async {
      final policyId = await _api.completeRegistration(
        fullName: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        platform: _selectedPlatforms.join(', '),
        city: _cityController.text,
        partnerId: _selectedPlatforms.contains('Swiggy')
            ? _swiggyPartnerIdController.text.trim()
            : (_selectedPlatforms.contains('Zomato')
                  ? _zomatoPartnerIdController.text.trim()
                  : ''),
        vehicleType: _vehicleType,
        plan: _plan,
        upiId: _upiController.text,
        acceptedTerms: _acceptedTerms,
      );

      // Sync the DriverProvider tree with the newly assigned driver
      if (mounted) {
        DriverProvider.of(
          context,
        ).switchDriver(DemoBackend.instance.activeDriver);
        DemoOrchestrator.instance.seedInitialNotifications();
      }

      final payload = {
        'submittedAt': DateTime.now().toIso8601String(),
        'policyId': policyId,
        'identity': {
          'fullName': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'licenseNumber': _licenseNumberController.text.trim(),
          'licenseFrontImagePath': _licenseFrontImage?.path,
          'licenseBackImagePath': _licenseBackImage?.path,
          'profileImagePath': _profileImage?.path,
        },
        'work': {
          'platforms': _selectedPlatforms.toList(),
          'swiggyPartnerId': _swiggyPartnerIdController.text.trim(),
          'zomatoPartnerId': _zomatoPartnerIdController.text.trim(),
          'city': _cityController.text.trim(),
          'vehicleType': _vehicleType,
          'vehicleRegistrationNumber': _vehicleRegistrationController.text
              .trim(),
        },
        'plan': {
          'selectedPlan': _plan,
          'weeklyPremium': _planPremiums[_plan],
          'upiId': _upiController.text.trim(),
          'autoDebit': _autoDebit,
          'acceptedTerms': _acceptedTerms,
        },
      };
      await _storage.saveRegistration(payload);

      if (!mounted) return;
      final goToDashboard = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => RegistrationSuccessScreen(policyId: policyId),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        goToDashboard == false ? AppRoutes.login : AppRoutes.home,
        (route) => false,
      );
    });
  }

  void _previousStep() {
    if (_step == 0 || _isBusy) return;
    setState(() => _step -= 1);
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0 || _isBusy) return;
    await _runTask(() async {
      await _api.requestOtp(
        phone: _phoneController.text,
        email: _emailController.text,
      );
      _otpController.clear();
      _startOtpTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent to your mobile number.')),
      );
    });
  }

  Future<void> _runTask(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _startOtpTimer() {
    _otpTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds == 0) {
        timer.cancel();
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1628),
      body: SafeArea(
        child: Column(
          children: [
            _StepProgress(step: _step),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _buildStepBody(),
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0B1628),
        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isBusy ? null : _previousStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back'),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isBusy ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _step == 3 ? 'Activate Coverage' : 'Continue',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody() {
    if (_step == 0) return _identityStep();
    if (_step == 1) return _otpStep();
    if (_step == 2) return _workStep();
    return _planStep();
  }

  // ── Step 0: Identity ────────────────────────────────────────────────────────

  Widget _identityStep() {
    return Form(
      key: _identityKey,
      child: Column(
        key: const ValueKey('identity'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            'Identity Details',
            'Your personal details to create a Continuum account.',
          ),
          _field(
            controller: _nameController,
            label: 'Full Name',
            hint: 'Enter your full name',
            icon: Icons.person_outline_rounded,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _phoneController,
            label: 'Mobile Number',
            hint: '+91 XXXXX XXXXX',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.trim().length < 10)
                ? 'Enter a valid phone number'
                : null,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _emailController,
            label: 'Email Address',
            hint: 'your@email.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _licenseNumberController,
            label: 'Driving License Number',
            hint: 'MH-01-XXXXXXXX',
            icon: Icons.credit_card_outlined,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'License number is required'
                : null,
          ),
          const SizedBox(height: 16),
          _imagePickerTile(
            title: 'License — Front',
            subtitle: 'Clear photo of license front side',
            file: _licenseFrontImage,
            onCamera: () => _pickImage(
              (f) => setState(() => _licenseFrontImage = f),
              ImageSource.camera,
            ),
            onGallery: () => _pickImage(
              (f) => setState(() => _licenseFrontImage = f),
              ImageSource.gallery,
            ),
          ),
          const SizedBox(height: 10),
          _imagePickerTile(
            title: 'License — Back',
            subtitle: 'Clear photo of license back side',
            file: _licenseBackImage,
            onCamera: () => _pickImage(
              (f) => setState(() => _licenseBackImage = f),
              ImageSource.camera,
            ),
            onGallery: () => _pickImage(
              (f) => setState(() => _licenseBackImage = f),
              ImageSource.gallery,
            ),
          ),
          const SizedBox(height: 10),
          _imagePickerTile(
            title: 'Your Photo',
            subtitle: 'Clear, front-facing photo',
            file: _profileImage,
            onCamera: () => _pickImage(
              (f) => setState(() => _profileImage = f),
              ImageSource.camera,
            ),
            onGallery: () => _pickImage(
              (f) => setState(() => _profileImage = f),
              ImageSource.gallery,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Step 1: OTP ─────────────────────────────────────────────────────────────

  Widget _otpStep() {
    return Form(
      key: _otpKey,
      child: Column(
        key: const ValueKey('otp'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            'Verify Mobile',
            'An OTP has been sent to ${_phoneController.text}.',
          ),
          _field(
            controller: _otpController,
            label: '6-digit OTP',
            hint: '• • • • • •',
            icon: Icons.lock_outline_rounded,
            keyboardType: TextInputType.number,
            validator: (v) => (v == null || v.trim().length < 4)
                ? 'Enter the OTP sent to your phone'
                : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                _resendSeconds > 0
                    ? 'Resend in ${_resendSeconds}s'
                    : 'Didn\'t receive the OTP?',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _resendSeconds == 0 && !_isBusy ? _resendOtp : null,
                child: Text(
                  'Resend',
                  style: TextStyle(
                    color: _resendSeconds == 0
                        ? AppTheme.accent
                        : Colors.white30,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Step 2: Work Profile ─────────────────────────────────────────────────────

  Widget _workStep() {
    return Form(
      key: _workKey,
      child: Column(
        key: const ValueKey('work'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            'Work Profile',
            'Your gig work details help us tailor your policy.',
          ),
          _field(
            controller: _cityController,
            label: 'City',
            hint: 'Bangalore, Chennai, Mumbai…',
            icon: Icons.location_city_outlined,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'City is required' : null,
          ),
          const SizedBox(height: 16),
          _darkDropdown(
            label: 'Vehicle Type',
            value: _vehicleType,
            items: const ['Bike', 'Scooter'],
            icon: Icons.two_wheeler_outlined,
            onChanged: (v) => setState(() => _vehicleType = v ?? _vehicleType),
          ),
          const SizedBox(height: 16),
          _field(
            controller: _vehicleRegistrationController,
            label: 'Vehicle Registration Number',
            hint: 'KA-01-AB-1234',
            icon: Icons.directions_car_outlined,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Registration number required'
                : null,
          ),
          const SizedBox(height: 20),
          Text(
            'Delivery Platforms',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ..._platformCheckboxes(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Step 3: Plan & Payment ──────────────────────────────────────────────────

  Widget _planStep() {
    return Form(
      key: _planKey,
      child: Column(
        key: const ValueKey('plan'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            'Plan & Payment',
            'Choose your Continuum Shield tier and set up auto-pay.',
          ),
          ..._planPremiums.entries.map((entry) {
            final plan = entry.key;
            final premium = entry.value;
            final selected = _plan == plan;
            return _planCard(
              plan: plan,
              premium: premium,
              selected: selected,
              onTap: () => setState(() => _plan = plan),
            );
          }),
          const SizedBox(height: 4),
          _field(
            controller: _upiController,
            label: 'UPI ID',
            hint: 'yourname@upi',
            icon: Icons.account_balance_wallet_outlined,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid UPI ID' : null,
          ),
          const SizedBox(height: 10),
          _darkSwitch(
            label: 'Enable auto-debit',
            subtitle: 'Auto-pay weekly premium every Monday via eNACH',
            value: _autoDebit,
            onChanged: (v) => setState(() => _autoDebit = v),
          ),
          const SizedBox(height: 10),
          _darkCheckbox(
            label: 'I accept the Continuum terms and conditions',
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Shared widgets ──────────────────────────────────────────────────────────

  Widget _stepHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFF80CBC4)],
            ).createShader(bounds),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String hint = '',
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
          prefixIcon: Icon(
            icon,
            color: Colors.white.withOpacity(0.35),
            size: 19,
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppTheme.accent.withOpacity(0.6),
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppTheme.dangerRed.withOpacity(0.7),
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.dangerRed, width: 1.5),
          ),
          errorStyle: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  Widget _darkDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E293B),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withOpacity(0.4),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        color: Colors.white.withOpacity(0.35),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        item,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          hint: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _planCard({
    required String plan,
    required int premium,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final tierColors = {
      'Silver': const Color(0xFF6B7280),
      'Gold': const Color(0xFFD97706),
      'Platinum': const Color(0xFF7C3AED),
    };
    final features = {
      'Silver': [
        'Weather & outage coverage',
        'UPI payout in 5 min',
        'Standard claim review',
      ],
      'Gold': [
        'Everything in Silver',
        'Priority claim processing',
        'Higher coverage limit',
      ],
      'Platinum': [
        'Everything in Gold',
        'Dedicated support line',
        'Maximum coverage limit',
      ],
    };
    final color = tierColors[plan] ?? Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? color.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          border: Border.all(
            color: selected ? color : Colors.white.withOpacity(0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? color : Colors.white30,
                  width: 1.5,
                ),
                color: selected ? color : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$plan Shield',
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '₹$premium/wk',
                        style: TextStyle(
                          color: selected ? color : Colors.white38,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (features[plan] ?? []).join(' · '),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _darkSwitch({
    required String label,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }

  Widget _darkCheckbox({
    required String label,
    required bool value,
    required void Function(bool?) onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value
              ? AppTheme.accent.withOpacity(0.08)
              : Colors.white.withOpacity(0.04),
          border: Border.all(
            color: value
                ? AppTheme.accent.withOpacity(0.4)
                : Colors.white.withOpacity(0.07),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: value ? AppTheme.accent : Colors.transparent,
                border: Border.all(
                  color: value ? AppTheme.accent : Colors.white30,
                  width: 1.5,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: value ? Colors.white : Colors.white60,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePickerTile({
    required String title,
    required String subtitle,
    required XFile? file,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) {
    final captured = file != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: captured
            ? AppTheme.successGreen.withOpacity(0.06)
            : Colors.white.withOpacity(0.04),
        border: Border.all(
          color: captured
              ? AppTheme.successGreen.withOpacity(0.35)
              : Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                captured ? Icons.check_circle_outline : Icons.image_outlined,
                size: 16,
                color: captured ? AppTheme.successGreen : Colors.white38,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: captured ? AppTheme.successGreen : Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            captured ? file.name : subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _iconBtn(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: onCamera,
              ),
              const SizedBox(width: 8),
              _iconBtn(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: onGallery,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.white54),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _platformCheckboxes() {
    const platforms = ['Swiggy', 'Zomato'];
    final widgets = <Widget>[];

    for (final platform in platforms) {
      final isSelected = _selectedPlatforms.contains(platform);

      // Platform checkbox
      widgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected && _selectedPlatforms.length > 1) {
                // Allow unselect only if more than one platform is selected
                _selectedPlatforms.remove(platform);
                if (platform == 'Swiggy') _swiggyPartnerIdController.clear();
                if (platform == 'Zomato') _zomatoPartnerIdController.clear();
              } else if (!isSelected) {
                // Allow select
                _selectedPlatforms.add(platform);
              }
              // If last platform and user tries to unselect, do nothing
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? AppTheme.primary.withOpacity(0.1)
                  : Colors.white.withOpacity(0.04),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.5)
                    : Colors.white.withOpacity(0.07),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: isSelected ? AppTheme.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : Colors.white30,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  platform,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Partner ID field if selected
      if (isSelected) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(
          _field(
            controller: platform == 'Swiggy'
                ? _swiggyPartnerIdController
                : _zomatoPartnerIdController,
            label: '$platform Partner ID',
            hint: platform == 'Swiggy' ? 'SWG-XXXX-XXX' : 'ZMT-XXXX-XXX',
            icon: Icons.badge_outlined,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? '$platform partner ID required'
                : null,
          ),
        );
        widgets.add(const SizedBox(height: 12));
      }
    }

    return widgets;
  }

  Future<void> _pickImage(
    void Function(XFile) onPicked,
    ImageSource source,
  ) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked != null) onPicked(picked);
  }
}

// ── Step progress indicator ────────────────────────────────────────────────────

class _StepProgress extends StatelessWidget {
  final int step;

  const _StepProgress({required this.step});

  @override
  Widget build(BuildContext context) {
    const labels = ['Identity', 'Verify', 'Work', 'Plan'];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0B1628),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = index <= step;
          final current = index == step;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: active ? AppTheme.accentGradient : null,
                      color: active ? null : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: current
                          ? [
                              BoxShadow(
                                color: AppTheme.accent.withOpacity(0.5),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                      color: active ? Colors.white70 : Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Registration success screen ───────────────────────────────────────────────

class RegistrationSuccessScreen extends StatelessWidget {
  final String policyId;

  const RegistrationSuccessScreen({Key? key, required this.policyId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1628),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(
              scale: 0.85 + 0.15 * v,
              child: Opacity(opacity: v, child: child),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.successGreen.withOpacity(0.15),
                    border: Border.all(
                      color: AppTheme.successGreen.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppTheme.successGreen,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Coverage Activated',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Your Continuum Shield policy is now active.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(
                    'Policy ID: $policyId',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 240,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Go to Dashboard',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 240,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back to Sign In'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
