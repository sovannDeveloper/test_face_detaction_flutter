import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'face_recognition_service.dart';
import 'util.dart';

enum CameraState { done, none }

class FaceData {
  final List<Face> faces;
  final Size imageSize;
  final Size screenSize;

  FaceData({
    this.faces = const [],
    this.imageSize = Size.zero,
    this.screenSize = Size.zero,
  });
}

class FaceDetectionService0{
  late CameraDescription _camera = cameras.first;
  final onDetection = StreamController<FaceData>.broadcast();
  final onRecognize = StreamController.broadcast();
  final cameraState = StreamController<CameraState>.broadcast();

  late Size screenSize;

  FaceDetectionService0([Size? screenSize0]) {
    screenSize = screenSize0 ?? Size.zero;
    cameraState.add(CameraState.none);
    _camera = cameras.firstWhere(
      (e) => e.lensDirection == CameraLensDirection.front,
    );
    _initCamera(_camera);
  }

  final faceRecognition = FaceRecognitionService0();
  static List<CameraDescription> _cameras = [];
  bool _isDetecting = false;
  int _frameCount = 0;
  late CameraController cameraController;
  bool _isRecognizing = false;

  CameraDescription get getCamera => _camera;

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

  final detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
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

      if (_frameCount % 3 != 0) {
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

      final faces = await detector.processImage(inputImage);

      onDetection.add(FaceData(
        faces: faces,
        imageSize: rotatedImageSize,
        screenSize: screenSize,
      ));

      _performRecognitionAsync(image, rotation);
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _performRecognitionAsync(
      CameraImage image, InputImageRotation rotation) async {
    if (_isRecognizing) return;

    _isRecognizing = true;

    try {
      final convertedImage =
          ImageUtil.convertCameraImageToImgWithRotation(image, rotation);

      if (convertedImage == null) return;

      final recognize = await faceRecognition.recognizeFace(convertedImage);

      if (recognize != null && recognize['confidence'] != null) {
        final confidencePercent = (recognize['confidence'] * 100).round();
        onRecognize.add('$confidencePercent');
      }
    } catch (e) {
      print('Error in async recognition: $e');
    } finally {
      _isRecognizing = false;
    }
  }

  InputImageRotation _getImageRotation() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (_camera.lensDirection == CameraLensDirection.front) {
        return InputImageRotation.rotation270deg;
      } else {
        return InputImageRotation.rotation90deg;
      }
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
    onRecognize.close();
    cameraState.close();
  }
}
