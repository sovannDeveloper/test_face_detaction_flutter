import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'face_attendance.dart/main.dart';

class MyFaceDetection {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  /// Detect faces in an image file
  Future<List<Face>> detectFaces(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final faces = await _faceDetector.processImage(inputImage);
    return faces;
  }

  /// Detect faces from camera image
  Future<(List<Face>, Uint8List)> detectFacesFromCamera(
      CameraImage image, CameraDescription camera) async {
    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());

    const InputImageRotation imageRotation = InputImageRotation.rotation0deg;

    const InputImageFormat inputImageFormat = InputImageFormat.nv21;

    final inputImageMetadata = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    final inputImage = InputImage.fromBytes(
      bytes: cameraImageToBytes(image) ?? Uint8List.fromList([]),
      metadata: inputImageMetadata,
    );

    final faces = await _faceDetector.processImage(inputImage);
    return (faces, Uint8List.fromList(inputImage.bytes ?? []));
  }

  static Uint8List? cameraImageToBytes(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;

      // Create an image from YUV420 format
      final img.Image imgImage = img.Image(width: width, height: height);

      final Plane yPlane = image.planes[0];
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];

      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

      // Cache bytes for faster access
      final Uint8List yBytes = yPlane.bytes;
      final Uint8List uBytes = uPlane.bytes;
      final Uint8List vBytes = vPlane.bytes;

      int yIndex = 0;
      for (int h = 0; h < height; h++) {
        final int uvRow = (h >> 1) * uvRowStride;

        for (int w = 0; w < width; w++) {
          final int uvIndex = (w >> 1) * uvPixelStride + uvRow;

          final int y = yBytes[yIndex++];
          final int u = uBytes[uvIndex];
          final int v = vBytes[uvIndex];

          // Optimized YUV to RGB conversion
          final int c = y - 16;
          final int d = u - 128;
          final int e = v - 128;

          int r = (298 * c + 409 * e + 128) >> 8;
          int g = (298 * c - 100 * d - 208 * e + 128) >> 8;
          int b = (298 * c + 516 * d + 128) >> 8;

          // Clamp and set pixel using direct buffer access
          imgImage.data!.setPixelRgba(
              w, h, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255), 255);
        }
      }

      // Encode to JPEG
      return Uint8List.fromList(img.encodeJpg(imgImage, quality: 85));
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}

class FaceDetectionPage extends StatefulWidget {
  const FaceDetectionPage({super.key});

  @override
  State<FaceDetectionPage> createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> {
  late final _faceDetection = MyFaceDetection();
  File? _selectedImage;
  List<Face>? _detectedFaces;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _faceDetection.dispose();
    super.dispose();
  }

  Future<void> _pickAndDetectFaces(ImageSource source) async {
    try {
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });

      final img = await ImagePicker().pickImage(source: source);

      if (img == null) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      final imageFile = File(img.path);
      final faces = await _faceDetection.detectFaces(imageFile);

      setState(() {
        _selectedImage = imageFile;
        _detectedFaces = faces;
        _isProcessing = false;
      });

      if (faces.isEmpty) {
        _showMessage('No faces detected in the image');
      } else {
        _showMessage('Detected ${faces.length} face(s)');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openLiveCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _showMessage('No camera available');
      return;
    }

    if (!mounted) return;

    final camera =
        cameras.firstWhere((e) => e.lensDirection == CameraLensDirection.front);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveCameraPage(camera: camera),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.blue),
              title: const Text('Live Camera'),
              onTap: () {
                Navigator.pop(context);
                _openLiveCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndDetectFaces(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndDetectFaces(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Face Detection'),
          backgroundColor: Colors.blue,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isProcessing)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (_errorMessage != null)
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  ),
                if (_selectedImage != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_detectedFaces != null && _detectedFaces!.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detection Results',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Divider(),
                          Text(
                            'Total Faces: ${_detectedFaces!.length}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _detectedFaces!.length,
                    itemBuilder: (context, index) {
                      final face = _detectedFaces![index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Face ${index + 1}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildFaceDetail(
                                'Smiling',
                                face.smilingProbability != null
                                    ? '${(face.smilingProbability! * 100).toStringAsFixed(1)}%'
                                    : 'N/A',
                              ),
                              _buildFaceDetail(
                                'Left Eye Open',
                                face.leftEyeOpenProbability != null
                                    ? '${(face.leftEyeOpenProbability! * 100).toStringAsFixed(1)}%'
                                    : 'N/A',
                              ),
                              _buildFaceDetail(
                                'Right Eye Open',
                                face.rightEyeOpenProbability != null
                                    ? '${(face.rightEyeOpenProbability! * 100).toStringAsFixed(1)}%'
                                    : 'N/A',
                              ),
                              _buildFaceDetail(
                                'Head Angle X',
                                face.headEulerAngleX != null
                                    ? '${face.headEulerAngleX!.toStringAsFixed(2)}°'
                                    : 'N/A',
                              ),
                              _buildFaceDetail(
                                'Head Angle Y',
                                face.headEulerAngleY != null
                                    ? '${face.headEulerAngleY!.toStringAsFixed(2)}°'
                                    : 'N/A',
                              ),
                              _buildFaceDetail(
                                'Tracking ID',
                                face.trackingId?.toString() ?? 'N/A',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
                if (_selectedImage == null && !_isProcessing)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.face,
                            size: 100,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No image selected',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the button below to start detection',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isProcessing ? null : _showImageSourceDialog,
          icon: const Icon(Icons.add_a_photo),
          label: const Text('Detect Faces'),
        ),
      ),
    );
  }

  Widget _buildFaceDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class LiveCameraPage extends StatefulWidget {
  final CameraDescription camera;

  const LiveCameraPage({
    super.key,
    required this.camera,
  });

  @override
  State<LiveCameraPage> createState() => _LiveCameraPageState();
}

class _LiveCameraPageState extends State<LiveCameraPage> {
  late final _detector = FaceDetectionServiceV2()
    ..initCameraRotation(widget.camera);
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    _initializeControllerFuture = _controller.initialize().then((_) {
      _controller.startImageStream(_detector.processCameraImage);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Live Face Detection'),
          backgroundColor: Colors.blue,
        ),
        body: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return StreamBuilder(
                  stream: _detector.stream,
                  builder: (_, s) {
                    final faces = s.data ?? [];

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_controller),
                        CustomPaint(
                          painter: FacePainter(
                            faces: faces,
                            imageSize: Size(
                              _controller.value.previewSize!.height,
                              _controller.value.previewSize!.width,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Faces: ${faces.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  });
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;

  FacePainter({required this.faces, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;

    for (final Face face in faces) {
      final scaleX = size.width / imageSize.width;
      final scaleY = size.height / imageSize.height;

      final rect = Rect.fromLTRB(
        face.boundingBox.left * scaleX,
        face.boundingBox.top * scaleY,
        face.boundingBox.right * scaleX,
        face.boundingBox.bottom * scaleY,
      );

      canvas.drawRect(rect, paint);

      // Draw smile indicator
      if (face.smilingProbability != null && face.smilingProbability! > 0.7) {
        final textPainter = TextPainter(
          text: const TextSpan(
            text: '😊',
            style: TextStyle(fontSize: 30),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(rect.left, rect.top - 40),
        );
      }
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}
