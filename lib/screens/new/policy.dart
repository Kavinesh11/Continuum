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
  bool _isInitializing = false;
  String _initLabel = '';
  int _visibleCount = 0;
  int _resolvedCount = 0;
  late double _currentPremium;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late AnimationController _chartAnimController;
  late Animation<double> _chartAnim;

  late List<Map<String, dynamic>> _factors;

  @override
  void initState() {
    super.initState();
    final driver = DemoBackend.instance.activeDriver;
    _currentPremium = driver.weeklyPremium;

    _factors = [
      {
        'name': 'Waterlogging incidents (30d)',
        'analyzeLabel': 'Querying oracle rainfall data for ${driver.zone}...',
        'outcome': driver.tier == 'Platinum'
            ? '0 incidents — Zone ${driver.zone} verified clean'
            : driver.tier == 'Gold'
                ? '1 incident on record'
                : '2 incidents detected',
        'adj': driver.tier == 'Platinum' ? -12 : driver.tier == 'Gold' ? -8 : -4,
        'confidence': 97,
        'icon': Icons.water_drop_outlined,
      },
      {
        'name': 'Order completion rate',
        'analyzeLabel': 'Fetching delivery records from ${driver.platform} API...',
        'outcome':
            '${(driver.completionRate * 100).toStringAsFixed(1)}% — ${_completionLabel(driver.completionRate)}',
        'adj': driver.tier == 'Platinum' ? -10 : driver.tier == 'Gold' ? -6 : -2,
        'confidence': 99,
        'icon': Icons.check_circle_outline_rounded,
      },
      {
        'name': 'Traffic density trends',
        'analyzeLabel': 'Cross-referencing zone traffic density index...',
        'outcome':
            driver.zone.contains('North') ? 'Moderate congestion' : 'Low congestion index',
        'adj': 0,
        'confidence': 88,
        'icon': Icons.traffic_rounded,
      },
      {
        'name': 'Platform app stability',
        'analyzeLabel': 'Checking ${driver.platform} API health scores (last 7d)...',
        'outcome': driver.tier == 'Platinum'
            ? '99.8% uptime — Excellent'
            : driver.tier == 'Gold'
                ? '99.2% uptime — Good'
                : '98.5% uptime — Average',
        'adj': driver.tier == 'Platinum' ? -8 : driver.tier == 'Gold' ? -4 : 0,
        'confidence': 95,
        'icon': Icons.speed_rounded,
      },
      {
        'name': 'Zone risk classification',
        'analyzeLabel': 'Classifying ${driver.zone} from geo-risk satellite data...',
        'outcome': _zoneRisk(driver.zone),
        'adj': driver.tier == 'Silver' ? 2 : 0,
        'confidence': 92,
        'icon': Icons.map_outlined,
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

    _chartAnimController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _chartAnim = CurvedAnimation(
      parent: _chartAnimController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _chartAnimController.dispose();
    super.dispose();
  }

  String _completionLabel(double rate) {
    if (rate >= 0.9) return 'Excellent';
    if (rate >= 0.8) return 'Good';
    return 'Average';
  }

  String _zoneRisk(String zone) {
    if (zone.contains('South') || zone.contains('Central')) return 'Low Risk (1.8/10)';
    if (zone.contains('North')) return 'Moderate (4.6/10)';
    return 'Low Risk (2.1/10)';
  }

  String _resultSummary() {
    final biggest = _factors
        .where((f) => (f['adj'] as int) < 0)
        .toList()
      ..sort((a, b) => (a['adj'] as int).compareTo(b['adj'] as int));
    if (biggest.isEmpty) return 'Your risk profile is stable this week.';
    final top = biggest.first['name'] as String;
    final topAdj = (biggest.first['adj'] as int).abs();
    return 'Biggest saving: ${top.split(' ').take(2).join(' ')} (−₹$topAdj). Your risk profile looks strong.';
  }

  int _overallConfidence() {
    if (_factors.isEmpty) return 0;
    final sum = _factors.fold<int>(0, (s, f) => s + (f['confidence'] as int));
    return (sum / _factors.length).round();
  }

  Future<void> _runRecalculation() async {
    if (_isCalculating) return;
    final driver = DemoBackend.instance.activeDriver;
    setState(() {
      _isCalculating = true;
      _isFinished = false;
      _isInitializing = true;
      _initLabel = 'Connecting to oracle data feed...';
      _visibleCount = 0;
      _resolvedCount = 0;
      _currentPremium = driver.weeklyPremium;
    });
    _chartAnimController.reset();

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _initLabel = 'Initializing Continuum Risk Engine v2.1...');
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _isInitializing = false);

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
    _chartAnimController.forward();
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
              if (_isInitializing) _buildInitializingWidget(),
              if (_visibleCount > 0) ...[
                ...List.generate(
                  _visibleCount,
                  (i) => _buildFactorRow(context, i),
                ),
              ],
              if (_isFinished) ...[
                const SizedBox(height: 12),
                _buildResultCard(savings),
                const SizedBox(height: 4),
                Center(
                  child: TextButton.icon(
                    onPressed: _runRecalculation,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Recalculate'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 16),
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
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_fix_high_rounded, color: AppTheme.primary, size: 18),
            SizedBox(width: 10),
            Text(
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

  Widget _buildInitializingWidget() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
        boxShadow: AppTheme.softShadowOf(context),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _initLabel,
              style: TextStyle(
                color: AppTheme.textSecondaryOf(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
        : (adj == 0 ? AppTheme.textSecondaryOf(context) : AppTheme.dangerRed);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Transform.translate(
        offset: Offset(20 * (1 - v), 0),
        child: Opacity(opacity: v, child: child),
      ),
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
                  Icon(
                    factor['icon'] as IconData,
                    size: 18,
                    color: adj <= 0 ? AppTheme.successGreen : AppTheme.dangerRed,
                  ),
                  const SizedBox(width: 12),
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
                        const SizedBox(height: 3),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.textSecondaryOf(context).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${factor['confidence']}%',
                          style: TextStyle(
                            color: AppTheme.textSecondaryOf(context),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primary.withOpacity(_pulseAnim.value),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          factor['analyzeLabel'] as String,
                          style: TextStyle(
                            color: AppTheme.textSecondaryOf(context),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TweenAnimationBuilder<double>(
                    key: ValueKey('progress_$index'),
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1100),
                    builder: (context, progress, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: AppTheme.primary.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                      ),
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
                        'You saved ₹$savings vs base rate',
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
            Text(
              _resultSummary(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.successGreen,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Model confidence: ${_overallConfidence()}%',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.successGreen.withOpacity(0.75),
                fontSize: 11,
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
    final values = [base + 6, base, base - 8, _currentPremium];
    return Container(
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: AppTheme.cardDecorationOf(context),
      child: AnimatedBuilder(
        animation: _chartAnim,
        builder: (context, _) => CustomPaint(
          painter: _HistoryChartPainter(
            values: values,
            labels: const ['Week −3', 'Week −2', 'Week −1', 'Current'],
            barColor: AppTheme.primary,
            textColor: AppTheme.textSecondaryOf(context),
            progress: _chartAnim.value,
          ),
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
              'Risk Engine v2.1 • Gemini-assisted • Updated weekly',
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
  final double progress;

  _HistoryChartPainter({
    required this.values,
    required this.labels,
    required this.barColor,
    required this.textColor,
    this.progress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.reduce(math.max);
    const double barWidth = 32.0;
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
      final double fullBarH = maxBarH * (values[i] / (maxVal * 1.08));
      final double barH = fullBarH * progress;
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

      if (progress > 0.85) {
        textPainter.text = TextSpan(
          text: '₹${values[i].toInt()}',
          style: TextStyle(
            color: textColor.withOpacity((progress - 0.85) / 0.15),
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
            color: textColor.withOpacity((progress - 0.85) / 0.15),
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
  }

  @override
  bool shouldRepaint(covariant _HistoryChartPainter old) =>
      old.progress != progress;
}
