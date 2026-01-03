import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
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
  late CameraDescription _camera = _faceDetection.cameras.first;

  @override
  void initState() {
    super.initState();

    _initializeModel();
  }

  Future<void> _initializeModel() async {
    try {
      await _faceRecognitionService.loadModel();
    } catch (e) {
      print('Fail to load model $e');
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
            icon: Icon(Icons.flip_camera_ios),
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
              children: [
                CameraPreview(_faceDetection.cameraController),
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: StreamBuilder<List<Face>>(
                      stream: _faceDetection.onDetection.stream,
                      builder: (context, s) {
                        if (!s.hasData || s.data!.isEmpty) {
                          return const SizedBox();
                        }

                        final faces = s.data ?? [];

                        return Center(
                          child: SingleChildScrollView(
                            child: Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Column(
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
                                        'Classification: ${faces[i].headEulerAngleY?.toStringAsFixed(2) ?? 'N/A'}\n'
                                        'Head Euler Angle Z: ${faces[i].headEulerAngleZ?.toStringAsFixed(2) ?? 'N/A'}\n',
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
