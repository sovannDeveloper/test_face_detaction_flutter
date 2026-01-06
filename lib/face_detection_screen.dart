import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:test_face_detaction/services/face_detection_service.dart';

import 'services/face_recognition_service.dart';
import 'widget.dart';

class FaceDetectionPage extends StatefulWidget {
  const FaceDetectionPage({super.key});

  @override
  State<FaceDetectionPage> createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> {
  final _faceRecognitionService = FaceRecognitionService();
  late final _faceDetection = FaceDetectionService(MediaQuery.of(context).size);

  @override
  void dispose() {
    _faceDetection.dispose();
    _faceRecognitionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: StreamBuilder<CameraState>(
            stream: _faceDetection.cameraState.stream,
            builder: (context, c) {
              if (c.data != CameraState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder(
                  stream: _faceDetection.onDetection.stream,
                  builder: (_, s) {
                    final faces = s.data?.faces ?? [];
                    final imgSize = s.data?.imageSize ?? Size.zero;

                    return AspectRatio(
                      aspectRatio: imgSize.width / imgSize.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        fit: StackFit.expand,
                        children: [
                          if (c.data == CameraState.done)
                            CameraPreview(_faceDetection.cameraController),
                          if (faces.isNotEmpty)
                            CustomPaint(painter: FacePainter(faces, imgSize)),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.flip_camera_ios),
                              onPressed: () {
                                _faceDetection.toggleCamera();
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  });
            }),
      ),
    );
  }
}
