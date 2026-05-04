import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'apply_form.dart';

class ClaimDetailSheet extends StatelessWidget {
  final Map<String, dynamic> claim;

  const ClaimDetailSheet({Key? key, required this.claim}) : super(key: key);

  static void show(BuildContext context, Map<String, dynamic> claim) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClaimDetailSheet(claim: claim),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAuto = claim['isAuto'] == true;
    final Color statusColor = claim['statusColor'] ?? AppTheme.primary;
    final String status = claim['status'] ?? 'Unknown';
    final String title = claim['title'] ?? 'Claim';
    final String desc =
        claim['claim_description'] ?? 'No description available';
    final String id = claim['id'] ?? 'CLM/XXXXXX';
    final amount = claim['amount'] ?? 0;
    final String? upiRef = claim['upiRef'];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  id,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textHintOf(context),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      if (isAuto || status == 'Approved')
                        Icon(
                          isAuto
                              ? Icons.bolt_rounded
                              : Icons.check_circle_outline,
                          color: statusColor,
                          size: 14,
                        ),
                      if (isAuto || status == 'Approved')
                        const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              desc,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Timeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildTimeline(
              status, isAuto, statusColor, context,
              claim['date']?.toString() ?? 'Recent',
            ),
          ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.05)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status == 'Approved'
                          ? 'Payout Amount'
                          : 'Expected Payout',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (upiRef != null)
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 12,
                            color: statusColor.withOpacity(0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            upiRef,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              color: statusColor.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Text(
                  amount > 0 ? '₹ $amount' : 'Determining...',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Edit button area
          if (!isAuto && status == 'Under Review') ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ApplyFormScreen(existingClaim: claim),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit Claim'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildTimeline(
    String status,
    bool isAuto,
    Color statusColor,
    BuildContext context,
    String date,
  ) {
    if (isAuto) {
      return Column(
        children: [
          _buildTimelineStep(
            'Submitted',
            '$date, 2:30 PM',
            true,
            AppTheme.successGreen,
            context,
          ),
          _buildTimelineStep(
            'Processed via Oracle',
            '$date, 2:31 PM',
            true,
            AppTheme.successGreen,
            context,
          ),
          _buildTimelineStep(
            'Approved',
            '$date, 2:32 PM',
            true,
            AppTheme.successGreen,
            context,
            isLast: true,
          ),
        ],
      );
    } else if (status == 'Approved') {
      return Column(
        children: [
          _buildTimelineStep(
            'Submitted',
            date,
            true,
            AppTheme.successGreen,
            context,
          ),
          _buildTimelineStep(
            'Review Completed',
            '$date, 5:30 PM',
            true,
            AppTheme.successGreen,
            context,
          ),
          _buildTimelineStep(
            'Approved',
            '$date, 5:30 PM',
            true,
            AppTheme.successGreen,
            context,
            isLast: true,
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildTimelineStep(
            'Submitted',
            date,
            true,
            AppTheme.primary,
            context,
          ),
          _buildTimelineStep(
            'In Review',
            'Expected within 24h',
            false,
            AppTheme.warningOrange,
            context,
          ),
          _buildTimelineStep(
            'Approved',
            'Pending',
            false,
            AppTheme.dividerOf(context),
            context,
            isLast: true,
          ),
        ],
      );
    }
  }

  Widget _buildTimelineStep(
    String title,
    String subtitle,
    bool isCompleted,
    Color color,
    BuildContext context, {
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? color : Colors.transparent,
                border: Border.all(
                  color: isCompleted ? color : color,
                  width: 2,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: isCompleted ? color : AppTheme.dividerOf(context),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isCompleted
                      ? AppTheme.textPrimaryOf(context)
                      : AppTheme.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textHintOf(context),
                ),
              ),
              if (!isLast) const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}
