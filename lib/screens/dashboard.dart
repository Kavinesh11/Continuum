import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../sandbox/driver_provider.dart';
import '../state/demo_state.dart';
import '../widgets/notification_action.dart';
import 'claim_flow.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  // ── Earnings trend ─────────────────────────────────────────────────────────
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

  // ── Live trigger data ──────────────────────────────────────────────────────
  static final _triggerData = [
    {
      'title': 'Weather Oracle',
      'source': 'IMD API',
      'alertMsg':
          'Rainfall: 62mm detected in Chennai Zone 4 — exceeds 50mm threshold',
      'icon': Icons.cloud_outlined,
    },
    {
      'title': 'Platform Outage',
      'source': 'Swiggy API ping',
      'alertMsg': 'Order routing API returning 503 in your zone',
      'icon': Icons.wifi_off_outlined,
    },
    {
      'title': 'Municipal Advisory',
      'source': 'Corporation RSS',
      'alertMsg': 'Chennai Corporation: Red Alert flood advisory active',
      'icon': Icons.warning_amber_outlined,
    },
    {
      'title': 'Order Density Drop',
      'source': 'Platform data',
      'alertMsg': 'Order volume 78% below hourly average in your area',
      'icon': Icons.trending_down_rounded,
    },
    {
      'title': 'Road Closure',
      'source': 'Traffic API',
      'alertMsg': 'Anna Salai, GST Road blocked — 3 major routes inaccessible',
      'icon': Icons.block_outlined,
    },
  ];

  // ── Animation controllers ──────────────────────────────────────────────────
  /// Single looping controller for the monitoring dot pulse on all cards.
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  /// Per-card shake controllers (fire once on alert activation).
  late final List<AnimationController> _shakeControllers;

  // ── Timestamps ─────────────────────────────────────────────────────────────
  late List<DateTime> _lastCheckedTimes;
  Timer? _timestampTimer;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Monitoring dot pulse (loops indefinitely)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Per-card shake controllers
    _shakeControllers = List.generate(
      5,
      (_) => AnimationController(
        duration: const Duration(milliseconds: 650),
        vsync: this,
      ),
    );

    // Staggered initial last-checked times (look like monitoring is ongoing)
    _lastCheckedTimes = [
      DateTime.now().subtract(const Duration(minutes: 2, seconds: 14)),
      DateTime.now().subtract(const Duration(minutes: 3, seconds: 42)),
      DateTime.now().subtract(const Duration(minutes: 1, seconds: 7)),
      DateTime.now().subtract(const Duration(minutes: 4, seconds: 23)),
      DateTime.now().subtract(const Duration(minutes: 2, seconds: 51)),
    ];

    // Refresh timestamps every 30 seconds (simulate live polling)
    _timestampTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < 5; i++) {
          _lastCheckedTimes[i] = DateTime.now();
        }
      });
    });

    DemoState.instance.addListener(_onDemoStateChanged);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    for (final c in _shakeControllers) {
      c.dispose();
    }
    _timestampTimer?.cancel();
    DemoState.instance.removeListener(_onDemoStateChanged);
    super.dispose();
  }

  // ── Demo state listener ────────────────────────────────────────────────────
  void _onDemoStateChanged() {
    if (!mounted) return;
    setState(() {});

    final demo = DemoState.instance;
    if (demo.alertCount >= 2 && !demo.claimFlowShown) {
      demo.markClaimFlowShown();
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        _showClaimFlow();
      });
    }
  }

  // ── Demo sequence ──────────────────────────────────────────────────────────
  /// Long-press on "CONTINUUM" title fires (or resets) the full demo sequence.
  Future<void> _fireDemoSequence() async {
    // Always reset first so the demo is cleanly repeatable
    DemoState.instance.resetAll();
    await Future.delayed(const Duration(milliseconds: 400));

    for (int i = 0; i < 5; i++) {
      if (!mounted) return;
      // Update timestamp to "just now" as each trigger fires
      setState(() => _lastCheckedTimes[i] = DateTime.now());
      _shakeControllers[i].forward(from: 0);
      DemoState.instance.activateTrigger(i);
      await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  void _showClaimFlow() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const ClaimFlowSheet(),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _formatLastChecked(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 90) return 'Just now';
    if (diff.inMinutes < 2) return '1 min ago';
    return '${diff.inMinutes} min ago';
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final driver = DriverProvider.of(context).driver;
    return Scaffold(
      appBar: AppBar(
        // Long-press on the title fires the hidden demo sequence
        title: GestureDetector(
          onLongPress: _fireDemoSequence,
          child: const Text('CONTINUUM'),
        ),
        leading: GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.accentGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.person, color: Colors.white, size: 16),
              ),
            ),
          ),
        ),
        actions: [const NotificationAction()],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(),
              const SizedBox(height: 20),
              _buildPlanStatusCard(),
              const SizedBox(height: 16),
              _buildTwoPillsRow(),
              const SizedBox(height: 24),
              Text(
                'Quick Actions',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              _buildQuickActions(context),
              const SizedBox(height: 28),
              // ── Live Triggers ──────────────────────────────────────────────
              _buildLiveTriggersSection(),
              const SizedBox(height: 28),
              _buildEarningsTrendSection(),
              const SizedBox(height: 24),
              Text(
                'Recent Activity',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _buildRecentActivity(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Live Triggers Section ──────────────────────────────────────────────────
  Widget _buildLiveTriggersSection() {
    final demo = DemoState.instance;
    final alertCount = demo.alertCount;
    final hasAlerts = alertCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Triggers',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Real-time disruption monitoring',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status pill
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: hasAlerts
                    ? AppTheme.dangerRed.withOpacity(0.1)
                    : AppTheme.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasAlerts
                      ? AppTheme.dangerRed.withOpacity(0.3)
                      : AppTheme.successGreen.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasAlerts
                            ? AppTheme.dangerRed
                            : AppTheme.successGreen.withOpacity(
                                _pulseAnim.value,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    hasAlerts
                        ? '$alertCount Alert${alertCount > 1 ? 's' : ''}'
                        : 'All Clear',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: hasAlerts
                          ? AppTheme.dangerRed
                          : AppTheme.successGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // 5 trigger cards
        for (int i = 0; i < 5; i++) _buildTriggerCard(i),
      ],
    );
  }

  Widget _buildTriggerCard(int index) {
    final isAlert = DemoState.instance.triggerAlerts[index];
    final data = _triggerData[index];

    return AnimatedBuilder(
      animation: _shakeControllers[index],
      builder: (context, _) {
        final v = _shakeControllers[index].value;
        // Damped sinusoidal shake
        final dx =
            math.sin(v * math.pi * 5) * 9.0 * math.max(0.0, 1.0 - v * 1.4);
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              boxShadow: AppTheme.softShadowOf(context),
              border: isAlert
                  ? Border.all(
                      color: AppTheme.dangerRed.withOpacity(0.3),
                      width: 1.5,
                    )
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Stack(
                children: [
                  // Animated left accent bar
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 4,
                      decoration: BoxDecoration(
                        color: isAlert
                            ? AppTheme.dangerRed
                            : AppTheme.successGreen,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: status dot + text + timestamp
                        Row(
                          children: [
                            // Pulsing or solid dot
                            if (!isAlert)
                              AnimatedBuilder(
                                animation: _pulseAnim,
                                builder: (_, __) => Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.successGreen.withOpacity(
                                      _pulseAnim.value,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.successGreen
                                            .withOpacity(
                                              _pulseAnim.value * 0.4,
                                            ),
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.dangerRed,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.dangerRed.withOpacity(
                                        0.5,
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(width: 6),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isAlert
                                    ? AppTheme.dangerRed
                                    : AppTheme.successGreen,
                              ),
                              child: Text(
                                isAlert ? '⚠ Alert Detected' : 'Monitoring...',
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatLastChecked(_lastCheckedTimes[index]),
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textHintOf(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        // Title + source row
                        Row(
                          children: [
                            Icon(
                              data['icon'] as IconData,
                              size: 15,
                              color: isAlert
                                  ? AppTheme.dangerRed
                                  : AppTheme.primary,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              data['title'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '— ${data['source']}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textHintOf(context),
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // Alert message (animated reveal)
                        AnimatedCrossFade(
                          firstChild: const SizedBox(
                            width: double.infinity,
                            height: 0,
                          ),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.dangerRed.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                data['alertMsg'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.dangerRed,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                          crossFadeState: isAlert
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 380),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Existing sections (unchanged) ──────────────────────────────────────────
  Widget _buildGreeting() {
    final driver = DriverProvider.of(context).driver;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Hello, ${driver.fullName} ',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Your shift ends in 3 hours. Drive safe!',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildPlanStatusCard() {
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
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -10,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PLAN STATUS',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: AppTheme.successGreen,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.successGreen.withOpacity(
                                      0.6,
                                    ),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'SECURE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Coverage Active',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.white.withOpacity(0.7),
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Next renewal on ${MockData.coverage['nextRenewal']}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: Colors.white.withOpacity(0.7),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Zone: ${MockData.coverage['zone']}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTwoPillsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildInfoPill(
            label: 'CURRENT CLAIM',
            value: MockData.currentClaim['status'] as String,
            subtitle: '2 days ago',
            subtitleColor: AppTheme.warningOrange,
            accentColor: AppTheme.warningOrange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoPill(
            label: 'WEEKLY PREMIUM',
            value: '₹99',
            subtitle: 'Paid via Razorpay',
            subtitleColor: AppTheme.textSecondaryOf(context),
            accentColor: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPill({
    required String label,
    required String value,
    required String subtitle,
    required Color subtitleColor,
    required Color accentColor,
  }) {
    return Container(
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
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textSecondaryOf(context),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionButton(
          context,
          Icons.note_add_rounded,
          'Apply Claim',
          AppTheme.primary,
          AppRoutes.apply,
          true,
        ),
        _buildActionButton(
          context,
          Icons.description_outlined,
          'View Policy',
          AppTheme.primary,
          AppRoutes.policy,
          true,
        ),
        _buildActionButton(
          context,
          Icons.track_changes_rounded,
          'Track Claim',
          AppTheme.primary,
          AppRoutes.claimStatus,
          true,
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
    bool isPrimary,
  ) {
    return GestureDetector(
      onTap: () {
        if (route == AppRoutes.home) return;
        Navigator.pushNamed(context, route);
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: isPrimary
                  ? LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isPrimary ? null : color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : AppTheme.softShadowOf(context),
            ),
            child: Icon(
              icon,
              color: isPrimary ? Colors.white : color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
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
        color: AppTheme.primary.withOpacity(0.08),
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.cardOf(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected
                ? AppTheme.primary
                : AppTheme.textSecondaryOf(context),
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
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.softShadowOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EARNINGS TREND',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AppTheme.primary.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Payout vs Premium Payment',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
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
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withOpacity(0.06),
                  AppTheme.primary.withOpacity(0.03),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.primary.withOpacity(0.08)),
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
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondaryOf(context),
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
                  title: 'LATEST \n PAYOUT',
                  value: 'INR ${_formatNumber(latestPayout)}',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF2FA7B1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'LATEST \n PREMIUM',
                  value: 'INR ${_formatNumber(latestPremium)}',
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFF35929B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(AppTheme.isDark(context) ? 0.25 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.8),
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              color: color,
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
    final icons = [
      Icons.bolt_rounded,
      Icons.payment_rounded,
      Icons.verified_rounded,
      Icons.access_time_rounded,
    ];
    final colors = [
      AppTheme.primary,
      const Color(0xFF6366F1),
      AppTheme.successGreen,
      AppTheme.warningOrange,
    ];

    return Column(
      children: activity.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        final color = colors[idx % colors.length];
        final icon = icons[idx % icons.length];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
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
                  child: Container(width: 3.5, color: color),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['subtitle'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        item['time'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textHintOf(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.4), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondaryOf(context),
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
      ..color = const Color(0xFF93D0D8).withOpacity(0.4)
      ..strokeWidth = 1.0;

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

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2FA7B1).withOpacity(0.15),
          const Color(0xFF2FA7B1).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final fillPath = Path()..moveTo(payoutPoints.first.dx, size.height);
    for (final p in payoutPoints) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(payoutPoints.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    _drawSeries(canvas, payoutPoints, const Color(0xFF2FA7B1), false);
    _drawSeries(canvas, premiumPoints, const Color(0xFF0F5A61), true);

    final glowPaint = Paint()
      ..color = const Color(0xFF2FA7B1).withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(payoutPoints.last, 8, glowPaint);

    final pointPaintPayout = Paint()..color = const Color(0xFF2FA7B1);
    final pointPaintPremium = Paint()..color = const Color(0xFF0F5A61);
    canvas.drawCircle(payoutPoints.last, 5, pointPaintPayout);
    canvas.drawCircle(premiumPoints.last, 5, pointPaintPremium);

    final whiteDot = Paint()..color = Colors.white;
    canvas.drawCircle(payoutPoints.last, 2.5, whiteDot);
    canvas.drawCircle(premiumPoints.last, 2.5, whiteDot);
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
      ..strokeWidth = 3
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
    if (distance == 0) return;
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
