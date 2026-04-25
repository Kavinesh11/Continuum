import 'package:flutter/foundation.dart';

class DemoState extends ChangeNotifier {
  DemoState._();
  static final DemoState instance = DemoState._();

  final List<bool> triggerAlerts = List<bool>.filled(5, false);
  final List<Map<String, dynamic>> autoClaims = [];
  final List<Map<String, dynamic>> manualClaims = [];

  bool claimFlowShown = false;

  bool killSwitchActive = false;
  bool reserveFloorBreached = false;
  bool zoneEnrollmentLocked = false;

  int get alertCount => triggerAlerts.where((v) => v).length;

  void activateTrigger(int index) {
    if (index < 0 || index >= triggerAlerts.length) return;
    triggerAlerts[index] = true;
    notifyListeners();
  }

  void markClaimFlowShown() {
    claimFlowShown = true;
    notifyListeners();
  }

  void addAutoClaim(Map<String, dynamic> claim) {
    autoClaims.insert(0, claim);
    notifyListeners();
  }

  void addManualClaim(Map<String, dynamic> claim) {
    manualClaims.insert(0, claim);
    notifyListeners();
  }

  void updateManualClaim(String claimId, Map<String, dynamic> claim) {
    final index = manualClaims.indexWhere((c) => c['id'] == claimId);
    if (index == -1) {
      manualClaims.insert(0, claim);
    } else {
      manualClaims[index] = claim;
    }
    notifyListeners();
  }

  void injectClaim(Map<String, dynamic> claim) {
    if (claim['isAuto'] == true) {
      addAutoClaim(claim);
    } else {
      addManualClaim(claim);
    }
  }

  void flagKillSwitch(bool value) {
    killSwitchActive = value;
    notifyListeners();
  }

  void flagReserveFloor(bool value) {
    reserveFloorBreached = value;
    notifyListeners();
  }

  void flagZoneLock(bool value) {
    zoneEnrollmentLocked = value;
    notifyListeners();
  }

  void resetAll() {
    for (var i = 0; i < triggerAlerts.length; i++) {
      triggerAlerts[i] = false;
    }
    autoClaims.clear();
    manualClaims.clear();
    claimFlowShown = false;
    killSwitchActive = false;
    reserveFloorBreached = false;
    zoneEnrollmentLocked = false;
    notifyListeners();
  }
}
