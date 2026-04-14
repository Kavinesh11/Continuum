import 'package:flutter/material.dart';

class MockData {
  static const user = {
    'partnerId': 'SWG-9284-912',
    'fullName': 'Partha Sen',
    'role': 'Delivery Partner',
    'city': 'Chennai',
    'platform': 'Swiggy + Zomato',
    'phone': '+91 98XXXXXX10',
    'emergencyContact': 'Anita Sen',
    'memberSince': 'Apr 2024',
  };

  static const coverage = {
    'status': 'Active',
    'plan': 'Comprehensive',
    'nextRenewal': 'May 01',
    'renewalDate': 'May 01, 2026',
    'zone': 'Chennai',
    'premium': 20,
    'coverageType': 'SECURE',
  };

  static const currentClaim = {
    'status': 'In Review',
    'statusColor': Color(0xFFFF8C00),
    'daysAgo': 2,
  };

  static const claims = [
    {
      'id': 'CLM/261203/MAN-8291',
      'title': 'Heavy Rain / Waterlogging',
      'date': 'Yesterday',
      'amount': 198,
      'status': 'Approved',
      'statusColor': Color(0xFF4CAF50),
      'progressPct': 1.0,
      'isAuto': false,
      'description': 'Heavy rain made delivery impossible',
      'upiRef': 'UPI/294102919'
    },
    {
      'id': 'CLM/261203/REV-4192',
      'title': 'Strike',
      'date': '2 days ago',
      'amount': 0,
      'status': 'Under Review',
      'statusColor': Color(0xFFFF8C00),
      'progressPct': 0.6,
      'isAuto': false,
      'description': 'Routes were blocked by municipal order',
    },
  ];

  static const claimStatusDetail = {
    'claimId': '#00-88291',
    'status': 'Under Review',
    'stages': [
      {'name': 'SUBMITTED', 'time': '10:00 AM, Sep 10', 'complete': true},
      {'name': 'REVIEW', 'time': 'In Progress', 'complete': true},
      {'name': 'APPROVED', 'time': 'Pending', 'complete': false},
      {'name': 'PAYOUT', 'time': 'Pending', 'complete': false},
    ],
    'expectedPayout': 2850,
    'timelineText': '2-3 business days',
    'verificationMessage': 'We are verifying your details',
  };

  static const assistHero = {
    'title': 'CONTINUUM Assist Bot',
    'subtitle': 'Instant help for claims, status, payout and policy questions',
    'ctaLabel': 'Start New Chat',
  };

  static const previousChats = [
    {
      'title': 'என் பிரீமியம் திட்டம் என்ன?',
      'subtitle': 'உங்கள் பிரீமியம் திட்டம் Gold ஆகும்.',
      'date': 'Today',
    },
    {
      'title': 'Claim stuck at review stage',
      'subtitle': 'Asked about expected timeline and next checks.',
      'date': 'Today',
    },
    {
      'title': 'How to capture live evidence',
      'subtitle': 'Guidance on camera-only photo proof for claim filing.',
      'date': 'Yesterday',
    },
    {
      'title': 'Payout amount clarification',
      'subtitle': 'Asked why disruption compensation changed this month.',
      'date': '5 Mar',
    },
  ];

  static const applyDefaults = {
    'reasons': [
      'Select a reason',
      'Heavy Rain / Waterlogging',
      'App Outage (Swiggy / Zomato)',
      'Road Block',
      'Strike',
      'Lockdown',
    ],
    'dateFormat': 'dd/MM/yyyy',
    'dateHint': 'dd/MM/yyyy',
    'descriptionHint': 'What happened? Keep it simple.',
    'audioLabel': 'Audio statement (optional)',
  };

  static const profileHistory = [
    {
      'incident': 'Flood Alert Disruption Claim',
      'status': 'Approved',
      'date': 'Submitted on 14 Jan 2025',
      'detail': 'Compensated for 3 days of suspended deliveries during city flood warnings.',
    },
  ];

  static const profileStats = {
    'totalProtected': 'INR 18,400',
    'claimsApproved': 6,
  };

  static const earningsTabs = ['Yearly', 'Monthly', 'Weekly'];

  static const earningsTrend = {
    'Yearly': [8, 12, 10, 14, 9],
    'Monthly': [6, 8, 7, 9, 8],
    'Weekly': [3, 5, 4, 6, 5],
  };

  static const recentActivity = [
    {
      'title': 'Claim moved to review',
      'subtitle': 'Heavy Rain Disruption',
      'time': '2h ago',
    },
    {
      'title': 'Premium auto-debited',
      'subtitle': 'Monthly premium paid successfully',
      'time': '1d ago',
    },
  ];

  static const subscriptionPlan = {
    'planName': 'Comprehensive Shield',
    'weeklyCost': 57,
    'billingCycle': 'Weekly',
    'nextBillingDate': 'Apr 09, 2026',
    'autoPay': true,
    'coverage': 'Accident + Weather + App Outage',
  };

  static const paymentMethods = [
    {
      'id': 'upi_1',
      'type': 'UPI',
      'label': 'partha@oksbi',
      'icon': 'account_balance',
      'isDefault': true,
    },
    {
      'id': 'card_1',
      'type': 'Card',
      'label': '•••• •••• •••• 4821',
      'icon': 'credit_card',
      'isDefault': false,
    },
    {
      'id': 'upi_2',
      'type': 'UPI',
      'label': 'partha@paytm',
      'icon': 'account_balance',
      'isDefault': false,
    },
  ];

  static const paymentHistory = [
    {
      'id': 'TXN-90281',
      'date': 'Mar 26, 2026',
      'amount': 57,
      'method': 'UPI • partha@oksbi',
      'status': 'Success',
    },
    {
      'id': 'TXN-89102',
      'date': 'Mar 19, 2026',
      'amount': 57,
      'method': 'UPI • partha@oksbi',
      'status': 'Success',
    },
    {
      'id': 'TXN-87934',
      'date': 'Mar 12, 2026',
      'amount': 57,
      'method': 'Card • ••4821',
      'status': 'Success',
    },
    {
      'id': 'TXN-86011',
      'date': 'Mar 05, 2026',
      'amount': 57,
      'method': 'UPI • partha@oksbi',
      'status': 'Failed',
    },
  ];
}
