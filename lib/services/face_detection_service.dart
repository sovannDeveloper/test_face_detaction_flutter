import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import 'face_recognition_service.dart';

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

class FaceDetectionService {
  late CameraDescription _camera = cameras.first;
  final onDetection = StreamController<FaceData>.broadcast();
  final cameraState = StreamController<CameraState>.broadcast();

  late Size screenSize;

  FaceDetectionService([Size? screenSize0]) {
    screenSize = screenSize0 ?? Size.zero;
    cameraState.add(CameraState.none);
    _camera = cameras.firstWhere(
      (e) => e.lensDirection == CameraLensDirection.front,
    );
    _initCamera(_camera);
  }

  final faceRecognition = FaceRecognitionService();
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

      final faces = await detector.processImage(inputImage);

      onDetection.add(FaceData(
          faces: faces, imageSize: rotatedImageSize, screenSize: screenSize));
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      _isDetecting = false;
    }
  }

  img.Image? convertCameraImageToImageFast(CameraImage cameraImage) {
    if (cameraImage.format.group == ImageFormatGroup.yuv420 ||
        cameraImage.format.group == ImageFormatGroup.nv21) {
      return convertYUV420ToImageFast(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      return convertBGRA8888ToImageFast(cameraImage);
    }
    return null;
  }

// Faster YUV420/NV21 conversion
  img.Image convertYUV420ToImageFast(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;

    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];

    final image = img.Image(width: width, height: height);

    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * width + x;
        final int uvIndex = uvPixelStride * (x >> 1) + uvRowStride * (y >> 1);

        final int yValue = yPlane.bytes[yIndex];
        final int uValue = uPlane.bytes[uvIndex];
        final int vValue = vPlane.bytes[uvIndex];

        // Fast YUV to RGB conversion using bit shifts
        final int c = yValue - 16;
        final int d = uValue - 128;
        final int e = vValue - 128;

        int r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
        int g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
        int b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);

        image.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    return image;
  }

// Faster BGRA8888 conversion
  img.Image convertBGRA8888ToImageFast(CameraImage cameraImage) {
    return img.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: cameraImage.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
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

  static Uint8List _convertCameraImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final img.Image convertedImage = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = (x ~/ 2) + (y ~/ 2) * (width ~/ 2);
        final int index = y * width + x;

        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        convertedImage.setPixelRgb(x, y, r, g, b);
      }
    }

    return Uint8List.fromList(img.encodeJpg(convertedImage));
  }

  static Uint8List? extractFaceWithLandmarks(Uint8List imageBytes, Face face) {
    try {
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return null;

      final rect = face.boundingBox;
      final padding = 50.0;

      final left = (rect.left - padding)
          .clamp(0.0, originalImage.width.toDouble())
          .toInt();
      final top = (rect.top - padding)
          .clamp(0.0, originalImage.height.toDouble())
          .toInt();
      final right = (rect.right + padding)
          .clamp(0.0, originalImage.width.toDouble())
          .toInt();
      final bottom = (rect.bottom + padding)
          .clamp(0.0, originalImage.height.toDouble())
          .toInt();

      final width = right - left;
      final height = bottom - top;

      final img.Image croppedFace = img.copyCrop(
        originalImage,
        x: left,
        y: top,
        width: width,
        height: height,
      );

      // Draw landmarks
      final landmarks = face.landmarks;

      // Draw eye positions
      if (landmarks[FaceLandmarkType.leftEye] != null) {
        final leftEye = landmarks[FaceLandmarkType.leftEye]!.position;
        img.drawCircle(croppedFace,
            x: (leftEye.x - left).toInt(),
            y: (leftEye.y - top).toInt(),
            radius: 5,
            color: img.ColorRgb8(255, 0, 0));
      }

      if (landmarks[FaceLandmarkType.rightEye] != null) {
        final rightEye = landmarks[FaceLandmarkType.rightEye]!.position;
        img.drawCircle(croppedFace,
            x: (rightEye.x - left).toInt(),
            y: (rightEye.y - top).toInt(),
            radius: 5,
            color: img.ColorRgb8(255, 0, 0));
      }

      return Uint8List.fromList(img.encodeJpg(croppedFace));
    } catch (e) {
      print('Error extracting face with landmarks: $e');
      return null;
    }
  }

  void dispose() {
    cameraController.dispose();
    detector.close();
    onDetection.close();
    cameraState.close();
  }
}
