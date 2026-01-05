import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:test_face_detaction/services/face_detection_service.dart';

import 'services/face_recognition_service.dart';

class FaceDetectionPage extends StatefulWidget {
  const FaceDetectionPage({super.key});

  @override
  State<FaceDetectionPage> createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> {
  final _faceRecognitionService = FaceRecognitionService();
  final _faceDetection = FaceDetectionService();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _faceRecognitionService.loadModel();
    } catch (e) {
      print('Failed to initialize services: $e');
    }
  }

  @override
  void dispose() {
    _faceDetection.dispose();
    _faceRecognitionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Detection Debug'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () {
              _faceDetection.toggleCamera();
            },
          ),
        ],
      ),
      body: StreamBuilder<CameraState>(
          stream: _faceDetection.cameraState.stream,
          builder: (context, s) {
            if (s.data != CameraState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                CameraPreview(_faceDetection.cameraController),
                StreamBuilder(
                    stream: _faceDetection.onDetection.stream,
                    builder: (_, s) {
                      final faces = s.data?.faces ?? [];
                      if (faces.isEmpty) {
                        return const SizedBox();
                      }

                      final imgSize = s.data?.imageSize ?? Size.zero;

                      return CustomPaint(
                        painter: FacePainter(
                          faces,
                          imgSize,
                          _faceDetection.getCamera.lensDirection,
                          _faceDetection
                              .cameraController.value.deviceOrientation,
                        ),
                      );
                    }),
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: StreamBuilder(
                      stream: _faceDetection.onDetection.stream,
                      builder: (context, s) {
                        final faces = s.data?.faces ?? [];
                        if (faces.isEmpty) {
                          return const SizedBox();
                        }

                        return Center(
                          child: SingleChildScrollView(
                            child: Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(faces.length, (i) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Text(
                                        'Face ${i + 1}: ${faces[i].boundingBox.toString()}\n'
                                        'Smile: ${faces[i].smilingProbability?.toStringAsFixed(2) ?? 'N/A'}\n'
                                        'Left Eye Open: ${faces[i].leftEyeOpenProbability?.toStringAsFixed(2) ?? 'N/A'}\n'
                                        'Right Eye Open: ${faces[i].rightEyeOpenProbability?.toStringAsFixed(2) ?? 'N/A'}\n'
                                        'Tracking ID: ${faces[i].trackingId ?? 'N/A'}\n'
                                        'Landmarks: ${faces[i].landmarks.length}\n'
                                        'Contour Points: ${faces[i].contours.length}\n'
                                        'Head Euler Angle Y: ${faces[i].headEulerAngleY?.toStringAsFixed(2) ?? 'N/A'}\n'
                                        'Head Euler Angle Z: ${faces[i].headEulerAngleZ?.toStringAsFixed(2) ?? 'N/A'}\n'
                                        'Size: ${_faceDetection.cameraController.value.previewSize}',
                                        key: Key('face_$i'),
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 10)),
                                  );
                                }),
                              ),
                            ),
                          ),
                        );
                      }),
                ),
              ],
            );
          }),
    );
  }
}

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final CameraLensDirection lens;
  final DeviceOrientation orientation;

  FacePainter(this.faces, this.imageSize, this.lens, this.orientation);

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
        lensDirection: lens,
        orientation: orientation,
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
    required CameraLensDirection lensDirection,
    required DeviceOrientation orientation,
  }) {
    // Get actual rotated image size based on orientation
    final Size rotatedImageSize =
        (orientation == DeviceOrientation.portraitUp ||
                orientation == DeviceOrientation.portraitDown)
            ? Size(imageSize.height, imageSize.width)
            : imageSize;

    // Calculate scale to fit image in widget
    final double scaleX = widgetSize.width / rotatedImageSize.width;
    final double scaleY = widgetSize.height / rotatedImageSize.height;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate centered position offsets
    final double scaledWidth = rotatedImageSize.width * scale;
    final double scaledHeight = rotatedImageSize.height * scale;
    final double offsetX = (widgetSize.width - scaledWidth) / 2;
    final double offsetY = (widgetSize.height - scaledHeight) / 2;

    // Transform coordinates based on orientation
    double left, top, right, bottom;

    if (orientation == DeviceOrientation.portraitUp) {
      // Rotate 90 degrees clockwise
      left = rect.top * scale + offsetX;
      top = (imageSize.width - rect.right) * scale + offsetY;
      right = rect.bottom * scale + offsetX;
      bottom = (imageSize.width - rect.left) * scale + offsetY;
    } else if (orientation == DeviceOrientation.landscapeLeft) {
      left = rect.left * scale + offsetX;
      top = rect.top * scale + offsetY;
      right = rect.right * scale + offsetX;
      bottom = rect.bottom * scale + offsetY;
    } else if (orientation == DeviceOrientation.portraitDown) {
      left = (imageSize.height - rect.bottom) * scale + offsetX;
      top = rect.left * scale + offsetY;
      right = (imageSize.height - rect.top) * scale + offsetX;
      bottom = rect.right * scale + offsetY;
    } else {
      // landscapeRight
      left = (imageSize.width - rect.right) * scale + offsetX;
      top = (imageSize.height - rect.bottom) * scale + offsetY;
      right = (imageSize.width - rect.left) * scale + offsetX;
      bottom = (imageSize.height - rect.top) * scale + offsetY;
    }

    // Mirror for front camera
    if (lensDirection == CameraLensDirection.front) {
      final double tempLeft = left;
      left = widgetSize.width - right;
      right = widgetSize.width - tempLeft;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
