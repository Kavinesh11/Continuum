import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PlanDetailsScreen extends StatelessWidget {
  const PlanDetailsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CONTINUUM'),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
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
              _buildHeroCard(),
              const SizedBox(height: 24),
              _buildSection(
                context,
                number: 1,
                title: 'Coverage',
                icon: Icons.shield_outlined,
                body:
                    'This plan covers income loss due to weather disruptions, '
                    'platform app outages, and verified accidents during active '
                    'delivery shifts.',
              ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                number: 2,
                title: 'Eligibility',
                icon: Icons.verified_user_outlined,
                body:
                    'Active gig workers on supported platforms (Swiggy, Zomato, etc.) '
                    'who have completed at least 30 days on the platform.',
              ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                number: 3,
                title: 'Claim Process',
                icon: Icons.description_outlined,
                body:
                    'File a claim within 48 hours of the incident. '
                    'Provide live photo evidence and a brief description. '
                    'Claims are reviewed within 2-3 business days.',
              ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                number: 4,
                title: 'Payouts',
                icon: Icons.account_balance_wallet_outlined,
                body:
                    'Approved payouts are disbursed to your linked UPI or bank '
                    'account within 1 business day after approval.',
              ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                number: 5,
                title: 'Exclusions',
                icon: Icons.block_outlined,
                body:
                    'Claims for incidents outside active shift hours, '
                    'self-inflicted damage, or fraudulent submissions '
                    'are not covered.',
              ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                number: 6,
                title: 'Renewal',
                icon: Icons.autorenew_rounded,
                body:
                    'Plan auto-renews weekly. You can cancel anytime '
                    'from Profile → Payments & Subscription.',
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.primaryGlow(0.25),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -6,
            child: Icon(
              Icons.policy_rounded,
              size: 90,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'COMPREHENSIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Gig Worker Protection Plan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete coverage for disruptions, outages, and accidents on platform.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required int number,
    required String title,
    required IconData icon,
    required String body,
  }) {
    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  number.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryOf(context),
                      height: 1.5,
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
}
