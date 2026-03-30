import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../data/mock_data.dart';
import '../routes/app_routes.dart';

class ApplyFormScreen extends StatefulWidget {
  const ApplyFormScreen({Key? key}) : super(key: key);

  @override
  State<ApplyFormScreen> createState() => _ApplyFormScreenState();
}

class _ApplyFormScreenState extends State<ApplyFormScreen> {
  late String _selectedReason;
  late TextEditingController _dateController;
  late TextEditingController _descriptionController;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isRecording = false;
  String? _audioPath;
  XFile? _capturedPhoto;

  @override
  void initState() {
    super.initState();
    _selectedReason = (MockData.applyDefaults['reasons'] as List)[0];
    _dateController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _dateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('CONTINUUM Claim', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tell us about your incident',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                'We are here to support your claim quickly.\nShare key details and capture live evidence in-app.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              _buildReasonDropdown(),
              const SizedBox(height: 16),
              _buildDateField(),
              const SizedBox(height: 16),
              _buildDescriptionField(),
              const SizedBox(height: 16),
              _buildPhotoCaptureCard(),
              const SizedBox(height: 16),
              _buildAudioOption(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF008A8A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Submit Claim',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasonDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reason for Claim', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.1)),
          ),
          child: DropdownButton<String>(
            value: _selectedReason,
            isExpanded: true,
            underline: Container(),
            items: (MockData.applyDefaults['reasons'] as List)
                .cast<String>()
                .map((reason) => DropdownMenuItem(value: reason, child: Text(reason)))
                .toList(),
            onChanged: (newValue) {
              setState(() => _selectedReason = newValue!);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date of occurrence', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: _dateController,
          readOnly: true,
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (pickedDate != null) {
              _dateController.text = '${pickedDate.day}/${pickedDate.month}/${pickedDate.year}';
            }
          },
          decoration: InputDecoration(
            hintText: MockData.applyDefaults['dateHint'] as String,
            suffixIcon: const Icon(Icons.calendar_today, color: Colors.black54),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Brief description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Describe what happened...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCaptureCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Live photo evidence', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _capturePhoto,
                  icon: const Icon(Icons.camera_alt, color: Color(0xFF008A8A), size: 18),
                  label: Text(
                    _capturedPhoto == null ? 'Take Photo' : 'Retake Photo',
                    style: const TextStyle(color: Color(0xFF008A8A), fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF008A8A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          if (_capturedPhoto != null) ...[
            const SizedBox(height: 8),
            const Text('Photo captured', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioOption() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.mic, color: Color(0xFF008A8A), size: 20),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Audio statement (optional)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      Text('Use device microphone', style: TextStyle(fontSize: 11, color: Colors.black54)),
                    ],
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: _toggleRecording,
                style: FilledButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.red : const Color(0xFF008A8A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(_isRecording ? Icons.stop : Icons.mic, size: 16),
                label: Text(_isRecording ? 'Stop' : 'Record'),
              ),
            ],
          ),
          if (_audioPath != null) ...[
            const SizedBox(height: 8),
            const Text('Audio captured', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  void _submitForm() {
    if (_selectedReason == 'Select a reason' || _dateController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Claim Submitted'),
        content: const Text('Your claim has been submitted successfully. Check the Status Tracker to monitor progress.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushReplacementNamed(context, AppRoutes.claimStatus);
            },
            child: const Text('Done', style: TextStyle(color: Color(0xFF008A8A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _capturePhoto() async {
    if (!kIsWeb) {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required to take photo evidence')),
        );
        return;
      }
    }

    final photo = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 75);
    if (photo != null && mounted) {
      setState(() => _capturedPhoto = photo);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(path == null ? 'Recording stopped' : 'Audio captured')),
      );
      return;
    }

    if (!kIsWeb) {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required to record audio')),
        );
        return;
      }
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
      return;
    }

    await _audioRecorder.start(const RecordConfig(), path: 'claim_audio_note.m4a');
    if (!mounted) return;
    setState(() => _isRecording = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recording started')),
    );
  }
}
