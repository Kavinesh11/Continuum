import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data & Privacy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _buildSectionHeader(context, Icons.database_outlined, 'What We Collect'),
          const SizedBox(height: 12),
          _buildDataCard(context, [
            _DataItem(
              icon: Icons.location_on_outlined,
              title: 'GPS Location',
              detail: 'Retained for 90 days. Used only to verify you were in an active disruption zone when a claim is triggered.',
            ),
            _DataItem(
              icon: Icons.payment_rounded,
              title: 'Payment History',
              detail: 'Premium debits and payout credits retained for 2 years. Required for tax receipts and financial audits.',
            ),
            _DataItem(
              icon: Icons.assignment_outlined,
              title: 'Claims',
              detail: 'Claim records retained indefinitely as part of your insurance policy history. IRDAI regulations require this.',
            ),
            _DataItem(
              icon: Icons.phone_android_outlined,
              title: 'Device & KYC',
              detail: 'Device fingerprint and Aadhaar hash (one-way encrypted) retained for fraud prevention. Raw Aadhaar number is never stored.',
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader(context, Icons.analytics_outlined, 'How We Use It'),
          const SizedBox(height: 12),
          _buildDataCard(context, [
            _DataItem(
              icon: Icons.location_searching_rounded,
              title: 'Oracle Zone Verification',
              detail: 'GPS confirms you were in the disruption zone when a payout is triggered. We never sell location data.',
            ),
            _DataItem(
              icon: Icons.security_rounded,
              title: 'Fraud Detection',
              detail: 'An AI isolation-forest model analyses claim patterns. Your data is never shared with other insurers.',
            ),
            _DataItem(
              icon: Icons.calculate_outlined,
              title: 'Actuarial Pricing',
              detail: 'Order completion rate and zone risk history adjust your weekly premium dynamically. No manual underwriting.',
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader(context, Icons.verified_user_outlined, 'Your Rights'),
          const SizedBox(height: 12),
          _buildDataCard(context, [
            _DataItem(
              icon: Icons.download_outlined,
              title: 'Download Your Data',
              detail: 'Request a copy of all data Continuum holds on you.',
              action: _ContactAction(label: 'Request export', email: 'privacy@continuum.in'),
            ),
            _DataItem(
              icon: Icons.delete_outline_rounded,
              title: 'Delete Your Account',
              detail: 'Close your account and request deletion of non-legally-required data. We retain financial records as required by IRDAI for 7 years.',
              action: _ContactAction(label: 'Request deletion', email: 'privacy@continuum.in'),
            ),
            _DataItem(
              icon: Icons.toggle_on_outlined,
              title: 'Consent Management',
              detail: 'Your DPDP Act consent receipt is on file. To withdraw consent for GPS tracking, contact us — note this will suspend claim eligibility.',
              action: _ContactAction(label: 'Manage consent', email: 'privacy@continuum.in'),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader(context, Icons.gavel_outlined, 'Regulatory & Compliance'),
          const SizedBox(height: 12),
          _buildInfoCard(context, [
            _InfoRow(
              label: 'IRDAI Registration',
              value: 'IRDAI/HLT/MISC/2026/001 (Demo)',
            ),
            _InfoRow(
              label: 'Product Type',
              value: 'Parametric Income-Loss Insurance',
            ),
            _InfoRow(
              label: 'Applicable Law',
              value: 'Insurance Act, 1938 · IRDAI Regulations',
            ),
            _InfoRow(
              label: 'Data Protection',
              value: 'Digital Personal Data Protection Act, 2023',
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader(context, Icons.support_agent_rounded, 'Grievance Contact'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warningOrange.withOpacity(0.06),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.warningOrange.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grievance Redressal Officer',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                _GrievanceRow(icon: Icons.person_outline_rounded, text: 'Arjun Sharma, Chief Compliance Officer'),
                const SizedBox(height: 6),
                _GrievanceRow(icon: Icons.email_outlined, text: 'grievance@continuum.in'),
                const SizedBox(height: 6),
                _GrievanceRow(icon: Icons.access_time_rounded, text: 'Response within 15 business days (IRDAI mandate)'),
                const SizedBox(height: 10),
                Text(
                  'If unresolved, escalate to IRDAI Consumer Affairs at igms.irda.gov.in',
                  style: TextStyle(
                    fontSize: 11, color: AppTheme.textSecondaryOf(context), height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Last updated: April 2026 · Version 2.1',
            style: TextStyle(
              fontSize: 11, color: AppTheme.textHintOf(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }

  Widget _buildDataCard(BuildContext context, List<_DataItem> items) {
    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        children: items.asMap().entries.map((e) {
          final item = e.value;
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, color: AppTheme.primary, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.detail,
                            style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondaryOf(context), height: 1.4,
                            ),
                          ),
                          if (item.action != null) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {}, // mailto: would open here in real app
                              child: Text(
                                item.action!.label,
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) Divider(height: 1, color: AppTheme.dividerOf(context)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<_InfoRow> rows) {
    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final row = e.value;
          final isLast = e.key == rows.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        row.label,
                        style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondaryOf(context), fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        row.value,
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) Divider(height: 1, color: AppTheme.dividerOf(context)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DataItem {
  final IconData icon;
  final String title;
  final String detail;
  final _ContactAction? action;
  const _DataItem({required this.icon, required this.title, required this.detail, this.action});
}

class _ContactAction {
  final String label;
  final String email;
  const _ContactAction({required this.label, required this.email});
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
}

class _GrievanceRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _GrievanceRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.warningOrange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryOf(context)),
          ),
        ),
      ],
    );
  }
}
