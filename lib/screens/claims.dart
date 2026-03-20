import 'package:flutter/material.dart';

class ClaimsScreen extends StatelessWidget {
  const ClaimsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Claims', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Filter', style: TextStyle(color: Colors.blueAccent)),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildClaimCard(
            'CLM-9824-21',
            'Severe Weather Downtime',
            'Oct 12, 2026',
            'Approved',
            '₹ 450.00',
            Colors.green,
          ),
          const SizedBox(height: 16),
          _buildClaimCard(
            'CLM-9102-54',
            'App Outage (Swiggy API)',
            'Sep 29, 2026',
            'Processing',
            'Pending',
            Colors.orange,
          ),
          const SizedBox(height: 16),
          _buildClaimCard(
            'CLM-8833-12',
            'Accident Coverage Base',
            'Aug 14, 2026',
            'Rejected',
            '₹ 0.00',
            Colors.redAccent,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.add_moderator, color: Colors.white),
        label: const Text('New Claim', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildClaimCard(String id, String type, String date, String status, String amount, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                id,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(type, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.black54),
                  const SizedBox(width: 6),
                  Text(date, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('View Details', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, size: 12, color: Colors.blue.shade700),
            ],
          )
        ],
      ),
    );
  }
}
