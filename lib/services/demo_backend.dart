import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../sandbox/sandbox_drivers.dart';

/// Singleton mock backend — backs every ApiService call with persona-aware,
/// deterministic fake data. No network required.
class DemoBackend {
  DemoBackend._();
  static final DemoBackend instance = DemoBackend._();

  // ── Active persona ─────────────────────────────────────────────────────────

  SandboxDriver _driver = sandboxDriverSudarshan;
  SandboxDriver get activeDriver => _driver;

  void setDriver(SandboxDriver driver) {
    _driver = driver;
    _seedStores();
  }

  // Overlay for profile edits within the session
  Map<String, dynamic> _profileOverlay = {};

  // ── Claim / payout / assist stores ────────────────────────────────────────

  final List<Map<String, dynamic>> _claims = [];
  final List<Map<String, dynamic>> _payouts = [];
  final List<Map<String, dynamic>> _assistMessages = [];

  // Track which new claims are auto-advancing (claimId → timer subscription)
  final Map<String, _ClaimAdvancer> _advancers = {};

  bool _bootstrapped = false;

  // ── Fraud flag ─────────────────────────────────────────────────────────────
  bool fraudFlagActive = false;

  // ── Bootstrap ──────────────────────────────────────────────────────────────

  void bootstrap() {
    if (_bootstrapped) return;
    _bootstrapped = true;
    _seedStores();
  }

  void _seedStores() {
    _claims
      ..clear()
      ..addAll(_seededClaims(_driver));
    _payouts
      ..clear()
      ..addAll(_seededPayouts(_driver));
    _assistMessages
      ..clear()
      ..addAll(_seededAssistHistory(_driver));
    _profileOverlay = {};
    fraudFlagActive = false;
  }

  // ── Simulated latency ──────────────────────────────────────────────────────

  static Future<void> _delay() =>
      Future.delayed(Duration(milliseconds: 200 + Random().nextInt(400)));

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String workerId, String password) async {
    await _delay();
    return {
      'token': 'demo.${base64UrlEncode(_driver.partnerId)}.exp9999',
      'expires_at': '2099-12-31T23:59:59Z',
      'worker_id': _driver.partnerId,
    };
  }

  // ── Worker profile ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getWorkerProfile(String workerId) async {
    await _delay();
    final d = _driver;
    return {
      'worker_id': d.partnerId,
      'full_name': _profileOverlay['full_name'] ?? d.fullName,
      'phone': _profileOverlay['phone'] ?? d.phone,
      'email': _profileOverlay['email'] ?? d.email,
      'city': _profileOverlay['city'] ?? d.city,
      'zone_id': _profileOverlay['zone'] ?? d.zone,
      'platform': d.platform,
      'tier': d.tier,
      'emergency_contact': _profileOverlay['emergency_contact'] ?? d.emergencyContact,
      'member_since': d.memberSince,
      'weekly_premium': d.weeklyPremium,
      'next_renewal': d.nextRenewal,
      'registered_at': _registeredAt(d),
      'claims_approved_count': d.claimsApproved,
      'total_protected_amount': d.totalProtected,
      'coverage_status': d.coverageStatus,
      'recent_claims': _claims.take(3).toList(),
    };
  }

  Future<Map<String, dynamic>> updateWorkerProfile(
    String workerId,
    Map<String, dynamic> data,
  ) async {
    await _delay();
    _profileOverlay.addAll(data);
    return {'status': 'ok', ...data};
  }

  // ── Claims ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getClaims() async {
    await _delay();
    return List<Map<String, dynamic>>.from(_claims);
  }

  Future<Map<String, dynamic>> getClaimStatus(String claimId) async {
    await _delay();
    // Try admin API — if it has a newer status, sync it back to local store
    final adminData = await _fetchFromAdmin(claimId);
    if (adminData != null) {
      final adminStatus = adminData['status'] as String? ?? '';
      final local = _claims.firstWhere(
        (c) => c['id'] == claimId,
        orElse: () => <String, dynamic>{},
      );
      if (adminStatus == 'Approved' || adminStatus == 'Rejected') {
        final newStatusCode = adminStatus == 'Approved' ? 'APPROVED' : 'REJECTED';
        final newAmount = adminStatus == 'Approved'
            ? (adminData['amount'] as num? ?? local['amount'] ?? 0).toDouble()
            : 0.0;
        final updated = {
          ...local.isNotEmpty ? local : _defaultClaimStatus(claimId),
          'statusCode': newStatusCode,
          'status': adminStatus,
          'amount': newAmount,
          'progressPct': 1.0,
          'verificationMsg': adminData['reviewNote'] ?? 'Reviewed by admin.',
          'upiRef': adminStatus == 'Approved' ? generateUpiRef() : null,
        };
        final idx = _claims.indexWhere((c) => c['id'] == claimId);
        if (idx != -1) {
          _claims[idx] = updated;
        }
        return _claimToStatus(updated);
      }
    }
    final claim = _claims.firstWhere(
      (c) => c['id'] == claimId,
      orElse: () => _claims.isNotEmpty ? _claims.first : _defaultClaimStatus(claimId),
    );
    return _claimToStatus(claim);
  }

  Future<Map<String, dynamic>> submitClaim(Map<String, dynamic> payload) async {
    await _delay();
    final reason = (payload['reason'] as String? ?? '').toLowerCase();
    final killSwitch = payload['_killSwitchActive'] == true;
    final isManual = payload['_isManual'] == true;
    final fraudFlag = fraudFlagActive;

    String status;
    String? verificationMsg;
    double amount = 0;
    bool isAuto = false;

    if (fraudFlag) {
      status = 'ESCALATED_TO_HUMAN';
      verificationMsg =
          'Crew-AI isolation-forest flagged anomalous claim pattern. Human review within 24h.';
    } else if (isManual) {
      // Manual form submissions always start as In Progress
      status = 'REVIEW';
      verificationMsg = killSwitch
          ? 'Payouts paused — safety review in progress (PAYOUT_KILL_SWITCH active).'
          : 'Claim submitted. Oracle network is verifying your report. Expected: 24h.';
      if (reason.contains('vehicle') || reason.contains('breakdown')) {
        status = 'REJECTED';
        verificationMsg =
            'GPS proximity log shows worker outside disruption zone during reported window.';
      }
    } else if (reason.contains('rain') ||
        reason.contains('weather') ||
        reason.contains('flood')) {
      if (killSwitch) {
        status = 'REVIEW';
        verificationMsg =
            'Payouts paused — safety review in progress (PAYOUT_KILL_SWITCH active).';
      } else {
        status = 'APPROVED';
        amount = _driver.tier == 'Platinum'
            ? 450.0
            : _driver.tier == 'Gold'
                ? 312.0
                : 247.0;
        isAuto = true;
      }
    } else if (reason.contains('outage') || reason.contains('app')) {
      status = killSwitch ? 'REVIEW' : 'APPROVED';
      amount = killSwitch
          ? 0
          : _driver.tier == 'Platinum'
              ? 312.0
              : _driver.tier == 'Gold'
                  ? 180.0
                  : 99.0;
      verificationMsg = killSwitch
          ? 'Payouts paused — safety review in progress.'
          : null;
    } else if (reason.contains('vehicle') || reason.contains('breakdown')) {
      status = 'REJECTED';
      verificationMsg =
          'GPS proximity log shows worker outside disruption zone during reported window.';
    } else if (reason.contains('network') || reason.contains('failure')) {
      status = 'REVIEW';
      verificationMsg = 'Cross-referencing telecom outage reports. Expected 24h.';
    } else {
      status = 'REVIEW';
    }

    final claimId = generateClaimId();
    final claim = <String, dynamic>{
      'id': claimId,
      'claim_id': claimId,
      'eventType': payload['reason'] ?? 'Disruption',
      'reason': payload['reason'] ?? 'Disruption',
      'description': payload['description'] ?? '',
      'date': todayLabel(),
      'status': _statusLabel(status),
      'statusCode': status,
      'amount': amount,
      'progressPct': _progressPct(status),
      'upiRef': status == 'APPROVED' ? generateUpiRef() : null,
      'verificationMsg': verificationMsg,
      'isAuto': isAuto,
      'claim_description': payload['description'] ?? '',
      'submitted_at': DateTime.now().toIso8601String(),
    };

    _claims.insert(0, claim);

    if (status == 'APPROVED' && isAuto) {
      // Only auto-advance oracle-approved auto-claims through stages
      _startAutoAdvancer(claimId);
    } else if (status == 'REVIEW' || status == 'ESCALATED_TO_HUMAN') {
      // Manual/fraud claims → post to admin dashboard for human review
      _postToAdmin(claim, isFraud: status == 'ESCALATED_TO_HUMAN');
    }

    return claim;
  }

  // ── Payouts ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPayouts() async {
    await _delay();
    return List<Map<String, dynamic>>.from(_payouts);
  }

  void addPayoutEntry(Map<String, dynamic> entry) {
    _payouts.insert(0, entry);
  }

  // ── Admin bridge ───────────────────────────────────────────────────────────

  Future<void> postClaimToAdmin(Map<String, dynamic> claim) => _postToAdmin(claim);

  void startManualClaimWatcher(String claimId) {
    Timer.periodic(const Duration(seconds: 6), (timer) {
      final idx = _claims.indexWhere((c) => c['id'] == claimId);
      if (idx == -1) { timer.cancel(); return; }
      final code = _claims[idx]['statusCode'] as String? ?? '';
      if (code == 'APPROVED' || code == 'REJECTED') { timer.cancel(); return; }
      getClaimStatus(claimId);
    });
  }

  Future<void> _postToAdmin(Map<String, dynamic> claim, {bool isFraud = false}) async {
    try {
      final d = _driver;
      await http.post(
        Uri.parse('${AppConfig.adminBridgeUrl}/api/claims'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': claim['id'],
          'driver': d.fullName,
          'tier': d.tier,
          'zone': d.zone.split(' — ').first,
          'reason': claim['reason'] ?? claim['eventType'] ?? 'Disruption',
          'description': claim['claim_description'] ?? claim['description'] ?? '',
          'amount': claim['amount'] ?? 0,
          'fraudScore': isFraud ? 0.81 : 0.15,
          'priority': isFraud ? 'High' : 'Medium',
          'submittedAt': claim['submitted_at'] ?? DateTime.now().toIso8601String(),
          'isFraud': isFraud,
        }),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Admin dashboard not running — fall back to local-only mode
    }
  }

  Future<Map<String, dynamic>?> _fetchFromAdmin(String claimId) async {
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.adminBridgeUrl}/api/claims/$claimId'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ── Risk profile ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchRiskProfile(
    Map<String, dynamic> payload,
  ) async {
    await _delay();
    final d = _driver;
    final riskScore = d.tier == 'Platinum'
        ? 0.82
        : d.tier == 'Gold'
            ? 0.65
            : 0.48;
    return {
      'worker_id': d.partnerId,
      'risk_score': riskScore,
      'tier': d.tier,
      'weekly_premium': d.weeklyPremium,
      'coverage_limit': d.totalProtected,
      'next_renewal': d.nextRenewal,
    };
  }

  // ── Policy content ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPolicyContent() async {
    await _delay();
    final d = _driver;
    final tier = d.tier;
    final zone = d.zone.split(' — ').first;
    return {
      'hero': {
        'badge': '$tier TIER',
        'title': '$tier Shield Plan',
        'subtitle': 'Coverage active in $zone',
      },
      'sections': [
        {
          'title': 'Coverage',
          'icon_key': 'coverage',
          'body':
              'You are covered for income loss due to: severe weather events (IMD orange/red alerts), platform app outages >30min, network failures affecting delivery apps, and municipal disruption advisories.\n\nYour $tier tier coverage limit is ₹${_coverageLimit(tier)}.',
        },
        {
          'title': 'Eligibility',
          'icon_key': 'eligibility',
          'body':
              'Active delivery partners registered on ${d.platform} with a minimum 3 months on-platform history. $tier tier requires ${_eligibilityReq(tier)}.\n\nYour account is verified and in good standing.',
        },
        {
          'title': 'Claim Process',
          'icon_key': 'claim_process',
          'body':
              'Tap "Apply Claim" on the dashboard. Submit the disruption reason, date, a brief description, and optional photo/audio evidence.\n\nWeather & outage claims auto-approve within 5 minutes via oracle consensus. Manual review claims resolve within 24 hours.',
        },
        {
          'title': 'Payouts',
          'icon_key': 'payouts',
          'body':
              'Approved payouts are disbursed to your registered UPI ID via PayU eNACH within 5 minutes of approval.\n\nUPI reference format: UPI/DDMMYY/CONT{txn_id}. Keep this for your records.',
        },
        {
          'title': 'Exclusions',
          'icon_key': 'exclusions',
          'body':
              'Claims are not payable for: vehicle breakdowns outside oracle-verified disruption windows, orders cancelled by the partner, pre-existing conditions, or events outside registered zone.\n\nFraudulent submissions trigger automatic isolation-forest review.',
        },
        {
          'title': 'Renewal',
          'icon_key': 'renewal',
          'body':
              'Your weekly premium of ₹${d.weeklyPremium.toStringAsFixed(0)} is auto-debited every Monday via eNACH. Next renewal: ${d.nextRenewal}.\n\nMissed payments result in a 7-day grace period before coverage suspension.',
        },
      ],
    };
  }

  // ── Oracle network status ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getOracleStatus() async {
    await _delay();
    final d = _driver;
    final hasAlert = fraudFlagActive ||
        _claims.any((c) => (c['statusCode'] as String? ?? '') == 'APPROVED' &&
            c['isAuto'] == true);
    final platformStatus = fraudFlagActive ? 'Alert' : 'Nominal';
    final platformReading = fraudFlagActive
        ? '${d.platform}: 3,741 anomaly reports'
        : '${d.platform}: 0 reports';

    final autoEvents = _claims
        .where((c) => c['isAuto'] == true)
        .take(3)
        .toList();

    return {
      'consensus_reached': hasAlert,
      'oracles': [
        {
          'name': 'IMD India',
          'type': 'Weather',
          'icon_key': 'cloud',
          'status': hasAlert ? 'Alert' : 'Nominal',
          'reading': hasAlert
              ? 'Red Alert — ${d.zone.split(' — ').last}, ${d.city}'
              : 'No active advisories',
          'confidence': hasAlert ? 0.94 : 0.72,
        },
        {
          'name': 'AccuWeather',
          'type': 'Weather',
          'icon_key': 'wb_cloudy',
          'status': hasAlert ? 'Alert' : 'Nominal',
          'reading': hasAlert
              ? 'Extreme rain >100mm/h'
              : 'Clear conditions',
          'confidence': hasAlert ? 0.91 : 0.68,
        },
        {
          'name': 'NASA-GPM',
          'type': 'Rainfall',
          'icon_key': 'water_drop',
          'status': hasAlert ? 'Alert' : 'Nominal',
          'reading': hasAlert
              ? 'GPM IMERG: High intensity detected'
              : 'IMERG: Low precipitation',
          'confidence': hasAlert ? 0.88 : 0.61,
        },
        {
          'name': 'CPCB AQI',
          'type': 'Air Quality',
          'icon_key': 'air',
          'status': 'Nominal',
          'reading': 'AQI 142 — Moderate',
          'confidence': 0.72,
        },
        {
          'name': 'DownDetector',
          'type': 'Platform',
          'icon_key': 'signal_wifi_off',
          'status': platformStatus,
          'reading': platformReading,
          'confidence': fraudFlagActive ? 0.89 : 0.85,
        },
      ],
      'last_consensus': hasAlert ? todayLabel() : 'No recent consensus',
      'auto_events': autoEvents,
      'ml_model': {
        'name': 'IsoForest-XGB Ensemble v2.4',
        'version': '2.4.1',
        'last_trained': _daysAgoLabel(10),
        'accuracy': 0.947,
        'precision': 0.931,
        'recall': 0.962,
        'features': [
          {'name': 'Zone weather score', 'importance': 0.34},
          {'name': 'Platform API latency', 'importance': 0.27},
          {'name': 'Order density delta', 'importance': 0.19},
          {'name': 'Historical claim rate', 'importance': 0.12},
          {'name': 'GPS proximity score', 'importance': 0.08},
        ],
        'prediction': hasAlert
            ? {'label': 'HIGH_DISRUPTION', 'confidence': 0.91, 'threshold': 0.72}
            : {'label': 'NOMINAL', 'confidence': 0.88, 'threshold': 0.72},
        'anomaly_score': hasAlert ? 0.81 : 0.12,
        'shap_top_factor': hasAlert
            ? 'Zone weather score (↑ +0.28)'
            : 'Platform API latency (↓ −0.04)',
      },
      'data_sources': [
        {'name': 'IMD Real-Time API', 'latency_ms': 142, 'status': 'connected', 'records_last_hour': 3_840},
        {'name': 'Platform Webhook', 'latency_ms': 38, 'status': 'connected', 'records_last_hour': 12_200},
        {'name': 'NASA-GPM S3 Feed', 'latency_ms': 890, 'status': 'connected', 'records_last_hour': 288},
        {'name': 'Municipal RSS', 'latency_ms': 210, 'status': 'connected', 'records_last_hour': 14},
        {'name': 'Traffic API', 'latency_ms': 320, 'status': 'connected', 'records_last_hour': 7_640},
      ],
    };
  }

  // ── Registration ───────────────────────────────────────────────────────────

  Future<void> requestOtp({
    required String phone,
    required String email,
  }) async {
    await _delay();
    // Mock: OTP "sent" — any 6-digit value will verify
  }

  Future<void> verifyOtp(String otp) async {
    await _delay();
    // Mock: all OTPs pass
  }

  /// Returns a formatted claims summary for the active persona — used by GeminiService.
  String getSeededClaimsSummary() {
    final claims = _seededClaims(_driver);
    return claims.map((c) {
      final id = c['id'];
      final event = c['eventType'];
      final status = c['status'];
      final amount = (c['amount'] as num?) ?? 0;
      final upi = c['upiRef'] as String?;
      final note = c['verificationMsg'] as String?;
      if (upi != null && upi.isNotEmpty) {
        return '- $id: $event ($status ₹${amount.toStringAsFixed(0)}, ref $upi)';
      } else if (note != null && note.isNotEmpty) {
        return '- $id: $event ($status — $note)';
      }
      return '- $id: $event ($status)';
    }).join('\n');
  }

  /// Returns a formatted payouts summary for the active persona — used by GeminiService.
  String getSeededPayoutsSummary() {
    final payouts = _seededPayouts(_driver);
    return payouts.take(3).map((p) {
      final id = p['id'];
      final date = p['date'];
      final amount = (p['amount'] as num?) ?? 0;
      final status = p['status'];
      return '- $id: ₹${amount.toStringAsFixed(0)} on $date ($status)';
    }).join('\n');
  }

  Future<String> completeRegistration({
    required String fullName,
    required String phone,
    required String email,
    required String platform,
    required String city,
    required String partnerId,
    required String vehicleType,
    required String plan,
    required String upiId,
    required bool acceptedTerms,
  }) async {
    await _delay();
    // Map plan tier to the closest sandbox persona
    final driver = plan == 'Platinum'
        ? sandboxDriverSudarshan
        : plan == 'Gold'
            ? sandboxDriverDakshina
            : sandboxDriverSudha;
    setDriver(driver);
    final policyId =
        'POL-${driver.tier.substring(0, 2).toUpperCase()}-${DateTime.now().millisecondsSinceEpoch % 100000}';
    return policyId;
  }

  // ── Assist chat ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAssistMessages() async {
    await _delay();
    return List<Map<String, dynamic>>.from(_assistMessages);
  }

  Future<Map<String, dynamic>> sendAssistMessage(String message) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final lower = message.toLowerCase();
    String reply;

    if (lower.contains('claim') || lower.contains('apply')) {
      reply =
          'Tap *Apply Claim* on the dashboard. Most weather/outage claims auto-approve in under 5 minutes via our oracle network.';
    } else if (lower.contains('payout') || lower.contains('money')) {
      reply =
          'Approved payouts hit your linked UPI within 5 minutes. We use eNACH on PayU — reference format UPI/DDMMYY/CONT{txn_id}.';
    } else if (lower.contains('premium') || lower.contains('pay')) {
      reply =
          'Your weekly premium is ₹${_driver.weeklyPremium.toStringAsFixed(0)} — auto-debited every Monday from your UPI. Next debit: ${_driver.nextRenewal}.';
    } else if (lower.contains('weather') ||
        lower.contains('rain') ||
        lower.contains('flood')) {
      reply =
          'Yes — IMD, AccuWeather and NASA-GPM oracles run continuously. 3-of-4 consensus triggers an auto-claim within 2 minutes of alert confirmation.';
    } else if (lower.contains('platinum') ||
        lower.contains('gold') ||
        lower.contains('silver') ||
        lower.contains('tier') ||
        lower.contains('coverage') ||
        lower.contains('plan')) {
      reply =
          'You\'re on the ${_driver.tier} Shield Plan — ₹${_driver.totalProtected.toStringAsFixed(0)} total coverage at ₹${_driver.weeklyPremium.toStringAsFixed(0)}/week. Covered events: severe weather, platform outages, bandh/strikes, and roadblocks. Oracle consensus triggers auto-approval within minutes.';
    } else if (lower.contains('fraud') || lower.contains('review')) {
      reply =
          'Fraud detection runs an isolation-forest model + crew-AI guardrails. ESCALATED_TO_HUMAN claims clear within 24h after human review.';
    } else if (lower.contains('status') || lower.contains('track')) {
      reply =
          'Tap any claim from the *Claims* tab to see live progress through SUBMITTED → REVIEW → APPROVED → PAYOUT.';
    } else {
      reply =
          "I'm here for claims, payouts, premium and policy questions — try *'how does payout work?'* or *'apply claim'*.";
    }

    final botMsg = {
      'id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
      'role': 'assistant',
      'content': reply,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _assistMessages.add(botMsg);
    return botMsg;
  }

  void addAssistMessage(Map<String, dynamic> msg) {
    _assistMessages.add(msg);
  }

  Future<void> clearAssistHistory() async {
    await _delay();
    _assistMessages.clear();
    _assistMessages.addAll(_seededAssistHistory(_driver));
  }

  // ── Claim store helpers used by orchestrator ───────────────────────────────

  List<Map<String, dynamic>> get claims => List.unmodifiable(_claims);

  void injectClaim(Map<String, dynamic> claim) {
    _claims.insert(0, claim);
  }

  void updateClaim(String claimId, Map<String, dynamic> updates) {
    final index = _claims.indexWhere((c) => c['id'] == claimId);
    if (index != -1) {
      _claims[index] = {..._claims[index], ...updates};
    }
  }

  Map<String, dynamic>? latestInReviewClaim() {
    try {
      return _claims.firstWhere(
        (c) =>
            (c['status'] as String? ?? '').toLowerCase().contains('review') ||
            (c['statusCode'] as String? ?? '') == 'REVIEW',
      );
    } catch (_) {
      return null;
    }
  }

  // ── Auto-advancing claim stages ────────────────────────────────────────────

  void _startAutoAdvancer(String claimId) {
    _advancers[claimId]?.cancel();
    _advancers[claimId] = _ClaimAdvancer(claimId, _claims, () {
      _advancers.remove(claimId);
    });
  }

  // ── Seeded data per persona ─────────────────────────────────────────────────

  List<Map<String, dynamic>> _seededClaims(SandboxDriver d) {
    if (d.partnerId == sandboxDriverSudarshan.partnerId) {
      return [
        _makeClaim(
          id: 'CLM-9824-21',
          eventType: 'Severe Weather',
          date: _daysAgoLabel(2),
          status: 'Approved',
          statusCode: 'APPROVED',
          amount: 450.0,
          progressPct: 1.0,
          upiRef: 'UPI/${_upiDatePrefix(2)}/CONT847291',
          isAuto: false,
        ),
        _makeClaim(
          id: 'CLM-9102-54',
          eventType: 'Platform Outage',
          date: _daysAgoLabel(7),
          status: 'In Review',
          statusCode: 'REVIEW',
          amount: 180.0,
          progressPct: 0.5,
          verificationMsg: 'Cross-referencing Swiggy + Zomato incident logs for Bangalore South. Expected resolution: 24h.',
        ),
        _makeClaim(
          id: 'CLM-8833-12',
          eventType: 'Severe Weather + Platform Outage',
          date: _daysAgoLabel(13),
          status: 'Auto-Approved',
          statusCode: 'APPROVED',
          amount: 247.0,
          progressPct: 1.0,
          upiRef: 'UPI/${_upiDatePrefix(13)}/CONT829130',
          isAuto: true,
          verificationMsg: 'IMD + NASA-GPM oracle consensus (4/4 sources). Auto-approved.',
        ),
      ];
    } else if (d.partnerId == sandboxDriverDakshina.partnerId) {
      return [
        _makeClaim(
          id: 'CLM-7711-08',
          eventType: 'Heavy Rain',
          date: _daysAgoLabel(3),
          status: 'Approved',
          statusCode: 'APPROVED',
          amount: 312.0,
          progressPct: 1.0,
          upiRef: 'UPI/${_upiDatePrefix(3)}/CONT711082',
        ),
        _makeClaim(
          id: 'CLM-7611-22',
          eventType: 'App Outage',
          date: _daysAgoLabel(10),
          status: 'In Review',
          statusCode: 'REVIEW',
          amount: 0,
          progressPct: 0.5,
          verificationMsg: 'Platform outage log verification pending.',
        ),
        _makeClaim(
          id: 'CLM-7322-90',
          eventType: 'Vehicle Breakdown',
          date: _daysAgoLabel(17),
          status: 'Rejected',
          statusCode: 'REJECTED',
          amount: 0,
          progressPct: 1.0,
          verificationMsg:
              'GPS log shows worker outside disruption zone during reported window.',
        ),
      ];
    } else {
      // Sudha (Silver)
      return [
        _makeClaim(
          id: 'CLM-5510-44',
          eventType: 'Network Failure',
          date: _daysAgoLabel(5),
          status: 'Approved',
          statusCode: 'APPROVED',
          amount: 180.0,
          progressPct: 1.0,
          upiRef: 'UPI/${_upiDatePrefix(5)}/CONT551044',
        ),
        _makeClaim(
          id: 'CLM-5388-19',
          eventType: 'Severe Weather',
          date: _daysAgoLabel(15),
          status: 'Auto-Approved',
          statusCode: 'APPROVED',
          amount: 224.0,
          progressPct: 1.0,
          upiRef: 'UPI/${_upiDatePrefix(15)}/CONT538819',
          isAuto: true,
        ),
      ];
    }
  }

  List<Map<String, dynamic>> _seededPayouts(SandboxDriver d) {
    if (d.partnerId == sandboxDriverSudarshan.partnerId) {
      return [
        _makePayout('PAY-4721', _daysAgoLabel(2), 450.0, 'UPI/${_upiDatePrefix(2)}/CONT847291', 'Success'),
        _makePayout('PAY-4512', _daysAgoLabel(13), 247.0, 'UPI/${_upiDatePrefix(13)}/CONT829130', 'Success'),
        _makePayout('PAY-4101', _daysAgoLabel(35), 312.0, 'UPI/${_upiDatePrefix(35)}/CONT410100', 'Success'),
        _makePayout('PAY-3988', _daysAgoLabel(49), 247.0, 'UPI/${_upiDatePrefix(49)}/CONT398801', 'Failed'),
      ];
    } else if (d.partnerId == sandboxDriverDakshina.partnerId) {
      return [
        _makePayout('PAY-3311', _daysAgoLabel(3), 312.0, 'UPI/${_upiDatePrefix(3)}/CONT711082', 'Success'),
        _makePayout('PAY-3102', _daysAgoLabel(25), 99.0, 'UPI/${_upiDatePrefix(25)}/CONT310200', 'Success'),
        _makePayout('PAY-2988', _daysAgoLabel(43), 247.0, 'UPI/${_upiDatePrefix(43)}/CONT298801', 'Pending'),
      ];
    } else {
      return [
        _makePayout('PAY-1821', _daysAgoLabel(5), 180.0, 'UPI/${_upiDatePrefix(5)}/CONT551044', 'Success'),
        _makePayout('PAY-1710', _daysAgoLabel(15), 224.0, 'UPI/${_upiDatePrefix(15)}/CONT538819', 'Success'),
        _makePayout('PAY-1601', _daysAgoLabel(34), 49.0, 'UPI/${_upiDatePrefix(34)}/CONT160100', 'Success'),
      ];
    }
  }

  List<Map<String, dynamic>> _seededAssistHistory(SandboxDriver d) {
    final firstName = d.fullName.split(' ').first;
    final latestClaim = _claims.isNotEmpty ? _claims.first : null;
    final latestClaimId = latestClaim?['id'] as String? ?? 'your latest claim';
    return [
      {
        'id': 'seed_1',
        'role': 'assistant',
        'content':
            'Hi $firstName! I\'m your Continuum Assist bot. You\'re on the ${d.tier} Shield Plan — ₹${d.totalProtected.toStringAsFixed(0)} coverage, ₹${d.weeklyPremium.toStringAsFixed(0)}/week. Ask me anything about claims, payouts, or your policy.',
        'timestamp': DateTime.now()
            .subtract(const Duration(hours: 2))
            .toIso8601String(),
      },
      {
        'id': 'seed_2',
        'role': 'user',
        'content': 'What\'s the status of my claim $latestClaimId?',
        'timestamp': DateTime.now()
            .subtract(const Duration(hours: 1, minutes: 55))
            .toIso8601String(),
      },
      {
        'id': 'seed_3',
        'role': 'assistant',
        'content':
            'Claim $latestClaimId is currently ${latestClaim?['status'] ?? 'In Review'}. ${latestClaim?['verificationMsg'] ?? 'Our oracle network is verifying your report.'} Tap the claim card for a live progress view.',
        'timestamp': DateTime.now()
            .subtract(const Duration(hours: 1, minutes: 54))
            .toIso8601String(),
      },
      {
        'id': 'seed_4',
        'role': 'user',
        'content': 'When is my next premium due?',
        'timestamp': DateTime.now()
            .subtract(const Duration(hours: 1, minutes: 30))
            .toIso8601String(),
      },
      {
        'id': 'seed_5',
        'role': 'assistant',
        'content':
            'Your next ₹${d.weeklyPremium.toStringAsFixed(0)} premium debit is on ${d.nextRenewal}, auto-pulled via eNACH. You\'re covered until then — ${d.zone} is active.',
        'timestamp': DateTime.now()
            .subtract(const Duration(hours: 1, minutes: 29))
            .toIso8601String(),
      },
    ];
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _makeClaim({
    required String id,
    required String eventType,
    required String date,
    required String status,
    required String statusCode,
    required double amount,
    required double progressPct,
    String? upiRef,
    String? verificationMsg,
    bool isAuto = false,
  }) {
    return {
      'id': id,
      'claim_id': id,
      'eventType': eventType,
      'reason': eventType,
      'date': date,
      'status': status,
      'statusCode': statusCode,
      'amount': amount,
      'progressPct': progressPct,
      'upiRef': upiRef,
      'verificationMsg': verificationMsg,
      'isAuto': isAuto,
      'claim_description': '',
    };
  }

  Map<String, dynamic> _makePayout(
    String id,
    String date,
    double amount,
    String txnRef,
    String status,
  ) {
    return {
      'id': id,
      'date': date,
      'amount': amount,
      'payu_txn_ref': txnRef,
      'status': status,
      'method': 'UPI',
    };
  }

  Map<String, dynamic> _claimToStatus(Map<String, dynamic> claim) {
    final statusCode = claim['statusCode'] as String? ?? 'REVIEW';
    final stages = <Map<String, dynamic>>[
      {
        'name': 'SUBMITTED',
        'time': claim['submitted_at'] != null
            ? _formatTime(DateTime.parse(claim['submitted_at'] as String))
            : claim['date'] as String? ?? '',
        'complete': true,
      },
      {
        'name': 'REVIEW',
        'time': statusCode == 'APPROVED' || statusCode == 'REJECTED'
            ? 'Completed'
            : statusCode == 'REVIEW'
                ? 'In Progress'
                : 'Pending',
        'complete': statusCode != 'SUBMITTED',
      },
      {
        'name': 'APPROVED',
        'time': statusCode == 'APPROVED' ? 'Completed' : 'Pending',
        'complete': statusCode == 'APPROVED',
      },
      {
        'name': 'PAYOUT',
        'time': claim['upiRef'] != null ? claim['upiRef'] as String : 'Pending',
        'complete': claim['upiRef'] != null,
      },
    ];

    return {
      'claimId': claim['id'],
      'claim_id': claim['id'],
      'status': claim['status'] ?? 'In Review',
      'statusCode': statusCode,
      'stages': stages,
      'expectedPayout': claim['amount'] ?? 0,
      'timelineText': statusCode == 'APPROVED' ? 'Paid' : '2-3 business days',
      'verificationMessage': claim['verificationMsg'] ?? 'Verifying your claim details.',
      'verification_message': claim['verificationMsg'] ?? 'Verifying your claim details.',
      'upiRef': claim['upiRef'],
      'claim_description': claim['claim_description'] ?? claim['description'] ?? '',
      'reason': claim['reason'] ?? claim['eventType'] ?? 'Claim',
      'event_type': claim['eventType'] ?? claim['reason'] ?? 'Claim',
    };
  }

  Map<String, dynamic> _defaultClaimStatus(String claimId) => {
        'id': claimId,
        'status': 'In Review',
        'statusCode': 'REVIEW',
        'amount': 0.0,
        'progressPct': 0.5,
      };

  String _statusLabel(String code) {
    switch (code) {
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      case 'REVIEW':
        return 'In Review';
      case 'ESCALATED_TO_HUMAN':
        return 'Under Review — Fraud Queue';
      default:
        return 'Submitted';
    }
  }

  double _progressPct(String code) {
    switch (code) {
      case 'APPROVED':
        return 1.0;
      case 'REJECTED':
        return 1.0;
      case 'REVIEW':
        return 0.5;
      case 'ESCALATED_TO_HUMAN':
        return 0.6;
      default:
        return 0.2;
    }
  }

  String generateClaimId() {
    final n = 1000 + Random().nextInt(8999);
    final s = 10 + Random().nextInt(89);
    return 'CLM-$n-$s';
  }

  String generateUpiRef() {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    final y = now.year.toString().substring(2);
    final n = 100000 + Random().nextInt(899999);
    return 'UPI/$d$m$y/CONT$n';
  }

  String todayLabel() {
    final now = DateTime.now();
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[now.month]} ${now.day}, ${now.year}';
  }

  String _daysAgoLabel(int daysAgo) {
    final dt = DateTime.now().subtract(Duration(days: daysAgo));
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }

  String _upiDatePrefix(int daysAgo) {
    final dt = DateTime.now().subtract(Duration(days: daysAgo));
    return '${dt.day.toString().padLeft(2, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.year.toString().substring(2)}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '$h:$m $ampm, ${months[dt.month]} ${dt.day}';
  }

  String _registeredAt(SandboxDriver d) {
    switch (d.memberSince) {
      case 'Jan 2024':
        return '2024-01-15T09:00:00Z';
      case 'Mar 2023':
        return '2023-03-22T10:00:00Z';
      case 'Jun 2024':
        return '2024-06-10T11:00:00Z';
      default:
        return '2024-01-01T09:00:00Z';
    }
  }

  String _coverageLimit(String tier) {
    switch (tier) {
      case 'Platinum':
        return '24,800';
      case 'Gold':
        return '18,400';
      default:
        return '9,200';
    }
  }

  String _eligibilityReq(String tier) {
    switch (tier) {
      case 'Platinum':
        return '500+ completed orders and 90%+ completion rate';
      case 'Gold':
        return '200+ completed orders and 80%+ completion rate';
      default:
        return '50+ completed orders';
    }
  }

  // ── Minimal base64 helper (no dart:convert import needed for this) ──────────

  static String base64UrlEncode(String input) {
    final bytes = input.codeUnits;
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final output = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final b0 = bytes[i];
      final b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      output.write(chars[(b0 >> 2) & 0x3F]);
      output.write(chars[((b0 & 0x3) << 4) | ((b1 >> 4) & 0xF)]);
      output.write(chars[((b1 & 0xF) << 2) | ((b2 >> 6) & 0x3)]);
      output.write(chars[b2 & 0x3F]);
    }
    return output.toString();
  }
}

// ── Auto-claim stage advancer ────────────────────────────────────────────────

class _ClaimAdvancer {
  final String claimId;
  final List<Map<String, dynamic>> claims;
  final void Function() onDone;
  late final Timer _timer;
  int _step = 0;

  _ClaimAdvancer(this.claimId, this.claims, this.onDone) {
    _timer = Timer.periodic(const Duration(seconds: 4), _tick);
  }

  void _tick(Timer _) {
    final index = claims.indexWhere((c) => c['id'] == claimId);
    if (index == -1) {
      cancel();
      return;
    }
    final claim = claims[index];
    final code = claim['statusCode'] as String? ?? 'SUBMITTED';

    if (_step == 0 && code == 'SUBMITTED') {
      claims[index] = {
        ...claim,
        'statusCode': 'REVIEW',
        'status': 'In Review',
        'progressPct': 0.5,
      };
    } else if (_step == 1 && code == 'REVIEW') {
      claims[index] = {
        ...claim,
        'statusCode': 'APPROVED',
        'status': 'Approved',
        'progressPct': 1.0,
        'amount': (claim['amount'] as num? ?? 0) > 0
            ? claim['amount']
            : 247.0,
      };
    } else if (_step == 2 && code == 'APPROVED') {
      final now = DateTime.now();
      final d = now.day.toString().padLeft(2, '0');
      final m = now.month.toString().padLeft(2, '0');
      final y = now.year.toString().substring(2);
      final n = 100000 + Random().nextInt(899999);
      final ref = 'UPI/$d$m$y/CONT$n';
      claims[index] = {
        ...claim,
        'upiRef': ref,
        'progressPct': 1.0,
      };
      cancel();
      return;
    }
    _step++;
  }

  void cancel() {
    _timer.cancel();
    onDone();
  }
}

