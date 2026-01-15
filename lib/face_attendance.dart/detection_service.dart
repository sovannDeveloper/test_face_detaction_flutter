part of 'main.dart';

class FaceDetectionService {
  final _detectionStream = StreamController<List<Face>>.broadcast();
  late InputImageRotation _rotation;
  bool _isDetecting = false;
  int _frameCount = 0;
  DateTime? _lastProcessTime;
  static const _minProcessInterval = Duration(milliseconds: 100);

  InputImageRotation get rotation => _rotation;

  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: false,
      enableContours: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  Stream<List<Face>> get stream => _detectionStream.stream;

  // Make this properly async with Future return type
  Future<void> processCameraImage(CameraImage image) async {
    if (_isDetecting) return;

    final now = DateTime.now();

    if (_lastProcessTime != null &&
        now.difference(_lastProcessTime!) < _minProcessInterval) {
      return;
    }

    _isDetecting = true;
    _lastProcessTime = now;

    try {
      _frameCount++;

      if (_frameCount % 3 != 0) {
        return;
      }

      final format = _getInputImageFormat(image.format);
      final originalImageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      final inputImage = InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        metadata: InputImageMetadata(
          size: originalImageSize,
          rotation: _rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final faces = await _detector
          .processImage(inputImage)
          .timeout(const Duration(seconds: 2), onTimeout: () => <Face>[]);

      if (_detectionStream.hasListener) {
        _detectionStream.add(faces);
      }
    } catch (e) {
      if (_detectionStream.hasListener) {
        _detectionStream.add(<Face>[]);
      }
    } finally {
      _isDetecting = false;
    }
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

  void initCameraRotation(CameraDescription camera) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (camera.lensDirection == CameraLensDirection.front) {
        _rotation = InputImageRotation.rotation270deg;
      } else {
        _rotation = InputImageRotation.rotation90deg;
      }
    } else {
      _rotation = InputImageRotation.rotation0deg;
    }
  }

  void dispose() {
    _detector.close();
    _detectionStream.close();
  }
}
