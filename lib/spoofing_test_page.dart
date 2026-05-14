import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'main.dart';

// ── Design tokens ──────────────────────────────────────────────────────────
const _kBg = Color(0xFF0D0D0F);
const _kSurface = Color(0xFF1C1C1E);
const _kBorder = Color(0xFF2C2C2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGreen = Color(0xFF30D158);
const _kRed = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);
const _kText2 = Color(0xFF8E8E93);

class SpoofingTestPage extends StatefulWidget {
  const SpoofingTestPage({super.key});

  @override
  State<SpoofingTestPage> createState() => _SpoofingTestPageState();
}

class _SpoofingTestPageState extends State<SpoofingTestPage> {
  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: false,
      enableContours: false,
      enableClassification: false,
      enableTracking: false,
      minFaceSize: 0.1,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  File? _image;
  bool _isAnalyzing = false;
  List<_FaceResult> _faceResults = [];
  String? _noFaceMsg;
  String? _error;

  // Threshold: score <= threshold → REAL. Default 0.5.
  double _threshold = 0.5;

  final List<_BatchItem> _batch = [];
  bool _isBatchMode = false;
  bool _isBatchRunning = false;

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  // ── Pick helpers ───────────────────────────────────────────────────────────

  Future<void> _pickSingle(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    setState(() {
      _image = File(picked.path);
      _faceResults = [];
      _noFaceMsg = null;
      _error = null;
    });
  }

  Future<void> _pickBatch() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty) return;
    setState(() {
      _batch.clear();
      _batch.addAll(picked.map((x) => _BatchItem(file: File(x.path))));
    });
  }

  // ── Core: detect face crop → run spoof ───────────────────────────────────

  Future<List<_FaceResult>> _detectAndSpoof(File file) async {
    final inputImage = InputImage.fromFilePath(file.path);
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) return [];

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return [];

    final results = <_FaceResult>[];
    for (final face in faces) {
      final box = face.boundingBox;
      // Add 20% padding so the model sees full face context
      final pad = (box.width * 0.2).toInt();
      final x = (box.left.toInt() - pad).clamp(0, decoded.width - 1);
      final y = (box.top.toInt() - pad).clamp(0, decoded.height - 1);
      final w = (box.width.toInt() + pad * 2).clamp(1, decoded.width - x);
      final h = (box.height.toInt() + pad * 2).clamp(1, decoded.height - y);

      final cropped =
          img.copyCrop(decoded, x: x, y: y, width: w, height: h);
      final croppedBytes =
          Uint8List.fromList(img.encodeJpg(cropped, quality: 95));

      final raw = await spoofingDetector.detect(croppedBytes);
      final score = raw['confidence'] as double;

      results.add(_FaceResult(
        cropBytes: croppedBytes,
        score: score,
        isReal: score <= _threshold,
      ));
    }
    return results;
  }

  // ── Analyze single ─────────────────────────────────────────────────────────

  Future<void> _analyze() async {
    if (_image == null) return;
    setState(() {
      _isAnalyzing = true;
      _faceResults = [];
      _noFaceMsg = null;
      _error = null;
    });
    try {
      final results = await _detectAndSpoof(_image!);
      if (results.isEmpty) {
        _noFaceMsg = 'No face detected in this image.\nTry a clearer photo.';
      } else {
        _faceResults = results;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  // ── Batch run ──────────────────────────────────────────────────────────────

  Future<void> _runBatch() async {
    if (_batch.isEmpty) return;
    setState(() {
      _isBatchRunning = true;
      for (final b in _batch) {
        b.results = null;
        b.noFace = false;
        b.error = null;
      }
    });
    for (int i = 0; i < _batch.length; i++) {
      try {
        final results = await _detectAndSpoof(_batch[i].file);
        _batch[i].results = results;
        _batch[i].noFace = results.isEmpty;
      } catch (e) {
        _batch[i].error = e.toString();
      }
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => _isBatchRunning = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Spoof Test',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          _ModeToggle(
            batch: _isBatchMode,
            onChanged: (v) => setState(() {
              _isBatchMode = v;
              _image = null;
              _faceResults = [];
              _noFaceMsg = null;
              _error = null;
              _batch.clear();
            }),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isBatchMode ? _buildBatchBody() : _buildSingleBody(),
    );
  }

  // ── Single mode ────────────────────────────────────────────────────────────

  Widget _buildSingleBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLabel('Image'),
          const SizedBox(height: 10),
          _buildImagePreview(),
          const SizedBox(height: 14),
          _buildPickRow(),
          const SizedBox(height: 16),
          _buildThresholdSlider(),
          if (_image != null) ...[
            const SizedBox(height: 14),
            _buildAnalyzeButton(),
          ],
          if (_noFaceMsg != null) ...[
            const SizedBox(height: 14),
            _buildInfoCard(_noFaceMsg!),
          ],
          if (_faceResults.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildLabel('Detected Faces (${_faceResults.length})'),
            const SizedBox(height: 10),
            ..._faceResults.asMap().entries.map((e) {
              return Padding(
                padding: EdgeInsets.only(
                    bottom: e.key < _faceResults.length - 1 ? 10 : 0),
                child: _FaceResultCard(
                    result: e.value, index: e.key, threshold: _threshold),
              );
            }),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _buildErrorCard(_error!),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _image == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_search_rounded,
                      size: 44, color: Color(0xFF48484A)),
                  SizedBox(height: 10),
                  Text('No image selected',
                      style: TextStyle(color: _kText2, fontSize: 14)),
                  SizedBox(height: 4),
                  Text('Pick a photo or take a selfie',
                      style: TextStyle(
                          color: Color(0xFF48484A), fontSize: 12)),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_image!, fit: BoxFit.cover),
                  if (_isAnalyzing)
                    Container(
                      color: Colors.black54,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: _kPrimary),
                          SizedBox(height: 12),
                          Text('Detecting face…',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildPickRow() {
    return Row(
      children: [
        Expanded(
          child: _PickButton(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            color: _kPrimary,
            onTap: _isAnalyzing ? null : () => _pickSingle(ImageSource.gallery),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PickButton(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            color: _kOrange,
            onTap: _isAnalyzing ? null : () => _pickSingle(ImageSource.camera),
          ),
        ),
      ],
    );
  }

  Widget _buildThresholdSlider() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Spoof Threshold',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _threshold.toStringAsFixed(2),
                  style: const TextStyle(
                      fontSize: 12,
                      color: _kPrimary,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _kPrimary,
              inactiveTrackColor: _kBorder,
              thumbColor: _kPrimary,
              overlayColor: _kPrimary.withValues(alpha: 0.15),
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: _threshold,
              min: 0.1,
              max: 0.9,
              divisions: 16,
              onChanged: (v) => setState(() {
                _threshold = v;
                // Reapply threshold to existing results without re-running model
                for (final r in _faceResults) {
                  r.isReal = r.score <= _threshold;
                }
              }),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Strict (more spoof)',
                  style: TextStyle(fontSize: 10, color: _kText2)),
              Text('Lenient (more real)',
                  style: TextStyle(fontSize: 10, color: _kText2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return ElevatedButton.icon(
      onPressed: _isAnalyzing ? null : _analyze,
      icon: _isAnalyzing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.security_rounded, size: 18),
      label: Text(_isAnalyzing ? 'Analyzing…' : 'Detect & Analyze'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildInfoCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: _kOrange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(color: _kOrange, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kRed.withValues(alpha: 0.3)),
      ),
      child: Text(msg,
          style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13)),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _kText2,
          letterSpacing: 0.8),
    );
  }

  // ── Batch mode ─────────────────────────────────────────────────────────────

  Widget _buildBatchBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLabel('Batch Images'),
              const SizedBox(height: 10),
              _buildThresholdSlider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PickButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Pick Multiple',
                      color: _kPrimary,
                      onTap: _isBatchRunning ? null : _pickBatch,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickButton(
                      icon: Icons.security_rounded,
                      label: _isBatchRunning ? 'Running…' : 'Run All',
                      color: _kGreen,
                      loading: _isBatchRunning,
                      onTap: (_isBatchRunning || _batch.isEmpty)
                          ? null
                          : _runBatch,
                    ),
                  ),
                ],
              ),
              if (_batch.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildBatchSummary(),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
        Expanded(
          child: _batch.isEmpty
              ? const Center(
                  child: Text('No images selected',
                      style: TextStyle(
                          color: Color(0xFF48484A), fontSize: 14)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _batch.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _BatchTile(item: _batch[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildBatchSummary() {
    final total = _batch.length;
    final done =
        _batch.where((b) => b.results != null || b.error != null).length;
    final real = _batch
        .where((b) => b.results?.any((r) => r.isReal) ?? false)
        .length;
    final spoof = _batch
        .where((b) => b.results?.any((r) => !r.isReal) ?? false)
        .length;
    final noFace = _batch.where((b) => b.noFace).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(label: 'Total', value: '$total', color: _kText2),
          _StatChip(label: 'Done', value: '$done', color: _kPrimary),
          _StatChip(label: 'Real', value: '$real', color: _kGreen),
          _StatChip(label: 'Spoof', value: '$spoof', color: _kRed),
          _StatChip(label: 'No Face', value: '$noFace', color: _kOrange),
        ],
      ),
    );
  }
}

// ── Face result card ───────────────────────────────────────────────────────

class _FaceResultCard extends StatelessWidget {
  final _FaceResult result;
  final int index;
  final double threshold;

  const _FaceResultCard({
    required this.result,
    required this.index,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    final color = result.isReal ? _kGreen : _kRed;
    final label = result.isReal ? 'Real Face' : 'Spoof Detected';
    final icon = result.isReal
        ? Icons.verified_user_rounded
        : Icons.warning_amber_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          // Cropped face thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              result.cropBytes,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Face ${index + 1}',
                      style: const TextStyle(
                          fontSize: 12, color: _kText2),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 11, color: color),
                          const SizedBox(width: 4),
                          Text(
                            result.isReal ? 'REAL' : 'SPOOF',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: color,
                                letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  'Raw score: ${result.score.toStringAsFixed(4)}  ·  Threshold: ${threshold.toStringAsFixed(2)}',
                  style:
                      const TextStyle(fontSize: 11, color: _kText2),
                ),
                const SizedBox(height: 8),
                _ScoreBar(score: result.score, threshold: threshold),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final double score;
  final double threshold;

  const _ScoreBar({required this.score, required this.threshold});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final barWidth = constraints.maxWidth;
      final markerX = threshold * barWidth;
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 7, color: _kBorder),
                FractionallySizedBox(
                  widthFactor: score.clamp(0.0, 1.0),
                  child: Container(
                    height: 7,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_kGreen, _kOrange, _kRed],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // Threshold marker
                Positioned(
                  left: markerX - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                _dot(_kGreen),
                const SizedBox(width: 3),
                const Text('Real', style: TextStyle(fontSize: 10, color: _kText2)),
              ]),
              Row(children: [
                _dot(Colors.white),
                const SizedBox(width: 3),
                const Text('Threshold',
                    style: TextStyle(fontSize: 10, color: _kText2)),
              ]),
              Row(children: [
                _dot(_kRed),
                const SizedBox(width: 3),
                const Text('Spoof',
                    style: TextStyle(fontSize: 10, color: _kText2)),
              ]),
            ],
          ),
        ],
      );
    });
  }

  Widget _dot(Color c) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final bool batch;
  final ValueChanged<bool> onChanged;
  const _ModeToggle({required this.batch, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!batch),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _kPrimary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kPrimary.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              batch ? Icons.photo_library_rounded : Icons.burst_mode_rounded,
              size: 13,
              color: _kPrimary,
            ),
            const SizedBox(width: 5),
            Text(
              batch ? 'Single' : 'Batch',
              style: const TextStyle(
                  fontSize: 12,
                  color: _kPrimary,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  const _PickButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color),
                    )
                  : Icon(icon, size: 18, color: color),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchTile extends StatelessWidget {
  final _BatchItem item;
  const _BatchTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final results = item.results;
    final err = item.error;
    final noFace = item.noFace;

    Color borderColor = _kBorder;
    if (results != null && results.isNotEmpty) {
      borderColor = results.any((r) => !r.isReal)
          ? _kRed.withValues(alpha: 0.4)
          : _kGreen.withValues(alpha: 0.4);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(item.file,
                width: 62, height: 62, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.file.path.split('/').last,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (results != null && results.isNotEmpty) ...[
                  Text(
                    '${results.length} face(s) · '
                    '${results.where((r) => r.isReal).length} real · '
                    '${results.where((r) => !r.isReal).length} spoof',
                    style: const TextStyle(fontSize: 12, color: _kText2),
                  ),
                ] else if (noFace) ...[
                  const Text('No face detected',
                      style: TextStyle(fontSize: 12, color: _kOrange)),
                ] else if (err != null) ...[
                  Text(err,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFFF6B6B)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ] else ...[
                  const Text('Pending…',
                      style: TextStyle(fontSize: 12, color: _kText2)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (results != null && results.isNotEmpty)
            _VerdictBadge(
              isReal: !results.any((r) => !r.isReal),
            )
          else if (noFace)
            const Icon(Icons.face_outlined, color: _kOrange, size: 20)
          else if (err != null)
            const Icon(Icons.error_outline_rounded,
                color: _kRed, size: 20)
          else
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _kText2),
            ),
        ],
      ),
    );
  }
}

class _VerdictBadge extends StatelessWidget {
  final bool isReal;
  const _VerdictBadge({required this.isReal});

  @override
  Widget build(BuildContext context) {
    final color = isReal ? _kGreen : _kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isReal ? 'REAL' : 'SPOOF',
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.5),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: _kText2)),
      ],
    );
  }
}

// ── Data models ────────────────────────────────────────────────────────────

class _FaceResult {
  final Uint8List cropBytes;
  final double score;
  bool isReal;

  _FaceResult({
    required this.cropBytes,
    required this.score,
    required this.isReal,
  });
}

class _BatchItem {
  final File file;
  List<_FaceResult>? results;
  bool noFace = false;
  String? error;
  _BatchItem({required this.file});
}
