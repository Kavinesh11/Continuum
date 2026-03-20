import 'package:flutter/material.dart';

class ClaimModel {
  final String claimId;
  final String eventType;
  final String date;
  final String status;
  final double amount;
  final Color statusColor;

  ClaimModel({
    required this.claimId,
    required this.eventType,
    required this.date,
    required this.status,
    required this.amount,
    required this.statusColor,
  });
}
