import 'package:flutter/material.dart';

class ApplyFormScreen extends StatefulWidget {
  const ApplyFormScreen({Key? key}) : super(key: key);

  @override
  State<ApplyFormScreen> createState() => _ApplyFormScreenState();
}

class _ApplyFormScreenState extends State<ApplyFormScreen> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Apply for Coverage', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 2) {
            setState(() {
              _currentStep += 1;
            });
          } else {
            // Submit logic
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Application Submitted'),
                content: const Text('Your auto-verification process has started. Check Status Tracker.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() {
              _currentStep -= 1;
            });
          } else {
            Navigator.of(context).pop();
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(_currentStep == 2 ? 'Submit Application' : 'Continue', style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back', style: TextStyle(color: Colors.black54)),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Personal Details'),
            content: Column(
              children: [
                _buildTextField('Full Name', Icons.person),
                const SizedBox(height: 12),
                _buildTextField('Aadhaar / PAN', Icons.credit_card),
              ],
            ),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.editing,
          ),
          Step(
            title: const Text('Vehicle & Gig Details'),
            content: Column(
              children: [
                _buildTextField('Vehicle Registration Number', Icons.numbers),
                const SizedBox(height: 12),
                _buildTextField('Primary Delivery Platform (e.g., Swiggy)', Icons.work_outline),
              ],
            ),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : _currentStep == 1 ? StepState.editing : StepState.indexed,
          ),
          Step(
            title: const Text('Plan Selection'),
            content: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.blueAccent),
                      SizedBox(width: 12),
                      Expanded(child: Text('Comprehensive Cover (₹45/week)\nIncludes Downtime, Weather, & Accident', style: TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('By submitting, you authorize auto-debit from your partner wallet.', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
            isActive: _currentStep >= 2,
            state: _currentStep == 2 ? StepState.editing : StepState.indexed,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.black45),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
