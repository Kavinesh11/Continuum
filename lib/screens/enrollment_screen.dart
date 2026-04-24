import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({Key? key}) : super(key: key);

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  String _selectedTier = 'silver';
  String _selectedZone = 'mumbai_central';
  bool _isSubmitting = false;
  bool _consentGiven = false;

  final _tiers = {
    'silver': {'label': 'Silver', 'cap': '500', 'premium': '~30-50'},
    'gold': {'label': 'Gold', 'cap': '1,000', 'premium': '~60-90'},
    'platinum': {'label': 'Platinum', 'cap': '2,000', 'premium': '~100-150'},
  };

  final _zones = {
    'mumbai_central': 'Mumbai Central',
    'mumbai_western': 'Mumbai Western',
    'mumbai_harbour': 'Mumbai Harbour',
  };

  Future<void> _enroll() async {
    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms to continue.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final api = ApiService();
      final workerId = await api.getWorkerId();
      if (workerId == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      final result = await api.createPolicy({
        'worker_id': workerId,
        'tier': _selectedTier,
        'zone_id': _selectedZone,
      });

      if (!mounted) return;

      if (result.containsKey('policy_id')) {
        Navigator.pushNamed(context, AppRoutes.consent);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'Enrollment failed. Try again.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enroll in Continuum')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose your plan',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Weekly micro-premium deducted from your payout cycle.',
              style: TextStyle(color: AppTheme.textSecondaryOf(context)),
            ),
            const SizedBox(height: 20),
            ...(_tiers.entries.map((e) => _buildTierCard(e.key, e.value))),
            const SizedBox(height: 24),
            Text(
              'Select your zone',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedZone,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: _zones.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedZone = v ?? _selectedZone),
            ),
            const SizedBox(height: 24),
            CheckboxListTile(
              value: _consentGiven,
              onChanged: (v) => setState(() => _consentGiven = v ?? false),
              title: const Text(
                'I accept the Terms & Conditions and acknowledge the 72-hour activation delay.',
                style: TextStyle(fontSize: 13),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _enroll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Enroll Now',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard(String key, Map<String, String> tier) {
    final isSelected = _selectedTier == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedTier = key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? AppTheme.primary.withOpacity(0.06) : null,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: key,
              groupValue: _selectedTier,
              onChanged: (v) => setState(() => _selectedTier = v ?? key),
              activeColor: AppTheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tier['label']!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Coverage up to \u20B9${tier["cap"]} per event',
                    style: TextStyle(
                      color: AppTheme.textSecondaryOf(context),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '\u20B9${tier["premium"]}/wk',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
