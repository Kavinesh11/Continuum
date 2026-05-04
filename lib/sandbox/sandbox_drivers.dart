// Sandbox driver personas — 3 real-world inspired profiles
// Each carries: profile, location history, order history, earnings, risk tier

DateTime _today(int h, int m) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

String _renewalDate(int daysFromNow) {
  final dt = DateTime.now().add(Duration(days: daysFromNow));
  const months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[dt.month]} ${dt.day}, ${dt.year}';
}

String _todayId() {
  final n = DateTime.now();
  return '${n.year}${n.month.toString().padLeft(2, '0')}'
      '${n.day.toString().padLeft(2, '0')}';
}

class SandboxLocation {
  final double lat;
  final double lng;
  final String address;
  final String zone;
  final DateTime timestamp;

  SandboxLocation({
    required this.lat,
    required this.lng,
    required this.address,
    required this.zone,
    required this.timestamp,
  });
}

class SandboxOrder {
  final String orderId;
  final String platform; // Swiggy | Zomato
  final String status; // completed | failed | cancelled
  final double earnings;
  final String pickupAddress;
  final String dropAddress;
  final DateTime timestamp;
  final int durationMinutes;

  SandboxOrder({
    required this.orderId,
    required this.platform,
    required this.status,
    required this.earnings,
    required this.pickupAddress,
    required this.dropAddress,
    required this.timestamp,
    required this.durationMinutes,
  });
}

class SandboxDriver {
  final String partnerId;
  final String fullName;
  final String initials;
  final String phone;
  final String email;
  final String city;
  final String zone;
  final String platform;
  final String emergencyContact;
  final String memberSince;
  final String tier; // Silver | Gold | Platinum
  final double weeklyPremium;
  final double totalProtected;
  final int claimsApproved;
  final String coverageStatus;
  final String nextRenewal;
  final SandboxLocation currentLocation;
  final List<SandboxLocation> locationHistory;
  final List<SandboxOrder> orderHistory;

  SandboxDriver({
    required this.partnerId,
    required this.fullName,
    required this.initials,
    required this.phone,
    required this.email,
    required this.city,
    required this.zone,
    required this.platform,
    required this.emergencyContact,
    required this.memberSince,
    required this.tier,
    required this.weeklyPremium,
    required this.totalProtected,
    required this.claimsApproved,
    required this.coverageStatus,
    required this.nextRenewal,
    required this.currentLocation,
    required this.locationHistory,
    required this.orderHistory,
  });

  /// Weekly earnings derived from completed orders
  double get weeklyEarnings => orderHistory
      .where((o) => o.status == 'completed')
      .fold(0.0, (sum, o) => sum + o.earnings);

  /// Total orders this week
  int get weeklyOrderCount => orderHistory.length;

  /// Completion rate
  double get completionRate {
    if (orderHistory.isEmpty) return 0;
    final completed = orderHistory.where((o) => o.status == 'completed').length;
    return completed / orderHistory.length;
  }
}

// ---------------------------------------------------------------------------
// Driver 1 — Sudarshan (Power User, Platinum tier, Bangalore)
// ---------------------------------------------------------------------------
final _sudarshanLocations = [
  SandboxLocation(
    lat: 12.9352,
    lng: 77.6245,
    address: 'HSR Layout Sector 2',
    zone: 'Bangalore South',
    timestamp: _today(8, 0),
  ),
  SandboxLocation(
    lat: 12.9279,
    lng: 77.6271,
    address: 'Koramangala 5th Block',
    zone: 'Bangalore South',
    timestamp: _today(9, 15),
  ),
  SandboxLocation(
    lat: 12.9141,
    lng: 77.6101,
    address: 'BTM Layout 2nd Stage',
    zone: 'Bangalore South',
    timestamp: _today(10, 30),
  ),
  SandboxLocation(
    lat: 12.9352,
    lng: 77.6245,
    address: 'HSR Layout Sector 2',
    zone: 'Bangalore South',
    timestamp: _today(12, 0),
  ),
  SandboxLocation(
    lat: 12.9716,
    lng: 77.5946,
    address: 'Indiranagar 100ft Road',
    zone: 'Bangalore Central',
    timestamp: _today(14, 45),
  ),
];

final _sudarshanOrders = [
  SandboxOrder(
    orderId: 'SWG-${_todayId()}-001',
    platform: 'Swiggy',
    status: 'completed',
    earnings: 68.0,
    pickupAddress: 'Meghana Foods, HSR',
    dropAddress: 'Sector 4, HSR',
    timestamp: _today(8, 30),
    durationMinutes: 18,
  ),
  SandboxOrder(
    orderId: 'SWG-${_todayId()}-002',
    platform: 'Swiggy',
    status: 'completed',
    earnings: 72.0,
    pickupAddress: 'Burger King, Koramangala',
    dropAddress: '5th Block, Koramangala',
    timestamp: _today(9, 45),
    durationMinutes: 22,
  ),
  SandboxOrder(
    orderId: 'ZMT-${_todayId()}-003',
    platform: 'Zomato',
    status: 'failed',
    earnings: 0.0,
    pickupAddress: 'Pizza Hut, BTM',
    dropAddress: 'BTM 1st Stage',
    timestamp: _today(11, 0),
    durationMinutes: 0,
  ),
  SandboxOrder(
    orderId: 'SWG-${_todayId()}-004',
    platform: 'Swiggy',
    status: 'completed',
    earnings: 85.0,
    pickupAddress: 'Truffles, Koramangala',
    dropAddress: 'HSR Sector 6',
    timestamp: _today(12, 30),
    durationMinutes: 28,
  ),
  SandboxOrder(
    orderId: 'SWG-${_todayId()}-005',
    platform: 'Swiggy',
    status: 'completed',
    earnings: 61.0,
    pickupAddress: 'Dominos, Indiranagar',
    dropAddress: '12th Main, Indiranagar',
    timestamp: _today(15, 10),
    durationMinutes: 15,
  ),
  SandboxOrder(
    orderId: 'ZMT-${_todayId()}-006',
    platform: 'Zomato',
    status: 'completed',
    earnings: 78.0,
    pickupAddress: 'Biryani Blues, HSR',
    dropAddress: 'Sector 1, HSR',
    timestamp: _today(17, 0),
    durationMinutes: 20,
  ),
  SandboxOrder(
    orderId: 'SWG-${_todayId()}-007',
    platform: 'Swiggy',
    status: 'completed',
    earnings: 90.0,
    pickupAddress: 'Social, Koramangala',
    dropAddress: '4th Block, Koramangala',
    timestamp: _today(19, 30),
    durationMinutes: 25,
  ),
];

final sandboxDriverSudarshan = SandboxDriver(
  partnerId: 'SWG-9284-912',
  fullName: 'Sudarshan K.',
  initials: 'SK',
  phone: '+91 98XXXXXX10',
  email: 'sudarshan.k@gigpartner.in',
  city: 'Bangalore',
  zone: 'Bangalore South — HSR Layout',
  platform: 'Swiggy + Zomato',
  emergencyContact: 'Kavitha K.',
  memberSince: 'Jan 2024',
  tier: 'Platinum',
  weeklyPremium: 199.0,
  totalProtected: 24800.0,
  claimsApproved: 8,
  coverageStatus: 'Active',
  nextRenewal: _renewalDate(7),
  currentLocation: SandboxLocation(
    lat: 12.9716,
    lng: 77.5946,
    address: 'Indiranagar 100ft Road',
    zone: 'Bangalore Central',
    timestamp: _today(14, 45),
  ),
  locationHistory: _sudarshanLocations,
  orderHistory: _sudarshanOrders,
);

// ---------------------------------------------------------------------------
// Driver 2 — Dakshina Moorthy (Full-Time Earner, Gold tier, Chennai)
// ---------------------------------------------------------------------------
final _dakshinaLocations = [
  SandboxLocation(
    lat: 13.0827,
    lng: 80.2707,
    address: 'Anna Nagar West',
    zone: 'Chennai North',
    timestamp: _today(8, 0),
  ),
  SandboxLocation(
    lat: 13.0569,
    lng: 80.2425,
    address: 'Vadapalani Junction',
    zone: 'Chennai Central',
    timestamp: _today(10, 0),
  ),
  SandboxLocation(
    lat: 13.0358,
    lng: 80.2108,
    address: 'Ashok Nagar',
    zone: 'Chennai Central',
    timestamp: _today(12, 30),
  ),
  SandboxLocation(
    lat: 13.0569,
    lng: 80.2425,
    address: 'Vadapalani Junction',
    zone: 'Chennai Central',
    timestamp: _today(15, 0),
  ),
  SandboxLocation(
    lat: 13.0827,
    lng: 80.2707,
    address: 'Anna Nagar West',
    zone: 'Chennai North',
    timestamp: _today(18, 0),
  ),
];

final _dakshinaOrders = [
  SandboxOrder(
    orderId: 'SWG-${_todayId()}-101',
    platform: 'Swiggy',
    status: 'completed',
    earnings: 55.0,
    pickupAddress: 'Saravana Bhavan, Anna Nagar',
    dropAddress: 'Anna Nagar 2nd Ave',
    timestamp: _today(8, 45),
    durationMinutes: 20,
  ),
  SandboxOrder(
    orderId: 'SWG-${_todayId()}-102',
    platform: 'Swiggy',
    status: 'completed',
    earnings: 62.0,
    pickupAddress: 'KFC, Vadapalani',
    dropAddress: 'Ashok Nagar 10th Ave',
    timestamp: _today(10, 30),
    durationMinutes: 24,
  ),
  SandboxOrder(
    orderId: 'SWG-${_todayId()}-103',
    platform: 'Swiggy',
    status: 'cancelled',
    earnings: 0.0,
    pickupAddress: 'Dominos, Ashok Nagar',
    dropAddress: 'Virugambakkam',
    timestamp: _today(12, 0),
    durationMinutes: 0,
  ),
  SandboxOrder(
    orderId: 'ZMT-${_todayId()}-104',
    platform: 'Zomato',
    status: 'completed',
    earnings: 70.0,
    pickupAddress: 'Anjappar, Vadapalani',
    dropAddress: 'Koyambedu',
    timestamp: _today(13, 15),
    durationMinutes: 30,
  ),
  SandboxOrder(
    orderId: 'SWG-${_todayId()}-105',
    platform: 'Swiggy',
    status: 'completed',
    earnings: 58.0,
    pickupAddress: 'Subway, Anna Nagar',
    dropAddress: 'Anna Nagar East',
    timestamp: _today(16, 0),
    durationMinutes: 18,
  ),
  SandboxOrder(
    orderId: 'ZMT-${_todayId()}-106',
    platform: 'Zomato',
    status: 'completed',
    earnings: 75.0,
    pickupAddress: 'Murugan Idli, Anna Nagar',
    dropAddress: 'Thirumangalam',
    timestamp: _today(19, 0),
    durationMinutes: 22,
  ),
];

final sandboxDriverDakshina = SandboxDriver(
  partnerId: 'ZMT-4471-338',
  fullName: 'Dakshina Moorthy',
  initials: 'DM',
  phone: '+91 94XXXXXX22',
  email: 'dakshina.m@gigpartner.in',
  city: 'Chennai',
  zone: 'Chennai Central — Anna Nagar',
  platform: 'Swiggy + Zomato',
  emergencyContact: 'Meenakshi M.',
  memberSince: 'Mar 2023',
  tier: 'Gold',
  weeklyPremium: 99.0,
  totalProtected: 18400.0,
  claimsApproved: 6,
  coverageStatus: 'Active',
  nextRenewal: _renewalDate(5),
  currentLocation: SandboxLocation(
    lat: 13.0569,
    lng: 80.2425,
    address: 'Vadapalani Junction',
    zone: 'Chennai Central',
    timestamp: _today(15, 0),
  ),
  locationHistory: _dakshinaLocations,
  orderHistory: _dakshinaOrders,
);

// ---------------------------------------------------------------------------
// Driver 3 — Sudha (Part-Time Operator, Silver tier, Kolkata)
// ---------------------------------------------------------------------------
final _sudhaLocations = [
  SandboxLocation(
    lat: 22.5726,
    lng: 88.3639,
    address: 'Park Street',
    zone: 'Kolkata Central',
    timestamp: _today(10, 0),
  ),
  SandboxLocation(
    lat: 22.5448,
    lng: 88.3426,
    address: 'Ballygunge',
    zone: 'Kolkata South',
    timestamp: _today(11, 30),
  ),
  SandboxLocation(
    lat: 22.5204,
    lng: 88.3637,
    address: 'Tollygunge',
    zone: 'Kolkata South',
    timestamp: _today(13, 0),
  ),
  SandboxLocation(
    lat: 22.5448,
    lng: 88.3426,
    address: 'Ballygunge',
    zone: 'Kolkata South',
    timestamp: _today(15, 30),
  ),
  SandboxLocation(
    lat: 22.5726,
    lng: 88.3639,
    address: 'Park Street',
    zone: 'Kolkata Central',
    timestamp: _today(17, 0),
  ),
];

final _sudhaOrders = [
  SandboxOrder(
    orderId: 'SWG-${_todayId()}-201',
    platform: 'Swiggy',
    status: 'completed',
    earnings: 45.0,
    pickupAddress: 'Peter Cat, Park Street',
    dropAddress: 'Camac Street',
    timestamp: _today(10, 30),
    durationMinutes: 15,
  ),
  SandboxOrder(
    orderId: 'SWG-${_todayId()}-202',
    platform: 'Swiggy',
    status: 'completed',
    earnings: 52.0,
    pickupAddress: 'Arsalan, Ballygunge',
    dropAddress: 'Gariahat',
    timestamp: _today(12, 0),
    durationMinutes: 20,
  ),
  SandboxOrder(
    orderId: 'SWG-${_todayId()}-203',
    platform: 'Swiggy',
    status: 'completed',
    earnings: 38.0,
    pickupAddress: 'Kewpies, Elgin',
    dropAddress: 'Tollygunge',
    timestamp: _today(13, 45),
    durationMinutes: 25,
  ),
  SandboxOrder(
    orderId: 'ZMT-${_todayId()}-204',
    platform: 'Zomato',
    status: 'failed',
    earnings: 0.0,
    pickupAddress: 'Mocambo, Park Street',
    dropAddress: 'Esplanade',
    timestamp: _today(15, 0),
    durationMinutes: 0,
  ),
  SandboxOrder(
    orderId: 'SWG-${_todayId()}-205',
    platform: 'Swiggy',
    status: 'completed',
    earnings: 48.0,
    pickupAddress: 'Bhojohori Manna, Ballygunge',
    dropAddress: 'Rashbehari Ave',
    timestamp: _today(16, 30),
    durationMinutes: 18,
  ),
];

final sandboxDriverSudha = SandboxDriver(
  partnerId: 'SWG-7731-556',
  fullName: 'Sudha P.',
  initials: 'SP',
  phone: '+91 70XXXXXX88',
  email: 'sudha.p@gigpartner.in',
  city: 'Kolkata',
  zone: 'Kolkata South — Ballygunge',
  platform: 'Swiggy',
  emergencyContact: 'Partha P.',
  memberSince: 'Jun 2024',
  tier: 'Silver',
  weeklyPremium: 49.0,
  totalProtected: 9200.0,
  claimsApproved: 3,
  coverageStatus: 'Active',
  nextRenewal: _renewalDate(9),
  currentLocation: SandboxLocation(
    lat: 22.5448,
    lng: 88.3426,
    address: 'Ballygunge',
    zone: 'Kolkata South',
    timestamp: _today(15, 30),
  ),
  locationHistory: _sudhaLocations,
  orderHistory: _sudhaOrders,
);

/// All available sandbox drivers
final List<SandboxDriver> allSandboxDrivers = [
  sandboxDriverSudarshan,
  sandboxDriverDakshina,
  sandboxDriverSudha,
];

