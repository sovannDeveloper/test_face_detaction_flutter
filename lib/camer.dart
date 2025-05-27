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
      home: FaceDetectionPage(camera: cameras.length > 1 ? cameras[1] : cameras[0]),
    );
  }
}

class FaceDetectionPage extends StatefulWidget {
  final CameraDescription camera;
  const FaceDetectionPage({Key? key, required this.camera}) : super(key: key);

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

  // Smile and blink detection states
  bool _isSmiling = false;
  bool _isBlinking = false;
  bool _isRecording = false;
  List<String> _detectionEvents = [];

  // Thresholds for detection
  final double _smileThreshold = 0.8;
  final double _blinkThreshold = 0.3;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true, // Essential for smile and eye detection
        enableLandmarks: true,
        enableTracking: true,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      _cameraController = CameraController(
        widget.camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController.initialize();

      _imageSize = Size(
        _cameraController.value.previewSize!.width,
        _cameraController.value.previewSize!.height,
      );

      _cameraController.startImageStream(_processCameraImage);

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      InputImageRotation rotation = _getImageRotation();

      final inputImage = InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: _getInputImageFormat(image.format),
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        setState(() {
          _faces = faces;
          _detectSmileAndBlink(faces);
        });
      }
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      _isDetecting = false;
    }
  }

  void _detectSmileAndBlink(List<Face> faces) {
    bool currentlySmiling = false;
    bool currentlyBlinking = false;

    for (var face in faces) {
      // Check for smile
      if (face.smilingProbability != null) {
        if (face.smilingProbability! > _smileThreshold) {
          currentlySmiling = true;
          if (!_isSmiling && _isRecording) {
            _addDetectionEvent('😊 Smile detected!');
          }
        }
      }

      // Check for eye blink (both eyes closed)
      bool leftEyeClosed =
          face.leftEyeOpenProbability != null && face.leftEyeOpenProbability! < _blinkThreshold;
      bool rightEyeClosed =
          face.rightEyeOpenProbability != null && face.rightEyeOpenProbability! < _blinkThreshold;

      if (leftEyeClosed && rightEyeClosed) {
        currentlyBlinking = true;
        if (!_isBlinking && _isRecording) {
          _addDetectionEvent('😉 Blink detected!');
        }
      }
    }

    _isSmiling = currentlySmiling;
    _isBlinking = currentlyBlinking;
  }

  void _addDetectionEvent(String event) {
    String timestamp = DateTime.now().toString().substring(11, 19);
    _detectionEvents.insert(0, '$timestamp - $event');
    if (_detectionEvents.length > 10) {
      _detectionEvents.removeLast();
    }
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _detectionEvents.clear();
        _addDetectionEvent('🔴 Recording started');
      } else {
        _addDetectionEvent('⛔ Recording stopped');
      }
    });
  }

  void _clearEvents() {
    setState(() {
      _detectionEvents.clear();
    });
  }

  InputImageRotation _getImageRotation() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return InputImageRotation.rotation90deg;
    }
    return InputImageRotation.rotation0deg;
  }

  InputImageFormat _getInputImageFormat(ImageFormat format) {
    switch (format.group) {
      case ImageFormatGroup.yuv420:
        return InputImageFormat.yuv420;
      case ImageFormatGroup.bgra8888:
        return InputImageFormat.bgra8888;
      default:
        return InputImageFormat.nv21;
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
        isSmiling: _isSmiling,
        isBlinking: _isBlinking,
      ),
    );
  }

  Widget _buildDetectionPanel() {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Status indicators
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatusIndicator('😊', 'Smile', _isSmiling),
                _buildStatusIndicator('👁️', 'Blink', _isBlinking),
                _buildStatusIndicator('🔴', 'Recording', _isRecording),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _toggleRecording,
                icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
                label: Text(_isRecording ? 'Stop' : 'Start'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.red : Colors.green,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _clearEvents,
                icon: Icon(Icons.clear),
                label: Text('Clear'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
              ),
            ],
          ),

          SizedBox(height: 15),

          // Events list
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(10),
              ),
              child: _detectionEvents.isEmpty
                  ? Center(
                      child: Text(
                        'No events recorded yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _detectionEvents.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _detectionEvents[index],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String emoji, String label, bool isActive) {
    return Column(
      children: [
        Text(
          emoji,
          style: TextStyle(
            fontSize: 30,
            color: isActive ? Colors.white : Colors.grey,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.green : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Detection - Smile & Blink'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Camera preview
          CameraPreview(_cameraController),

          // Face detection overlay
          Positioned.fill(child: _buildResults()),

          // Face count display
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                'Faces: ${_faces.length}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),

          // Detection panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildDetectionPanel(),
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
  final bool isSmiling;
  final bool isBlinking;

  FacePainter({
    required this.faces,
    required this.imageSize,
    required this.previewSize,
    required this.isSmiling,
    required this.isBlinking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / imageSize.height;
    final double scaleY = size.height / imageSize.width;

    final Paint facePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;

    final Paint smilePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.yellow;

    final Paint blinkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.blue;

    for (var face in faces) {
      // Transform bounding box coordinates
      final Rect rect = Rect.fromLTRB(
        face.boundingBox.top * scaleX,
        (imageSize.width - face.boundingBox.right) * scaleY,
        face.boundingBox.bottom * scaleX,
        (imageSize.width - face.boundingBox.left) * scaleY,
      );

      // Choose paint based on detection state
      Paint currentPaint = facePaint;
      if (face.smilingProbability != null && face.smilingProbability! > 0.8) {
        currentPaint = smilePaint; // Yellow for smile
      } else if (face.leftEyeOpenProbability != null &&
          face.rightEyeOpenProbability != null &&
          face.leftEyeOpenProbability! < 0.3 &&
          face.rightEyeOpenProbability! < 0.3) {
        currentPaint = blinkPaint; // Blue for blink
      }

      // Draw face bounding box
      canvas.drawRect(rect, currentPaint);

      // Draw probability text
      if (face.smilingProbability != null) {
        final textSpan = TextSpan(
          text: 'Smile: ${(face.smilingProbability! * 100).toInt()}%',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            backgroundColor: Colors.black54,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(rect.left, rect.top - 30));
      }

      // Draw eye open probabilities
      if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
        final eyeTextSpan = TextSpan(
          text:
              'Eyes: L${(face.leftEyeOpenProbability! * 100).toInt()}% R${(face.rightEyeOpenProbability! * 100).toInt()}%',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            backgroundColor: Colors.black54,
          ),
        );
        final eyeTextPainter = TextPainter(
          text: eyeTextSpan,
          textDirection: TextDirection.ltr,
        );
        eyeTextPainter.layout();
        eyeTextPainter.paint(canvas, Offset(rect.left, rect.top - 15));
      }
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.isSmiling != isSmiling ||
        oldDelegate.isBlinking != isBlinking;
  }
}
