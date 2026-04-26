import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../state/demo_orchestrator.dart';
import '../../widgets/notification_action.dart';

class StatusTrackerScreen extends StatefulWidget {
  const StatusTrackerScreen({Key? key}) : super(key: key);

  @override
  State<StatusTrackerScreen> createState() => _StatusTrackerScreenState();
}

class _StatusTrackerScreenState extends State<StatusTrackerScreen> {
  Map<String, dynamic>? _liveData;
  bool _isLoading = true;
  bool _invalidClaim = false;
  String? _claimId;
  Timer? _pollTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_claimId != null || _invalidClaim) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) {
      _claimId = args;
      _loadStatus();
      return;
    }
    if (args is Map<String, dynamic>) {
      final id = args['id']?.toString() ?? args['claimId']?.toString();
      if (id != null && id.isNotEmpty) {
        _claimId = id;
        _loadStatus();
        return;
      }
      _liveData = args;
      _isLoading = false;
      return;
    }

    setState(() {
      _isLoading = false;
      _invalidClaim = true;
    });
  }

  Future<void> _loadStatus() async {
    if (_claimId == null) return;
    try {
      final result = await ApiService().getClaimStatus(_claimId!);
      if (!mounted) return;
      setState(() {
        _liveData = result;
        _isLoading = false;
      });
      _scheduleNextPoll(result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scheduleNextPoll(Map<String, dynamic> data) {
    _pollTimer?.cancel();
    final code = (data['statusCode'] ?? '').toString();
    if (code == 'APPROVED' || code == 'REJECTED') return;
    _pollTimer = Timer(const Duration(seconds: 4), _loadStatus);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _buildDisplayData(dynamic args) {
    final mapArgs = args is Map<String, dynamic> ? args : null;
    final source = _liveData ?? mapArgs ?? const <String, dynamic>{};
    final statusRaw = (source['status'] ?? mapArgs?['status'] ?? 'processing')
        .toString();
    final status = statusRaw.toLowerCase() == 'approved'
        ? 'Approved'
        : (statusRaw.toLowerCase() == 'rejected' ? 'Rejected' : 'Under Review');
    final amount =
        (source['estimated_payout'] ??
                source['expectedPayout'] ??
                mapArgs?['amount'] ??
                0)
            .toString();
    final claimId =
        (source['claim_id'] ??
                source['id'] ??
                mapArgs?['id'] ??
                _claimId ??
                'N/A')
            .toString();
    final stages = (source['stages'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    final mappedStages = stages.isNotEmpty
        ? stages
              .map(
                (s) => {
                  'name': (s['name'] ?? '').toString().toUpperCase(),
                  'time': (s['time'] ?? '').toString().isEmpty
                      ? ((s['complete'] == true || s['completed'] == true) ? 'Completed' : 'Pending')
                      : (s['time']).toString(),
                  // DemoBackend uses 'complete'; some backends use 'completed'
                  'complete': s['complete'] == true || s['completed'] == true,
                },
              )
              .toList()
        : [
            {'name': 'SUBMITTED', 'time': 'Completed', 'complete': true},
            {
              'name': 'REVIEW',
              'time': status == 'Under Review' ? 'In Progress' : 'Done',
              'complete': true,
            },
            {
              'name': 'APPROVED',
              'time': status == 'Approved' ? 'Done' : 'Pending',
              'complete': status == 'Approved',
            },
            {
              'name': 'PAYOUT',
              'time': status == 'Approved' ? 'Processing' : 'Pending',
              'complete': false,
            },
          ];

    return {
      'claimId': claimId,
      'status': status,
      'isAuto': mapArgs?['isAuto'] == true,
      'isApproved': status == 'Approved',
      'reason':
          (source['eventType'] ??
                  source['event_type'] ??
                  source['title'] ??
                  source['reason'] ??
                  'Claim')
              .toString(),
      'claim_description':
          (source['claim_description'] ??
                  source['description'] ??
                  '')
              .toString(),
      'expectedPayout': amount,
      'timelineText':
          (source['timelineText'] ??
                  source['timeline_text'] ??
                  (status == 'Approved'
                      ? 'Within 1 business day'
                      : '2-3 business days'))
              .toString(),
      'verificationMessage':
          (source['verificationMessage'] ??
                  source['verification_message'] ??
                  (status == 'Approved'
                      ? 'Verification complete'
                      : 'We are verifying your details'))
              .toString(),
      'stages': mappedStages,
    };
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final data = _buildDisplayData(args);
    final stages = (data['stages'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('CONTINUUM'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          },
        ),
        actions: [const NotificationAction()],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _invalidClaim
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Invalid claim reference. Open status from a specific claim.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusHeader(context, data),
                          const SizedBox(height: 22),
                          _buildProgressCard(context, stages),
                          const SizedBox(height: 22),
                          _buildClaimDetailsCard(context, data),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onLongPress: () {
                              if (_claimId != null) {
                                DemoOrchestrator.instance.forceApprove(_claimId!);
                                Future.delayed(
                                  const Duration(milliseconds: 600),
                                  _loadStatus,
                                );
                              }
                            },
                            child: _buildPayoutCard(context, data),
                          ),
                          const SizedBox(height: 16),
                          _buildTimelineCard(context, data),
                          const SizedBox(height: 16),
                          _buildVerificationPanel(context, data),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context, Map<String, dynamic> data) {
    final status = data['status'] as String;
    final isAuto = data['isAuto'] as bool;
    final isApproved = data['isApproved'] as bool;

    List<Color> gradientColors;
    Color shadowColor;

    if (isAuto || status == 'Auto-Approved') {
      gradientColors = const [Color(0xFF8B5CF6), Color(0xFF6366F1)];
      shadowColor = const Color(0xFF8B5CF6);
    } else if (isApproved || status == 'Approved') {
      gradientColors = const [AppTheme.successGreen, Color(0xFF059669)];
      shadowColor = AppTheme.successGreen;
    } else {
      gradientColors = const [AppTheme.warningOrange, Color(0xFFE67E22)];
      shadowColor = AppTheme.warningOrange;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CLAIM ${data['claimId']}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data['status'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isApproved
                ? 'Payout has been approved and is being processed'
                : 'Your claim is being reviewed by our team',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    List<Map<String, dynamic>> stages,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 24),
          _buildProgressStepper(context, stages),
        ],
      ),
    );
  }

  Widget _buildProgressStepper(
    BuildContext context,
    List<Map<String, dynamic>> stages,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: stages.asMap().entries.map((entry) {
        final idx = entry.key;
        final stage = entry.value;
        final isComplete = stage['complete'] as bool;

        final leftLineColor = idx == 0
            ? Colors.transparent
            : (stages[idx]['complete'] as bool
                  ? AppTheme.primary
                  : AppTheme.dividerOf(context));

        final rightLineColor = idx == stages.length - 1
            ? Colors.transparent
            : ((stages[idx + 1]['complete'] as bool)
                  ? AppTheme.primary
                  : AppTheme.dividerOf(context));

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Container(height: 3, color: leftLineColor)),
                  _buildCircle(context, stage, idx),
                  Expanded(child: Container(height: 3, color: rightLineColor)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                stage['name'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isComplete
                      ? AppTheme.primary
                      : AppTheme.textHintOf(context),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                stage['time'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCircle(
    BuildContext context,
    Map<String, dynamic> stage,
    int index,
  ) {
    final isComplete = stage['complete'] as bool;
    const size = 38.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isComplete ? AppTheme.accentGradient : null,
        color: isComplete ? null : AppTheme.dividerOf(context),
        boxShadow: isComplete
            ? [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.35),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isComplete
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  color: AppTheme.textHintOf(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }

  Widget _buildPayoutCard(BuildContext context, Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.primaryGlow(0.2),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -5,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 70,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXPECTED PAYOUT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.7),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹ ${data['expectedPayout']}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              // Glassmorphic icon container
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClaimDetailsCard(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Claim Details',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Reason',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data['reason'] as String,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Description',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data['claim_description'] as String,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimaryOf(context),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(BuildContext context, Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationOf(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expected Timeline',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data['timelineText'] as String,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationPanel(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.06),
            AppTheme.primary.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppTheme.warningOrange,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.warningOrange.withOpacity(0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification In Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data['verificationMessage'] as String,
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
    );
  }
}
