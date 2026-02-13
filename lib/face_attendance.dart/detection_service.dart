part of 'main.dart';

/// Blink twice
/// Turn head left
/// Turn head right
/// Smile
/// Raise eyebrows

class FaceDetectionService {
  final _detectionStream =
      StreamController<(List<Face>, CameraImage)>.broadcast();
  final _testImgStream = StreamController<Uint8List>.broadcast();
  late InputImageRotation _rotation;
  bool _isDetecting = false;
  int _frameCount = 0;

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

  Stream<(List<Face>, CameraImage)> get stream => _detectionStream.stream;
  Stream<Uint8List> get testStream => _testImgStream.stream;

  void process(CameraImage image) {
    if (_isDetecting) return;

    _frameCount++;

    if (_frameCount % 5 != 0) {
      return;
    }

    _processImageAsync(image);
  }

  // Separate async method that runs in background
  Future<void> _processImageAsync(CameraImage image) async {
    _isDetecting = true;

    try {
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
        _detectionStream.add((faces, image));
      }
    } catch (e) {
      if (_detectionStream.hasListener) {
        _detectionStream.add((<Face>[], image));
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
    _testImgStream.close();
  }
}
