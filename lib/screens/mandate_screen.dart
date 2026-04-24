import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class MandateScreen extends StatefulWidget {
  const MandateScreen({Key? key}) : super(key: key);

  @override
  State<MandateScreen> createState() => _MandateScreenState();
}

class _MandateScreenState extends State<MandateScreen> {
  final _upiController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _createMandate() async {
    final upiId = _upiController.text.trim();
    if (upiId.isEmpty || !upiId.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid UPI ID (e.g. name@upi)')),
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

      final result = await api.createMandate({
        'worker_id': workerId,
        'upi_id': upiId,
        'mandate_type': 'UPI_ENACH',
        'max_amount': 200,
        'frequency': 'weekly',
      });

      if (!mounted) return;

      if (result.containsKey('mandate_id') || result.containsKey('status')) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text('Setup Complete'),
              ],
            ),
            content: const Text(
              'Your UPI mandate has been created. '
              'Weekly premiums will be auto-debited from your registered UPI ID. '
              'Your policy activates after a 72-hour waiting period.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.home,
                    (route) => false,
                  );
                },
                child: Text(
                  'Go to Dashboard',
                  style: TextStyle(color: AppTheme.primary),
                ),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'Mandate creation failed.'),
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
      appBar: AppBar(title: const Text('UPI Premium Mandate')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.08),
                    AppTheme.primary.withOpacity(0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet,
                          color: AppTheme.primary, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Auto-Pay Setup',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your weekly premium will be automatically debited via UPI eNACH mandate. '
                    'This aligns with your Zomato/Swiggy weekly payout cycle so you never miss a payment.',
                    style: TextStyle(
                      color: AppTheme.textSecondaryOf(context),
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Enter your UPI ID',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _upiController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'yourname@upi',
                prefixIcon: const Icon(Icons.payment),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
                Icons.repeat, 'Frequency: Weekly (matches your payout cycle)'),
            _buildInfoRow(
                Icons.currency_rupee, 'Max debit: \u20B9200/week'),
            _buildInfoRow(
                Icons.cancel_outlined, 'You can revoke the mandate anytime'),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _createMandate,
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
                        'Authorize Mandate',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondaryOf(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
