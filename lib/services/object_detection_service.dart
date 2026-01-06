import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

enum CameraState { done, none }

class ObjectData {
  final List<DetectedObject> objects;
  final Size imageSize;
  final Size screenSize;

  ObjectData({
    this.objects = const [],
    this.imageSize = Size.zero,
    this.screenSize = Size.zero,
  });
}

class ObjectDetectionService {
  late CameraDescription _camera = cameras.first;
  final onDetection = StreamController<ObjectData>.broadcast();
  final cameraState = StreamController<CameraState>.broadcast();

  ObjectDetectionService([Size? screenSize0]) {
    cameraState.add(CameraState.none);
    _camera = cameras.firstWhere(
      (e) => e.lensDirection == CameraLensDirection.back,
    );
    _initCamera(_camera);
  }

  static List<CameraDescription> _cameras = [];
  bool _isDetecting = false;
  int _frameCount = 0;
  late CameraController cameraController;

  CameraDescription get getCamera => _camera;

  Future<void> _initCamera(CameraDescription camera) async {
    cameraState.add(CameraState.none);
    await Future.delayed(const Duration(milliseconds: 500));

    cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await cameraController.initialize();
    await Future.delayed(const Duration(milliseconds: 250));

    cameraController.startImageStream(_processCameraImage);
    cameraState.add(CameraState.done);
  }

  Future<void> toggleCamera() async {
    await cameraController.stopImageStream();
    await cameraController.dispose();

    _camera = _camera.lensDirection == CameraLensDirection.front
        ? cameras.firstWhere(
            (cam) => cam.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          )
        : cameras.firstWhere(
            (cam) => cam.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first,
          );

    await _initCamera(_camera);
  }

  // Initialize object detector
  late final ObjectDetector detector;

  Future<void> _initializeDetector() async {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    );
    detector = ObjectDetector(options: options);
  }

  // Alternative: Use custom model
  Future<void> _initializeCustomDetector(String modelPath) async {
    final options = LocalObjectDetectorOptions(
      mode: DetectionMode.stream,
      modelPath: modelPath,
      classifyObjects: true,
      multipleObjects: true,
    );
    detector = ObjectDetector(options: options);
  }

  List<CameraDescription> get cameras => _cameras;

  static Future<void> initCameras() async {
    _cameras = await availableCameras();
  }

  Future<void> initialize() async {
    await _initializeDetector();
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

      final rotation = _getImageRotation();
      final format = _getInputImageFormat(image.format);

      final originalImageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      final rotatedImageSize = rotation == InputImageRotation.rotation90deg ||
              rotation == InputImageRotation.rotation270deg
          ? Size(originalImageSize.height, originalImageSize.width)
          : originalImageSize;

      final inputImage = InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        metadata: InputImageMetadata(
          size: originalImageSize,
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final objects = await detector.processImage(inputImage);

      onDetection
          .add(ObjectData(objects: objects, imageSize: rotatedImageSize));
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
