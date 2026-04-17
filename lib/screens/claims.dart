import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class ClaimsScreen extends StatefulWidget {
  const ClaimsScreen({Key? key}) : super(key: key);

  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen> {
  String _selectedFilter = 'All';
  bool _isLoading = true;
  List<Map<String, dynamic>> _liveClaims = [];

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  Future<void> _loadClaims() async {
    setState(() => _isLoading = true);
    try {
      final claims = await ApiService().getClaims();
      if (!mounted) return;
      setState(() {
        _liveClaims = claims;
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
          action: SnackBarAction(label: 'Retry', onPressed: _loadClaims),
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
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Claims',
                            style: Theme.of(context).textTheme.displayLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track and manage your claims',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 18),
                          _buildSummaryPills(),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                              boxShadow: AppTheme.primaryGlow(0.2),
                            ),
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, AppRoutes.apply),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd,
                                  ),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.note_add_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Apply New Claim',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          _buildFilterChips(),
                          const SizedBox(height: 16),
                          _buildClaimsList(context),
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

  Widget _buildSummaryPills() {
    final total = _liveClaims.length;
    final approved = _liveClaims
        .where(
          (c) => (c['status'] ?? '').toString().toLowerCase() == 'approved',
        )
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            label: 'TOTAL CLAIMS',
            value: '$total',
            icon: Icons.assignment_outlined,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            label: 'APPROVED',
            value: '$approved',
            icon: Icons.check_circle_outline,
            color: AppTheme.successGreen,
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
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textSecondaryOf(context),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'In Review', 'Approved', 'Rejected'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters
            .map(
              (filter) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedFilter = filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
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
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildClaimsList(BuildContext context) {
    final allClaims = _liveClaims;
    final filteredClaims = _selectedFilter == 'All'
        ? allClaims
        : allClaims.where((claim) {
            final status = (claim['status'] ?? '').toString().toLowerCase();
            switch (_selectedFilter) {
              case 'In Review':
                return status == 'processing' || status == 'in review';
              case 'Approved':
                return status == 'approved';
              case 'Rejected':
                return status == 'rejected';
              default:
                return true;
            }
          }).toList();

    if (filteredClaims.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: AppTheme.cardDecorationOf(context),
        child: Text(
          'No claims yet. Tap "Apply New Claim" to create one.',
          style: TextStyle(
            color: AppTheme.textSecondaryOf(context),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Column(
      children: filteredClaims.asMap().entries.map((entry) {
        int idx = entry.key;
        var claim = entry.value;
        final statusText = (claim['status'] ?? 'processing').toString();
        final statusColor = _statusColor(statusText);
        final claimId = (claim['claim_id'] ?? claim['id'] ?? 'CLAIM')
            .toString();
        final title = (claim['event_type'] ?? claim['title'] ?? 'Claim')
            .toString();
        final date =
            (claim['event_timestamp'] ??
                    claim['created_at'] ??
                    claim['date'] ??
                    '')
                .toString();
        final amount = (claim['amount'] ?? claim['estimated_payout'] ?? 0)
            .toString();
        final progress =
            (claim['progress_pct'] as num?)?.toDouble() ??
            (claim['progressPct'] as num?)?.toDouble() ??
            _statusProgress(statusText);

        return Column(
          children: [
            GestureDetector(
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.claimStatus,
                arguments: claimId,
              ),
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
                                  claimId,
                                  style: TextStyle(
                                    fontSize: 12,
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
                                  child: Text(
                                    statusText,
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
                              title,
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
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 13,
                                      color: AppTheme.textHintOf(context),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _prettyDate(date),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondaryOf(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '₹ $amount',
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
                                value: progress.clamp(0.0, 1.0),
                                minHeight: 4,
                                backgroundColor: statusColor.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (idx < (filteredClaims.length - 1)) const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppTheme.successGreen;
      case 'rejected':
        return AppTheme.dangerRed;
      default:
        return AppTheme.warningOrange;
    }
  }

  double _statusProgress(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'rejected':
        return 1.0;
      case 'processing':
      case 'in review':
        return 0.6;
      default:
        return 0.3;
    }
  }

  String _prettyDate(String raw) {
    if (raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }
}
