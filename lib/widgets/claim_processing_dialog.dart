import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../state/demo_state.dart';

class ClaimProcessingDialog extends StatefulWidget {
  final String selectedReason;
  final String? existingClaimId;

  const ClaimProcessingDialog({Key? key, required this.selectedReason, this.existingClaimId}) : super(key: key);

  @override
  State<ClaimProcessingDialog> createState() => _ClaimProcessingDialogState();
}

class _ClaimProcessingDialogState extends State<ClaimProcessingDialog> {
  bool _isProcessing = true;
  String _processingText = 'Submitting claim...';
  bool _showOutcome = false;
  
  @override
  void initState() {
    super.initState();
    _runSimulation();
  }

  Future<void> _runSimulation() async {
    // Phase 1
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _processingText = 'Running fraud check...');
    
    // Phase 2
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    setState(() => _processingText = 'Reviewing oracle evidence...');
    
    // Phase 3
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    
    setState(() {
      _isProcessing = false;
      _showOutcome = true;
    });
  }

  void _finish() {
    final bool isAutoApprove = widget.selectedReason == 'Heavy Rain / Waterlogging' || 
                               widget.selectedReason == 'App Outage (Swiggy / Zomato)';
                               
    final String randomId = (1000 + Random().nextInt(9000)).toString();
    final String refPrefix = isAutoApprove ? 'MAN-' : 'REV-';
    
    final Map<String, dynamic> newClaim = {
      'id': 'CLM/261203/$refPrefix$randomId',
      'title': widget.selectedReason == 'Select a reason' ? 'Other Disruption' : widget.selectedReason,
      'date': 'Today',
      'amount': isAutoApprove ? 224 : 0,
      'status': isAutoApprove ? 'Approved' : 'Under Review',
      'statusColor': isAutoApprove ? AppTheme.successGreen : AppTheme.warningOrange,
      'progressPct': isAutoApprove ? 1.0 : 0.6,
      'isAuto': false,
      'description': 'Submitted via Apply Form',
    };
    
    if (isAutoApprove) {
      newClaim['upiRef'] = 'UPI/${100000 + Random().nextInt(900000)}';
    }

    if (widget.existingClaimId != null) {
      newClaim['id'] = widget.existingClaimId;
      DemoState.instance.updateManualClaim(widget.existingClaimId!, newClaim);
    } else {
      DemoState.instance.addManualClaim(newClaim);
    }
    
    // Pop the dialog and then pop the apply screen to return to Claims
    Navigator.of(context).pop(); // pop dialog
    Navigator.of(context).pop(); // pop apply form
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _processingText,
                  key: ValueKey(_processingText),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_showOutcome) {
      final bool isAutoApprove = widget.selectedReason == 'Heavy Rain / Waterlogging' || 
                                 widget.selectedReason == 'App Outage (Swiggy / Zomato)';
      
      final Color color = isAutoApprove ? AppTheme.successGreen : AppTheme.warningOrange;
      final IconData icon = isAutoApprove ? Icons.check_circle_outline : Icons.pending_actions;
      final String title = isAutoApprove ? 'Claim Approved' : 'Claim Under Review';
      final String desc = isAutoApprove ? '₹224 will be credited within 2 hours' : 'Our team will review within 24 hours';
      final String tagText = isAutoApprove ? 'Auto-approved based on oracle consensus' : 'Manual review required — insufficient oracle data';
      final String refPrefix = isAutoApprove ? 'MAN-' : 'REV-';
      
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimaryOf(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryOf(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.cardDecorationOf(context),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Claim Ref', style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 12)),
                      Text('CLM/261203/$refPrefix****', style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'monospace', fontSize: 12)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      Icon(isAutoApprove ? Icons.bolt : Icons.info_outline, size: 14, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          tagText,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _finish,
              style: ElevatedButton.styleFrom(backgroundColor: color),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      );
    }
    
    return const SizedBox();
  }
}
