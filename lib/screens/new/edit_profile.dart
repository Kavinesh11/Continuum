import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _platformController;
  late TextEditingController _emergencyController;
  bool _isSaving = false;
  String _partnerId = 'N/A';
  String _tier = 'Standard';
  String _memberSince = '-';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _cityController = TextEditingController();
    _platformController = TextEditingController();
    _emergencyController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ApiService().getWorkerProfileCurrent();
      if (!mounted) return;
      _nameController.text = (profile['full_name'] ?? '').toString();
      _phoneController.text = (profile['phone'] ?? '').toString();
      _cityController.text = (profile['city'] ?? '').toString();
      _platformController.text = (profile['platform'] ?? '').toString();
      _emergencyController.text = (profile['emergency_contact'] ?? '')
          .toString();
      _partnerId = (profile['worker_id'] ?? 'N/A').toString();
      _tier = (profile['tier'] ?? 'Standard').toString();
      _memberSince = (profile['member_since'] ?? profile['registered_at'] ?? '-').toString();
      setState(() {});
    } on ServerException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Service temporarily unavailable. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'Retry', onPressed: _loadProfile),
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _platformController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar ──
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.accentGradient,
                        boxShadow: AppTheme.primaryGlow(0.25),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.cardOf(context),
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.softShadowOf(context),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: AppTheme.primary,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildMetaChip('ID $_partnerId', Icons.badge_outlined),
                    _buildMetaChip(
                      '$_tier tier',
                      Icons.workspace_premium_outlined,
                    ),
                    _buildMetaChip(
                      'Since $_memberSince',
                      Icons.calendar_today_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Form sections ──
              _buildSectionLabel(Icons.person_outline_rounded, 'Personal'),
              const SizedBox(height: 12),
              _buildFieldCard(
                context: context,
                isDark: isDark,
                children: [
                  _buildField(
                    'Full Name',
                    _nameController,
                    Icons.badge_outlined,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    'Phone Number',
                    _phoneController,
                    Icons.phone_outlined,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    'City',
                    _cityController,
                    Icons.location_on_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 22),

              _buildSectionLabel(Icons.work_outline_rounded, 'Work'),
              const SizedBox(height: 12),
              _buildFieldCard(
                context: context,
                isDark: isDark,
                children: [
                  _buildField(
                    'Platform (e.g. Swiggy, Zomato)',
                    _platformController,
                    Icons.delivery_dining_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 22),

              _buildSectionLabel(Icons.emergency_outlined, 'Emergency'),
              const SizedBox(height: 12),
              _buildFieldCard(
                context: context,
                isDark: isDark,
                children: [
                  _buildField(
                    'Emergency Contact',
                    _emergencyController,
                    Icons.contact_phone_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── Save button ──
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: AppTheme.primaryGlow(0.25),
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Save Changes',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldCard({
    required BuildContext context,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(children: children),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimaryOf(context),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondaryOf(context),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
      ),
    );
  }

  Widget _buildMetaChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primary, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ApiService().updateWorkerProfileCurrent({
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'platform': _platformController.text.trim(),
        'emergency_contact': _emergencyController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.pop(context);
    } on ServerException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Service temporarily unavailable. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'Retry', onPressed: _save),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not save profile right now.'),
          backgroundColor: AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
