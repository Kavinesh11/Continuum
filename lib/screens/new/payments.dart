import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  bool _autoPay = true;
  String _selectedMethodId = 'upi_1';
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _policyContent;
  List<Map<String, dynamic>> _payouts = [];

  static const List<Map<String, dynamic>> _paymentMethods = [
    {'id': 'upi_1', 'type': 'UPI', 'label': 'primary@upi', 'isDefault': true},
    {
      'id': 'card_1',
      'type': 'Card',
      'label': '•••• •••• •••• 4821',
      'isDefault': false,
    },
  ];

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
        _payouts = payouts.map(_mapPayout).toList();
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

  Map<String, dynamic> _mapPayout(Map<String, dynamic> payout) {
    final amount =
        (payout['amount'] as num?)?.toDouble() ??
        (payout['payout_amount'] as num?)?.toDouble() ??
        0;
    final statusRaw = (payout['status'] ?? 'processed')
        .toString()
        .toLowerCase();
    final status =
        (statusRaw == 'disbursed' ||
            statusRaw == 'processed' ||
            statusRaw == 'success')
        ? 'Success'
        : (statusRaw == 'pending' ? 'Pending' : 'Failed');
    final date = DateTime.tryParse(
      (payout['disbursed_at'] ?? payout['created_at'] ?? '').toString(),
    );
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateText = date == null
        ? 'Recent'
        : '${months[date.month - 1]} ${date.day}, ${date.year}';

    return {
      'id': (payout['payout_id'] ?? 'TXN-NA').toString(),
      'date': dateText,
      'amount': amount.round(),
      'method': (payout['payu_txn_ref'] ?? 'Bank Transfer').toString(),
      'status': status,
    };
  }

  String _formatRenewalDate(dynamic v) {
    if (v == null) return 'Upcoming cycle';
    try {
      final dt = DateTime.parse(v.toString()).toLocal();
      return '${dt.day} ${_monthName(dt.month)} ${dt.year}';
    } catch (_) {
      return v.toString();
    }
  }

  String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

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
      'nextBillingDate': _formatRenewalDate(_profile?['next_renewal']),
    };
  }

  @override
  Widget build(BuildContext context) {
    final plan = _buildPlanData();
    final methods = _paymentMethods;
    final history = _payouts;

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
                    _buildPaymentMethodsSection(context, methods),
                    const SizedBox(height: 22),
                    _buildPayNowButton(context),
                    const SizedBox(height: 28),
                    _buildPaymentHistory(context, history),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
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

  Widget _buildPaymentMethodsSection(
    BuildContext context,
    List<Map<String, dynamic>> methods,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Payment Methods',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Add method tapped'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: AppTheme.primary, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Add new',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...methods.map((method) {
          final isSelected = _selectedMethodId == method['id'];
          final iconData = method['type'] == 'UPI'
              ? Icons.account_balance_rounded
              : Icons.credit_card_rounded;

          return GestureDetector(
            onTap: () =>
                setState(() => _selectedMethodId = method['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardOf(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primary
                      : AppTheme.dividerOf(context),
                  width: isSelected ? 2 : 1.5,
                ),
                boxShadow: isSelected
                    ? AppTheme.primaryGlow(0.1)
                    : AppTheme.softShadowOf(context),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withOpacity(0.12)
                          : AppTheme.textHintOf(context).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      iconData,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textSecondaryOf(context),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          method['type'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textSecondaryOf(context),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          method['label'] as String,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (method['isDefault'] == true)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Default',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.successGreen,
                        ),
                      ),
                    ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.dividerOf(context),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primary,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
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
              _profile?['weekly_premium'] != null
                  ? 'Pay Now — ₹${(_profile!['weekly_premium'] as num).toStringAsFixed(0)}'
                  : 'Pay Now',
              style: const TextStyle(
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
          final isSuccess = txn['status'] == 'Success';
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
                                    '₹${txn['amount']}',
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
                                      txn['status'] as String,
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
                                '${txn['method']} • ${txn['date']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryOf(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                txn['id'] as String,
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
