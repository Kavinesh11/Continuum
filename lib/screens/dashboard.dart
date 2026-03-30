import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../data/mock_data.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedTrend = 'Monthly';

  static const Map<String, _TrendSeries> _trendSeriesByRange = {
    'Yearly': _TrendSeries(
      labels: ['2022', '2023', '2024', '2025', '2026'],
      payout: [15800, 18150, 20500, 24200, 27650],
      premium: [1480, 1560, 1620, 1710, 1830],
    ),
    'Monthly': _TrendSeries(
      labels: [
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
      ],
      payout: [
        980,
        1180,
        1510,
        1780,
        2010,
        1880,
        2320,
        2480,
        2690,
        2790,
        3110,
        2850,
      ],
      premium: [120, 132, 148, 138, 130, 166, 178, 170, 196, 220, 208, 170],
    ),
    'Weekly': _TrendSeries(
      labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      payout: [320, 410, 380, 460, 520, 610, 570],
      premium: [24, 28, 26, 30, 33, 37, 35],
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'CONTINUUM',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF008A8A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: CircleAvatar(
              backgroundColor: const Color(0xFFE8A8A8),
              child: const Text(
                'PS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.black54,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(),
              const SizedBox(height: 24),
              _buildPlanStatusCard(),
              const SizedBox(height: 16),
              _buildTwoPillsRow(),
              const SizedBox(height: 24),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _buildQuickActions(context),
              const SizedBox(height: 24),
              _buildEarningsTrendSection(),
              const SizedBox(height: 24),
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildRecentActivity(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, ${MockData.user['fullName']}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Your shift ends in 3 hours. Drive safe!',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildPlanStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF008A8A), Color(0xFF005F5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF008A8A).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PLAN STATUS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '✓ SECURE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Coverage Active',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Next renewal on ${MockData.coverage['nextRenewal']}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            'Zone: ${MockData.coverage['zone']}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoPillsRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CURRENT CLAIM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  MockData.currentClaim['status'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '2 days ago',
                  style: TextStyle(fontSize: 12, color: Color(0xFFFF8C00)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weekly PREMIUM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '57',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF008A8A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Paid via Autopay',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionButton(
          context,
          Icons.note_add,
          'Apply Claim',
          const Color(0xFF008A8A),
          AppRoutes.apply,
        ),
        _buildActionButton(
          context,
          Icons.description_outlined,
          'View Policy',
          Colors.grey,
          AppRoutes.policy,
        ),
        _buildActionButton(
          context,
          Icons.track_changes_outlined,
          'Track Latest Claim',
          Colors.grey,
          AppRoutes.claimStatus,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    String route,
  ) {
    return GestureDetector(
      onTap: () {
        if (route == AppRoutes.home) {
          return;
        }
        Navigator.pushNamed(context, route);
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFD4EBEE),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabChip('Yearly'),
          _buildTabChip('Monthly'),
          _buildTabChip('Weekly'),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label) {
    final selected = _selectedTrend == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedTrend = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFF28A3AD) : const Color(0xFF3A6D74),
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsTrendSection() {
    final series =
        _trendSeriesByRange[_selectedTrend] ?? _trendSeriesByRange['Monthly']!;
    final latestPayout = series.payout.last;
    final latestPremium = series.premium.last;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFC),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFCBE9ED), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EARNINGS TREND',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Color(0xFF527B82),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Payout vs Premium Payment by month',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6C8D93),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(alignment: Alignment.center, child: _buildEarningsTabs()),
          const SizedBox(height: 14),
          const Row(
            children: [
              _LegendDot(color: Color(0xFF2FA7B1), label: 'Payout'),
              SizedBox(width: 20),
              _LegendDot(color: Color(0xFF0F5A61), label: 'Premium'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE1EFF1),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _EarningsTrendPainter(series: series),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: series.labels
                      .map(
                        (month) => Expanded(
                          child: Text(
                            month,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF5B7F86),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'LATEST MONTH PAYOUT',
                  value: 'INR ${_formatNumber(latestPayout)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'LATEST MONTH PREMIUM',
                  value: 'INR ${_formatNumber(latestPremium)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFD1E9ED),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF4F757D),
              letterSpacing: 0.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              color: Color(0xFF08373F),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    final raw = value.round().toString();
    final chars = raw.split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(chars[i]);
    }
    return buffer.toString().split('').reversed.join();
  }

  Widget _buildRecentActivity() {
    final activity = MockData.recentActivity as List<Map<String, dynamic>>;
    return Column(
      children: activity
          .map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF008A8A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.bolt,
                      color: Color(0xFF008A8A),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['subtitle'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item['time'] as String,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
              ),
            ),
          )
          .toList(),
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
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF446D74),
          ),
        ),
      ],
    );
  }
}

class _TrendSeries {
  final List<String> labels;
  final List<double> payout;
  final List<double> premium;

  const _TrendSeries({
    required this.labels,
    required this.payout,
    required this.premium,
  });
}

class _EarningsTrendPainter extends CustomPainter {
  final _TrendSeries series;

  const _EarningsTrendPainter({required this.series});

  @override
  void paint(Canvas canvas, Size size) {
    final allValues = [...series.payout, ...series.premium];
    final maxValue = allValues.reduce((a, b) => a > b ? a : b);
    const minValue = 0.0;

    final gridPaint = Paint()
      ..color = const Color(0xFF93D0D8)
      ..strokeWidth = 1.2;

    for (var i = 0; i < 4; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final payoutPoints = _createPoints(series.payout, size, maxValue, minValue);
    final premiumPoints = _createPoints(
      series.premium,
      size,
      maxValue,
      minValue,
    );

    _drawSeries(canvas, payoutPoints, const Color(0xFF2FA7B1), false);
    _drawSeries(canvas, premiumPoints, const Color(0xFF0F5A61), true);

    final pointPaintPayout = Paint()..color = const Color(0xFF2FA7B1);
    final pointPaintPremium = Paint()..color = const Color(0xFF0F5A61);
    canvas.drawCircle(payoutPoints.last, 6, pointPaintPayout);
    canvas.drawCircle(premiumPoints.last, 6, pointPaintPremium);
  }

  List<Offset> _createPoints(
    List<double> values,
    Size size,
    double maxValue,
    double minValue,
  ) {
    if (values.length == 1) {
      return [Offset(size.width / 2, size.height / 2)];
    }

    final usableHeight = size.height - 10;
    final denominator = (maxValue - minValue) == 0 ? 1 : (maxValue - minValue);

    return List<Offset>.generate(values.length, (index) {
      final x = size.width * (index / (values.length - 1));
      final normalized = (values[index] - minValue) / denominator;
      final y = usableHeight - (usableHeight * normalized) + 5;
      return Offset(x, y);
    });
  }

  void _drawSeries(
    Canvas canvas,
    List<Offset> points,
    Color color,
    bool dashed,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (dashed) {
      for (var i = 0; i < points.length - 1; i++) {
        _drawDashedLine(canvas, points[i], points[i + 1], paint);
      }
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt((dx * dx) + (dy * dy));
    if (distance == 0) {
      return;
    }
    final dashCount = (distance / (dashWidth + dashSpace)).floor();

    for (var i = 0; i < dashCount; i++) {
      final startProgress = (i * (dashWidth + dashSpace)) / distance;
      final endProgress =
          ((i * (dashWidth + dashSpace)) + dashWidth) / distance;

      final from = Offset(
        start.dx + (dx * startProgress),
        start.dy + (dy * startProgress),
      );
      final to = Offset(
        start.dx + (dx * endProgress),
        start.dy + (dy * endProgress),
      );
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EarningsTrendPainter oldDelegate) {
    return oldDelegate.series != series;
  }
}
