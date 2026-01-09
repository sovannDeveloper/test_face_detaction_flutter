part of 'main.dart';

class FaceData {
  final Face face;
  final Size imageSize;
  final bool isVerify;
  final BlinkEvent? blinkEvent;

  FaceData({
    required this.face,
    this.blinkEvent,
    this.isVerify = false,
    this.imageSize = Size.zero,
  });
}

class FaceDetectionService {
  final onDetection = StreamController<FaceData?>.broadcast();
  late InputImageRotation _rotation;
  late final _blinkDetector = AdvancedBlinkDetector();
  final faceRecognition = FaceRecognitionService();
  bool _isDetecting = false;
  int _frameCount = 0;
  bool _isRecognizing = false;
  int _id = 0;
  bool _isVerify = false;
  BlinkEvent? _blinkEvent;

  final detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  void processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      _frameCount++;

      if (_frameCount % 3 != 0) {
        _isDetecting = false;
        return;
      }

      final format = _getInputImageFormat(image.format);

      final originalImageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      final rotatedImageSize = _rotation == InputImageRotation.rotation90deg ||
              _rotation == InputImageRotation.rotation270deg
          ? Size(originalImageSize.height, originalImageSize.width)
          : originalImageSize;

      final inputImage = InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        metadata: InputImageMetadata(
          size: originalImageSize,
          rotation: _rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final faces = await detector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final trackingId = faces.first.trackingId ?? 0;

        if (trackingId != _id) {
          _isVerify = false;
          _id = trackingId;
          _blinkEvent = null;
          _blinkDetector.resetCalibration();
        }

        // Verify eyes
        if (_isVerify && _blinkEvent?.type != BlinkType.bothEyes) {
          final event = _blinkDetector.processFrame(faces.first);

          _blinkEvent = event;
        }

        onDetection.add(FaceData(
          face: faces.first,
          imageSize: rotatedImageSize,
          isVerify: _isVerify,
          blinkEvent: _blinkEvent,
        ));

        if (_frameCount % 20 == 0) {
          _performRecognitionAsync(image, _rotation);
        }
      }
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _performRecognitionAsync(
      CameraImage image, InputImageRotation rotation) async {
    if (_isRecognizing || _isVerify) return;

    _isRecognizing = true;

    try {
      final convertedImage =
          ImageUtil.convertCameraImageToImgWithRotation(image, rotation);

      if (convertedImage == null) return;

      final recognize = await faceRecognition.recognizeFace(convertedImage);

      if (recognize != null && recognize['confidence'] != null) {
        final confidencePercent = (recognize['confidence'] * 100).round();

        _isVerify = confidencePercent > 50;
      }
    } catch (e) {
      print('Error in async recognition: $e');
    } finally {
      _isRecognizing = false;
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

  void init(CameraDescription camera) {
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

  static Rect scaleRect({
    required Rect rect,
    required Size size,
    required Size widgetSize,
  }) {
    final double scaleX = widgetSize.width / size.width;
    final double scaleY = widgetSize.height / size.height;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate centered position offsets
    final double scaledWidth = size.width * scale;
    final double scaledHeight = size.height * scale;
    final double offsetX = (widgetSize.width - scaledWidth) / 2;
    final double offsetY = (widgetSize.height - scaledHeight) / 2;

    // Scale the rectangle
    double left = rect.left * scale + offsetX;
    double top = rect.top * scale + offsetY;
    double right = rect.right * scale + offsetX;
    double bottom = rect.bottom * scale + offsetY;

    return Rect.fromLTRB(
      left.clamp(0, left),
      top.clamp(0, top),
      right.clamp(0, right),
      bottom.clamp(0, bottom),
    );
  }

  void dispose() {
    detector.close();
    onDetection.close();
  }
}
