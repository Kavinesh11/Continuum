import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../routes/app_routes.dart';
import '../../services/demo_backend.dart';
import '../../state/demo_state.dart';
import '../../theme/app_theme.dart';

/// Full zero-touch claim flow shown as a modal bottom sheet.
/// Plays through 5 animated steps then shows a success payout screen.
class ClaimFlowSheet extends StatefulWidget {
  const ClaimFlowSheet({Key? key}) : super(key: key);

  @override
  State<ClaimFlowSheet> createState() => _ClaimFlowSheetState();
}

class _ClaimFlowSheetState extends State<ClaimFlowSheet>
    with SingleTickerProviderStateMixin {
  // ── Step definitions ──────────────────────────────────────────────────────
  static const _steps = [
    'Verifying your GPS location...',
    'Cross-checking oracle consensus...',
    'Validating policy status...',
    'Fraud check passed — clean signal',
    'Initiating UPI transfer to linked account...',
  ];

  static const _stepDurations = [1500, 2800, 1000, 1500, 2000];

  // ── Oracle source data shown during step 2 ────────────────────────────────
  static const _oracleSources = [
    (name: 'IMD Rainfall', reading: '8.2 mm detected', confirmed: true),
    (name: 'AccuWeather', reading: 'Precip probability 82%', confirmed: true),
    (name: 'NASA GPM', reading: '5.4 mm/hr confirmed', confirmed: true),
    (name: 'Downdetector', reading: 'No platform outage', confirmed: false),
  ];

  // ── State ─────────────────────────────────────────────────────────────────
  int _currentStep = 0;
  bool _completed = false;
  int _oracleRowsVisible = 0; // how many oracle source rows have appeared

  late final AnimationController _checkmarkController;
  late final Animation<double> _checkmarkScale;
  late final Animation<double> _amountFade;

  @override
  void initState() {
    super.initState();

    _checkmarkController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _checkmarkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkmarkController,
        curve: const Interval(0.0, 0.65, curve: Curves.elasticOut),
      ),
    );

    _amountFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkmarkController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );

    _startFlow();
  }

  // ── Tier-aware payout amount ──────────────────────────────────────────────
  int get _payoutAmount {
    final tier = DemoBackend.instance.activeDriver.tier;
    return tier == 'Platinum' ? 380 : tier == 'Gold' ? 247 : 180;
  }

  String get _driverTier => DemoBackend.instance.activeDriver.tier;

  // ── Flow logic ─────────────────────────────────────────────────────────────
  Future<void> _startFlow() async {
    for (int i = 0; i < _steps.length; i++) {
      if (!mounted) return;
      setState(() {
        _currentStep = i;
        if (i == 1) _oracleRowsVisible = 0; // reset oracle rows when step 2 starts
      });

      // During step 2: stagger oracle source rows every 450ms
      if (i == 1) {
        for (int r = 0; r < _oracleSources.length; r++) {
          await Future.delayed(const Duration(milliseconds: 450));
          if (!mounted) return;
          setState(() => _oracleRowsVisible = r + 1);
        }
        // Wait a moment after all rows before moving on
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        await Future.delayed(Duration(milliseconds: _stepDurations[i]));
      }
    }

    if (!mounted) return;

    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr =
        '${now.day} ${months[now.month - 1]} ${now.year}, '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    DemoState.instance.addAutoClaim({
      'id': '#AUTO-847291',
      'title': 'Weather + Platform Outage',
      'date': dateStr,
      'amount': _payoutAmount,
      'status': 'Auto-Approved',
      'statusColor': const Color(0xFF6366F1),
      'progressPct': 1.0,
      'isAuto': true,
      'upiRef': 'UPI/040426/CONT847291',
    });

    setState(() {
      _currentStep = 5;
      _completed = true;
    });

    await _checkmarkController.forward();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _formatTimestamp() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}, '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _checkmarkController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 36,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerOf(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedCrossFade(
            firstChild: _buildStepperView(),
            secondChild: _buildSuccessView(),
            crossFadeState: _completed
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 400),
          ),
        ],
      ),
    );
  }

  // ── Stepper view ───────────────────────────────────────────────────────────
  Widget _buildStepperView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.dangerRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.dangerRed,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Disruption Detected',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Initiating automatic claim — no action needed',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        ...List.generate(_steps.length, _buildStepRow),
        // Oracle source breakdown — visible only during step 2
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _currentStep == 1
              ? _buildOracleBreakdown()
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildStepRow(int index) {
    final bool isDone = index < _currentStep;
    final bool isActive = index == _currentStep;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? AppTheme.successGreen
                  : isActive
                  ? AppTheme.primary
                  : AppTheme.dividerOf(context),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: isDone
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : isActive
                ? const Padding(
                    padding: EdgeInsets.all(7),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textHintOf(context),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isDone
                    ? AppTheme.successGreen
                    : isActive
                    ? AppTheme.textPrimaryOf(context)
                    : AppTheme.textHintOf(context),
              ),
              child: Text(_steps[index]),
            ),
          ),
          if (isDone)
            Icon(
              Icons.check_circle_rounded,
              color: AppTheme.successGreen.withOpacity(0.65),
              size: 16,
            ),
        ],
      ),
    );
  }

  // ── Oracle breakdown (step 2 only) ─────────────────────────────────────────
  Widget _buildOracleBreakdown() {
    final confirmedCount = _oracleSources
        .take(_oracleRowsVisible)
        .where((s) => s.confirmed)
        .length;

    return Padding(
      padding: const EdgeInsets.only(left: 48, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(_oracleSources.length, (i) {
            if (i >= _oracleRowsVisible) return const SizedBox.shrink();
            final src = _oracleSources[i];
            return AnimatedOpacity(
              opacity: i < _oracleRowsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      src.confirmed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 14,
                      color: src.confirmed
                          ? AppTheme.successGreen
                          : AppTheme.textHintOf(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      src.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        src.reading,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          // Consensus summary row
          if (_oracleRowsVisible == _oracleSources.length) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.successGreen.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, size: 13, color: AppTheme.successGreen),
                  const SizedBox(width: 6),
                  Text(
                    'Consensus: $confirmedCount of ${_oracleSources.length}  ·  THRESHOLD MET',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.successGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Success view ───────────────────────────────────────────────────────────
  Widget _buildSuccessView() {
    final isLowerTier = _driverTier != 'Platinum';
    return AnimatedBuilder(
      animation: _checkmarkController,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: _checkmarkScale.value,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppTheme.successGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.successGreen.withOpacity(0.45),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Opacity(
              opacity: _amountFade.value,
              child: Column(
                children: [
                  Text(
                    '₹$_payoutAmount credited to your UPI',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_driverTier tier payout',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No action was required from you',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: AppTheme.successGreen.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          Icons.tag_rounded,
                          'UPI Reference',
                          'UPI/040426/CONT847291',
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.access_time_rounded,
                          'Timestamp',
                          _formatTimestamp(),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.bolt_rounded,
                          'Trigger Reason',
                          'Weather + Platform Outage',
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.shield_rounded,
                          'Oracle Consensus',
                          '3 of 4 sources confirmed',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Post-success CTAs
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            // Navigate to claims tab (index 1 in HomeShell)
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.home,
                              (route) => false,
                              arguments: 1,
                            );
                          },
                          icon: const Icon(Icons.history_rounded, size: 16),
                          label: const Text('View Claims'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: BorderSide(color: AppTheme.primary.withOpacity(0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Share link copied!'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondaryOf(context),
                            side: BorderSide(color: AppTheme.dividerOf(context)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Upgrade nudge for Silver / Gold
                  if (isLowerTier) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.planDetails);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_upward_rounded, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Platinum holders get ₹380 for this event. See plans →',
                                style: TextStyle(
                                  fontSize: 11, color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.successGreen.withOpacity(0.8)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryOf(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }
}
