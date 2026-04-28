import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class StatusTrackerScreen extends StatefulWidget {
  const StatusTrackerScreen({Key? key}) : super(key: key);

  @override
  State<StatusTrackerScreen> createState() => _StatusTrackerScreenState();
}

class _StatusTrackerScreenState extends State<StatusTrackerScreen> {
  Map<String, dynamic>? _liveData;
  bool _isLoading = true;
  String? _claimId;
  bool _invalidClaim = false;
  Timer? _pollTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && _claimId == null) {
      _claimId = args;
      _loadStatus();
    } else if (_claimId == null) {
      setState(() {
        _isLoading = false;
        _invalidClaim = true;
      });
    }
  }

  Future<void> _loadStatus() async {
    if (_claimId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final result = await ApiService().getClaimStatus(_claimId!);
      if (!mounted) return;
      setState(() {
        _liveData = result;
        _isLoading = false;
      });
      _maybeStartPolling(result['status'] as String?);
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
          action: SnackBarAction(label: 'Retry', onPressed: _loadStatus),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _buildStages(Map<String, dynamic> data) {
    final status = (data['status'] as String? ?? '').toLowerCase();
    final decidedAt = data['decided_at']?.toString() ?? '';
    final isDecided = status == 'approved' || status == 'rejected';
    final isScoring =
        status == 'processing' ||
        status == 'in review' ||
        status == 'fraud_queue' ||
        isDecided;
    final isVerifying = status == 'in review' || isDecided;

    String _fmt(String iso) {
      final dt = DateTime.tryParse(iso);
      if (dt == null) return '';
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return [
      {'name': 'SUBMITTED', 'complete': true, 'time': ''},
      {'name': 'SCORING', 'complete': isScoring, 'time': ''},
      {'name': 'REVIEW', 'complete': isVerifying, 'time': ''},
      {
        'name': 'DECISION',
        'complete': isDecided,
        'time': isDecided ? _fmt(decidedAt) : '',
      },
    ];
  }

  void _maybeStartPolling(String? status) {
    _pollTimer?.cancel();
    final s = (status ?? '').toLowerCase();
    if (s == 'processing' || s == 'in review') {
      _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _loadStatus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _liveData;
    final stages = data != null ? _buildStages(data) : <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('CONTINUUM'),
        leading: GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/profile'),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.accentGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.notifications_none_rounded,
                color: AppTheme.textSecondaryOf(context),
                size: 22,
              ),
            ),
          ),
        ],
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 40,
                            color: AppTheme.warningOrange,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Invalid claim reference. Please open status from a specific claim.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondaryOf(context),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : data == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Unable to load claim status right now.',
                        style: TextStyle(
                          color: AppTheme.textSecondaryOf(context),
                          fontSize: 14,
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
                          _buildPayoutCard(context, data),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFE67E22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CLAIM ${data['claimId'] ?? data['claim_id'] ?? '—'}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            (data['status'] as String? ?? 'Processing').toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your claim is being reviewed by our team',
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
        final isComplete = stage['complete'] as bool? ?? false;

        final leftLineColor = idx == 0
            ? Colors.transparent
            : (stages[idx]['complete'] as bool? ?? false
                  ? AppTheme.primary
                  : AppTheme.dividerOf(context));

        final rightLineColor = idx == stages.length - 1
            ? Colors.transparent
            : ((stages[idx + 1]['complete'] as bool? ?? false)
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
                stage['name'] as String? ?? '',
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
                stage['time'] as String? ?? '',
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
    final isComplete = stage['complete'] as bool? ?? false;
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
    final payout =
        data['expectedPayout'] ??
        data['estimated_payout'] ??
        data['amount'] ??
        '—';
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
                    '₹ $payout',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
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

  Widget _buildTimelineCard(BuildContext context, Map<String, dynamic> data) {
    final timeline =
        data['timelineText'] ?? data['timeline'] ?? 'Pending review';
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
                timeline.toString(),
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
    final msg =
        data['verificationMessage'] ??
        data['verification_message'] ??
        'Verification in progress';
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
                  msg.toString(),
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
