import 'package:flutter/material.dart';

class StatusTrackerScreen extends StatelessWidget {
  const StatusTrackerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Status Tracker', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(color: Colors.orange.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.orange, size: 36),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Claim CLM-9102-54', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 4),
                      Text('Estimated payout in 4 hours', style: TextStyle(color: Colors.black54, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 24),
            _buildTimelineNode(
              isCompleted: true,
              isFirst: true,
              isLast: false,
              title: 'Claim Initiated',
              time: '10:00 AM, Sep 29',
              description: 'Automated trigger via Downdetector API.',
            ),
            _buildTimelineNode(
              isCompleted: true,
              isFirst: false,
              isLast: false,
              title: 'Oracle Verification',
              time: '10:15 AM, Sep 29',
              description: 'Downtime verified by 3 independent nodes.',
            ),
            _buildTimelineNode(
              isCompleted: false,
              isFirst: false,
              isLast: false,
              title: 'Funds Processing',
              time: 'In Progress',
              description: 'Smart contract executing transfer queue to UPI.',
            ),
            _buildTimelineNode(
              isCompleted: false,
              isFirst: false,
              isLast: true,
              title: 'Payout Completed',
              time: 'Pending',
              description: 'Awaiting confirmation from bank.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineNode({
    required bool isCompleted,
    required bool isFirst,
    required bool isLast,
    required String title,
    required String time,
    required String description,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? Colors.green : Colors.grey.shade300,
                  border: isCompleted ? null : Border.all(color: Colors.grey.shade400, width: 2),
                ),
                child: isCompleted ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? Colors.green : Colors.grey.shade300,
                  ),
                )
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isCompleted ? Colors.black87 : Colors.black54)),
                  const SizedBox(height: 4),
                  Text(time, style: TextStyle(color: isCompleted ? Colors.green[700] : Colors.black38, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(description, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
