function daysAgo(n: number, time: string): string {
  const dt = new Date();
  dt.setDate(dt.getDate() - n);
  const y = dt.getFullYear();
  const m = String(dt.getMonth() + 1).padStart(2, "0");
  const d = String(dt.getDate()).padStart(2, "0");
  return `${y}-${m}-${d} ${time}`;
}

// ── Personas ──────────────────────────────────────────────────────────────────

export const personas = {
  executive: { name: "Vikram Anand",     role: "CEO",                initials: "VA", color: "#8B5CF6" },
  ops:       { name: "Arjun Mehta",      role: "Platform Engineer",  initials: "AM", color: "#F59E0B" },
  adjuster:  { name: "Preethi Nair",     role: "Claims Adjuster",    initials: "PN", color: "#008A8A" },
} as const;

export type PersonaKey = keyof typeof personas;

// ── Operations KPIs (existing) ────────────────────────────────────────────────

export const initialReviewerProfile = {
  reviewer_id: "REV-001",
  full_name: "Preethi Nair",
  role: "Claims Reviewer",
  region: "South & East India",
  assigned_zones: ["BLR-South", "BLR-North", "CHN-Central", "KOL-South"],
  claims_reviewed_today: 14,
  avg_review_time_mins: 4.2,
};

export const initialKpis = {
  pendingQueue: 23,
  approvedToday: 41,
  rejectedToday: 6,
  fraudFlagged: 2,
  reserveRunwayDays: 94,
  zonesActive: 3,
  zonesTotal: 3,
  avgPayout: 284,
  totalPayoutToday: 11644,
};

// ── Executive KPIs ────────────────────────────────────────────────────────────

export const initialExecutiveKpis = {
  lossRatio: 76,            // % — danger > 100
  bcr: 1.18,                // benefit-cost ratio — danger < 1.05
  brierScore: 0.14,         // model accuracy — danger > 0.20
  partnerRetention: 92,     // % renewing after first claim
  activePolicies: 4820,
  reserveRunwayDays: 94,
  totalPayoutMTD: 284000,
  avgPayoutPerClaim: 284,
  weeklyPayoutTrend: [48200, 52100, 44800, 61300, 58900, 67400, 71200],
  zoneMetrics: [
    { zone: "BLR-South",   policies: 2140, lossRatio: 82, bcr: 1.11, status: "Healthy"  },
    { zone: "CHN-Central", policies: 1680, lossRatio: 71, bcr: 1.29, status: "Healthy"  },
    { zone: "KOL-South",   policies: 1000, lossRatio: 68, bcr: 1.35, status: "Optimal"  },
  ],
};

// ── Ops / Platform Health ─────────────────────────────────────────────────────

export const initialOpsHealth = {
  services: [
    { name: "Oracle Engine",    status: "healthy",  latencyMs: 142,  uptime: 99.91 },
    { name: "Claims Scoring",   status: "healthy",  latencyMs: 38,   uptime: 99.98 },
    { name: "Crew-AI Agents",   status: "healthy",  latencyMs: 890,  uptime: 99.71 },
    { name: "FastAPI Gateway",  status: "healthy",  latencyMs: 28,   uptime: 99.99 },
    { name: "UPI Disbursement", status: "degraded", latencyMs: 1240, uptime: 98.30 },
  ],
  kafkaQueues: [
    { topic: "fraud_queue",     lag: 3 },
    { topic: "payout_queue",    lag: 0 },
    { topic: "oracle_triggers", lag: 1 },
  ],
  oracleFeeds: [
    { name: "IMD India",    status: "nominal", confidence: 0.88, lastPollMs: 142 },
    { name: "AccuWeather",  status: "nominal", confidence: 0.79, lastPollMs: 310 },
    { name: "NASA-GPM",     status: "nominal", confidence: 0.72, lastPollMs: 890 },
    { name: "CPCB AQI",     status: "nominal", confidence: 0.94, lastPollMs: 210 },
    { name: "DownDetector", status: "alert",   confidence: 0.61, lastPollMs: 320 },
  ],
  eventLog: [
    { ts: daysAgo(0, "09:18"), type: "oracle",  msg: "Oracle consensus reached — BLR-South flood confirmed (3/4 affirm)" },
    { ts: daysAgo(0, "09:12"), type: "kafka",   msg: "fraud_queue consumer caught up — lag 3 → 0" },
    { ts: daysAgo(0, "09:04"), type: "payout",  msg: "UPI disbursement ₹450 — UPI/050526/CONT847312 — 1.24 s latency" },
    { ts: daysAgo(0, "08:55"), type: "scoring", msg: "CLM-9102-54 scored: isolation-forest 0.71 → fraud_queue" },
    { ts: daysAgo(0, "08:44"), type: "oracle",  msg: "IMD India poll: rainfall 82 mm/hr — confidence 0.88" },
    { ts: daysAgo(0, "08:31"), type: "health",  msg: "UPI Disbursement latency spike: 420 ms → 1240 ms (under investigation)" },
    { ts: daysAgo(0, "08:20"), type: "kafka",   msg: "payout_queue flushed — 12 jobs processed, lag 0" },
    { ts: daysAgo(0, "08:10"), type: "scoring", msg: "Claims Scoring service restarted — cold start 38 ms" },
  ],
};

// ── Claims ────────────────────────────────────────────────────────────────────

export const initialClaims = [
  {
    id: "CLM-9824-21",
    driver: "Sudarshan K.",
    tier: "Platinum",
    reason: "Severe Weather",
    description: "Heavy flooding in Koramangala disrupted all deliveries for 4 hours.",
    amount: 450,
    status: "Pending",
    priority: "High",
    fraudScore: 0.08,
    zone: "BLR-South",
    justification: "",
    submittedAt: daysAgo(0, "08:30"),
    isFraud: false,
  },
  {
    id: "CLM-7711-08",
    driver: "Dakshina Moorthy",
    tier: "Gold",
    reason: "Heavy Rain",
    description: "Anna Nagar roads waterlogged — no deliveries possible from 3pm to 7pm.",
    amount: 312,
    status: "Pending",
    priority: "High",
    fraudScore: 0.12,
    zone: "CHN-Central",
    justification: "",
    submittedAt: daysAgo(0, "07:50"),
    isFraud: false,
  },
  {
    id: "CLM-5510-44",
    driver: "Sudha P.",
    tier: "Silver",
    reason: "Network Failure",
    description: "Swiggy app showing connection errors, no order assignments for 2 hours.",
    amount: 180,
    status: "Pending",
    priority: "Medium",
    fraudScore: 0.09,
    zone: "KOL-South",
    justification: "",
    submittedAt: daysAgo(1, "18:10"),
    isFraud: false,
  },
  {
    id: "CLM-9102-54",
    driver: "Sudarshan K.",
    tier: "Platinum",
    reason: "Platform Outage",
    description: "Zomato backend down — no orders for 3 hours. Zero income window.",
    amount: 390,
    status: "Pending",
    priority: "High",
    fraudScore: 0.71,
    zone: "BLR-South",
    justification: "",
    submittedAt: daysAgo(1, "15:45"),
    isFraud: true,
  },
  {
    id: "CLM-7322-90",
    driver: "Dakshina Moorthy",
    tier: "Gold",
    reason: "Vehicle Breakdown",
    amount: 0,
    description: "Bike engine failure at Vadapalani. Could not complete shift.",
    status: "Rejected",
    priority: "Low",
    fraudScore: 0.44,
    zone: "CHN-Central",
    justification: "GPS proximity log shows worker outside disruption zone.",
    submittedAt: daysAgo(2, "14:00"),
    isFraud: false,
  },
  {
    id: "CLM-5388-19",
    driver: "Sudha P.",
    tier: "Silver",
    reason: "Severe Weather",
    description: "Cyclone warning — Ballygunge area inaccessible due to waterlogging.",
    amount: 224,
    status: "Approved",
    priority: "Medium",
    fraudScore: 0.06,
    zone: "KOL-South",
    justification: "Oracle consensus confirmed. IMD red alert active.",
    submittedAt: daysAgo(2, "10:30"),
    isFraud: false,
  },
  {
    id: "CLM-8101-33",
    driver: "Arjun P.",
    tier: "Silver",
    reason: "App Outage",
    description: "Blinkit app unresponsive for entire morning shift. Screenshot attached.",
    amount: 180,
    status: "Pending",
    priority: "Medium",
    fraudScore: 0.15,
    zone: "BLR-South",
    justification: "",
    submittedAt: daysAgo(0, "09:00"),
    isFraud: false,
  },
  {
    id: "CLM-6623-77",
    driver: "Meena S.",
    tier: "Gold",
    reason: "Waterlogging",
    description: "Adyar area completely flooded. Stuck for 5 hours with no deliveries.",
    amount: 312,
    status: "Pending",
    priority: "High",
    fraudScore: 0.19,
    zone: "CHN-Central",
    justification: "",
    submittedAt: daysAgo(0, "06:45"),
    isFraud: false,
  },
];

// ── Drivers (extended with full adjuster dossier data) ────────────────────────

export const initialDrivers = [
  {
    name: "Sudarshan K.",
    tier: "Platinum",
    zone: "BLR-South",
    platform: "Swiggy + Zomato",
    claims: 8,
    riskScore: 0.82,
    totalPayout: 24800,
    partnerId: "SWG-9284-912",
    phone: "+91 98765 43210",
    upiHandle: "sudarshan.k@ybl",
    partnerSince: "Jan 2024",
    weeklyPremium: 199,
    totalCoverage: 24800,
    premiumsPaid: 17,
    premiumsMissed: 0,
    gpsZoneHistory: "Consistent zone presence (BLR-South, 45+ min soak confirmed on all approved claims)",
    recentOrders: [
      { date: daysAgo(0, "11:30"), platform: "Swiggy",  earnings: 85,  completed: true  },
      { date: daysAgo(0, "09:10"), platform: "Zomato",  earnings: 72,  completed: true  },
      { date: daysAgo(1, "18:45"), platform: "Swiggy",  earnings: 0,   completed: false },
      { date: daysAgo(1, "14:22"), platform: "Zomato",  earnings: 68,  completed: true  },
      { date: daysAgo(2, "12:00"), platform: "Swiggy",  earnings: 90,  completed: true  },
      { date: daysAgo(2, "09:30"), platform: "Zomato",  earnings: 61,  completed: true  },
      { date: daysAgo(3, "16:10"), platform: "Swiggy",  earnings: 78,  completed: true  },
    ],
    claimHistory: [
      { id: "CLM-9824-21", date: daysAgo(0, "08:30"),  reason: "Severe Weather",   amount: 450, status: "Pending"  },
      { id: "CLM-9102-54", date: daysAgo(1, "15:45"),  reason: "Platform Outage",  amount: 390, status: "Pending"  },
      { id: "CLM-8833-12", date: daysAgo(13, "10:00"), reason: "Severe Weather",   amount: 247, status: "Approved" },
      { id: "CLM-8120-07", date: daysAgo(21, "14:30"), reason: "Network Failure",  amount: 312, status: "Approved" },
      { id: "CLM-7901-44", date: daysAgo(35, "08:15"), reason: "Heavy Rain",       amount: 450, status: "Approved" },
    ],
    securityEvents: [
      { date: daysAgo(7, "11:00"),  event: "Routine re-attestation (JWT refresh)", outcome: "Cleared" },
      { date: daysAgo(14, "09:30"), event: "Device fingerprint updated",            outcome: "Cleared" },
      { date: daysAgo(30, "16:45"), event: "PlayIntegrity check on claim submit",   outcome: "Cleared" },
    ],
  },
  {
    name: "Dakshina Moorthy",
    tier: "Gold",
    zone: "CHN-Central",
    platform: "Swiggy + Zomato",
    claims: 6,
    riskScore: 0.65,
    totalPayout: 18400,
    partnerId: "ZMT-4471-338",
    phone: "+91 94440 22110",
    upiHandle: "dakshina.m@okicici",
    partnerSince: "Mar 2023",
    weeklyPremium: 99,
    totalCoverage: 18400,
    premiumsPaid: 27,
    premiumsMissed: 1,
    gpsZoneHistory: "Mostly consistent (CHN-Central). One adjacent-zone soak on 2026-04-18 — grace applied.",
    recentOrders: [
      { date: daysAgo(0, "10:00"), platform: "Zomato", earnings: 62,  completed: true  },
      { date: daysAgo(1, "17:30"), platform: "Swiggy", earnings: 55,  completed: true  },
      { date: daysAgo(2, "13:00"), platform: "Zomato", earnings: 70,  completed: true  },
      { date: daysAgo(2, "14:00"), platform: "Swiggy", earnings: 0,   completed: false },
      { date: daysAgo(3, "09:45"), platform: "Zomato", earnings: 58,  completed: true  },
      { date: daysAgo(4, "11:20"), platform: "Swiggy", earnings: 75,  completed: true  },
      { date: daysAgo(5, "08:30"), platform: "Zomato", earnings: 66,  completed: true  },
    ],
    claimHistory: [
      { id: "CLM-7711-08", date: daysAgo(0, "07:50"),  reason: "Heavy Rain",        amount: 312, status: "Pending"  },
      { id: "CLM-7322-90", date: daysAgo(2, "14:00"),  reason: "Vehicle Breakdown", amount: 0,   status: "Rejected" },
      { id: "CLM-7101-55", date: daysAgo(10, "09:00"), reason: "App Outage",        amount: 180, status: "Approved" },
      { id: "CLM-6844-21", date: daysAgo(22, "15:00"), reason: "Heavy Rain",        amount: 312, status: "Approved" },
      { id: "CLM-6611-08", date: daysAgo(40, "10:30"), reason: "Severe Weather",    amount: 312, status: "Approved" },
    ],
    securityEvents: [
      { date: daysAgo(5, "08:00"),  event: "Routine re-attestation", outcome: "Cleared" },
      { date: daysAgo(20, "14:00"), event: "PlayIntegrity check",     outcome: "Cleared" },
    ],
  },
  {
    name: "Sudha P.",
    tier: "Silver",
    zone: "KOL-South",
    platform: "Swiggy",
    claims: 3,
    riskScore: 0.48,
    totalPayout: 9200,
    partnerId: "SWG-7731-556",
    phone: "+91 90330 11220",
    upiHandle: "sudha.p@paytm",
    partnerSince: "Jun 2024",
    weeklyPremium: 49,
    totalCoverage: 9200,
    premiumsPaid: 9,
    premiumsMissed: 0,
    gpsZoneHistory: "Consistent zone presence (KOL-South). All soak periods verified.",
    recentOrders: [
      { date: daysAgo(1, "18:10"), platform: "Swiggy", earnings: 48,  completed: true  },
      { date: daysAgo(2, "14:30"), platform: "Swiggy", earnings: 52,  completed: true  },
      { date: daysAgo(3, "11:00"), platform: "Swiggy", earnings: 0,   completed: false },
      { date: daysAgo(3, "09:15"), platform: "Swiggy", earnings: 45,  completed: true  },
      { date: daysAgo(4, "16:20"), platform: "Swiggy", earnings: 38,  completed: true  },
    ],
    claimHistory: [
      { id: "CLM-5510-44", date: daysAgo(1, "18:10"),  reason: "Network Failure", amount: 180, status: "Pending"  },
      { id: "CLM-5388-19", date: daysAgo(2, "10:30"),  reason: "Severe Weather",  amount: 224, status: "Approved" },
      { id: "CLM-5201-07", date: daysAgo(15, "09:00"), reason: "App Outage",      amount: 99,  status: "Approved" },
    ],
    securityEvents: [
      { date: daysAgo(3, "10:00"),  event: "Routine re-attestation",              outcome: "Cleared" },
      { date: daysAgo(10, "15:30"), event: "SIM swap attempt detected (blocked)",  outcome: "Blocked — payout frozen 2h pending re-KYC" },
    ],
  },
  {
    name: "Arjun P.",
    tier: "Silver",
    zone: "BLR-South",
    platform: "Blinkit",
    claims: 2,
    riskScore: 0.51,
    totalPayout: 4100,
    partnerId: "BLK-3312-441",
    phone: "+91 87650 33210",
    upiHandle: "arjun.p@ybl",
    partnerSince: "Sep 2024",
    weeklyPremium: 49,
    totalCoverage: 9200,
    premiumsPaid: 8,
    premiumsMissed: 0,
    gpsZoneHistory: "Consistent (BLR-South). Cell-ID corroborates GPS on all submissions.",
    recentOrders: [
      { date: daysAgo(0, "09:00"), platform: "Blinkit", earnings: 55,  completed: true  },
      { date: daysAgo(1, "13:30"), platform: "Blinkit", earnings: 62,  completed: true  },
      { date: daysAgo(2, "10:00"), platform: "Blinkit", earnings: 0,   completed: false },
      { date: daysAgo(3, "11:45"), platform: "Blinkit", earnings: 48,  completed: true  },
    ],
    claimHistory: [
      { id: "CLM-8101-33", date: daysAgo(0, "09:00"),  reason: "App Outage",     amount: 180, status: "Pending"  },
      { id: "CLM-8044-21", date: daysAgo(18, "14:00"), reason: "Severe Weather", amount: 180, status: "Approved" },
    ],
    securityEvents: [
      { date: daysAgo(8, "09:00"), event: "Routine re-attestation", outcome: "Cleared" },
    ],
  },
  {
    name: "Meena S.",
    tier: "Gold",
    zone: "CHN-Central",
    platform: "Zomato",
    claims: 4,
    riskScore: 0.67,
    totalPayout: 11600,
    partnerId: "ZMT-5512-229",
    phone: "+91 99440 55100",
    upiHandle: "meena.s@okaxis",
    partnerSince: "Nov 2023",
    weeklyPremium: 99,
    totalCoverage: 18400,
    premiumsPaid: 22,
    premiumsMissed: 2,
    gpsZoneHistory: "Mostly consistent. One GPS-cell divergence (>2 km) flagged on 2026-04-22 — 0.3 spatial penalty applied.",
    recentOrders: [
      { date: daysAgo(0, "06:45"), platform: "Zomato", earnings: 0,   completed: false },
      { date: daysAgo(1, "10:30"), platform: "Zomato", earnings: 72,  completed: true  },
      { date: daysAgo(2, "09:15"), platform: "Zomato", earnings: 65,  completed: true  },
      { date: daysAgo(3, "12:00"), platform: "Zomato", earnings: 80,  completed: true  },
    ],
    claimHistory: [
      { id: "CLM-6623-77", date: daysAgo(0, "06:45"),  reason: "Waterlogging",   amount: 312, status: "Pending"  },
      { id: "CLM-6411-33", date: daysAgo(12, "10:00"), reason: "Heavy Rain",      amount: 312, status: "Approved" },
      { id: "CLM-6102-18", date: daysAgo(28, "14:30"), reason: "App Outage",      amount: 180, status: "Approved" },
      { id: "CLM-5888-44", date: daysAgo(45, "09:00"), reason: "Network Failure", amount: 180, status: "Approved" },
    ],
    securityEvents: [
      { date: daysAgo(4, "11:30"),  event: "Routine re-attestation",                          outcome: "Cleared" },
      { date: daysAgo(22, "16:00"), event: "GPS-cell divergence >2 km flagged on claim submit", outcome: "0.3 spatial penalty applied" },
    ],
  },
  {
    name: "Ravi T.",
    tier: "Platinum",
    zone: "BLR-North",
    platform: "Swiggy",
    claims: 9,
    riskScore: 0.79,
    totalPayout: 28300,
    partnerId: "SWG-1122-884",
    phone: "+91 96770 44321",
    upiHandle: "ravi.t@ybl",
    partnerSince: "Oct 2023",
    weeklyPremium: 199,
    totalCoverage: 24800,
    premiumsPaid: 29,
    premiumsMissed: 1,
    gpsZoneHistory: "Consistent (BLR-North). High claim frequency (9 claims, 90d cap: 3) — velocity flag active.",
    recentOrders: [
      { date: daysAgo(0, "10:00"), platform: "Swiggy", earnings: 90,  completed: true  },
      { date: daysAgo(1, "09:30"), platform: "Swiggy", earnings: 85,  completed: true  },
      { date: daysAgo(2, "11:00"), platform: "Swiggy", earnings: 78,  completed: true  },
      { date: daysAgo(3, "08:45"), platform: "Swiggy", earnings: 92,  completed: true  },
      { date: daysAgo(4, "10:15"), platform: "Swiggy", earnings: 88,  completed: true  },
    ],
    claimHistory: [
      { id: "CLM-2211-44", date: daysAgo(1, "10:00"),  reason: "Heavy Rain",     amount: 450, status: "Approved" },
      { id: "CLM-2101-33", date: daysAgo(8, "09:00"),  reason: "App Outage",     amount: 312, status: "Approved" },
      { id: "CLM-1988-21", date: daysAgo(18, "14:00"), reason: "Severe Weather", amount: 450, status: "Approved" },
      { id: "CLM-1877-08", date: daysAgo(32, "11:30"), reason: "Network Failure", amount: 312, status: "Approved" },
      { id: "CLM-1744-55", date: daysAgo(50, "08:00"), reason: "Heavy Rain",     amount: 450, status: "Approved" },
    ],
    securityEvents: [
      { date: daysAgo(2, "08:00"),  event: "Routine re-attestation",                   outcome: "Cleared" },
      { date: daysAgo(15, "12:00"), event: "Velocity cap warning: 4 claims in 90 days", outcome: "Flagged — adjuster review required" },
    ],
  },
];

// ── Audit logs ────────────────────────────────────────────────────────────────

export const initialAuditLogs = [
  { timestamp: daysAgo(0, "09:14"), actor: "Preethi Nair", action: "APPROVED",      target: "CLM-5388-19", details: "₹224, Severe Weather — oracle consensus confirmed" },
  { timestamp: daysAgo(0, "09:02"), actor: "Preethi Nair", action: "REJECTED",      target: "CLM-7322-90", details: "₹0, Vehicle Breakdown — outside disruption zone" },
  { timestamp: daysAgo(1, "17:41"), actor: "System",       action: "AUTO-APPROVED", target: "CLM-8833-12", details: "₹247, oracle 3/4 consensus (IMD + AccuWeather + NASA-GPM)" },
  { timestamp: daysAgo(1, "16:22"), actor: "Preethi Nair", action: "REJECTED",      target: "CLM-9102-54", details: "fraud score 0.71 — isolation-forest anomaly detected" },
  { timestamp: daysAgo(1, "14:09"), actor: "Preethi Nair", action: "APPROVED",      target: "CLM-6101-88", details: "₹312, Heavy Rain — CHN-Central" },
];

// ── Simulation notification pool (cycles during live demo) ───────────────────

export const simulationNotifications = [
  "[RAIN] BLR-South rainfall advisory — oracle consensus building (2/4)",
  "[DEBIT] Premium debit Rs.199 — Sudarshan K. (auto-renewed)",
  "[ALERT] CLM-9102-54 fraud score 0.81 — crew-AI escalation",
  "[ORACLE] Oracle consensus reached — BLR-South flood confirmed (3/4)",
  "[UPI] Disbursement Rs.450 sent — UPI/050526/CONT847312",
  "[FLOOD] CHN-Central waterlogging detected — advisory issued",
  "[LOCK] BLR-North adverse selection monitor: 3 claims in 2 hrs",
  "[SHIELD] IdentityAnchor™ re-attestation — DRV-9988 cleared",
  "[RESERVE] Rs.8.4L disbursed MTD — runway 94 days",
  "[SCORE] Brier score recalculated: 0.14 — within CI gate",
];

// ── Claim templates for live simulation generator ─────────────────────────────

export const claimTemplates = [
  { driver: "Sudarshan K.",    tier: "Platinum", zone: "BLR-South",   reason: "Severe Weather",   amount: 450, fraudScore: 0.08 },
  { driver: "Dakshina Moorthy",tier: "Gold",     zone: "CHN-Central", reason: "Heavy Rain",        amount: 312, fraudScore: 0.12 },
  { driver: "Meena S.",        tier: "Gold",     zone: "CHN-Central", reason: "Waterlogging",      amount: 312, fraudScore: 0.19 },
  { driver: "Arjun P.",        tier: "Silver",   zone: "BLR-South",   reason: "App Outage",        amount: 180, fraudScore: 0.15 },
  { driver: "Sudha P.",        tier: "Silver",   zone: "KOL-South",   reason: "Network Failure",   amount: 180, fraudScore: 0.09 },
  { driver: "Ravi T.",         tier: "Platinum", zone: "BLR-North",   reason: "Platform Outage",   amount: 450, fraudScore: 0.22 },
];

// ── Risk Intelligence incident seeds ─────────────────────────────────────────

export const initialGeoFenceIncidents = [
  { id: "CLM-4491-77", driver: "Ranjit S.",  zone: "BLR-South",  entryDelta: "8 min before trigger",  soakMinutes: 8,  outcome: "Blocked", detail: "Entry detected 8 min before flood trigger. Soak threshold: 45 min." },
  { id: "CLM-3302-14", driver: "Meena V.",   zone: "CHN-Central",entryDelta: "12 min before trigger", soakMinutes: 12, outcome: "Blocked", detail: "GPS jump from OMR to flood zone 12 min pre-trigger. Static-lock flag raised." },
  { id: "CLM-8821-03", driver: "Harish D.",  zone: "BLR-North",  entryDelta: "51 min before trigger", soakMinutes: 51, outcome: "Paid",    detail: "Soak period satisfied. Genuine pre-positioning confirmed by cell-ID corroboration." },
];

export const initialTrustSignalIncidents = [
  { id: "ORC-001", time: daysAgo(3, "14:31"), source: "AccuWeather Feed", event: "TLS certificate mismatch",         outcome: "Nullified", detail: "Vote counted as OFFLINE. Benefit-of-doubt protocol engaged (2/4 online, 1 affirm → 50% cap)." },
  { id: "ORC-002", time: daysAgo(2, "09:17"), source: "IMD API",          event: "Stale data replay (22 min old)",   outcome: "Abstained", detail: "Data timestamp 22 min old. Vote converted to ABSTAIN — did not count toward consensus." },
  { id: "ORC-003", time: daysAgo(1, "18:55"), source: "NASA GPM",         event: "Valid response",                   outcome: "Affirm",    detail: "Certificate pinning passed. Fresh data (<8 min). Vote counted in consensus." },
];

export const initialIdentityAnchorIncidents = [
  { id: "DRV-7712", driver: "Priya K.",  event: "SIM swap detected",          trigger: "New IMSI on known device — 3-hour window",          outcome: "Payout Frozen", detail: "UPI handle unchanged but IMSI rotated. Payout frozen pending re-attestation via PlayIntegrity + OTP." },
  { id: "DRV-3301", driver: "Selvam R.", event: "New device binding attempt",  trigger: "PlayIntegrity verdict: FAILS_BASIC_INTEGRITY",       outcome: "Rejected",      detail: "Device attestation failed. JWT revoked. Account locked for 24h pending manual KYC re-verification." },
  { id: "DRV-9988", driver: "Anita B.",  event: "Routine re-attestation",      trigger: "JWT nearing 24h expiry — auto-refreshed",            outcome: "Cleared",       detail: "Re-attestation passed. IMSI, device fingerprint, and UPI cross-checked. No anomaly." },
];

export const initialActivityCrossIncidents = [
  { id: "CLM-5541-99", driver: "Venkat P.", platform: "Swiggy",         ordersFound: 3, claimWindow: "15:00–19:00", outcome: "Vetoed",    detail: "3 orders completed on Swiggy during claimed disruption window. Platform API veto applied — claim auto-rejected." },
  { id: "CLM-6632-07", driver: "Deepa N.",  platform: "Zomato",         ordersFound: 1, claimWindow: "10:00–14:00", outcome: "Escalated", detail: "1 order found. Partial activity — escalated to human reviewer. Possible order accepted before disruption widened." },
  { id: "CLM-8870-12", driver: "Sunil T.",  platform: "Swiggy + Zomato",ordersFound: 0, claimWindow: "09:00–13:00", outcome: "Eligible",  detail: "Zero orders on both platforms during window. No active-work signal. Claim auto-approved at oracle consensus." },
];

export const initialFairTimeIncidents = [
  { id: "OUT-2205-01", zone: "BLR-South",   outageWindow: "01:45–04:30", outageHours: 2.75, driverActiveHours: 0,   overlapHours: 0,   benefitPct: 0,  outcome: "₹0 paid",   detail: "Outage occurred 1:45–4:30 AM. Driver's last active order was 23:10. Zero overlap → ₹0 benefit." },
  { id: "OUT-2205-02", zone: "CHN-Central", outageWindow: "07:00–10:00", outageHours: 3,    driverActiveHours: 2.5, overlapHours: 2.5, benefitPct: 83, outcome: "₹374 paid", detail: "Outage 7–10 AM. Driver active 7:00–9:30 (2.5h overlap out of 3h outage = 83% benefit)." },
  { id: "OUT-2205-03", zone: "KOL-South",   outageWindow: "02:00–05:00", outageHours: 3,    driverActiveHours: 1,   overlapHours: 1,   benefitPct: 33, outcome: "₹149 paid", detail: "Late-night shift driver — 1h overlap with outage. 33% proportional benefit applied." },
];
