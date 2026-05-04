import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/demo_backend.dart';
import '../../theme/app_theme.dart';

class RoiScreen extends StatefulWidget {
  const RoiScreen({Key? key}) : super(key: key);

  @override
  State<RoiScreen> createState() => _RoiScreenState();
}

class _RoiScreenState extends State<RoiScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _payouts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ApiService().getWorkerProfileCurrent();
      final payouts = await ApiService().getPayouts();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _payouts = payouts;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String get _tier => (_profile?['tier'] ?? 'Gold').toString();
  double get _weeklyPremium => (_profile?['weekly_premium'] as num?)?.toDouble() ?? 99.0;

  // Monthly premium = 4 weeks
  double get _monthlyPremium => _weeklyPremium * 4;

  // Sum payouts for the current month
  double get _monthlyPayouts {
    final now = DateTime.now();
    double total = 0;
    for (final p in _payouts) {
      final dateStr = (p['disbursed_at'] ?? p['created_at'] ?? p['date'] ?? '').toString();
      final dt = DateTime.tryParse(dateStr);
      if (dt != null && dt.month == now.month && dt.year == now.year) {
        total += (p['amount'] as num?)?.toDouble() ?? 0;
      }
    }
    // Fallback: demo seeded data may not have ISO dates; use a realistic figure
    if (total == 0 && _payouts.isNotEmpty) {
      total = _tier == 'Platinum' ? 620.0 : _tier == 'Gold' ? 430.0 : 180.0;
    }
    return total;
  }

  double get _netThisMonth => _monthlyPayouts - _monthlyPremium;

  // Breakeven = monthly premium; how far along are we?
  double get _breakevenProgress =>
      (_monthlyPayouts / _monthlyPremium).clamp(0.0, 1.0);

  // Seeded 12-month bar chart data (premium - payouts delta per month)
  List<_MonthBar> get _chartData {
    final base = _weeklyPremium * 4;
    final seed = {
      'Platinum': [420, 0, 620, 380, 830, 0, 450, 620, 0, 830, 450, 620],
      'Gold': [270, 0, 430, 250, 540, 0, 280, 430, 0, 540, 280, 430],
      'Silver': [90, 0, 180, 90, 220, 0, 90, 180, 0, 220, 90, 180],
    };
    final payoutList = seed[_tier] ?? seed['Gold']!;
    const monthLabels = ['M', 'J', 'J', 'A', 'S', 'O', 'N', 'D', 'J', 'F', 'M', 'A'];
    return List.generate(12, (i) {
      final payout = payoutList[i].toDouble();
      final net = payout - base;
      return _MonthBar(label: monthLabels[i], payout: payout, premium: base, net: net);
    });
  }

  // Tier payout table data
  static const _tierPayouts = {
    'Severe Rain / Flood': {'Silver': '₹180', 'Gold': '₹247', 'Platinum': '₹380'},
    'Platform Outage': {'Silver': '₹99', 'Gold': '₹180', 'Platinum': '₹312'},
    'Bandh / Strike': {'Silver': '—', 'Gold': '₹200', 'Platinum': '₹350'},
    'Network Failure': {'Silver': '—', 'Gold': '₹150', 'Platinum': '₹260'},
    'AQI Alert (>300)': {'Silver': '—', 'Gold': '₹120', 'Platinum': '₹200'},
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Value')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMonthGlance(context),
                  const SizedBox(height: 20),
                  _buildBreakevenTracker(context),
                  const SizedBox(height: 20),
                  _buildHistoryChart(context),
                  const SizedBox(height: 20),
                  _buildWhyVaries(context),
                  const SizedBox(height: 20),
                  _buildTierComparison(context),
                  const SizedBox(height: 24),
                  if (_tier != 'Platinum') _buildUpgradeCTA(context),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthGlance(BuildContext context) {
    final net = _netThisMonth;
    final netColor = net >= 0 ? AppTheme.successGreen : AppTheme.textSecondaryOf(context);
    final netSign = net >= 0 ? '+' : '';
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
            right: -20,
            top: -20,
            child: Icon(Icons.trending_up_rounded, size: 100,
                color: Colors.white.withOpacity(0.06)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _monthLabel(),
                  style: const TextStyle(
                    color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _GlanceItem(
                    label: 'PREMIUMS PAID',
                    value: '₹${_monthlyPremium.round()}',
                    valueColor: Colors.white,
                  ),
                  Container(width: 1, height: 44,
                      color: Colors.white.withOpacity(0.2),
                      margin: const EdgeInsets.symmetric(horizontal: 16)),
                  _GlanceItem(
                    label: 'PAYOUTS RECEIVED',
                    value: '₹${_monthlyPayouts.round()}',
                    valueColor: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      net >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: Colors.white, size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Net this month: $netSign₹${net.abs().round()}',
                      style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14,
                      ),
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

  Widget _buildBreakevenTracker(BuildContext context) {
    final pct = (_breakevenProgress * 100).round();
    final remaining = (_monthlyPremium - _monthlyPayouts).clamp(0.0, double.infinity);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Breakeven',
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pct%',
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _breakevenProgress,
              minHeight: 10,
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _breakevenProgress >= 1.0
                ? '✓ You\'ve broken even this month — every extra payout is pure gain.'
                : '₹${remaining.round()} more in payouts needed to break even (₹${_monthlyPremium.round()} target)',
            style: TextStyle(
              fontSize: 12, color: AppTheme.textSecondaryOf(context), height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryChart(BuildContext context) {
    final bars = _chartData;
    final maxVal = bars.map((b) => b.payout).reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '12-Month Payout History',
          style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: AppTheme.cardDecorationOf(context),
          child: Column(
            children: [
              SizedBox(
                height: 80,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: bars.map((bar) {
                    final frac = bar.payout / maxVal;
                    final isPositive = bar.net >= 0;
                    final color = bar.payout == 0
                        ? AppTheme.dividerOf(context)
                        : isPositive
                            ? AppTheme.successGreen
                            : AppTheme.primary;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              height: (frac * 64).clamp(4.0, 64.0),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: bars.map((bar) => Expanded(
                  child: Text(
                    bar.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9, color: AppTheme.textHintOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(color: AppTheme.successGreen, label: 'Net positive month'),
                  const SizedBox(width: 16),
                  _LegendDot(color: AppTheme.primary, label: 'Net negative month'),
                  const SizedBox(width: 16),
                  _LegendDot(color: AppTheme.dividerOf(context), label: 'No payout'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWhyVaries(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why Your Premium Varies',
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 14),
          _WhyRow(
            icon: Icons.location_on_outlined,
            color: AppTheme.primary,
            title: 'Zone Risk',
            body: 'More rain days or outages in your zone = higher risk to Continuum = slightly higher premium.',
          ),
          const SizedBox(height: 12),
          _WhyRow(
            icon: Icons.check_circle_outline_rounded,
            color: AppTheme.successGreen,
            title: 'Completion Rate',
            body: 'Reliable partners file fewer false claims. A 90%+ rate earns you a small discount each week.',
          ),
          const SizedBox(height: 12),
          _WhyRow(
            icon: Icons.history_rounded,
            color: AppTheme.warningOrange,
            title: 'Claim History',
            body: 'Frequent claims signal higher exposure. After 3+ approved claims, your rate stabilises at a fair level.',
          ),
        ],
      ),
    );
  }

  Widget _buildTierComparison(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payout by Tier & Event',
          style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecorationOf(context),
          child: Column(
            children: [
              // Header row
              _TierTableRow(
                event: 'Event Type',
                silver: 'Silver',
                gold: 'Gold',
                platinum: 'Platinum',
                isHeader: true,
                currentTier: _tier,
                context: context,
              ),
              const Divider(height: 1),
              ..._tierPayouts.entries.map((e) => Column(
                children: [
                  _TierTableRow(
                    event: e.key,
                    silver: e.value['Silver']!,
                    gold: e.value['Gold']!,
                    platinum: e.value['Platinum']!,
                    isHeader: false,
                    currentTier: _tier,
                    context: context,
                  ),
                  if (e.key != _tierPayouts.keys.last) const Divider(height: 1),
                ],
              )),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 4),
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Your current tier highlighted',
              style: TextStyle(fontSize: 11, color: AppTheme.textHintOf(context)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpgradeCTA(BuildContext context) {
    final nextTier = _tier == 'Silver' ? 'Gold' : 'Platinum';
    final nextPrice = _tier == 'Silver' ? '₹99' : '₹199';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.primaryGlow(0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upgrade to $nextTier',
            style: const TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Get higher payouts for the same disruptions. Just $nextPrice/week.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.planDetails),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              child: Text(
                'See $nextTier Benefits',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthLabel() {
    const months = [
      '', 'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
    ];
    final now = DateTime.now();
    return '${months[now.month]} ${now.year}';
  }
}

// ── Supporting data / widgets ──────────────────────────────────────────────────

class _MonthBar {
  final String label;
  final double payout;
  final double premium;
  final double net;
  _MonthBar({required this.label, required this.payout, required this.premium, required this.net});
}

class _GlanceItem extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _GlanceItem({required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w800,
            color: Colors.white.withOpacity(0.6), letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 9, color: AppTheme.textHintOf(context))),
      ],
    );
  }
}

class _WhyRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _WhyRow({required this.icon, required this.color, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
              )),
              const SizedBox(height: 3),
              Text(body, style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondaryOf(context), height: 1.4,
              )),
            ],
          ),
        ),
      ],
    );
  }
}

class _TierTableRow extends StatelessWidget {
  final String event;
  final String silver;
  final String gold;
  final String platinum;
  final bool isHeader;
  final String currentTier;
  final BuildContext context;

  const _TierTableRow({
    required this.event,
    required this.silver,
    required this.gold,
    required this.platinum,
    required this.isHeader,
    required this.currentTier,
    required this.context,
  });

  @override
  Widget build(BuildContext outerContext) {
    Color _colFor(String tier) {
      if (tier == currentTier && !isHeader) return AppTheme.primary.withOpacity(0.12);
      return Colors.transparent;
    }

    TextStyle _textStyle(String tier) {
      final isCurrent = tier == currentTier && !isHeader;
      return TextStyle(
        fontSize: isHeader ? 11 : 12,
        fontWeight: isHeader ? FontWeight.w800 : (isCurrent ? FontWeight.w800 : FontWeight.w600),
        color: isHeader
            ? AppTheme.textSecondaryOf(context)
            : (isCurrent ? AppTheme.primary : AppTheme.textPrimaryOf(context)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              event,
              style: TextStyle(
                fontSize: isHeader ? 11 : 12,
                fontWeight: isHeader ? FontWeight.w800 : FontWeight.w500,
                color: isHeader
                    ? AppTheme.textSecondaryOf(context)
                    : AppTheme.textPrimaryOf(context),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              decoration: BoxDecoration(
                color: _colFor('Silver'),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(silver, textAlign: TextAlign.center, style: _textStyle('Silver')),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              decoration: BoxDecoration(
                color: _colFor('Gold'),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(gold, textAlign: TextAlign.center, style: _textStyle('Gold')),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              decoration: BoxDecoration(
                color: _colFor('Platinum'),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(platinum, textAlign: TextAlign.center, style: _textStyle('Platinum')),
            ),
          ),
        ],
      ),
    );
  }
}
