part of 'main.dart';

class _Detector {
  List<Face> _currentFaces = [];
  InputImageRotation? _rotation;
  bool _isDetecting = false;
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

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

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (var plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
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

  /// From path or camera image
  InputImage? _processImage(Object image) {
    if (image is String) {
      return InputImage.fromFilePath(image);
    } else if (image is CameraImage) {
      final format = _getInputImageFormat(image.format);
      final originalImageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      return InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        metadata: InputImageMetadata(
          size: originalImageSize,
          rotation: _rotation ?? InputImageRotation.rotation0deg,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }

    return null;
  }

  /// Process from file
  Future<List<Face>> process(Object image) async {
    if (_isDetecting) return _currentFaces;
    _isDetecting = true;

    try {
      final inputImage = _processImage(image);

      if (inputImage == null) {
        return _currentFaces;
      }

      final faces = await _detector
          .processImage(inputImage)
          .timeout(const Duration(seconds: 2), onTimeout: () => <Face>[]);
      _currentFaces = faces;
      _currentFaces = _currentFaces.where((e) => e.trackingId != null).toList();
      _currentFaces.sort(
        (a, b) => (a.trackingId ?? 0).compareTo(b.trackingId ?? 0),
      );
      return _currentFaces;
    } catch (e) {
      print('Face detection error: $e');
      return [];
    } finally {
      _isDetecting = false;
    }
  }

  void dispose() {
    _detector.close();
  }
}
