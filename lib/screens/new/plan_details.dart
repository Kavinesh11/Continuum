import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/demo_backend.dart';
import '../../theme/app_theme.dart';

class PlanDetailsScreen extends StatefulWidget {
  const PlanDetailsScreen({Key? key}) : super(key: key);

  @override
  State<PlanDetailsScreen> createState() => _PlanDetailsScreenState();
}

class _PlanDetailsScreenState extends State<PlanDetailsScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _content;
  bool _isLoading = true;
  late AnimationController _slideController;
  late Animation<double> _slideAnim;

  static const _sectionIcons = {
    'Coverage': Icons.shield_outlined,
    'Eligibility': Icons.verified_user_outlined,
    'Claim Process': Icons.description_outlined,
    'Payouts': Icons.account_balance_wallet_outlined,
    'Exclusions': Icons.block_outlined,
    'Renewal': Icons.autorenew_rounded,
  };

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _slideAnim = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );
    _loadContent();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    try {
      final content = await ApiService().getPolicyContent();
      if (!mounted) return;
      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = DemoBackend.instance.activeDriver;
    final hero = (_content?['hero'] as Map?)?.cast<String, dynamic>() ?? {};
    final sections = (_content?['sections'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    return Scaffold(
      appBar: AppBar(title: const Text('Policy Details')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedBuilder(
              animation: _slideAnim,
              builder: (context, child) => Opacity(
                opacity: _slideAnim.value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - _slideAnim.value)),
                  child: child,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(driver, hero),
                    const SizedBox(height: 24),
                    ...sections.asMap().entries.map((e) {
                      final i = e.key;
                      final s = e.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildSection(
                          context,
                          number: i + 1,
                          title: s['title'] as String? ?? '',
                          icon: _sectionIcons[s['title']] ?? Icons.info_outline,
                          body: s['body'] as String? ?? '',
                          delay: i * 80,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeroCard(dynamic driver, Map<String, dynamic> hero) {
    final badge = hero['badge'] as String? ?? '${driver.tier} TIER';
    final title = hero['title'] as String? ?? '${driver.tier} Shield Plan';
    final subtitle = hero['subtitle'] as String? ?? 'Coverage active in ${driver.zone}';

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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.75),
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
    int delay = 0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) =>
          Opacity(opacity: v, child: Transform.translate(offset: Offset(20 * (1 - v), 0), child: child)),
      child: Container(
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
                        Icon(icon, size: 15, color: AppTheme.primary),
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
      ),
    );
  }
}
