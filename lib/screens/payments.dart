import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  bool _autoPay = true;
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _policyContent;
  List<Map<String, dynamic>> _payouts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await ApiService().getWorkerProfileCurrent();
      final payouts = await ApiService().getPayouts();
      Map<String, dynamic>? policy;
      try {
        policy = await ApiService().getPolicyContent();
      } catch (_) {
        policy = null;
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _payouts = payouts;
        _policyContent = policy;
        _isLoading = false;
      });
    } on ServerException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Service temporarily unavailable. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'Retry', onPressed: _loadData),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _buildPlanData();

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlanCard(context, plan),
                    const SizedBox(height: 22),
                    _buildPayNowButton(context),
                    const SizedBox(height: 28),
                    _buildPaymentHistory(context, _payouts),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Map<String, dynamic> _buildPlanData() {
    final tier = (_profile?['tier'] ?? 'Standard').toString();
    final zone = (_profile?['zone_id'] ?? 'default').toString();
    final hero = _policyContent?['hero'] as Map<String, dynamic>?;

    return {
      'planName': hero?['title']?.toString() ?? '$tier Tier Plan',
      'coverage':
          hero?['subtitle']?.toString() ?? 'Coverage active in zone $zone',
      'weeklyCost':
          (_profile?['weekly_premium'] as num?)?.toStringAsFixed(0) ?? '—',
      'nextBillingDate': 'Upcoming cycle',
    };
  }

  Widget _buildPlanCard(BuildContext context, Map<String, dynamic> plan) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.primaryGlow(0.25),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            top: -15,
            child: Icon(
              Icons.shield_rounded,
              size: 90,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'YOUR PLAN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                plan['planName'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                plan['coverage'] as String,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WEEKLY COST',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withOpacity(0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${plan['weeklyCost']}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'NEXT BILLING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withOpacity(0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: Colors.white.withOpacity(0.8),
                              size: 12,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              plan['nextBillingDate'] as String,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.autorenew_rounded,
                          color: Colors.white.withOpacity(0.8),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Auto-Pay',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _autoPay,
                      onChanged: (v) => setState(() => _autoPay = v),
                      activeColor: Colors.white,
                      activeTrackColor: AppTheme.successGreen.withOpacity(0.7),
                      inactiveThumbColor: Colors.white70,
                      inactiveTrackColor: Colors.white.withOpacity(0.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayNowButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.primaryGlow(0.25),
      ),
      child: ElevatedButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.successGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Payment Initiated',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ],
              ),
              content: Text(
                'Your payment of ₹${(_profile?['weekly_premium'] as num?)?.toStringAsFixed(0) ?? '—'} has been initiated and will be processed shortly.',
                style: const TextStyle(height: 1.4),
              ),
              actions: [
                Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'Pay Now',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistory(
    BuildContext context,
    List<Map<String, dynamic>> history,
  ) {
    if (history.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: AppTheme.cardDecorationOf(context),
        child: Text(
          'No payout history yet.',
          style: TextStyle(
            color: AppTheme.textSecondaryOf(context),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment History',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 14),
        ...history.asMap().entries.map((entry) {
          final idx = entry.key;
          final txn = entry.value;
          final status = (txn['status'] ?? '').toString().toLowerCase();
          final isSuccess = status == 'disbursed' || status == 'success';
          final statusColor = isSuccess
              ? AppTheme.successGreen
              : AppTheme.dangerRed;

          return Container(
            margin: EdgeInsets.only(bottom: idx < history.length - 1 ? 10 : 0),
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              boxShadow: AppTheme.softShadowOf(context),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 4, color: statusColor),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isSuccess
                                ? Icons.check_circle_outline_rounded
                                : Icons.error_outline_rounded,
                            color: statusColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '₹${txn['amount'] ?? txn['disbursed_amount'] ?? 0}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimaryOf(context),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      (txn['status'] ?? 'pending').toString(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${txn['method'] ?? 'UPI'} • ${txn['disbursed_at'] ?? txn['updated_at'] ?? txn['created_at'] ?? '—'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryOf(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (txn['payout_id'] ?? txn['id'] ?? 'TXN')
                                    .toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textHintOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
