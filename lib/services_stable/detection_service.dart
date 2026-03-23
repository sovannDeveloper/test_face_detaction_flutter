part of 'main.dart';

/// Blink twice
/// Turn head left
/// Turn head right
/// Smile
/// Raise eyebrows

class FaceDetectionService {
  final _detectionStream = StreamController<(Face?, CameraImage?)>.broadcast();
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

  Stream<(Face?, CameraImage?)> get stream => _detectionStream.stream;

  void process(CameraImage image) {
    if (_isDetecting) return;

    _frameCount++;

    if (_frameCount % 5 != 0) {
      return;
    }

    _processImageAsync(image);
  }

  InputImage cameraImgToInputImg(CameraImage image) {
    final format = _getInputImageFormat(image.format);
    final originalImageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      metadata: InputImageMetadata(
        size: originalImageSize,
        rotation: _rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  // Separate async method that runs in background
  Future<void> _processImageAsync(CameraImage image) async {
    _isDetecting = true;

    try {
      final inputImage = cameraImgToInputImg(image);
      final faces = await _detector
          .processImage(inputImage)
          .timeout(const Duration(seconds: 2), onTimeout: () => <Face>[]);

      if (_detectionStream.hasListener) {
        final face = getSingleFace(faces);

        if (face == null) throw 'No face';

        _detectionStream.add((face, image));
      }
    } catch (e) {
      print('Detect Error: $e');
      if (_detectionStream.hasListener) {
        _detectionStream.add((null, null));
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

  Future<Uint8List> getFaceFromFilePath(
    Face face,
    InputImage inputImage,
  ) async {
    final Uint8List bytes = inputImage.bytes ?? Uint8List.fromList([]);
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image originalImage = frameInfo.image;

    final boundingBox = face.boundingBox;

    const padding = 0;
    final paddingX = boundingBox.width * padding;
    final paddingY = boundingBox.height * padding;

    final left = (boundingBox.left - paddingX).clamp(
      0,
      originalImage.width.toDouble(),
    );
    final top = (boundingBox.top - paddingY).clamp(
      0,
      originalImage.height.toDouble(),
    );
    final width = (boundingBox.width + paddingX * 2).clamp(
      0,
      originalImage.width - left,
    );
    final height = (boundingBox.height + paddingY * 2).clamp(
      0,
      originalImage.height - top,
    );

    final squareSize = (width < height ? width : height).toDouble();
    final centerX = left + width / 2;
    final centerY = top + height / 2;

    final squareLeft = (centerX - squareSize / 2)
        .clamp(0, originalImage.width.toDouble() - squareSize)
        .toDouble();
    final squareTop = (centerY - squareSize / 2)
        .clamp(0, originalImage.height.toDouble() - squareSize)
        .toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImageRect(
      originalImage,
      Rect.fromLTWH(squareLeft, squareTop, squareSize, squareSize),
      Rect.fromLTWH(0, 0, squareSize, squareSize),
      Paint(),
    );

    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(
      squareSize.toInt(),
      squareSize.toInt(),
    );
    final byteData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final pngBytes = byteData!.buffer.asUint8List();

    return pngBytes;
  }

  void dispose() {
    _detector.close();
    _detectionStream.close();
  }
}
