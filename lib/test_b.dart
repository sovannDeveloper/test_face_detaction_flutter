import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:test_face_detaction/services/object_detection_service.dart';

class ObjectDetectionPage extends StatefulWidget {
  const ObjectDetectionPage({super.key});

  @override
  State<ObjectDetectionPage> createState() => _ObjectDetectionPageState();
}

class _ObjectDetectionPageState extends State<ObjectDetectionPage> {
  late final ObjectDetectionService _objectDetection =
      ObjectDetectionService(MediaQuery.of(context).size)..initialize();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {}

  @override
  void dispose() {
    _objectDetection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Object Detection'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () {
              _objectDetection.toggleCamera();
            },
          ),
        ],
      ),
      body: StreamBuilder<CameraState>(
        stream: _objectDetection.cameraState.stream,
        builder: (context, s) {
          if (s.data != CameraState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              CameraPreview(_objectDetection.cameraController),
              StreamBuilder(
                stream: _objectDetection.onDetection.stream,
                builder: (_, s) {
                  final objects = s.data?.objects ?? [];
                  if (objects.isEmpty) {
                    return const SizedBox();
                  }

                  final imgSize = s.data?.imageSize ?? Size.zero;

                  return CustomPaint(
                    painter: ObjectPainter(
                      objects,
                      imgSize,
                      _objectDetection.getCamera.lensDirection,
                      _objectDetection.cameraController.value.deviceOrientation,
                    ),
                  );
                },
              ),
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: StreamBuilder(
                  stream: _objectDetection.onDetection.stream,
                  builder: (context, s) {
                    final objects = s.data?.objects ?? [];
                    if (objects.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Text(
                          'No objects detected',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${objects.length} object(s) detected',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...List.generate(objects.length, (i) {
                              final obj = objects[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Object ${i + 1}:',
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Tracking ID: ${obj.trackingId ?? 'N/A'}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                    if (obj.labels.isNotEmpty)
                                      ...obj.labels.map((label) => Text(
                                            '${label.text}: ${(label.confidence * 100).toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                            ),
                                          )),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ObjectPainter extends CustomPainter {
  final List<DetectedObject> objects;
  final Size imageSize;
  final CameraLensDirection lens;
  final DeviceOrientation orientation;

  ObjectPainter(this.objects, this.imageSize, this.lens, this.orientation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.green;

    for (int i = 0; i < objects.length; i++) {
      final obj = objects[i];
      final rect = _scaleRect(
        rect: obj.boundingBox,
        imageSize: imageSize,
        widgetSize: size,
        lensDirection: lens,
        orientation: orientation,
      );

      canvas.drawRect(rect, paint);

      // Draw label if available
      if (obj.labels.isNotEmpty) {
        final label = obj.labels.first;
        _drawText(
          canvas: canvas,
          text: '${label.text} ${(label.confidence * 100).toStringAsFixed(0)}%',
          position: Offset(rect.left, rect.top - 25),
          backgroundColor: Colors.green,
        );
      } else {
        _drawText(
          canvas: canvas,
          text: 'Object ${i + 1}',
          position: Offset(rect.left, rect.top - 25),
          backgroundColor: Colors.blue,
        );
      }
    }
  }

  void _drawText({
    required Canvas canvas,
    required String text,
    required Offset position,
    required Color backgroundColor,
    Color textColor = Colors.white,
    double fontSize = 14,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Draw background
    final backgroundRect = Rect.fromLTWH(
      position.dx,
      position.dy,
      textPainter.width + 8,
      textPainter.height + 4,
    );

    final backgroundPaint = Paint()
      ..color = backgroundColor.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    canvas.drawRect(backgroundRect, backgroundPaint);

    // Draw text
    textPainter.paint(canvas, position + const Offset(4, 2));
  }

  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
    required CameraLensDirection lensDirection,
    required DeviceOrientation orientation,
  }) {
    final Size rotatedImageSize =
        (orientation == DeviceOrientation.portraitUp ||
                orientation == DeviceOrientation.portraitDown)
            ? Size(imageSize.height, imageSize.width)
            : imageSize;

    final double scaleX = widgetSize.width / rotatedImageSize.width;
    final double scaleY = widgetSize.height / rotatedImageSize.height;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    final double scaledWidth = rotatedImageSize.width * scale;
    final double scaledHeight = rotatedImageSize.height * scale;
    final double offsetX = (widgetSize.width - scaledWidth) / 2;
    final double offsetY = (widgetSize.height - scaledHeight) / 2;

    double left, top, right, bottom;

    if (orientation == DeviceOrientation.portraitUp) {
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
      left = (imageSize.width - rect.right) * scale + offsetX;
      top = (imageSize.height - rect.bottom) * scale + offsetY;
      right = (imageSize.width - rect.left) * scale + offsetX;
      bottom = (imageSize.height - rect.top) * scale + offsetY;
    }

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
