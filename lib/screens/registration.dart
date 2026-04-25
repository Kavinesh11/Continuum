import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

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
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
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
  final _workKey = GlobalKey<FormState>();
  final _planKey = GlobalKey<FormState>();

  int _step = 0;
  bool _isBusy = false;
  String _platform = 'Swiggy';
  String _vehicleType = 'Bike';
  String _plan = 'Comprehensive';
  bool _acceptedTerms = false;
  bool _autoDebit = true;

  /// Map user-facing plan names to backend tier values
  String get _tier {
    switch (_plan) {
      case 'Basic':
        return 'silver';
      case 'Pro':
        return 'gold';
      case 'Comprehensive':
        return 'platinum';
      default:
        return 'silver';
    }
  }

  /// Map user-facing platform to backend platform value
  String get _backendPlatform {
    switch (_platform) {
      case 'Swiggy':
        return 'swiggy';
      case 'Zomato':
        return 'zomato';
      case 'Swiggy + Zomato':
        return 'swiggy'; // default to swiggy for combo
      default:
        return 'swiggy';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _licenseNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
      setState(() => _step = 1);
      return;
    }

    if (_step == 1) {
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
      setState(() => _step = 2);
      return;
    }

    if (!_planKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept terms and conditions.')),
      );
      return;
    }

    // Final step: call the real backend registration API
    await _runTask(() async {
      final workerId = const Uuid().v4();

      final partnerId = _platform == 'Swiggy + Zomato'
          ? '${_swiggyPartnerIdController.text.trim()}_${_zomatoPartnerIdController.text.trim()}'
          : _partnerIdController.text.trim();

      final result = await _api.register(
        workerId: workerId,
        platform: _backendPlatform,
        upiId: _upiController.text.trim(),
        tier: _tier,
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        city: _cityController.text.trim(),
      );

      // Check for errors from the backend
      if (result.containsKey('error')) {
        final error = result['error'] as String;
        if (error == 'worker_already_exists') {
          throw Exception('An account with this Partner ID already exists. Please login instead.');
        } else if (error == 'missing_fields') {
          throw Exception('Please fill in all required fields.');
        } else if (error == 'password_too_short') {
          throw Exception('Password must be at least 8 characters.');
        } else {
          throw Exception(error);
        }
      }

      // Save registration data locally for reference
      final payload = {
        'submittedAt': DateTime.now().toIso8601String(),
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
          'partnerId': partnerId,
          'swiggyPartnerId': _swiggyPartnerIdController.text.trim(),
          'zomatoPartnerId': _zomatoPartnerIdController.text.trim(),
          'city': _cityController.text.trim(),
          'vehicleType': _vehicleType,
          'vehicleRegistrationNumber': _vehicleRegistrationController.text
              .trim(),
        },
        'plan': {
          'selectedPlan': _plan,
          'tier': _tier,
          'upiId': _upiController.text.trim(),
          'autoDebit': _autoDebit,
          'acceptedTerms': _acceptedTerms,
        },
      };
      await _storage.saveRegistration(payload);

      if (!mounted) return;

      // Show success screen, then navigate to login
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RegistrationSuccessScreen(
            workerId: workerId,
            policyEligibleFrom: result['policy_eligible_from'] as String?,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.login,
              (route) => false,
            );
          },
        ),
      ),
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
                          : Text(_step == 2 ? 'Register' : 'Continue'),
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
    if (_step == 1) return _workStep();
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
            'Enter your primary details to create your account.',
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
          const SizedBox(height: 12),
          _field(
            controller: _passwordController,
            label: 'Password',
            obscureText: true,
            validator: (v) {
              if (v == null || v.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _field(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            obscureText: true,
            validator: (v) {
              if (v != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
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
              label: 'Partner ID (used as your Worker ID for login)',
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
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      obscureText: obscureText,
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
    const labels = ['Identity', 'Work', 'Plan'];
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
  final String workerId;
  final String? policyEligibleFrom;

  const RegistrationSuccessScreen({
    Key? key,
    required this.workerId,
    this.policyEligibleFrom,
  }) : super(key: key);

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
                'Worker ID: $workerId',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (policyEligibleFrom != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Policy eligible from: $policyEligibleFrom',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Use your phone number and password to login.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
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
