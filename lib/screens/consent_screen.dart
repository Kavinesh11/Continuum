import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({Key? key}) : super(key: key);

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _gpsConsent = false;
  bool _piiConsent = false;
  bool _payoutConsent = false;
  bool _isSubmitting = false;

  bool get _allConsented => _gpsConsent && _piiConsent && _payoutConsent;

  static const _purposes = [
    {
      'key': 'gps',
      'title': 'Location Data Collection',
      'description':
          'We collect GPS coordinates during active delivery hours to verify your presence in the insured zone when a disruption occurs. Data is retained for 60 days and encrypted at rest.',
    },
    {
      'key': 'pii',
      'title': 'Identity Verification',
      'description':
          'Your Aadhaar hash and device fingerprint are stored to prevent duplicate enrollment and fraudulent claims. Raw Aadhaar numbers are never stored.',
    },
    {
      'key': 'payout',
      'title': 'Automated Payout via UPI',
      'description':
          'When a verified disruption occurs, payouts are automatically credited to your registered UPI ID. By consenting, you authorize Continuum to initiate UPI transfers.',
    },
  ];

  Future<void> _submitConsent() async {
    setState(() => _isSubmitting = true);
    try {
      final api = ApiService();
      final workerId = await api.getWorkerId();
      if (workerId == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      await api.submitConsent({
        'worker_id': workerId,
        'purposes': ['gps_location_tracking', 'aadhaar_verification', 'upi_mandate'],
        'consent_version': 'v1.0',
        'consented_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.mandate);
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
      appBar: AppBar(title: const Text('Data Consent (DPDP Act)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Under the Digital Personal Data Protection Act 2023, '
                      'we need your explicit consent for each purpose below.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildConsentItem(
              _purposes[0],
              _gpsConsent,
              (v) => setState(() => _gpsConsent = v ?? false),
            ),
            _buildConsentItem(
              _purposes[1],
              _piiConsent,
              (v) => setState(() => _piiConsent = v ?? false),
            ),
            _buildConsentItem(
              _purposes[2],
              _payoutConsent,
              (v) => setState(() => _payoutConsent = v ?? false),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _allConsented && !_isSubmitting ? _submitConsent : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
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
                        'I Consent & Continue',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'You can withdraw consent at any time from your profile.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentItem(
    Map<String, String> purpose,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? AppTheme.primary.withOpacity(0.5) : Colors.grey.shade300,
        ),
        color: value ? AppTheme.primary.withOpacity(0.04) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: AppTheme.primary,
              ),
              Expanded(
                child: Text(
                  purpose['title']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              purpose['description']!,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
