import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class PolicyScreen extends StatefulWidget {
  const PolicyScreen({Key? key}) : super(key: key);

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _content;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    try {
      final content = await ApiService().getPolicyContent();
      if (!mounted) return;
      setState(() {
        _content = content;
        _isLoading = false;
      });
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
          action: SnackBarAction(label: 'Retry', onPressed: _loadPolicy),
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
  Widget build(BuildContext context) {
    final hero = (_content?['hero'] as Map<String, dynamic>?) ?? const {};
    final sections = (_content?['sections'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(hero),
                    const SizedBox(height: 24),
                    ...sections.asMap().entries.map(
                      (entry) => Padding(
                        padding: EdgeInsets.only(
                          bottom: entry.key == sections.length - 1 ? 0 : 16,
                        ),
                        child: _buildSection(
                          context,
                          number: entry.key + 1,
                          title: (entry.value['title'] ?? 'Section').toString(),
                          icon: _iconFor(entry.value['icon_key']?.toString()),
                          body: (entry.value['body'] ?? '').toString(),
                        ),
                      ),
                    ),
                    if (sections.isEmpty)
                      _buildSection(
                        context,
                        number: 1,
                        title: 'Coverage',
                        icon: Icons.shield_outlined,
                        body: 'Policy content is currently unavailable.',
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeroCard(Map<String, dynamic> hero) {
    final badge = (hero['badge'] ?? 'COMPREHENSIVE').toString();
    final title = (hero['title'] ?? 'Gig Worker Protection Plan').toString();
    final subtitle = (hero['subtitle'] ?? 'Coverage details').toString();

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
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
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

  IconData _iconFor(String? iconKey) {
    switch (iconKey) {
      case 'coverage':
        return Icons.shield_outlined;
      case 'eligibility':
        return Icons.verified_user_outlined;
      case 'claim_process':
        return Icons.description_outlined;
      case 'payouts':
        return Icons.account_balance_wallet_outlined;
      case 'exclusions':
        return Icons.block_outlined;
      case 'renewal':
        return Icons.autorenew_rounded;
      default:
        return Icons.article_outlined;
    }
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
