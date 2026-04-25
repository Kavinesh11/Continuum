import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/demo_backend.dart';
import '../../theme/app_theme.dart';

class PolicyScreen extends StatefulWidget {
  const PolicyScreen({Key? key}) : super(key: key);

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen>
    with TickerProviderStateMixin {
  bool _isCalculating = false;
  bool _isFinished = false;
  int _visibleCount = 0;
  int _resolvedCount = 0;
  late double _currentPremium;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  late List<Map<String, dynamic>> _factors;

  @override
  void initState() {
    super.initState();
    final driver = DemoBackend.instance.activeDriver;
    _currentPremium = driver.weeklyPremium;

    _factors = [
      {
        'name': 'Waterlogging incidents (30d)',
        'outcome': '0 incidents',
        'adj': driver.tier == 'Platinum' ? -12 : driver.tier == 'Gold' ? -8 : -4,
      },
      {
        'name': 'Your order completion rate',
        'outcome': '${(driver.completionRate * 100).toStringAsFixed(0)}% (${_completionLabel(driver.completionRate)})',
        'adj': driver.tier == 'Platinum' ? -10 : driver.tier == 'Gold' ? -6 : -2,
      },
      {
        'name': 'Traffic density trends',
        'outcome': 'Average',
        'adj': 0,
      },
      {
        'name': 'Platform app stability',
        'outcome': driver.tier == 'Platinum' ? 'Excellent' : 'Good',
        'adj': driver.tier == 'Platinum' ? -8 : -4,
      },
      {
        'name': 'Zone risk classification',
        'outcome': _zoneRisk(driver.zone),
        'adj': driver.tier == 'Silver' ? 2 : 0,
      },
    ];

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String _completionLabel(double rate) {
    if (rate >= 0.9) return 'Excellent';
    if (rate >= 0.8) return 'Good';
    return 'Average';
  }

  String _zoneRisk(String zone) {
    if (zone.contains('South') || zone.contains('Central')) return 'Low Risk';
    if (zone.contains('North')) return 'Moderate';
    return 'Low Risk';
  }

  Future<void> _runRecalculation() async {
    if (_isCalculating) return;
    final driver = DemoBackend.instance.activeDriver;
    setState(() {
      _isCalculating = true;
      _isFinished = false;
      _visibleCount = 0;
      _resolvedCount = 0;
      _currentPremium = driver.weeklyPremium;
    });

    for (int i = 0; i < _factors.length; i++) {
      if (!mounted) return;
      setState(() => _visibleCount = i + 1);
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      setState(() {
        _resolvedCount = i + 1;
        _currentPremium += (_factors[i]['adj'] as int).toDouble();
      });
    }

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _isFinished = true;
      _isCalculating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final driver = DemoBackend.instance.activeDriver;
    final savings = (driver.weeklyPremium - _currentPremium).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Policy'),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.all(12.0),
            child: Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildOverviewCard(driver),
              const SizedBox(height: 28),
              _buildSectionTitle('Dynamic Pricing Engine'),
              const SizedBox(height: 4),
              Text(
                'Real-time risk factors affecting your premium this week',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: 16),
              if (!_isCalculating && !_isFinished) _buildCalculateButton(),
              if (_visibleCount > 0) ...[
                ...List.generate(
                  _visibleCount,
                  (i) => _buildFactorRow(context, i),
                ),
              ],
              if (_isFinished) ...[
                const SizedBox(height: 12),
                _buildResultCard(savings),
                const SizedBox(height: 28),
                _buildSectionTitle('Premium History'),
                const SizedBox(height: 16),
                _buildChartSection(context, driver),
              ],
              const SizedBox(height: 32),
              _buildBadge(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildOverviewCard(dynamic driver) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - v)),
        child: Opacity(opacity: v, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.primaryGlow(0.25),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.zone,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${driver.tier} Shield Plan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.shield_outlined,
                  color: Colors.white.withOpacity(0.5),
                  size: 40,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Base Premium',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${driver.weeklyPremium.toStringAsFixed(0)}/week',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'This Week',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: driver.weeklyPremium,
                        end: _currentPremium,
                      ),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        '₹${value.toInt()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculateButton() {
    return InkWell(
      onTap: _runRecalculation,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_fix_high_rounded,
              color: AppTheme.primary,
              size: 18,
            ),
            const SizedBox(width: 10),
            const Text(
              'Run Risk Recalculation',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactorRow(BuildContext context, int index) {
    final isResolved = index < _resolvedCount;
    final factor = _factors[index];
    final int adj = factor['adj'] as int;
    final String adjStr =
        adj > 0 ? '+₹$adj' : (adj == 0 ? '±₹0' : '−₹${adj.abs()}');
    final Color adjColor = adj < 0
        ? AppTheme.successGreen
        : (adj == 0
            ? AppTheme.textSecondaryOf(context)
            : AppTheme.dangerRed);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) =>
          Transform.translate(offset: Offset(20 * (1 - v), 0), child: Opacity(opacity: v, child: child)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.softShadowOf(context),
          border: Border.all(
            color: isResolved
                ? (adj <= 0
                    ? AppTheme.successGreen.withOpacity(0.3)
                    : AppTheme.dangerRed.withOpacity(0.3))
                : AppTheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: isResolved
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          factor['name'] as String,
                          style: TextStyle(
                            color: AppTheme.textPrimaryOf(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          factor['outcome'] as String,
                          style: TextStyle(
                            color: AppTheme.textSecondaryOf(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: adjColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      adjStr,
                      style: TextStyle(
                        color: adjColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary.withOpacity(_pulseAnim.value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Analyzing ${(factor['name'] as String).split(' ').first}…',
                    style: TextStyle(
                      color: AppTheme.textSecondaryOf(context),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildResultCard(int savings) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(
        scale: 0.9 + 0.1 * v,
        child: Opacity(opacity: v, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.successGreen.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppTheme.successGreen,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      savings > 0
                          ? 'This week you pay ₹${_currentPremium.round()}'
                          : 'Premium unchanged this week',
                      style: const TextStyle(
                        color: AppTheme.successGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (savings > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'You saved ₹$savings',
                        style: const TextStyle(
                          color: AppTheme.successGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Your zone had zero waterlogging incidents in the last 30 days.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.successGreen,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(BuildContext context, dynamic driver) {
    final base = driver.weeklyPremium;
    final values = [
      base + 6,
      base,
      base - 8,
      _currentPremium,
    ];
    return Container(
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: AppTheme.cardDecorationOf(context),
      child: CustomPaint(
        painter: _HistoryChartPainter(
          values: values,
          labels: const ['Week-1', 'Week-2', 'Week-3', 'Current'],
          barColor: AppTheme.primary,
          textColor: AppTheme.textSecondaryOf(context),
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.textHintOf(context).withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'ML-Optimized Pricing • Updated weekly',
              style: TextStyle(
                color: AppTheme.textSecondaryOf(context),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color barColor;
  final Color textColor;

  _HistoryChartPainter({
    required this.values,
    required this.labels,
    required this.barColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.reduce(math.max);
    final double barWidth = 32.0;
    final double spacing =
        (size.width - barWidth * values.length) / (values.length + 1);

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < values.length; i++) {
      final double x = spacing + i * (barWidth + spacing);
      final double maxBarH = size.height - 40;
      final double barH = maxBarH * (values[i] / (maxVal * 1.08));
      final double y = size.height - 22 - barH;

      paint.color = i == values.length - 1
          ? AppTheme.successGreen
          : barColor.withOpacity(0.3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barH),
          const Radius.circular(6),
        ),
        paint,
      );

      textPainter.text = TextSpan(
        text: '₹${values[i].toInt()}',
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, y - 16),
      );

      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, size.height - 14),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
