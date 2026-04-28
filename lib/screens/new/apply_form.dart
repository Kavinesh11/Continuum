import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class ApplyFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existingClaim;
  const ApplyFormScreen({Key? key, this.existingClaim}) : super(key: key);

  @override
  State<ApplyFormScreen> createState() => _ApplyFormScreenState();
}

class _ApplyFormScreenState extends State<ApplyFormScreen> {
  static const List<String> _claimReasons = [
    'Select a reason',
    'Heavy Rain / Waterlogging',
    'App Outage (Swiggy / Zomato)',
    'Network Failure',
    'Vehicle Breakdown',
  ];

  late String _selectedReason;
  late TextEditingController _dateController;
  late TextEditingController _descriptionController;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isRecording = false;
  bool _isSubmitting = false;
  List<String> _audioPaths = [];
  List<XFile> _capturedPhotos = [];

  @override
  void initState() {
    super.initState();
    String presetReason = widget.existingClaim?['title'] ?? _claimReasons[0];
    if (!_claimReasons.contains(presetReason)) {
      presetReason = _claimReasons[0];
    }
    _selectedReason = presetReason;

    _dateController = TextEditingController(
      text: widget.existingClaim?['date'] ?? '',
    );
    // If the mock didn't specify description, initialize blank
    _descriptionController = TextEditingController(
      text:
          widget.existingClaim?['claim_description'] ==
              'Submitted via Apply Form'
          ? ''
          : (widget.existingClaim?['claim_description'] ?? ''),
    );
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
      appBar: AppBar(
        title: Text(widget.existingClaim != null ? 'Edit Claim' : 'New Claim'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withOpacity(0.06),
                      AppTheme.primary.withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tell us about your incident',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Share key details and capture live evidence.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryOf(context),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _buildSectionLabel(
                Icons.help_outline_rounded,
                'Reason for Claim',
              ),
              const SizedBox(height: 8),
              _buildReasonDropdown(),
              const SizedBox(height: 18),
              _buildSectionLabel(
                Icons.calendar_today_rounded,
                'Date of Occurrence',
              ),
              const SizedBox(height: 8),
              _buildDateField(),
              const SizedBox(height: 18),
              _buildSectionLabel(Icons.notes_rounded, 'Brief Description'),
              const SizedBox(height: 8),
              _buildDescriptionField(),
              const SizedBox(height: 18),
              _buildPhotoCaptureCard(),
              const SizedBox(height: 14),
              _buildAudioOption(),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: AppTheme.primaryGlow(0.25),
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              widget.existingClaim != null
                                  ? 'Update Claim'
                                  : 'Submit Claim',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
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

  Widget _buildSectionLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: AppTheme.cardDecorationOf(context),
      child: DropdownButton<String>(
        value: _selectedReason,
        isExpanded: true,
        underline: Container(),
        dropdownColor: AppTheme.cardOf(context),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppTheme.textSecondaryOf(context),
        ),
        style: TextStyle(
          color: AppTheme.textPrimaryOf(context),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        items: _claimReasons
            .cast<String>()
            .map(
              (reason) => DropdownMenuItem(value: reason, child: Text(reason)),
            )
            .toList(),
        onChanged: (newValue) {
          setState(() => _selectedReason = newValue!);
        },
      ),
    );
  }

  Widget _buildDateField() {
    return TextField(
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
          _dateController.text =
              '${pickedDate.day}/${pickedDate.month}/${pickedDate.year}';
        }
      },
      decoration: InputDecoration(
        hintText: 'DD/MM/YYYY',
        suffixIcon: Container(
          margin: const EdgeInsets.only(right: 8),
          child: const Icon(
            Icons.calendar_today_rounded,
            color: AppTheme.primary,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextField(
      controller: _descriptionController,
      maxLines: 4,
      decoration: const InputDecoration(hintText: 'Describe what happened...'),
    );
  }

  Widget _buildPhotoCaptureCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppTheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Live photo evidence',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ..._capturedPhotos.asMap().entries.map((entry) {
                final int index = entry.key;
                final XFile file = entry.value;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: kIsWeb
                            ? Image.network(file.path, fit: BoxFit.cover)
                            : Image.file(File(file.path), fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _capturedPhotos.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cancel_rounded,
                            color: AppTheme.dangerRed,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
              GestureDetector(
                onTap: _capturePhoto,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_rounded,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioOption() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isRecording
                      ? AppTheme.dangerRed.withOpacity(0.1)
                      : AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.mic_rounded,
                  color: _isRecording ? AppTheme.dangerRed : AppTheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio statement',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    Text(
                      'Optional • Use device microphone',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: _isRecording
                      ? const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        )
                      : AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_isRecording ? AppTheme.dangerRed : AppTheme.primary)
                              .withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _toggleRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                  ),
                  icon: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    _isRecording ? 'Stop' : 'Record',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_audioPaths.isNotEmpty) ...[
            const SizedBox(height: 12),
            Column(
              children: _audioPaths.asMap().entries.map((entry) {
                int i = entry.key;
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.successGreen.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.successGreen,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Audio note ${i + 1} captured',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.successGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Playing audio placeholder...'),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: AppTheme.primary,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _audioPaths.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppTheme.dangerRed,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_selectedReason == 'Select a reason' ||
        _dateController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill all required fields'),
          backgroundColor: AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final claimId = const Uuid().v4();
      final workerId = await ApiService().getCurrentWorkerId();
      final profile = await ApiService().getWorkerProfileCurrent();
      final zoneId = (profile['zone_id'] as String?) ?? 'default';
      final payload = {
        'claim_id': claimId,
        'worker_id': workerId,
        'event_type': _selectedReason,
        'event_timestamp': DateTime.now().toIso8601String(),
        'verification_message': _descriptionController.text.trim(),
        'claim_description': _descriptionController.text.trim(),
        'zone_id': zoneId,
        'gps_coordinates': [0.0, 0.0],
        'device_attestation_token': 'mobile_app',
      };

      final result = await ApiService().submitClaim(payload);
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.claimStatus,
        arguments: (result['claim_id'] ?? claimId).toString(),
      );
    } on ServerException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Service temporarily unavailable. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'Retry', onPressed: _submitForm),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Network error. Please check your connection.'),
          backgroundColor: AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _capturePhoto() async {
    if (!kIsWeb) {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Camera permission is required to take photo evidence',
            ),
          ),
        );
        return;
      }
    }

    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
    );
    if (photo != null && mounted) {
      setState(() => _capturedPhotos.add(photo));
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        if (path != null) {
          _audioPaths.add(path);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(path == null ? 'Recording stopped' : 'Audio captured'),
        ),
      );
      return;
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
      return;
    }

    String path =
        'claim_audio_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
    if (!kIsWeb) {
      path = '${Directory.systemTemp.path}/$path';
    }

    await _audioRecorder.start(const RecordConfig(), path: path);
    if (!mounted) return;
    setState(() => _isRecording = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Recording started')));
  }
}
