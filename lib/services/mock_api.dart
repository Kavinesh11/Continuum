import 'claim_model.dart';
import 'package:flutter/material.dart';

class MockApiService {
  static Future<List<ClaimModel>> fetchClaims() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      ClaimModel(claimId: 'CLM-9824-21', eventType: 'Severe Weather Downtime', date: 'Oct 12, 2026', status: 'Approved', amount: 450.0, statusColor: Colors.green),
      ClaimModel(claimId: 'CLM-9102-54', eventType: 'App Outage (Swiggy API)', date: 'Sep 29, 2026', status: 'Processing', amount: 0.0, statusColor: Colors.orange),
      ClaimModel(claimId: 'CLM-8833-12', eventType: 'Accident Coverage Base', date: 'Aug 14, 2026', status: 'Rejected', amount: 0.0, statusColor: Colors.redAccent),
    ];
  }
}
