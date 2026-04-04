import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../routes/app_routes.dart';
import '../services/api_service.dart';
import '../services/registration_storage_service.dart';
import '../theme/app_theme.dart';

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
  String _platform = 'Swiggy';
  String _vehicleType = 'Bike';
  String _plan = 'Comprehensive';
  bool _acceptedTerms = false;
  bool _autoDebit = true;
  int _resendSeconds = 30;
  Timer? _otpTimer;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload license front, back, and your photo.'),
          ),
        );
        return;
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
      if (_platform == 'Swiggy + Zomato') {
        if (_swiggyPartnerIdController.text.trim().isEmpty ||
            _zomatoPartnerIdController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter both Swiggy and Zomato partner IDs.'),
            ),
          );
          return;
        }
      }
      setState(() => _step = 3);
      return;
    }

    if (!_planKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept terms and conditions.')),
      );
      return;
    }

    await _runTask(() async {
      final policyId = await _api.completeRegistration(
        fullName: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        platform: _platform,
        city: _cityController.text,
        partnerId: _platform == 'Swiggy + Zomato'
            ? '${_swiggyPartnerIdController.text.trim()} | ${_zomatoPartnerIdController.text.trim()}'
            : _partnerIdController.text,
        vehicleType: _vehicleType,
        plan: _plan,
        upiId: _upiController.text,
        acceptedTerms: _acceptedTerms,
      );
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
          'platform': _platform,
          'partnerId': _partnerIdController.text.trim(),
          'swiggyPartnerId': _swiggyPartnerIdController.text.trim(),
          'zomatoPartnerId': _zomatoPartnerIdController.text.trim(),
          'city': _cityController.text.trim(),
          'vehicleType': _vehicleType,
          'vehicleRegistrationNumber': _vehicleRegistrationController.text
              .trim(),
        },
        'plan': {
          'selectedPlan': _plan,
          'upiId': _upiController.text.trim(),
          'autoDebit': _autoDebit,
          'acceptedTerms': _acceptedTerms,
        },
      };
      await _storage.saveRegistration(payload);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RegistrationSuccessScreen(policyId: policyId),
        ),
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
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
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
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
      appBar: AppBar(title: const Text('Registration')),
      body: SafeArea(
        child: Column(
          children: [
            _StepProgress(step: _step),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildStepBody(),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: AppTheme.dividerOf(context)),
                ),
              ),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        child: const Text('Back'),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isBusy ? null : _nextStep,
                      child: _isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_step == 3 ? 'Submit' : 'Continue'),
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

  Widget _buildStepBody() {
    if (_step == 0) return _identityStep();
    if (_step == 1) return _otpStep();
    if (_step == 2) return _workStep();
    return _planStep();
  }

  Widget _identityStep() {
    return Form(
      key: _identityKey,
      child: Column(
        key: const ValueKey('identity'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Identity Details',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your primary details to start account creation.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          _field(
            controller: _nameController,
            label: 'Full Name',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _phoneController,
            label: 'Mobile Number',
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.trim().length < 10)
                ? 'Enter a valid phone number'
                : null,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _emailController,
            label: 'Email Address',
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _licenseNumberController,
            label: 'License Number',
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'License number is required'
                : null,
          ),
          const SizedBox(height: 14),
          _imagePickerTile(
            title: 'License Front Image',
            file: _licenseFrontImage,
            onCamera: () => _pickImage(
              (picked) => setState(() => _licenseFrontImage = picked),
              ImageSource.camera,
            ),
            onGallery: () => _pickImage(
              (picked) => setState(() => _licenseFrontImage = picked),
              ImageSource.gallery,
            ),
          ),
          const SizedBox(height: 10),
          _imagePickerTile(
            title: 'License Back Image',
            file: _licenseBackImage,
            onCamera: () => _pickImage(
              (picked) => setState(() => _licenseBackImage = picked),
              ImageSource.camera,
            ),
            onGallery: () => _pickImage(
              (picked) => setState(() => _licenseBackImage = picked),
              ImageSource.gallery,
            ),
          ),
          const SizedBox(height: 10),
          _imagePickerTile(
            title: 'Your Photo',
            file: _profileImage,
            onCamera: () => _pickImage(
              (picked) => setState(() => _profileImage = picked),
              ImageSource.camera,
            ),
            onGallery: () => _pickImage(
              (picked) => setState(() => _profileImage = picked),
              ImageSource.gallery,
            ),
          ),
        ],
      ),
    );
  }

  Widget _otpStep() {
    return Form(
      key: _otpKey,
      child: Column(
        key: const ValueKey('otp'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verify OTP', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'An OTP has been sent to ${_phoneController.text}.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          _field(
            controller: _otpController,
            label: '6-digit OTP',
            keyboardType: TextInputType.number,
            validator: (v) => (v == null || v.trim().length != 6)
                ? 'Enter 6-digit OTP'
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                _resendSeconds > 0
                    ? 'Resend OTP in ${_resendSeconds}s'
                    : 'Did not receive OTP?',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _resendSeconds == 0 ? _resendOtp : null,
                child: const Text('Resend'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _workStep() {
    return Form(
      key: _workKey,
      child: Column(
        key: const ValueKey('work'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Work Profile',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Add your gig work details so policy can be tailored.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: _platform,
            decoration: const InputDecoration(labelText: 'Platform'),
            items: const [
              DropdownMenuItem(value: 'Swiggy', child: Text('Swiggy')),
              DropdownMenuItem(value: 'Zomato', child: Text('Zomato')),
              DropdownMenuItem(
                value: 'Swiggy + Zomato',
                child: Text('Swiggy + Zomato'),
              ),
            ],
            onChanged: (v) => setState(() {
              _platform = v ?? _platform;
            }),
          ),
          const SizedBox(height: 12),
          if (_platform == 'Swiggy + Zomato') ...[
            _field(
              controller: _swiggyPartnerIdController,
              label: 'Swiggy Partner ID',
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Swiggy partner ID is required'
                  : null,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _zomatoPartnerIdController,
              label: 'Zomato Partner ID',
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Zomato partner ID is required'
                  : null,
            ),
          ] else
            _field(
              controller: _partnerIdController,
              label: 'Partner ID',
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Partner ID is required'
                  : null,
            ),
          const SizedBox(height: 12),
          _field(
            controller: _cityController,
            label: 'City / Zone',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'City is required' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _vehicleType,
            decoration: const InputDecoration(labelText: 'Vehicle Type'),
            items: const [
              DropdownMenuItem(value: 'Bike', child: Text('Bike')),
              DropdownMenuItem(value: 'Scooter', child: Text('Scooter')),
              DropdownMenuItem(value: 'Cycle', child: Text('Cycle')),
            ],
            onChanged: (v) => setState(() => _vehicleType = v ?? _vehicleType),
          ),
          const SizedBox(height: 12),
          _field(
            controller: _vehicleRegistrationController,
            label: 'Vehicle Registration Number',
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Vehicle registration number is required'
                : null,
          ),
        ],
      ),
    );
  }

  Widget _planStep() {
    return Form(
      key: _planKey,
      child: Column(
        key: const ValueKey('plan'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan & Payment',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Choose a plan and complete policy setup.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ...['Basic', 'Pro', 'Comprehensive'].map((plan) {
            final selected = _plan == plan;
            final premium = plan == 'Basic'
                ? 39
                : plan == 'Pro'
                ? 57
                : 79;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? AppTheme.primary
                      : AppTheme.dividerOf(context),
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: RadioListTile<String>(
                value: plan,
                groupValue: _plan,
                title: Text(plan),
                subtitle: Text('₹$premium / week'),
                onChanged: (v) => setState(() => _plan = v ?? _plan),
              ),
            );
          }),
          const SizedBox(height: 10),
          _field(
            controller: _upiController,
            label: 'UPI ID',
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid UPI ID' : null,
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable auto-debit'),
            value: _autoDebit,
            onChanged: (v) => setState(() => _autoDebit = v),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
            title: const Text('I accept terms and conditions'),
            subtitle: !_acceptedTerms
                ? const Text('Required to continue')
                : null,
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(labelText: label, hintText: 'Enter here'),
    );
  }

  Widget _imagePickerTile({
    required String title,
    required XFile? file,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            file == null ? 'No file selected' : file.name,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Camera'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('Upload'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(
    void Function(XFile) onPicked,
    ImageSource source,
  ) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked != null) {
      onPicked(picked);
    }
  }
}

class _StepProgress extends StatelessWidget {
  final int step;

  const _StepProgress({required this.step});

  @override
  Widget build(BuildContext context) {
    const labels = ['Identity', 'OTP', 'Work', 'Plan'];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.dividerOf(context))),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = index <= step;
          return Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.primary
                        : AppTheme.dividerOf(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[index],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: active
                        ? AppTheme.textPrimaryOf(context)
                        : AppTheme.textHintOf(context),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class RegistrationSuccessScreen extends StatelessWidget {
  final String policyId;

  const RegistrationSuccessScreen({Key? key, required this.policyId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF16A34A),
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Registration Complete',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Policy ID: $policyId',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: 220,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Continue to Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
