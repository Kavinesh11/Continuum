// SandboxService — fake backend that serves driver data with simulated latency.
// Drop-in replacement for real API calls during sandbox/demo mode.

import 'sandbox_drivers.dart';

class SandboxService {
  final SandboxDriver driver;

  const SandboxService(this.driver);

  /// Simulates a network round-trip
  Future<T> _delay<T>(T value, [int ms = 400]) =>
      Future.delayed(Duration(milliseconds: ms), () => value);

  // --- Profile ---

  Future<Map<String, dynamic>> fetchProfile() => _delay({
    'partnerId': driver.partnerId,
    'fullName': driver.fullName,
    'initials': driver.initials,
    'phone': driver.phone,
    'email': driver.email,
    'city': driver.city,
    'zone': driver.zone,
    'platform': driver.platform,
    'emergencyContact': driver.emergencyContact,
    'memberSince': driver.memberSince,
    'tier': driver.tier,
    'coverageStatus': driver.coverageStatus,
    'nextRenewal': driver.nextRenewal,
    'weeklyPremium': driver.weeklyPremium,
    'totalProtected': driver.totalProtected,
    'claimsApproved': driver.claimsApproved,
  });

  // --- Location ---

  Future<Map<String, dynamic>> fetchCurrentLocation() => _delay({
    'lat': driver.currentLocation.lat,
    'lng': driver.currentLocation.lng,
    'address': driver.currentLocation.address,
    'zone': driver.currentLocation.zone,
    'timestamp': driver.currentLocation.timestamp.toIso8601String(),
  });

  Future<List<Map<String, dynamic>>> fetchLocationHistory() => _delay(
    driver.locationHistory
        .map(
          (l) => {
            'lat': l.lat,
            'lng': l.lng,
            'address': l.address,
            'zone': l.zone,
            'timestamp': l.timestamp.toIso8601String(),
          },
        )
        .toList(),
  );

  // --- Orders ---

  Future<List<Map<String, dynamic>>> fetchOrderHistory() => _delay(
    driver.orderHistory
        .map(
          (o) => {
            'orderId': o.orderId,
            'platform': o.platform,
            'status': o.status,
            'earnings': o.earnings,
            'pickupAddress': o.pickupAddress,
            'dropAddress': o.dropAddress,
            'timestamp': o.timestamp.toIso8601String(),
            'durationMinutes': o.durationMinutes,
          },
        )
        .toList(),
  );

  // --- Earnings summary ---

  Future<Map<String, dynamic>> fetchEarningsSummary() => _delay({
    'weeklyEarnings': driver.weeklyEarnings,
    'weeklyOrderCount': driver.weeklyOrderCount,
    'completionRate': driver.completionRate,
    'tier': driver.tier,
    'weeklyPremium': driver.weeklyPremium,
  });

  // --- Risk profile (mocked score based on tier) ---

  Future<Map<String, dynamic>> fetchRiskProfile() => _delay({
    'riskScore': driver.tier == 'Platinum'
        ? 0.82
        : driver.tier == 'Gold'
        ? 0.65
        : 0.48,
    'zone': driver.zone,
    'tier': driver.tier,
    'triggerProbabilityThisWeek': driver.tier == 'Platinum' ? 0.14 : 0.09,
    'expectedLoss': driver.weeklyPremium * 0.61,
  });
}
