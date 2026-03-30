import 'package:flutter/material.dart';
import '../data/mock_data.dart';

class StatusTrackerScreen extends StatelessWidget {
  const StatusTrackerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final detail = MockData.claimStatusDetail as Map<String, dynamic>;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Claim Status', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusHeader(detail),
              const SizedBox(height: 24),
              _buildProgressTracker(detail),
              const SizedBox(height: 24),
              _buildPayoutCard(detail),
              const SizedBox(height: 20),
              _buildTimelineCard(detail),
              const SizedBox(height: 20),
              _buildVerificationPanel(detail),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader(Map<String, dynamic> detail) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.search, color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail['status'] as String,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                'Claim ID: ${(detail['claimId'] as String)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTracker(Map<String, dynamic> detail) {
    final stages = detail['stages'] as List<Map<String, dynamic>>;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Claim Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: stages.asMap().entries.map((entry) {
              int idx = entry.key;
              final stage = entry.value;
              final stageName = stage['name'] as String;
              final isCompleted = stage['complete'] as bool;
              final isCurrent = !isCompleted && idx > 0 && (stages[idx - 1]['complete'] == true);
              return Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? Colors.green
                              : isCurrent
                                  ? const Color(0xFF008A8A)
                                  : Colors.grey.shade300,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check, color: Colors.white, size: 24)
                              : isCurrent
                                  ? const Icon(Icons.more_horiz, color: Colors.white, size: 20)
                                  : const Text('', style: TextStyle(color: Colors.white60)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 64,
                        child: Text(
                          stageName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isCompleted || isCurrent ? Colors.black87 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (idx < stages.length - 1)
                    Container(
                      width: 24,
                      height: 2,
                      color: isCompleted ? Colors.green : Colors.grey.shade300,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPayoutCard(Map<String, dynamic> detail) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Expected Payout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          Text(
            'INR ${detail['expectedPayout']}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          const Text('On successful approval', style: TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic> detail) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Expected Timeline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          Text(
            detail['timelineText'] as String,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          const Text('If all documents are verified', style: TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildVerificationPanel(Map<String, dynamic> detail) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Verification in Progress',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail['verificationMessage'] as String,
            style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.5),
          ),
        ],
      ),
    );
  }
}
