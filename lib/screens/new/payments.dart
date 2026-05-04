import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/demo_backend.dart';
import '../../state/demo_orchestrator.dart';

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

  String _filterTab = 'All';

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

  List<Map<String, dynamic>> get _paymentMethods {
    final driver = DemoBackend.instance.activeDriver;
    final upiHandle =
        '${driver.partnerId.toLowerCase().replaceAll('-', '')}@okaxis';
    final lastFour =
        ((driver.partnerId.hashCode.abs() % 9000) + 1000).toString();
    return [
      {'id': 'upi_1', 'type': 'UPI', 'label': upiHandle, 'isDefault': true},
      {
        'id': 'card_1',
        'type': 'Card',
        'label': '•••• •••• •••• $lastFour',
        'isDefault': false,
      },
    ];
  }

  void _showAddMethodSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerOf(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 16),
            for (final opt in [
              (Icons.account_balance_rounded, 'UPI', 'Link a UPI ID instantly'),
              (Icons.credit_card_rounded, 'Credit / Debit Card', 'Visa, Mastercard, RuPay'),
              (Icons.account_balance_outlined, 'Net Banking', 'Link your bank account'),
            ]) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(opt.$1, color: AppTheme.primary, size: 20),
                ),
                title: Text(
                  opt.$2,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                subtitle: Text(
                  opt.$3,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textHintOf(context),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${opt.$2} linking coming soon'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
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

    // Prefer pre-formatted date string; fall back to ISO parse
    String dateText;
    if (payout['date'] != null) {
      dateText = payout['date'].toString();
    } else {
      final date = DateTime.tryParse(
        (payout['disbursed_at'] ?? payout['created_at'] ?? '').toString(),
      );
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      dateText = date == null
          ? 'Recent'
          : '${months[date.month - 1]} ${date.day}, ${date.year}';
    }

    final txnType = (payout['type'] ?? '').toString();
    final isDebit = txnType.contains('debit') || txnType.contains('premium');

    return {
      'id': (payout['id'] ?? payout['payout_id'] ?? 'TXN-NA').toString(),
      'date': dateText,
      'amount': amount.round(),
      'method': (payout['payu_txn_ref'] ?? payout['method'] ?? 'Bank Transfer').toString(),
      'status': status,
      'isDebit': isDebit,
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

  void _confirmAutoPayOff() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: AppTheme.warningOrange, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'Turn off auto-pay?',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coverage pauses after 7 days without payment. You\'ll need to pay manually each week.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondaryOf(context), height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                    child: const Text(
                      'Keep auto-pay ON',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _autoPay = false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerRed,
                      side: BorderSide(color: AppTheme.dangerRed.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                    child: const Text(
                      'Turn off',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handlePayNow() {
    final amount = (_profile?['weekly_premium'] as num?)?.toStringAsFixed(0) ?? '—';
    showAdaptiveDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Text(
          'Pay ₹$amount now?',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Text(
          _autoPay
              ? 'Auto-pay is already enabled. This will charge ₹$amount immediately in addition to your scheduled debit.'
              : 'This will immediately charge ₹$amount to your selected payment method.',
          style: const TextStyle(height: 1.4, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondaryOf(context))),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executePay();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Pay Now',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _executePay() {
    DemoOrchestrator.instance.premiumDebited();
    final driver = DemoBackend.instance.activeDriver;
    final upiHandle =
        '${driver.partnerId.toLowerCase().replaceAll('-', '')}@okaxis';
    setState(() {
      _payouts = [
        {
          'id': 'TXN-${DateTime.now().millisecondsSinceEpoch % 100000}',
          'date': _todayLabel(),
          'amount': (_profile?['weekly_premium'] as num?)?.round() ?? 199,
          'method': 'UPI • $upiHandle',
          'status': 'Success',
          'isDebit': true,
        },
        ..._payouts,
      ];
    });
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.successGreen, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Payment Initiated',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
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
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Done',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
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
                    const SizedBox(height: 14),
                    _buildRoiRow(context),
                    const SizedBox(height: 28),
                    _buildPaymentHistory(context, history),
                    const SizedBox(height: 16),
                    _buildTaxHint(context),
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
                      onChanged: (newVal) {
                        if (!newVal) {
                          _confirmAutoPayOff();
                        } else {
                          setState(() => _autoPay = true);
                        }
                      },
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
                onTap: _showAddMethodSheet,
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
        onPressed: _handlePayNow,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.payment_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
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

  Widget _buildRoiRow(BuildContext context) {
    final driver = DemoBackend.instance.activeDriver;
    final premium = driver.weeklyPremium * 4;
    final payoutTotal = _tier == 'Platinum' ? 620.0 : _tier == 'Gold' ? 430.0 : 180.0;
    final net = payoutTotal - premium;
    final netSign = net >= 0 ? '+' : '';
    final remaining = (premium - payoutTotal).clamp(0.0, double.infinity);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.roi),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.trending_up_rounded,
                  color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This month: Paid ₹${premium.round()} · Received ₹${payoutTotal.round()} · Net $netSign₹${net.abs().round()}',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    net < 0
                        ? '₹${remaining.round()} more in payouts to break even'
                        : 'You\'ve broken even this month!',
                    style: TextStyle(
                      fontSize: 11, color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.textHintOf(context), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxHint(BuildContext context) {
    final annualPremium = (DemoBackend.instance.activeDriver.weeklyPremium * 52).round();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.textHintOf(context).withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 14, color: AppTheme.textHintOf(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Premiums paid (FY 2025–26): ₹$annualPremium · '
              'May be deductible under Section 80D for self-employed. Consult your CA.',
              style: TextStyle(
                fontSize: 11, color: AppTheme.textSecondaryOf(context), height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _tier => (_profile?['tier'] ?? DemoBackend.instance.activeDriver.tier).toString();

  Widget _buildPaymentHistory(
    BuildContext context,
    List<Map<String, dynamic>> history,
  ) {
    final filtered = history.where((txn) {
      if (_filterTab == 'Credits') return txn['isDebit'] != true;
      if (_filterTab == 'Debits') return txn['isDebit'] == true;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Payment History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            Row(
              children: [
                for (final tab in ['All', 'Credits', 'Debits'])
                  GestureDetector(
                    onTap: () => setState(() => _filterTab = tab),
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _filterTab == tab
                            ? AppTheme.primary.withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _filterTab == tab
                              ? AppTheme.primary.withOpacity(0.3)
                              : AppTheme.dividerOf(context),
                        ),
                      ),
                      child: Text(
                        tab,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _filterTab == tab
                              ? AppTheme.primary
                              : AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No ${_filterTab.toLowerCase()} transactions',
                style: TextStyle(color: AppTheme.textHintOf(context), fontSize: 13),
              ),
            ),
          ),
        ...filtered.asMap().entries.map((entry) {
          final idx = entry.key;
          final txn = entry.value;
          final isDebit = txn['isDebit'] == true;
          final isSuccess = txn['status'] == 'Success';
          final amountColor = isDebit ? AppTheme.dangerRed : AppTheme.successGreen;
          final statusColor = isSuccess
              ? AppTheme.successGreen
              : AppTheme.dangerRed;

          return Container(
            margin: EdgeInsets.only(bottom: idx < filtered.length - 1 ? 10 : 0),
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
                            isDebit
                                ? Icons.arrow_upward_rounded
                                : isSuccess
                                    ? Icons.arrow_downward_rounded
                                    : Icons.error_outline_rounded,
                            color: isDebit ? AppTheme.dangerRed : statusColor,
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
                                    '${isDebit ? '-' : '+'}₹${txn['amount']}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: amountColor,
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

  String _todayLabel() {
    final now = DateTime.now();
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[now.month]} ${now.day}, ${now.year}';
  }
}
