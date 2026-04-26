import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../sandbox/sandbox_drivers.dart';
import '../services/demo_backend.dart';
import 'demo_state.dart';
import 'notification_state.dart';

/// Singleton that owns all scripted presentation scenarios.
/// Composes DemoState + NotificationState + DemoBackend.
class DemoOrchestrator {
  DemoOrchestrator._();
  static final DemoOrchestrator instance = DemoOrchestrator._();

  bool _bootstrapped = false;

  void bootstrap() {
    if (_bootstrapped) return;
    _bootstrapped = true;
    DemoBackend.instance.bootstrap();
    seedInitialNotifications();
  }

  // ── Active driver convenience ─────────────────────────────────────────────

  SandboxDriver get _driver => DemoBackend.instance.activeDriver;
  String get _partnerId => _driver.partnerId;
  DemoState get _state => DemoState.instance;
  NotificationState get _notif => NotificationState.instance;

  // ── Seed initial notifications ────────────────────────────────────────────

  void seedInitialNotifications() {
    _notif.setUnreadNotifications(_partnerId, [
      NotificationItem(
        id: 'notif_seed_1',
        title: 'Coverage active',
        detail: 'Your ${_driver.tier} Shield Plan renews on ${_driver.nextRenewal}.',
        timeLabel: '2h ago',
      ),
      NotificationItem(
        id: 'notif_seed_2',
        title: 'Premium debited',
        detail: '₹${_driver.weeklyPremium.toStringAsFixed(0)} debited from your UPI for weekly coverage.',
        timeLabel: '1d ago',
      ),
    ]);
  }

  // ── 1. Flood alert + auto-payout ─────────────────────────────────────────

  void floodAlert() {
    _state.activateTrigger(2); // Trigger #3 (Municipal Advisory)

    _notif.addNotification(
      _partnerId,
      NotificationItem(
        id: 'notif_flood_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Red Alert: Flood advisory active',
        detail:
            'Municipal corporation has issued a red flood alert in your zone. Oracle consensus reached — assessing eligibility.',
        timeLabel: 'Just now',
      ),
    );

    Timer(const Duration(seconds: 4), () {
      final ref = DemoBackend.instance.generateUpiRef();
      final claim = <String, dynamic>{
        'id': DemoBackend.instance.generateClaimId(),
        'eventType': 'Severe Weather — Flood Advisory',
        'reason': 'Severe Weather — Flood Advisory',
        'date': DemoBackend.instance.todayLabel(),
        'status': 'Auto-Approved',
        'statusCode': 'APPROVED',
        'amount': 450.0,
        'progressPct': 1.0,
        'upiRef': ref,
        'isAuto': true,
        'verificationMsg': '3-of-4 oracle consensus. Auto-approved.',
        'claim_description': 'Flood advisory — auto-triggered.',
        'submitted_at': DateTime.now().toIso8601String(),
      };
      _state.addAutoClaim(claim);
      DemoBackend.instance.injectClaim(claim);

      _notif.addNotification(
        _partnerId,
        NotificationItem(
          id: 'notif_payout_${DateTime.now().millisecondsSinceEpoch}',
          title: '₹450 credited to your UPI',
          detail: 'Auto-claim approved. Ref: $ref',
          timeLabel: 'Just now',
        ),
      );
    });
  }

  // ── 2. App-outage alert ───────────────────────────────────────────────────

  void appOutageAlert() {
    _state.activateTrigger(1);

    _notif.addNotification(
      _partnerId,
      NotificationItem(
        id: 'notif_outage_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Platform outage detected',
        detail:
            '${_driver.platform} outage reported in your zone. Income protection window open.',
        timeLabel: 'Just now',
      ),
    );
  }

  // ── 3. Auto-claim + payout (assist chat backdoor) ─────────────────────────

  void autoClaimAndPayout() {
    final ref = DemoBackend.instance.generateUpiRef();
    final claimId = DemoBackend.instance.generateClaimId();

    final claim = <String, dynamic>{
      'id': claimId,
      'eventType': 'Platform Outage — Auto-Claim',
      'reason': 'Platform Outage',
      'date': DemoBackend.instance.todayLabel(),
      'status': 'Auto-Approved',
      'statusCode': 'APPROVED',
      'amount': 247.0,
      'progressPct': 1.0,
      'upiRef': ref,
      'isAuto': true,
      'verificationMsg': 'Oracle consensus. Auto-approved.',
      'claim_description': 'Auto-triggered outage claim.',
      'submitted_at': DateTime.now().toIso8601String(),
    };
    _state.addAutoClaim(claim);
    DemoBackend.instance.injectClaim(claim);

    _notif.addNotification(
      _partnerId,
      NotificationItem(
        id: 'notif_autoclaim_${DateTime.now().millisecondsSinceEpoch}',
        title: '₹247 credited to your UPI',
        detail: 'Platform outage auto-claim approved. Ref: $ref',
        timeLabel: 'Just now',
      ),
    );
  }

  // ── 4. Fraud queue escalation ─────────────────────────────────────────────

  void fraudQueueEscalation() {
    DemoBackend.instance.fraudFlagActive = true;

    final existing = DemoBackend.instance.latestInReviewClaim();
    final claimId = existing?['id'] as String? ??
        DemoBackend.instance.generateClaimId();

    DemoBackend.instance.updateClaim(claimId, {
      'status': 'Under Review — Fraud Queue',
      'statusCode': 'ESCALATED_TO_HUMAN',
      'progressPct': 0.6,
      'verificationMsg':
          'Crew-AI isolation-forest flagged anomalous pattern. Human review within 24h.',
    });

    // Post to admin dashboard for human review
    _postFraudToAdmin(claimId, existing);

    _notif.addNotification(
      _partnerId,
      NotificationItem(
        id: 'notif_fraud_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Claim routed to specialist review',
        detail:
            'Claim $claimId has been escalated for specialist review. Expected resolution: 24h.',
        timeLabel: 'Just now',
      ),
    );
  }

  void _postFraudToAdmin(String claimId, Map<String, dynamic>? existing) {
    final d = DemoBackend.instance.activeDriver;
    final payload = jsonEncode({
      'id': claimId,
      'driver': d.fullName,
      'tier': d.tier,
      'zone': d.zone.split(' — ').first,
      'reason': existing?['reason'] ?? existing?['eventType'] ?? 'Fraud Review',
      'description': existing?['claim_description'] ?? '',
      'amount': existing?['amount'] ?? 0,
      'fraudScore': 0.81,
      'priority': 'High',
      'submittedAt': DateTime.now().toIso8601String(),
      'isFraud': true,
    });
    http.post(
      Uri.parse('${AppConfig.adminBridgeUrl}/api/claims'),
      headers: {'Content-Type': 'application/json'},
      body: payload,
    ).timeout(const Duration(seconds: 3)).catchError((_) => http.Response('', 200));
  }

  // ── 5. Kill-switch trip ───────────────────────────────────────────────────

  void killSwitchTrip() {
    _state.flagKillSwitch(true);

    _notif.addNotification(
      _partnerId,
      NotificationItem(
        id: 'notif_killswitch_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Payout system under maintenance',
        detail:
            'Payouts are temporarily paused for a safety review. In-progress claims will resume automatically.',
        timeLabel: 'Just now',
      ),
    );
  }

  // ── 6. Reserve floor breach ───────────────────────────────────────────────

  void reserveFloorBreach() {
    _state.flagReserveFloor(true);

    _notif.addNotification(
      _partnerId,
      NotificationItem(
        id: 'notif_reserve_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Coverage status update',
        detail:
            'Reserve runway at 87 days — autopay paused on new policies. Existing coverage unaffected.',
        timeLabel: 'Just now',
      ),
    );
  }

  // ── 7. Zone enrollment lock ───────────────────────────────────────────────

  void zoneEnrollmentLock() {
    _state.flagZoneLock(true);

    _notif.addNotification(
      _partnerId,
      NotificationItem(
        id: 'notif_zone_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Zone enrollment paused',
        detail:
            'New policy enrollment in your zone is temporarily paused. Renewals continue normally.',
        timeLabel: 'Just now',
      ),
    );
  }

  // ── 8. Premium debited ────────────────────────────────────────────────────

  void premiumDebited() {
    final amount = _driver.weeklyPremium;
    final ref = 'UPI/${_todayCompact()}/CONT${_shortId()}';

    DemoBackend.instance.addPayoutEntry({
      'id': 'PAY-${_shortId()}',
      'date': DemoBackend.instance.todayLabel(),
      'amount': amount,
      'payu_txn_ref': ref,
      'status': 'Success',
      'method': 'UPI',
      'type': 'premium_debit',
    });

    _notif.addNotification(
      _partnerId,
      NotificationItem(
        id: 'notif_premium_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Premium debited ₹${amount.toStringAsFixed(0)}',
        detail: 'Weekly premium paid. Coverage renewed. Ref: $ref',
        timeLabel: 'Just now',
      ),
    );
  }

  // ── 9. Submit manual claim (called from apply_form) ───────────────────────

  Future<Map<String, dynamic>> submitManualClaim(
    String reason,
    String description,
    List<String> photos,
    String? audioPath,
  ) async {
    final result = await DemoBackend.instance.submitClaim({
      'reason': reason,
      'description': description,
      'photos': photos,
      'audio': audioPath,
      '_killSwitchActive': DemoState.instance.killSwitchActive,
      '_isManual': true,
    });

    _state.addManualClaim(result);

    final status = result['statusCode'] as String? ?? 'REVIEW';
    if (status == 'APPROVED') {
      final ref = result['upiRef'] as String? ?? '';
      final amount = (result['amount'] as num? ?? 0).toDouble();
      _notif.addNotification(
        _partnerId,
        NotificationItem(
          id: 'notif_claim_approved_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Claim approved — ₹${amount.toStringAsFixed(0)} incoming',
          detail: 'Your claim for $reason was approved. Ref: $ref',
          timeLabel: 'Just now',
        ),
      );
    } else if (status == 'ESCALATED_TO_HUMAN') {
      _notif.addNotification(
        _partnerId,
        NotificationItem(
          id: 'notif_fraud2_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Claim under specialist review',
          detail:
              'Your recent claim has been routed for specialist review. Expected: 24h.',
          timeLabel: 'Just now',
        ),
      );
    }

    return result;
  }

  // ── 10. Bandh zero-touch scenario ────────────────────────────────────────

  void bandhAlert() {
    DemoState.instance.triggerAlerts[3] = true;
    DemoState.instance.notifyListeners();

    _notif.addNotification(
      _partnerId,
      NotificationItem(
        id: 'notif_bandh_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Bandh advisory — Zone 4B',
        detail:
            'Municipal authorities declared general bandh in your delivery zone. Parametric coverage is now active.',
        timeLabel: 'Just now',
      ),
    );

    Future.delayed(const Duration(seconds: 4), () {
      final claimId = DemoBackend.instance.generateClaimId();
      const amount = 380.0;
      final ref = DemoBackend.instance.generateUpiRef();
      final claim = <String, dynamic>{
        'id': claimId,
        'claim_id': claimId,
        'eventType': 'Bandh / General Strike',
        'title': 'Bandh / General Strike',
        'reason': 'Bandh / General Strike',
        'amount': amount,
        'status': 'Approved',
        'statusCode': 'APPROVED',
        'progressPct': 1.0,
        'upiRef': ref,
        'isAuto': true,
        'date': DemoBackend.instance.todayLabel(),
        'claim_description':
            'Auto-triggered: Bandh detected in Zone 4B. Oracle consensus reached (3/4 sources).',
        'submitted_at': DateTime.now().toIso8601String(),
      };
      DemoBackend.instance.injectClaim(claim);
      _state.addAutoClaim(claim);
      _notif.addNotification(
        _partnerId,
        NotificationItem(
          id: 'notif_bandh_pay_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Bandh payout credited — ₹${amount.toStringAsFixed(0)}',
          detail:
              'Compensation for Zone 4B bandh disruption. UPI Ref: $ref',
          timeLabel: 'Just now',
        ),
      );
    });
  }

  // ── 11. Seed 3 fresh notifications ────────────────────────────────────────

  void seedDemoNotifications() {
    _notif.addNotification(
      _partnerId,
      NotificationItem(
        id: 'notif_wx_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Weather alert in your zone',
        detail:
            'IMD has issued an orange advisory. Monitor for auto-claim updates.',
        timeLabel: 'Just now',
      ),
    );
    _notif.addNotification(
      _partnerId,
      NotificationItem(
        id: 'notif_prem_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Premium debited',
        detail:
            '₹${_driver.weeklyPremium.toStringAsFixed(0)} debited for weekly coverage.',
        timeLabel: '5m ago',
      ),
    );
    _notif.addNotification(
      _partnerId,
      NotificationItem(
        id: 'notif_approv_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Claim approved',
        detail: 'Your recent claim has been approved and payout initiated.',
        timeLabel: '15m ago',
      ),
    );
  }

  // ── 12. Force-approve a specific claim (status tracker easter egg) ────────

  void forceApprove(String claimId) {
    final ref = DemoBackend.instance.generateUpiRef();
    final existing = DemoBackend.instance.claims.firstWhere(
      (c) => c['id'] == claimId,
      orElse: () => const <String, dynamic>{},
    );
    final existingAmount = (existing['amount'] as num?)?.toDouble() ?? 0;
    DemoBackend.instance.updateClaim(claimId, {
      'status': 'Approved',
      'statusCode': 'APPROVED',
      'progressPct': 1.0,
      'upiRef': ref,
      'amount': existingAmount > 0 ? existingAmount : 247.0,
    });

    // Mirror into DemoState manual claims if present
    final idx = DemoState.instance.manualClaims
        .indexWhere((c) => c['id'] == claimId);
    if (idx != -1) {
      DemoState.instance.manualClaims[idx] = {
        ...DemoState.instance.manualClaims[idx],
        'statusCode': 'APPROVED',
        'status': 'Approved',
        'upiRef': ref,
        'progressPct': 1.0,
      };
      DemoState.instance.notifyListeners();
    }

    _notif.addNotification(
      _partnerId,
      NotificationItem(
        id: 'notif_force_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Claim approved',
        detail: 'Claim $claimId approved. Ref: $ref',
        timeLabel: 'Just now',
      ),
    );
  }

  // ── 13. Reset all ─────────────────────────────────────────────────────────

  void resetAll() {
    _state.resetAll();
    _notif.clearPartner(_partnerId);
    DemoBackend.instance.fraudFlagActive = false;
    DemoBackend.instance.setDriver(_driver); // re-seeds data stores
    seedInitialNotifications();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _todayCompact() {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    final y = now.year.toString().substring(2);
    return '$d$m$y';
  }

  String _shortId() {
    return (1000 + DateTime.now().millisecondsSinceEpoch % 8999).toString();
  }
}
