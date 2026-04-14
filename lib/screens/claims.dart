import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../state/demo_state.dart';
import 'claim_detail_sheet.dart';

class ClaimsScreen extends StatefulWidget {
  const ClaimsScreen({Key? key}) : super(key: key);

  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen> {
  String _selectedFilter = 'All';

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    DemoState.instance.addListener(_onDemoStateChanged);
  }

  @override
  void dispose() {
    DemoState.instance.removeListener(_onDemoStateChanged);
    super.dispose();
  }

  void _onDemoStateChanged() {
    if (mounted) setState(() {});
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _allClaims {
    final base = List<Map<String, dynamic>>.from(
      MockData.claims as List<Map<String, dynamic>>,
    );
    return [
      ...DemoState.instance.autoClaims,
      ...DemoState.instance.manualClaims,
      ...base
    ];
  }

  int get _totalClaimsCount => _allClaims.length;

  int get _autoApprovedCount =>
      _allClaims.where((c) => c['isAuto'] == true || c['status'] == 'Auto-Approved').length;

  int get _pendingCount =>
      _allClaims.where((c) => c['status'] == 'Under Review' || c['status'] == 'In Review').length;

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CONTINUUM'),
        leading: GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
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
              Text('My Claims',
                  style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 4),
              Text('Track and manage your claims',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
              _buildSummaryPills(),
              const SizedBox(height: 20),
              _buildFilterChips(),
              const SizedBox(height: 16),
              _buildClaimsList(context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.apply);
        },
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ── Summary pills ──────────────────────────────────────────────────────────
  Widget _buildSummaryPills() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            label: 'TOTAL\nCLAIMS',
            value: '$_totalClaimsCount',
            icon: Icons.assignment_outlined,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            label: 'AUTO\nAPPROVE',
            value: '$_autoApprovedCount',
            icon: Icons.bolt_rounded,
            color: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            label: 'PENDING\nREVIEW',
            value: '$_pendingCount',
            icon: Icons.pending_actions,
            color: AppTheme.warningOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textSecondaryOf(context),
                            letterSpacing: 0.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              value,
                              key: ValueKey(value),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter chips ───────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    final filters = ['All', 'Manual', 'Auto'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters
            .map((filter) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedFilter == filter
                            ? AppTheme.primary
                            : AppTheme.cardOf(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _selectedFilter == filter
                              ? AppTheme.primary
                              : AppTheme.dividerOf(context),
                          width: 1.5,
                        ),
                        boxShadow: _selectedFilter == filter
                            ? AppTheme.primaryGlow(0.15)
                            : null,
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: _selectedFilter == filter
                              ? Colors.white
                              : AppTheme.textSecondaryOf(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Claims list ────────────────────────────────────────────────────────────
  Widget _buildClaimsList(BuildContext context) {
    final all = _allClaims;

    final filtered = _selectedFilter == 'All'
        ? all
        : all.where((c) {
            final isAuto = c['isAuto'] == true;
            if (_selectedFilter == 'Auto') {
              return isAuto;
            }
            if (_selectedFilter == 'Manual') {
              return !isAuto;
            }
            return true;
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'No claims found',
            style: TextStyle(color: AppTheme.textHintOf(context)),
          ),
        ),
      );
    }

    return Column(
      children: filtered.asMap().entries.map((entry) {
        final idx = entry.key;
        final claim = entry.value;
        final isAuto = claim['isAuto'] == true;

        return Column(
          children: [
            isAuto
                ? _buildAutoClaimCard(claim, context)
                : _buildRegularClaimCard(claim, context),
            if (idx < filtered.length - 1) const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  // ── Regular claim card (existing style) ───────────────────────────────────
  Widget _buildRegularClaimCard(
      Map<String, dynamic> claim, BuildContext context) {
    final statusColor = claim['statusColor'] as Color;
    return GestureDetector(
      onTap: () => ClaimDetailSheet.show(context, claim),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.softShadowOf(context),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: statusColor),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          claim['id'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textHintOf(context),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            claim['status'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      claim['title'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 13,
                                color: AppTheme.textHintOf(context)),
                            const SizedBox(width: 4),
                            Text(
                              claim['date'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '₹ ${claim['amount']}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: claim['progressPct'] as double,
                        minHeight: 4,
                        backgroundColor: statusColor.withOpacity(0.1),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(statusColor),
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

  // ── Auto-approved claim card (distinct style) ──────────────────────────────
  Widget _buildAutoClaimCard(
      Map<String, dynamic> claim, BuildContext context) {
    const badgeColor = Color(0xFF6366F1); // indigo/purple — distinct from others
    return GestureDetector(
      onTap: () => ClaimDetailSheet.show(context, claim),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.softShadowOf(context),
          border: Border.all(
            color: badgeColor.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Stack(
            children: [
              // Left accent — indigo
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: badgeColor),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          claim['id'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textHintOf(context),
                          ),
                        ),
                        const Spacer(),
                        // Auto-Approved badge with lightning bolt
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded,
                                  color: badgeColor, size: 13),
                              SizedBox(width: 3),
                              Text(
                                'Auto-Approved',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: badgeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      claim['title'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Zero-touch tag
                    Row(
                      children: [
                        Icon(Icons.touch_app_rounded,
                            size: 13,
                            color: badgeColor.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(
                          'Zero-touch — no action required',
                          style: TextStyle(
                            fontSize: 11,
                            color: badgeColor.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 13,
                                color: AppTheme.textHintOf(context)),
                            const SizedBox(width: 4),
                            Text(
                              claim['date'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '₹ ${claim['amount']}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // UPI reference
                    if (claim['upiRef'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                size: 12,
                                color: badgeColor.withOpacity(0.7)),
                            const SizedBox(width: 6),
                            Text(
                              claim['upiRef'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: badgeColor.withOpacity(0.8),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    // Full progress bar (completed)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: const LinearProgressIndicator(
                        value: 1.0,
                        minHeight: 4,
                        backgroundColor: Color(0x1A6366F1),
                        valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
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
