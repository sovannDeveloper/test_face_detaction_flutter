import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

class FaceDetectionPage extends StatefulWidget {
  const FaceDetectionPage({super.key});

  @override
  State<FaceDetectionPage> createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> {
  File? _imageFile;
  List<Face> _faces = [];
  Size _imageSize = Size.zero;
  bool _isProcessing = false;

  late final FaceDetector _faceDetector;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeDetector();
  }

  void _initializeDetector() {
    final options = FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);

      if (pickedFile == null) return;

      setState(() {
        _isProcessing = true;
        _imageFile = File(pickedFile.path);
      });

      await _processImage(pickedFile.path);
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processImage(String imagePath) async {
    try {
      // Create InputImage from file
      final inputImage = InputImage.fromFilePath(imagePath);

      // Get image dimensions
      final imageFile = File(imagePath);
      final decodedImage =
          await decodeImageFromList(imageFile.readAsBytesSync());

      setState(() {
        _imageSize = Size(
          decodedImage.width.toDouble(),
          decodedImage.height.toDouble(),
        );
      });

      // Detect faces
      final faces = await _faceDetector.processImage(inputImage);

      setState(() {
        _faces = faces;
      });
    } catch (e) {
      print('Error processing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: $e')),
      );
    }
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Detection'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: () => _pickImage(ImageSource.gallery),
            tooltip: 'Pick from gallery',
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () => _pickImage(ImageSource.camera),
            tooltip: 'Take photo',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isProcessing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_imageFile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image, size: 100, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'No image selected',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Pick from Gallery'),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Display image
        Image.file(
          _imageFile!,
          fit: BoxFit.contain,
        ),
        // Draw face rectangles
        if (_faces.isNotEmpty)
          CustomPaint(
            painter: FacePainter(
              _faces,
              _imageSize,
            ),
          ),
        // Display face information
        if (_faces.isNotEmpty)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            bottom: 20,
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_faces.length, (i) {
                      final face = _faces[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Face ${i + 1}: ${face.boundingBox.toString()}\n'
                          'Smile: ${face.smilingProbability?.toStringAsFixed(2) ?? 'N/A'}\n'
                          'Left Eye Open: ${face.leftEyeOpenProbability?.toStringAsFixed(2) ?? 'N/A'}\n'
                          'Right Eye Open: ${face.rightEyeOpenProbability?.toStringAsFixed(2) ?? 'N/A'}\n'
                          'Tracking ID: ${face.trackingId ?? 'N/A'}\n'
                          'Landmarks: ${face.landmarks.length}\n'
                          'Contour Points: ${face.contours.length}\n'
                          'Head Euler Angle Y: ${face.headEulerAngleY?.toStringAsFixed(2) ?? 'N/A'}\n'
                          'Head Euler Angle Z: ${face.headEulerAngleZ?.toStringAsFixed(2) ?? 'N/A'}\n'
                          'Image Size: ${_imageSize.width.toInt()}x${_imageSize.height.toInt()}',
                          key: Key('face_$i'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;

  FacePainter(this.faces, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.green;

    for (final face in faces) {
      final rect = _scaleRect(
        rect: face.boundingBox,
        imageSize: imageSize,
        widgetSize: size,
      );

      canvas.drawRect(rect, paint);

      // Draw center point for debugging
      final center = rect.center;
      canvas.drawCircle(center, 5, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
    }
  }

  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
  }) {
    // Calculate scale to fit image in widget (maintain aspect ratio)
    final double scaleX = widgetSize.width / imageSize.width;
    final double scaleY = widgetSize.height / imageSize.height;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate centered position offsets
    final double scaledWidth = imageSize.width * scale;
    final double scaledHeight = imageSize.height * scale;
    final double offsetX = (widgetSize.width - scaledWidth) / 2;
    final double offsetY = (widgetSize.height - scaledHeight) / 2;

    // Scale the rectangle
    final left = rect.left * scale + offsetX;
    final top = rect.top * scale + offsetY;
    final right = rect.right * scale + offsetX;
    final bottom = rect.bottom * scale + offsetY;

    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
