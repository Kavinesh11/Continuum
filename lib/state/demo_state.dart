import 'package:flutter/foundation.dart';

/// Singleton ChangeNotifier that drives the live demo sequence across screens.
/// Used by DashboardScreen (triggers) and ClaimsScreen (auto-claims).
class DemoState extends ChangeNotifier {
  static final DemoState instance = DemoState._internal();
  DemoState._internal();

  // ── Trigger state ──────────────────────────────────────────────────────────
  final List<bool> _triggerAlerts = List.filled(5, false);

  List<bool> get triggerAlerts => List.unmodifiable(_triggerAlerts);

  int get alertCount => _triggerAlerts.where((a) => a).length;

  // ── Claim flow guard ───────────────────────────────────────────────────────
  /// True once the zero-touch claim overlay has been shown for this session.
  bool claimFlowShown = false;

  // ── Auto-approved claims (added by ClaimFlowSheet on completion) ───────────
  final List<Map<String, dynamic>> autoClaims = [];

  // ── Manual claims ──────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> manualClaims = [];

  // ── Actions ────────────────────────────────────────────────────────────────

  void activateTrigger(int index) {
    if (index >= 0 && index < 5) {
      _triggerAlerts[index] = true;
      notifyListeners();
    }
  }

  /// Resets all triggers and claim flow guard so the demo can be repeated.
  void resetAll() {
    for (int i = 0; i < _triggerAlerts.length; i++) {
      _triggerAlerts[i] = false;
    }
    claimFlowShown = false;
    manualClaims.clear();
    notifyListeners();
  }

  /// Called by ClaimFlowSheet once the animated stepper finishes.
  void addAutoClaim(Map<String, dynamic> claim) {
    autoClaims.insert(0, claim);
    notifyListeners();
  }

  void addManualClaim(Map<String, dynamic> claim) {
    manualClaims.insert(0, claim);
    notifyListeners();
  }

  void updateManualClaim(String id, Map<String, dynamic> updatedClaim) {
    final index = manualClaims.indexWhere((claim) => claim['id'] == id);
    if (index != -1) {
      manualClaims[index] = updatedClaim;
      notifyListeners();
    }
  }

  /// Marks the flow as shown without re-notifying (avoids double-trigger).
  void markClaimFlowShown() {
    claimFlowShown = true;
  }
}
