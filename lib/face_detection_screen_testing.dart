import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'face_attendance.dart/main.dart';
import 'main.dart';

// ── Design tokens ──────────────────────────────────────────────────────────
const _kBg = Color(0xFF0D0D0F);
const _kSurface = Color(0xFF1C1C1E);
const _kBorder = Color(0xFF2C2C2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGreen = Color(0xFF30D158);
const _kBlue = Color(0xFF32ADE6);
const _kRed = Color(0xFFFF453A);
const _kText2 = Color(0xFF8E8E93);

class FaceDetectionPage extends StatefulWidget {
  const FaceDetectionPage({super.key});

  @override
  State<FaceDetectionPage> createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> {
  late final _faceDetection = FaceDetectionService();
  final _recognition = FaceRecognitionService();

  File? _selectedImage;
  bool _isProcessing = false;
  bool _isRecognizing = false;
  String? _errorMessage;
  Map<String, dynamic>? _recognitionResult;
  Map<String, dynamic>? _spoofResult;

  List<CameraDescription> _cameras = [];
  CameraDescription? _camera;

  @override
  void initState() {
    super.initState();
    Future.microtask(_initCameras);
  }

  Future<void> _initCameras() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    _camera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );
    _faceDetection.initCameraRotation(_camera!);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _faceDetection.dispose();
    super.dispose();
  }

  void _openCamera({required bool front}) {
    final cam = _cameras.firstWhere(
      (c) =>
          c.lensDirection ==
          (front ? CameraLensDirection.front : CameraLensDirection.back),
      orElse: () => _cameras.first,
    );
    _faceDetection.initCameraRotation(cam);
    _camera = cam;
    setState(() {});

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveDetectionScreen(
          camera: cam,
          recognition: _recognition,
          detection: _faceDetection,
          spoofingDetector: spoofingDetector,
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _recognitionResult = null;
      _spoofResult = null;
    });
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      _selectedImage = File(picked.path);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isProcessing = false;
      setState(() {});
    }
  }

  Future<void> _recognize() async {
    if (_selectedImage == null) return;
    setState(() {
      _isRecognizing = true;
      _recognitionResult = null;
      _spoofResult = null;
    });
    try {
      final bytes = await _selectedImage!.readAsBytes();
      final results = await Future.wait([
        _recognition.recognize(bytes),
        spoofingDetector.detect(bytes),
      ]);
      _recognitionResult = results[0];
      _spoofResult = results[1];
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isRecognizing = false;
      setState(() {});
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Face Detection',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: _camera == null
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSection(
                    label: 'Live Camera',
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.camera_front_rounded,
                            label: 'Front Camera',
                            color: _kPrimary,
                            onTap: () => _openCamera(front: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.camera_rear_rounded,
                            label: 'Back Camera',
                            color: _kBlue,
                            onTap: () => _openCamera(front: false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    label: 'From Gallery',
                    child: _ActionCard(
                      icon: Icons.photo_library_rounded,
                      label: 'Choose Image',
                      color: _kGreen,
                      loading: _isProcessing,
                      onTap: _isProcessing ? null : _pickImage,
                    ),
                  ),
                  if (_selectedImage != null) ...[
                    const SizedBox(height: 16),
                    _buildImagePreview(),
                    const SizedBox(height: 12),
                    _buildRecognizeButton(),
                  ],
                  if (_recognitionResult != null || _spoofResult != null) ...[
                    const SizedBox(height: 16),
                    _buildResults(),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _buildError(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSection({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _kText2,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(
        _selectedImage!,
        height: 240,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildRecognizeButton() {
    return ElevatedButton.icon(
      onPressed: _isRecognizing ? null : _recognize,
      icon: _isRecognizing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.search_rounded, size: 18),
      label: Text(_isRecognizing ? 'Recognizing…' : 'Recognize Face'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildResults() {
    final recog = _recognitionResult;
    final spoof = _spoofResult;

    final matched = recog?['matched'] as bool? ?? false;
    final confidence = (recog?['confidence'] as double? ?? 0.0);
    final isReal = spoof?['isReal'] as bool? ?? false;
    final spoofConf = (spoof?['confidence'] as double? ?? 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recog != null)
          _ResultCard(
            icon: matched ? Icons.check_circle_rounded : Icons.cancel_rounded,
            iconColor: matched ? _kGreen : _kRed,
            title: matched ? 'Face Matched' : 'No Match',
            subtitle:
                'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
            badgeColor: matched ? _kGreen : _kRed,
            badgeText: matched ? 'MATCH' : 'NO MATCH',
          ),
        if (recog != null && spoof != null) const SizedBox(height: 10),
        if (spoof != null)
          _ResultCard(
            icon: isReal
                ? Icons.verified_user_rounded
                : Icons.warning_amber_rounded,
            iconColor: isReal ? _kGreen : _kRed,
            title: isReal ? 'Real Face' : 'Spoof Detected',
            subtitle:
                'Score: ${(spoofConf * 100).toStringAsFixed(1)}%',
            badgeColor: isReal ? _kGreen : _kRed,
            badgeText: isReal ? 'REAL' : 'SPOOF',
          ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kRed.withValues(alpha: 0.3)),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
      ),
    );
  }
}

// ── Reusable widgets ───────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: loading
                  ? Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      ),
                    )
                  : Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF48484A),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color badgeColor;
  final String badgeText;

  const _ResultCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badgeColor,
    required this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: _kText2),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: badgeColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
