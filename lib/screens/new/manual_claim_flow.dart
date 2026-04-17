import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../state/demo_state.dart';

class ManualClaimFlow extends StatefulWidget {
  const ManualClaimFlow({Key? key}) : super(key: key);

  @override
  State<ManualClaimFlow> createState() => _ManualClaimFlowState();
}

class _ManualClaimFlowState extends State<ManualClaimFlow> {
  int _currentStep = 0;
  String _selectedDisruption = '';

  // Processing steps in Step 3
  bool _isProcessing = false;
  String _processingText = 'Submitting claim...';
  bool _showOutcome = false;

  final List<Map<String, String>> _disruptionTypes = [
    {
      'title': 'Severe Weather',
      'icon': '🌧️',
      'desc': 'Rain/flooding made delivery impossible',
    },
    {
      'title': 'Platform Outage',
      'icon': '📵',
      'desc': 'App was down during my active hours',
    },
    {
      'title': 'Road Closure',
      'icon': '🚧',
      'desc': 'Routes were blocked by municipal order',
    },
    {
      'title': 'Other Disruption',
      'icon': '📋',
      'desc': 'Another verified income disruption',
    },
  ];

  void _nextStep() {
    if (_currentStep == 0 && _selectedDisruption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a disruption type')),
      );
      return;
    }

    if (_currentStep == 1) {
      // Start processing
      setState(() {
        _currentStep++;
        _isProcessing = true;
      });
      _runProcessingSimulation();
      return;
    }

    setState(() {
      _currentStep++;
    });
  }

  void _previousStep() {
    if (_currentStep > 0 && !_showOutcome) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _runProcessingSimulation() async {
    // Phase 1: Submitting
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _processingText = 'Running fraud check...';
    });

    // Phase 2: Fraud check
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    setState(() {
      _processingText = 'Reviewing oracle evidence...';
    });

    // Phase 3: Oracle
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    // Finish processing
    setState(() {
      _isProcessing = false;
      _showOutcome = true;
    });
  }

  void _finishFlow() {
    final bool isAutoApprove =
        _selectedDisruption == 'Severe Weather' ||
        _selectedDisruption == 'Platform Outage';

    final String randomId = (1000 + Random().nextInt(9000)).toString();
    final String refPrefix = isAutoApprove ? 'MAN-' : 'REV-';

    final Map<String, dynamic> newClaim = {
      'id': 'CLM/261203/$refPrefix$randomId',
      'title': _selectedDisruption,
      'date': 'Today',
      'amount': isAutoApprove ? 224 : 0,
      'status': isAutoApprove ? 'Approved' : 'Under Review',
      'statusColor': isAutoApprove
          ? AppTheme.successGreen
          : AppTheme.warningOrange,
      'progressPct': isAutoApprove ? 1.0 : 0.6,
      'isAuto': false,
      'claim_description': _disruptionTypes.firstWhere(
        (d) => d['title'] == _selectedDisruption,
      )['desc'],
    };

    if (isAutoApprove) {
      newClaim['upiRef'] = 'UPI/${100000 + Random().nextInt(900000)}';
    }

    DemoState.instance.addManualClaim(newClaim);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _previousStep,
        ),
        title: const Text('Apply Claim'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: List.generate(3, (index) {
                final active = index <= _currentStep;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: active
                          ? AppTheme.primary
                          : AppTheme.dividerOf(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStep(),
              ),
            ),
            if (!_isProcessing && !_showOutcome)
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _nextStep,
                    child: Text(_currentStep == 1 ? 'Submit Claim' : 'Next'),
                  ),
                ),
              ),
            if (_showOutcome)
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _finishFlow,
                    child: const Text('Done'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return const SizedBox();
    }
  }

  // ── Step 1 ─────────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What happened?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Select the reason for your income disruption.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        ..._disruptionTypes.map(
          (type) => GestureDetector(
            onTap: () => setState(() => _selectedDisruption = type['title']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _selectedDisruption == type['title']
                    ? AppTheme.primary.withOpacity(0.1)
                    : AppTheme.cardOf(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: _selectedDisruption == type['title']
                      ? AppTheme.primary
                      : AppTheme.dividerOf(context),
                  width: 1.5,
                ),
                boxShadow: AppTheme.softShadowOf(context),
              ),
              child: Row(
                children: [
                  Text(type['icon']!, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type['title']!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          type['desc']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedDisruption == type['title'])
                    const Icon(Icons.check_circle, color: AppTheme.primary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: 'Today',
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Date of Disruption',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Describe what happened',
            hintText:
                'e.g. Heavy rain in Velachery blocked all routes from 6pm to 9pm',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  // ── Step 2 ─────────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verify your details',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ve grouped your info. Please review.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecorationOf(context),
          child: Column(
            children: [
              _buildDetailRow('Partner\'s zone', 'Velachery, Chennai Zone 4'),
              const Divider(),
              _buildDetailRow('Active policy', 'Gold Plan — ₹99/week'),
              const Divider(),
              _buildDetailRow('Estimated payout', '₹180 - ₹247'),
              const Divider(),
              _buildDetailRow('Coverage hours', '6 hours remaining this week'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Supporting Evidence',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Evidence auto-fetched from your device and our oracle network',
          style: TextStyle(fontSize: 12, color: AppTheme.textHintOf(context)),
        ),
        const SizedBox(height: 16),
        _buildEvidenceItem(
          'GPS location log',
          'Verified in zone during disruption window',
        ),
        _buildEvidenceItem(
          'Platform activity record',
          'Zero completed orders during claimed period',
        ),
        _buildEvidenceItem(
          'Weather data',
          'IMD confirms 58mm rainfall in your zone',
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondaryOf(context),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryOf(context),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            color: AppTheme.successGreen,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3 ─────────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    if (_isProcessing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _processingText,
                  key: ValueKey(_processingText),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_showOutcome) {
      final bool isAutoApprove =
          _selectedDisruption == 'Severe Weather' ||
          _selectedDisruption == 'Platform Outage';

      final Color color = isAutoApprove
          ? AppTheme.successGreen
          : AppTheme.warningOrange;
      final IconData icon = isAutoApprove
          ? Icons.check_circle_outline
          : Icons.pending_actions;
      final String title = isAutoApprove
          ? 'Claim Approved'
          : 'Claim Under Review';
      final String desc = isAutoApprove
          ? '₹224 will be credited within 2 hours'
          : 'Our team will review within 24 hours';
      final String tagText = isAutoApprove
          ? 'Auto-approved based on oracle consensus'
          : 'Manual review required — insufficient oracle data';
      final String refPrefix = isAutoApprove ? 'MAN-' : 'REV-';

      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 64, color: color),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecorationOf(context),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Claim Reference',
                          style: TextStyle(
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                        Text(
                          'CLM/261203/$refPrefix****',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Row(
                      children: [
                        Icon(
                          isAutoApprove ? Icons.bolt : Icons.info_outline,
                          size: 16,
                          color: color,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tagText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox();
  }
}
