import 'dart:ui';
import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';

class StatusTrackerScreen extends StatelessWidget {
  const StatusTrackerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final claimId = args?['id'] as String? ?? MockData.claimStatusDetail['claimId'] as String;
    final status = args?['status'] as String? ?? MockData.claimStatusDetail['status'] as String;
    final amount = args?['amount']?.toString() ?? MockData.claimStatusDetail['expectedPayout'].toString();
    
    final isAuto = args?['isAuto'] == true;
    final isApproved = isAuto || status == 'Approved' || status == 'Auto-Approved';
    
    final stages = args == null
        ? MockData.claimStatusDetail['stages'] as List<Map<String, dynamic>>
        : [
            {'name': 'SUBMITTED', 'time': 'Completed', 'complete': true},
            {
              'name': 'REVIEW',
              'time': isAuto ? 'Auto' : 'In Progress',
              'complete': isApproved
            },
            {
              'name': 'APPROVED',
              'time': isAuto ? 'Auto' : (isApproved ? 'Done' : 'Pending'),
              'complete': isApproved
            },
            {
              'name': 'PAYOUT',
              'time': isAuto ? 'Completed' : 'Pending',
              'complete': isAuto
            },
          ];

    final timelineText = isAuto ? 'Within 2 hours' : '2-3 business days';
    final verificationMessage = isApproved
        ? 'Verification complete'
        : 'We are verifying your details';

    final data = {
      'claimId': claimId,
      'status': status,
      'isAuto': isAuto,
      'isApproved': isApproved,
      'expectedPayout': amount,
      'timelineText': timelineText,
      'verificationMessage': verificationMessage,
    };

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
              icon: Icon(Icons.notifications_none_rounded,
                  color: AppTheme.textSecondaryOf(context), size: 22),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
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
    );
  }

  Widget _buildStatusHeader(
      BuildContext context, Map<String, dynamic> data) {
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
      BuildContext context, List<Map<String, dynamic>> stages) {
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
      BuildContext context, List<Map<String, dynamic>> stages) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: stages.asMap().entries.map((entry) {
        final idx = entry.key;
        final stage = entry.value;
        final isComplete = stage['complete'] as bool;
        
        final leftLineColor = idx == 0 
           ? Colors.transparent 
           : (stages[idx]['complete'] as bool ? AppTheme.primary : AppTheme.dividerOf(context));
        
        final rightLineColor = idx == stages.length - 1
           ? Colors.transparent
           : ((stages[idx + 1]['complete'] as bool) ? AppTheme.primary : AppTheme.dividerOf(context));

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 3,
                      color: leftLineColor,
                    ),
                  ),
                  _buildCircle(context, stage, idx),
                  Expanded(
                    child: Container(
                      height: 3,
                      color: rightLineColor,
                    ),
                  ),
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
      BuildContext context, Map<String, dynamic> stage, int index) {
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
            ? const Icon(Icons.check_rounded,
                color: Colors.white, size: 18)
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

  Widget _buildPayoutCard(
      BuildContext context, Map<String, dynamic> data) {
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
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: const Icon(Icons.trending_up_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(
      BuildContext context, Map<String, dynamic> data) {
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
            child: const Icon(Icons.access_time_rounded,
                color: AppTheme.primary, size: 20),
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
      BuildContext context, Map<String, dynamic> data) {
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
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.1),
        ),
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
