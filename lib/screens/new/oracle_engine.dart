import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../state/demo_orchestrator.dart';
import '../../state/demo_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notification_action.dart';

class OracleEngineScreen extends StatefulWidget {
  const OracleEngineScreen({Key? key}) : super(key: key);

  @override
  State<OracleEngineScreen> createState() => _OracleEngineScreenState();
}

class _OracleEngineScreenState extends State<OracleEngineScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  Timer? _refresh;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    DemoState.instance.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    DemoState.instance.removeListener(_reload);
    _refresh?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _reload() => _load();

  Future<void> _load() async {
    try {
      final data = await ApiService().getOracleStatus();
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oracle Network'),
        actions: [const NotificationAction()],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Unable to load oracle status'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildConsensusCard(context),
                        const SizedBox(height: 12),
                        _buildInfoBanner(context),
                        const SizedBox(height: 20),
                        Text(
                          'Oracle Sources',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        _buildOracleGrid(context),
                        const SizedBox(height: 24),
                        Text(
                          'Auto-Triggered Events',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        _buildEventsFeed(context),
                        const SizedBox(height: 24),
                        _buildForecastCard(context),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildConsensusCard(BuildContext context) {
    final reached = _data!['consensus_reached'] as bool? ?? false;
    final oracles = (_data!['oracles'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final alertCount =
        oracles.where((o) => o['status'] == 'Alert').length;
    final threshold = 3;
    final progress = (alertCount / oracles.length).clamp(0.0, 1.0);

    return GestureDetector(
      onLongPress: () => DemoOrchestrator.instance.floodAlert(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: reached
              ? const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.08),
                    AppTheme.primary.withOpacity(0.03),
                  ],
                ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: reached
                ? const Color(0xFF8B5CF6).withOpacity(0.4)
                : AppTheme.primary.withOpacity(0.15),
          ),
          boxShadow: reached
              ? [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : AppTheme.softShadowOf(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reached
                          ? Colors.white.withOpacity(0.5 + _pulse.value * 0.5)
                          : AppTheme.successGreen
                              .withOpacity(0.5 + _pulse.value * 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  reached ? 'CONSENSUS REACHED' : 'MONITORING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: reached
                        ? Colors.white.withOpacity(0.8)
                        : AppTheme.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              reached
                  ? 'Oracle consensus triggered'
                  : 'Waiting for oracle consensus',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: reached
                    ? Colors.white
                    : AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              reached
                  ? 'Auto-claim evaluation in progress'
                  : 'Requires $threshold of ${oracles.length} oracles to confirm',
              style: TextStyle(
                fontSize: 12,
                color: reached
                    ? Colors.white.withOpacity(0.7)
                    : AppTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 16),
            // Consensus stepper
            Row(
              children: List.generate(oracles.length, (i) {
                final confirmed = i < alertCount;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < oracles.length - 1 ? 6 : 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 6,
                      decoration: BoxDecoration(
                        color: confirmed
                            ? (reached ? Colors.white : AppTheme.primary)
                            : (reached
                                ? Colors.white.withOpacity(0.25)
                                : AppTheme.dividerOf(context)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              '$alertCount of ${oracles.length} oracles confirming',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: reached
                    ? Colors.white.withOpacity(0.7)
                    : AppTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Last consensus: ${_data!['last_consensus'] ?? 'N/A'}',
              style: TextStyle(
                fontSize: 10,
                color: reached
                    ? Colors.white.withOpacity(0.5)
                    : AppTheme.textHintOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOracleGrid(BuildContext context) {
    final oracles = (_data!['oracles'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return Column(
      children: oracles.map((oracle) => _buildOracleCard(context, oracle)).toList(),
    );
  }

  Widget _buildOracleCard(BuildContext context, Map<String, dynamic> oracle) {
    final name = oracle['name'] as String? ?? '';
    final type = oracle['type'] as String? ?? '';
    final status = oracle['status'] as String? ?? 'Nominal';
    final reading = oracle['reading'] as String? ?? '';
    final confidence = (oracle['confidence'] as num?)?.toDouble() ?? 0.0;
    final isAlert = status == 'Alert';
    final statusColor =
        isAlert ? AppTheme.dangerRed : AppTheme.successGreen;
    final icon = _oracleIcon(oracle['icon_key'] as String? ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAlert
              ? AppTheme.dangerRed.withOpacity(0.2)
              : AppTheme.dividerOf(context),
        ),
        boxShadow: AppTheme.softShadowOf(context),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  type,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textHintOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  reading,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: confidence,
                          backgroundColor: AppTheme.dividerOf(context),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(statusColor),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(confidence * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsFeed(BuildContext context) {
    final events = (_data!['auto_events'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.dividerOf(context)),
        ),
        child: Center(
          child: Text(
            'No auto-triggered events yet',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ),
      );
    }

    return Column(
      children: events.map((event) {
        final title =
            (event['eventType'] ?? event['reason'] ?? 'Auto-claim').toString();
        final amount = (event['amount'] as num?)?.toDouble() ?? 0;
        final date = (event['date'] ?? '').toString();
        final upiRef = event['upiRef'] as String?;

        return GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (ctx) => _EventDetailSheet(
                title: title,
                amount: amount,
                date: date,
                upiRef: upiRef,
              ),
            );
          },
          child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardOf(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
            ),
            boxShadow: AppTheme.softShadowOf(context),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    if (upiRef != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        upiRef,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textHintOf(context),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textHintOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${amount.toInt()}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  Text(
                    'Auto-approved',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppTheme.textHintOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Continuum uses 5 independent data sources to verify disruptions. '
              'A payout triggers when 3 or more sources confirm the same event in your zone.',
              style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondaryOf(context), height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningOrange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.warningOrange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wb_cloudy_outlined, color: AppTheme.warningOrange, size: 18),
              const SizedBox(width: 8),
              Text(
                'Next 24 Hours Forecast',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Thunderstorm 70% likely by 4 PM in your zone (IMD forecast)',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '→ Auto-payout possible: ₹200–400 if oracle consensus reached',
            style: TextStyle(
              fontSize: 12, color: AppTheme.textSecondaryOf(context), height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                      'You\'ll be notified when oracle consensus is reached.'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warningOrange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.warningOrange.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded,
                      size: 14, color: AppTheme.warningOrange),
                  const SizedBox(width: 6),
                  Text(
                    'Notify me when confirmed',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppTheme.warningOrange,
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

  IconData _oracleIcon(String key) {
    switch (key) {
      case 'cloud': return Icons.cloud_outlined;
      case 'wb_cloudy': return Icons.wb_cloudy_outlined;
      case 'water_drop': return Icons.water_drop_outlined;
      case 'air': return Icons.air_rounded;
      case 'signal_wifi_off': return Icons.signal_wifi_off;
      default: return Icons.sensors_rounded;
    }
  }
}

// ── Event detail bottom sheet ──────────────────────────────────────────────────

class _EventDetailSheet extends StatelessWidget {
  final String title;
  final double amount;
  final String date;
  final String? upiRef;

  const _EventDetailSheet({
    required this.title,
    required this.amount,
    required this.date,
    this.upiRef,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '₹${amount.toInt()}',
            style: const TextStyle(
              fontSize: 32, fontWeight: FontWeight.w800,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Auto-approved · $date',
            style: TextStyle(
              fontSize: 12, color: AppTheme.textSecondaryOf(context),
            ),
          ),
          if (upiRef != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.successGreen.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.tag_rounded, size: 14,
                      color: AppTheme.successGreen.withOpacity(0.8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      upiRef!,
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryOf(context),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_outlined, size: 14, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Oracle consensus: 3 of 5 sources confirmed · IMD Rainfall + AccuWeather + Traffic Index',
                    style: TextStyle(
                      fontSize: 11, color: AppTheme.textSecondaryOf(context), height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondaryOf(context),
                side: BorderSide(color: AppTheme.dividerOf(context)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}
