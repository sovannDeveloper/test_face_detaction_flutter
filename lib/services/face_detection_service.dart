import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum CameraState { done, none }

class FaceDetectionService {
  late CameraDescription _camera = cameras.first;
  final onDetection = StreamController<List<Face>>.broadcast();
  final cameraState = StreamController<CameraState>.broadcast();

  FaceDetectionService() {
    cameraState.add(CameraState.none);
    _camera =
        cameras.firstWhere((e) => e.lensDirection == CameraLensDirection.front);
    _initCamera(_camera);
  }

  static List<CameraDescription> _cameras = [];
  bool _isDetecting = false;
  int _frameCount = 0;
  late CameraController cameraController;

  Future<void> _initCamera(CameraDescription camera) async {
    cameraState.add(CameraState.none);
    await Future.delayed(const Duration(milliseconds: 500));
    cameraController = CameraController(
      camera,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await cameraController.initialize();
    await Future.delayed(const Duration(milliseconds: 250));

    cameraController.startImageStream(_processCameraImage);
    cameraState.add(CameraState.done);
  }

  Future<void> toggleCamera() async {
    cameraController = CameraController(
      _camera,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    _camera = _camera.lensDirection == CameraLensDirection.front
        ? cameras.firstWhere(
            (cam) => cam.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first)
        : cameras.firstWhere(
            (cam) => cam.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first);
    await _initCamera(_camera);
  }

  final detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      minFaceSize: 1, // Allow smaller faces
      performanceMode: FaceDetectorMode.accurate, // Use fast mode
    ),
  );

  List<CameraDescription> get cameras => _cameras;

  static Future<void> initCameras() async {
    _cameras = await availableCameras();
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      _frameCount++;

      if (_frameCount % 5 != 0) {
        _isDetecting = false;
        return;
      }

      InputImageRotation rotation = _getImageRotation();
      InputImageFormat format = _getInputImageFormat(image.format);

      final inputImage = InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final faces = await detector.processImage(inputImage);

      onDetection.add(faces);
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImageRotation _getImageRotation() {
    if (defaultTargetPlatform == TargetPlatform.android) {
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

  void dispose() {
    cameraController.dispose();
    detector.close();
    onDetection.close();
    cameraState.close();
  }
}
