part of 'main.dart';

class FaceAntiSpoofingDetector {
  Interpreter? _interpreter;
  List<int>? _inputShape;
  List<int>? _outputShape;

  // Initialize the model
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/face_anti_spoofing.tflite',
      );

      // Get input and output shapes
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;

      print('Model loaded successfully');
      print('Input shape: $_inputShape');
      print('Output shape: $_outputShape');
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  // Preprocess image for the model
  List<List<List<List<double>>>> preprocessImage(img.Image image) {
    // Resize image to match model input (typically 256x256 or 224x224)
    int inputHeight = _inputShape![1];
    int inputWidth = _inputShape![2];

    img.Image resizedImage = img.copyResize(
      image,
      width: inputWidth,
      height: inputHeight,
    );

    // Convert to normalized float values
    List<List<List<List<double>>>> input = List.generate(
      1,
      (_) => List.generate(
        inputHeight,
        (y) => List.generate(
          inputWidth,
          (x) {
            img.Pixel pixel = resizedImage.getPixel(x, y);
            return [
              pixel.r / 255.0, // Normalize to [0, 1]
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );

    return input;
  }

  // Run inference from bytes
  Future<Map<String, dynamic>> detectSpoof(Uint8List imageBytes) async {
    if (_interpreter == null) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    // Decode bytes to image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image from bytes');
    }

    // Preprocess the image
    var input = preprocessImage(image);

    // Prepare output buffer
    var output =
        List.filled(_outputShape![1], 0.0).reshape([1, _outputShape![1]]);

    // Run inference
    _interpreter!.run(input, output);

    // Parse results
    // Typically output[0][0] is the probability of being real
    // and output[0][1] is the probability of being fake/spoofed
    double realScore = output[0][0];
    double spoofScore = output[0][1];

    bool isReal = realScore > spoofScore;
    double confidence = isReal ? realScore : spoofScore;

    return {
      'isReal': isReal,
      'confidence': confidence,
      'realScore': realScore,
      'spoofScore': spoofScore,
    };
  }

  // Alternative: Run inference from img.Image (if you already have decoded image)
  Future<Map<String, dynamic>> detectSpoofFromImage(img.Image image) async {
    if (_interpreter == null) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    // Preprocess the image
    var input = preprocessImage(image);

    // Prepare output buffer
    var output =
        List.filled(_outputShape![1], 0.0).reshape([1, _outputShape![1]]);

    // Run inference
    _interpreter!.run(input, output);

    // Parse results
    double realScore = output[0][0];
    double spoofScore = output[0][1];

    bool isReal = realScore > spoofScore;
    double confidence = isReal ? realScore : spoofScore;

    return {
      'isReal': isReal,
      'confidence': confidence,
      'realScore': realScore,
      'spoofScore': spoofScore,
    };
  }

  // Convert CameraImage to img.Image
  img.Image convertCameraImage(dynamic cameraImage) {
    // For YUV420 format (common on Android)
    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      return convertYUV420ToImage(cameraImage);
    }
    // For BGRA8888 format (common on iOS)
    else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      return convertBGRA8888ToImage(cameraImage);
    }
    throw UnsupportedError('Unsupported image format');
  }

  img.Image convertYUV420ToImage(dynamic cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final img.Image image = img.Image(width: width, height: height);
    final Plane yPlane = cameraImage.planes[0];
    final Plane uPlane = cameraImage.planes[1];
    final Plane vPlane = cameraImage.planes[2];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yPlane.bytesPerRow + x;
        final int uvIndex = (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2);

        final int yValue = yPlane.bytes[yIndex];
        final int uValue = uPlane.bytes[uvIndex];
        final int vValue = vPlane.bytes[uvIndex];

        // YUV to RGB conversion
        int r = (yValue + 1.370705 * (vValue - 128)).clamp(0, 255).toInt();
        int g = (yValue - 0.337633 * (uValue - 128) - 0.698001 * (vValue - 128))
            .clamp(0, 255)
            .toInt();
        int b = (yValue + 1.732446 * (uValue - 128)).clamp(0, 255).toInt();

        image.setPixelRgba(x, y, r, g, b, 255);
      }
    }
    return image;
  }

  img.Image convertBGRA8888ToImage(dynamic cameraImage) {
    return img.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: cameraImage.planes[0].bytes.buffer,
      format: img.Format.uint8,
      numChannels: 4,
    );
  }

  // Clean up resources
  void dispose() {
    _interpreter?.close();
  }
}
