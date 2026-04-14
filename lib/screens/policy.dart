import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PolicyScreen extends StatefulWidget {
  const PolicyScreen({Key? key}) : super(key: key);

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> with TickerProviderStateMixin {
  bool _isCalculating = false;
  bool _isFinished = false;
  int _visibleCount = 0;
  int _resolvedCount = 0;
  double _currentPremium = 99.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  final List<Map<String, dynamic>> _factors = [
    {"name": "Waterlogging incidents (30d)", "outcome": "0 incidents", "adj": -8},
    {"name": "Your accident history", "outcome": "Clean (6 months)", "adj": -6},
    {"name": "Traffic density trends", "outcome": "Average", "adj": 0},
    {"name": "Platform app stability", "outcome": "Good", "adj": -4},
    {"name": "Local road closures", "outcome": "None", "adj": -4},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runRecalculation() async {
    if (_isCalculating) return;
    setState(() {
      _isCalculating = true;
      _isFinished = false;
      _visibleCount = 0;
      _resolvedCount = 0;
      _currentPremium = 99.0;
    });

    for (int i = 0; i < _factors.length; i++) {
      if (!mounted) return;
      setState(() => _visibleCount = i + 1);
      
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (!mounted) return;
      setState(() {
        _resolvedCount = i + 1;
        _currentPremium += _factors[i]['adj'] as int;
      });
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _isFinished = true;
      _isCalculating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Policy'),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.all(12.0),
            child: Icon(Icons.arrow_back),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildOverviewCard(),
            const SizedBox(height: 28),
            _buildSectionTitle('Dynamic Pricing Engine'),
            const SizedBox(height: 16),
            if (!_isCalculating && !_isFinished) _buildCalculateButton(),
            if (_visibleCount > 0) ...[
              ...List.generate(_visibleCount, (index) {
                return _buildFactorRow(index);
              }),
            ],
            if (_isFinished) ...[
              const SizedBox(height: 12),
              _buildResultCard(),
              const SizedBox(height: 28),
              _buildSectionTitle('Premium History'),
              const SizedBox(height: 16),
              _buildChartSection(),
            ],
            const SizedBox(height: 32),
            _buildBadge(),
          ],
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

  Widget _buildOverviewCard() {
    return Container(
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
                      'Velachery, Chennai Zone 4',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gold Tier',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                 ],
               ),
               Icon(Icons.shield_outlined, color: Colors.white.withOpacity(0.5), size: 40),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Text(
                      'Base Premium',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '₹99/week',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                 ],
               ),
               Column(
                 crossAxisAlignment: CrossAxisAlignment.end,
                 children: [
                   Text(
                      'Current Premium',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                   TweenAnimationBuilder<double>(
                     tween: Tween<double>(begin: 99.0, end: _currentPremium),
                     duration: const Duration(milliseconds: 1500),
                     builder: (context, value, child) {
                       return Text(
                         '₹${value.toInt()}',
                         style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                       );
                     },
                   ),
                 ],
               ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalculateButton() {
     return InkWell(
       onTap: _runRecalculation,
       borderRadius: BorderRadius.circular(12),
       child: Container(
         width: double.infinity,
         padding: const EdgeInsets.symmetric(vertical: 16),
         decoration: BoxDecoration(
           color: AppTheme.cardOf(context),
           borderRadius: BorderRadius.circular(12),
           border: Border.all(color: AppTheme.primary.withOpacity(0.5), width: 1.5),
           boxShadow: [
             BoxShadow(
               color: AppTheme.primary.withOpacity(0.1),
               blurRadius: 10,
               offset: const Offset(0, 4),
             )
           ],
         ),
         child: const Center(
           child: Text(
             'Run Risk Recalculation',
             style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 15),
           ),
         ),
       ),
     );
  }

  Widget _buildFactorRow(int index) {
     final bool isResolved = index < _resolvedCount;
     final factor = _factors[index];
     final int adj = factor['adj'];
     final String adjStr = adj > 0 ? '+₹$adj' : (adj == 0 ? '±₹0' : '−₹${adj.abs()}');
     final Color adjColor = adj < 0 
         ? AppTheme.successGreen 
         : (adj == 0 ? AppTheme.textSecondaryOf(context) : AppTheme.dangerRed);

     return AnimatedContainer(
       duration: const Duration(milliseconds: 1500),
       margin: const EdgeInsets.only(bottom: 12),
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: AppTheme.cardOf(context),
         borderRadius: BorderRadius.circular(12),
         boxShadow: AppTheme.softShadowOf(context),
         border: Border.all(
             color: isResolved 
                    ? (adj <= 0 ? AppTheme.successGreen.withOpacity(0.3) : AppTheme.dangerRed.withOpacity(0.3))
                    : AppTheme.primary.withOpacity(0.2),
             width: 1),
       ),
       child: isResolved ? Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(factor['name'], style: TextStyle(color: AppTheme.textPrimaryOf(context), fontWeight: FontWeight.w600, fontSize: 14)),
                   const SizedBox(height: 4),
                   Text(factor['outcome'], style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: adjColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(adjStr, style: TextStyle(color: adjColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
         ]
       ) : Row(
         children: [
           AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(_pulseAnim.value),
                ),
              ),
           ),
           const SizedBox(width: 16),
           Text('Analyzing ${factor['name'].split(" ").first}...', style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 14)),
         ],
       ),
     );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.successGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 32),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('This week you pay ₹77', style: TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 2),
                  Text('You saved ₹22', style: TextStyle(color: AppTheme.successGreen, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Your zone had zero waterlogging incidents in the last 30 days.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.successGreen, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: AppTheme.cardDecorationOf(context),
      child: CustomPaint(
         painter: _HistoryChartPainter(
           values: [94, 99, 89, 77],
           labels: ['Week-1', 'Week-2', 'Week-3', 'Current'],
           barColor: AppTheme.primary,
           textColor: AppTheme.textSecondaryOf(context),
         ),
      ),
    );
  }

  Widget _buildBadge() {
     return Center(
       child: Container(
         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
         decoration: BoxDecoration(
           color: AppTheme.cardOf(context),
           borderRadius: BorderRadius.circular(20),
           border: Border.all(color: AppTheme.textHintOf(context).withOpacity(0.3)),
         ),
         child: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Icon(Icons.auto_awesome, size: 14, color: AppTheme.primary),
             const SizedBox(width: 8),
             Text('ML-Optimized Pricing • Updated weekly', style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 11, fontWeight: FontWeight.w500)),
           ]
         )
       )
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
    final double spacing = (size.width - (barWidth * values.length)) / (values.length - 1);
    
    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;
      
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    for (int i = 0; i < values.length; i++) {
       final double x = i * (barWidth + spacing);
       
       // Calculate dynamic height relative to container boundaries
       // Reserving top 30px for value text, and bottom 20px for labels.
       final double maxBarHeight = size.height - 40; 
       final double heightRatio = values[i] / (maxVal * 1.05); // Give a bit of headroom to the max value
       final double barHeight = maxBarHeight * heightRatio;
       final double y = size.height - 24 - barHeight; // Base coordinate is slightly above bottom label area
       
       final rect = RRect.fromRectAndRadius(
         Rect.fromLTWH(x, y, barWidth, barHeight),
         const Radius.circular(6),
       );
       
       if (i == values.length - 1) {
         paint.color = AppTheme.successGreen;
       } else {
         paint.color = barColor.withOpacity(0.3);
       }
       
       canvas.drawRRect(rect, paint);
       
       // Value text at top
       textPainter.text = TextSpan(
         text: '₹${values[i].toInt()}',
         style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600),
       );
       textPainter.layout();
       textPainter.paint(canvas, Offset(x + (barWidth - textPainter.width) / 2, y - 18));
       
       // Label at bottom
       textPainter.text = TextSpan(
         text: labels[i],
         style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600),
       );
       textPainter.layout();
       textPainter.paint(canvas, Offset(x + (barWidth - textPainter.width) / 2, size.height - 15));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
