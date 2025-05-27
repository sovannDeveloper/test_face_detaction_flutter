import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FaceDetectionPage(cameras: cameras),
    );
  }
}

class FaceDetectionPage extends StatefulWidget {
  final List<CameraDescription>? cameras;
  const FaceDetectionPage({super.key, required this.cameras});

  @override
  State<FaceDetectionPage> createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> {
  late CameraController _cameraController;
  late FaceDetector _faceDetector;
  bool _isDetecting = false;
  List<Face> _faces = [];
  late Size _imageSize;
  bool _isCameraInitialized = false;
  String _debugMessage = "Initializing...";
  int _frameCount = 0;
  late CameraDescription _camera = (widget.cameras ?? []).first;

  @override
  void initState() {
    super.initState();

    _initializeCamera();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false, // Disable to improve performance
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: false, // Disable to improve performance
        minFaceSize: 0.1, // Allow smaller faces
        performanceMode: FaceDetectorMode.fast, // Use fast mode
      ),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _debugMessage = "Setting up camera...";
      });

      _cameraController = CameraController(
        _camera,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController.initialize();

      setState(() {
        _debugMessage = "Camera initialized, preview size: ${_cameraController.value.previewSize}";
      });

      _imageSize = Size(
        _cameraController.value.previewSize!.width,
        _cameraController.value.previewSize!.height,
      );

      // Add a small delay before starting image stream
      await Future.delayed(const Duration(milliseconds: 500));

      _cameraController.startImageStream(_processCameraImage);

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _debugMessage = "Face detection active";
        });
      }
    } catch (e) {
      setState(() {
        _debugMessage = "Camera error: $e";
      });
      print('Error initializing camera: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      _frameCount++;

      // Process every 3rd frame to improve performance
      if (_frameCount % 3 != 0) {
        _isDetecting = false;
        return;
      }

      InputImageRotation rotation = _getImageRotation();
      InputImageFormat format = _getInputImageFormat(image.format);

      // Debug: Print image info occasionally
      if (_frameCount % 30 == 0) {
        print(
            'Processing frame $_frameCount: ${image.width}x${image.height}, format: ${image.format.group}');
      }

      final inputImage = InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        setState(() {
          _faces = faces;
          if (faces.isNotEmpty) {
            _debugMessage = "Detected ${faces.length} face(s) - Frame $_frameCount";
          } else if (_frameCount > 30) {
            _debugMessage = "No faces detected - Frame $_frameCount";
          }
        });
      }
    } catch (e) {
      setState(() {
        _debugMessage = "Detection error: $e";
      });
      print('Error processing image: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImageRotation _getImageRotation() {
    // More specific rotation handling
    if (defaultTargetPlatform == TargetPlatform.android) {
      // For front camera, might need different rotation
      if (_camera.lensDirection == CameraLensDirection.front) {
        return InputImageRotation.rotation270deg;
      } else {
        return InputImageRotation.rotation90deg;
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return InputImageRotation.rotation0deg;
    }
    return InputImageRotation.rotation0deg;
  }

  InputImageFormat _getInputImageFormat(ImageFormat format) {
    // More robust format detection
    if (defaultTargetPlatform == TargetPlatform.android) {
      switch (format.group) {
        case ImageFormatGroup.yuv420:
          return InputImageFormat.nv21;
        case ImageFormatGroup.bgra8888:
          return InputImageFormat.bgra8888;
        default:
          return InputImageFormat.nv21;
      }
    } else {
      // iOS
      return InputImageFormat.bgra8888;
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (var plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Widget _buildResults() {
    return CustomPaint(
      painter: FacePainter(
        faces: _faces,
        imageSize: _imageSize,
        previewSize: _cameraController.value.previewSize!,
        cameraLensDirection: _camera.lensDirection,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_debugMessage),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Detection Debug'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.flip_camera_ios),
            onPressed: () {
              setState(() {
                // Toggle camera direction
                _camera = _camera.lensDirection == CameraLensDirection.front
                    ? widget.cameras!.firstWhere(
                        (cam) => cam.lensDirection == CameraLensDirection.back,
                        orElse: () => widget.cameras!.first)
                    : widget.cameras!.firstWhere(
                        (cam) => cam.lensDirection == CameraLensDirection.front,
                        orElse: () => widget.cameras!.first);
                _initializeCamera();
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          CameraPreview(_cameraController),
          // Positioned.fill(child: _buildResults()),
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
                    children: List.generate(_faces.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                            'Face ${i + 1}: ${_faces[i].boundingBox.toString()}\n'
                            'Smile: ${_faces[i].smilingProbability?.toStringAsFixed(2) ?? 'N/A'}\n'
                            'Left Eye Open: ${_faces[i].leftEyeOpenProbability?.toStringAsFixed(2) ?? 'N/A'}\n'
                            'Right Eye Open: ${_faces[i].rightEyeOpenProbability?.toStringAsFixed(2) ?? 'N/A'}\n'
                            'Tracking ID: ${_faces[i].trackingId ?? 'N/A'}\n'
                            'Landmarks: ${_faces[i].landmarks.length}\n'
                            'Contour Points: ${_faces[i].contours.length}\n'
                            'Classification: ${_faces[i].headEulerAngleY?.toStringAsFixed(2) ?? 'N/A'}\n'
                            'Head Euler Angle Z: ${_faces[i].headEulerAngleZ?.toStringAsFixed(2) ?? 'N/A'}\n'
                            'Real-time: ${_cameraController.value.isStreamingImages ? "Yes" : "No"}',
                            key: Key('face_$i'),
                            style: const TextStyle(color: Colors.white, fontSize: 10)),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),

          // Performance indicator
          Positioned(
            bottom: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                'Frame: $_frameCount',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final Size previewSize;
  final CameraLensDirection cameraLensDirection;

  FacePainter({
    required this.faces,
    required this.imageSize,
    required this.previewSize,
    required this.cameraLensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Improved coordinate transformation
    final double scaleX = size.width / imageSize.height;
    final double scaleY = size.height / imageSize.width;

    final Paint facePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;

    final Paint landmarkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red;

    for (var face in faces) {
      // Transform coordinates based on camera orientation
      Rect rect;

      if (cameraLensDirection == CameraLensDirection.front) {
        // Front camera - mirror the coordinates
        rect = Rect.fromLTRB(
          (imageSize.height - face.boundingBox.bottom) * scaleX,
          face.boundingBox.left * scaleY,
          (imageSize.height - face.boundingBox.top) * scaleX,
          face.boundingBox.right * scaleY,
        );
      } else {
        // Back camera
        rect = Rect.fromLTRB(
          face.boundingBox.top * scaleX,
          (imageSize.width - face.boundingBox.right) * scaleY,
          face.boundingBox.bottom * scaleX,
          (imageSize.width - face.boundingBox.left) * scaleY,
        );
      }

      // Draw face bounding box
      canvas.drawRect(rect, facePaint);

      // Draw a center point for debugging
      final centerX = rect.left + (rect.width / 2);
      final centerY = rect.top + (rect.height / 2);
      canvas.drawCircle(Offset(centerX, centerY), 5.0, Paint()..color = Colors.yellow);

      // Draw face landmarks if available
      if (face.landmarks.isNotEmpty) {
        for (var landmark in face.landmarks.values) {
          if (landmark != null) {
            double x, y;

            if (cameraLensDirection == CameraLensDirection.front) {
              x = (imageSize.height - landmark.position.y) * scaleX;
              y = landmark.position.x * scaleY;
            } else {
              x = landmark.position.y * scaleX;
              y = (imageSize.width - landmark.position.x) * scaleY;
            }

            canvas.drawCircle(Offset(x, y), 3.0, landmarkPaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}
