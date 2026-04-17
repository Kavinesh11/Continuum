import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/models/claim_model.dart';

void main() {
  group('ClaimModel', () {
    test('required fields are assigned correctly', () {
      final claim = ClaimModel(
        claimId: 'CLM-001',
        eventType: 'heavy_rainfall',
        date: '2026-04-15',
        status: 'AutoApproved',
        amount: 250.0,
        statusColor: Colors.green,
      );

      expect(claim.claimId, 'CLM-001');
      expect(claim.eventType, 'heavy_rainfall');
      expect(claim.date, '2026-04-15');
      expect(claim.status, 'AutoApproved');
      expect(claim.amount, 250.0);
      expect(claim.statusColor, Colors.green);
      expect(claim.progressPct, isNull);
      expect(claim.verificationMsg, isNull);
    });

    test('optional fields can be set', () {
      final claim = ClaimModel(
        claimId: 'CLM-002',
        eventType: 'platform_outage',
        date: '2026-04-16',
        status: 'Processing',
        amount: 500.0,
        statusColor: Colors.orange,
        progressPct: 0.75,
        verificationMsg: 'Oracle consensus reached',
      );

      expect(claim.progressPct, 0.75);
      expect(claim.verificationMsg, 'Oracle consensus reached');
    });

    test('amount can be zero for pending claims', () {
      final claim = ClaimModel(
        claimId: 'CLM-003',
        eventType: 'aqi_hazard',
        date: '2026-04-17',
        status: 'Pending',
        amount: 0.0,
        statusColor: Colors.grey,
      );

      expect(claim.amount, 0.0);
    });
  });
}
