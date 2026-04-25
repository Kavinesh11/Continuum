import 'dart:ui';
import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../sandbox/driver_provider.dart';
import '../../state/notification_state.dart';
import '../../theme/app_theme.dart';
import '../../main.dart';
import '../../services/api_service.dart';
import '../../state/demo_orchestrator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _workerData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final result = await ApiService().getWorkerProfileCurrent();
      if (!mounted) return;
      setState(() {
        _workerData = result;
      });
    } on ServerException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Service temporarily unavailable. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'Retry', onPressed: _loadProfile),
        ),
      );
    } catch (_) {
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyRaw =
        (_workerData?['recent_claims'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();

    final name =
        (_workerData?['full_name'] ?? _workerData?['name'] ?? 'Partner')
            .toString();
    final initials = name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join()
        .toUpperCase();
    final city = (_workerData?['city'] ?? 'Unknown').toString();
    final phone = (_workerData?['phone'] ?? '--').toString();
    final platform = (_workerData?['platform'] ?? 'Unknown').toString();
    final zone = (_workerData?['zone_id'] ?? 'Unknown').toString();
    final tier = (_workerData?['tier'] ?? 'Standard').toString();
    final memberSince = (_workerData?['registered_at'] ?? 'N/A').toString();
    final totalProtected =
        (_workerData?['total_protected_amount'] ?? 0).toString();
    final claimsApproved =
        (_workerData?['claims_approved_count'] as num?)?.toInt() ?? 0;
    final emergencyContact =
        (_workerData?['emergency_contact'] ?? '--').toString();
    final history = historyRaw
        .map(
          (h) => {
            'incident': (h['event_type'] ?? 'Claim').toString(),
            'date': (h['submitted_at'] ?? 'Recent').toString(),
            'detail': (h['status'] ?? 'Pending').toString(),
          },
        )
        .toList();

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGradientHeader(
                    context,
                    name,
                    initials.isEmpty ? 'NA' : initials,
                    'Delivery Partner',
                    city,
                    memberSince,
                    tier,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsPills(
                          context,
                          '₹ $totalProtected',
                          claimsApproved,
                        ),
                        const SizedBox(height: 24),
                        _buildPersonalData(
                          context,
                          phone,
                          platform,
                          emergencyContact,
                          zone,
                        ),
                        const SizedBox(height: 24),
                        _buildQuickLinks(context),
                        const SizedBox(height: 24),
                        _buildHistorySection(context, history),
                        const SizedBox(height: 24),
                        _buildSignOutButton(context),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientHeader(
    BuildContext context,
    String name,
    String initials,
    String role,
    String city,
    String since,
    String tier,
  ) {
    return GestureDetector(
      onLongPress: () => DemoOrchestrator.instance.resetAll(),
      child: Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        24,
      ),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: AppTheme.primaryGlow(0.2),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const Text(
                        'Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                        child: Text(
                          '$tier Shield',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Notification bell
                      AnimatedBuilder(
                        animation: NotificationState.instance,
                        builder: (ctx, _) {
                          final provider = ctx.dependOnInheritedWidgetOfExactType<DriverProvider>();
                          final partnerId = provider?.driver.partnerId ?? 'current_worker';
                          final count = NotificationState.instance.notificationsFor(partnerId).length;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
                                onLongPress: () => DemoOrchestrator.instance.seedDemoNotifications(),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                                      ),
                                      child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ),
                              if (count > 0)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(color: AppTheme.dangerRed, shape: BoxShape.circle),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      // Edit button
                      GestureDetector(
                        onTap: () async {
                          await Navigator.pushNamed(context, AppRoutes.editProfile);
                          if (!mounted) return;
                          _loadProfile();
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  GestureDetector(
                    onLongPress: () => DemoOrchestrator.instance.fraudQueueEscalation(),
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$role • $city',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.18),
                                ),
                              ),
                              child: Text(
                                'Since $since',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),  // end GestureDetector (long-press header → resetAll)
    );
  }

  Widget _buildStatsPills(
    BuildContext context,
    String totalProtected,
    int claimsApproved,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coverage & Claims',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(
              label: 'Total Protected',
              value: totalProtected,
              icon: Icons.shield_outlined,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 12),
            _StatCard(
              label: 'Claims Approved',
              value: '$claimsApproved',
              icon: Icons.check_circle_outline,
              color: AppTheme.successGreen,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPersonalData(
    BuildContext context,
    String phone,
    String platform,
    String emergency,
    String zone,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Data',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 12),
        _buildDataRow(context, Icons.phone_outlined, 'Phone', phone),
        const SizedBox(height: 8),
        _buildDataRow(
          context,
          Icons.delivery_dining_outlined,
          'Platform',
          platform,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onLongPress: () => DemoOrchestrator.instance.zoneEnrollmentLock(),
          child: _buildDataRow(context, Icons.location_on_outlined, 'Zone', zone),
        ),
        const SizedBox(height: 8),
        _buildDataRow(
          context,
          Icons.emergency_outlined,
          'Emergency Contact',
          emergency,
        ),
      ],
    );
  }

  Widget _buildDataRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecorationOf(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinks(BuildContext context) {
    final themeProvider = ContinuumApp.themeProviderOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 12),

        // ── Payments row ──
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.payments),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.cardDecorationOf(context),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.payment_rounded,
                    color: Color(0xFF6366F1),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Payments & Subscription',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textHintOf(context),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── Edit Profile row ──
        GestureDetector(
          onTap: () async {
            await Navigator.pushNamed(context, AppRoutes.editProfile);
            if (!mounted) return;
            _loadProfile();
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.cardDecorationOf(context),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textHintOf(context),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── My Policy row ──
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.planDetails),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.cardDecorationOf(context),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Policy Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textHintOf(context),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── Dark Mode toggle ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.cardDecorationOf(context),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  themeProvider.isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: AppTheme.warningOrange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dark Mode',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    Text(
                      themeProvider.isDark ? 'On' : 'Off',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: themeProvider.isDark,
                onChanged: (_) => themeProvider.toggleTheme(),
                activeColor: AppTheme.primary,
                activeTrackColor: AppTheme.primary.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection(BuildContext context, List history) {
    if (history.isEmpty) return const SizedBox.shrink();
    final recent = history[0] as Map<String, dynamic>;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'View all',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecorationOf(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 4, color: AppTheme.successGreen),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              recent['incident'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.successGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Approved',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.successGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: AppTheme.textHintOf(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            recent['date'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recent['detail'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryOf(context),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.dangerRed.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: OutlinedButton(
          onPressed: () =>
              Navigator.pushReplacementNamed(context, AppRoutes.login),
          style: OutlinedButton.styleFrom(
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            backgroundColor: AppTheme.dangerRed.withOpacity(0.04),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: AppTheme.dangerRed, size: 18),
              SizedBox(width: 8),
              Text(
                'Sign Out',
                style: TextStyle(
                  color: AppTheme.dangerRed,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: AppTheme.cardDecorationOf(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.3)],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 14, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondaryOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryOf(context),
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

// class _DataRow extends StatelessWidget {
//   final String label;
//   final String value;
//   const _DataRow({required this.label, required this.value});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.black.withOpacity(0.05)),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: const TextStyle(fontSize: 13, color: Colors.black54),
//           ),
//           Text(
//             value,
//             style: const TextStyle(
//               fontSize: 13,
//               fontWeight: FontWeight.bold,
//               color: Colors.black87,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
