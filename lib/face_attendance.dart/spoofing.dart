part of 'main.dart';

class FaceAntiSpoofingDetector {
  Interpreter? _interpreter;
  List<int>? _inputShape;
  List<int>? _outputShape;
  TensorType? _inputType;
  TensorType? _outputType;

  // Initialize the model
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/face_anti_spoofing.tflite',
      );

      // Get input and output shapes
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      _inputType = _interpreter!.getInputTensor(0).type;
      _outputType = _interpreter!.getOutputTensor(0).type;

      print('Model loaded successfully');
      print('Input shape: $_inputShape');
      print('Output shape: $_outputShape');
      print('Input type: $_inputType');
      print('Output type: $_outputType');
    } catch (e) {
      print('Error loading model: $e');
      rethrow;
    }
  }

  // Preprocess image for the model
  dynamic preprocessImage(img.Image image) {
    // Resize image to match model input (typically 256x256 or 224x224)
    int inputHeight = _inputShape![1];
    int inputWidth = _inputShape![2];
    int inputChannels = _inputShape!.length > 3 ? _inputShape![3] : 3;

    img.Image resizedImage = img.copyResize(
      image,
      width: inputWidth,
      height: inputHeight,
    );

    // Determine if model expects float32 or uint8
    if (_inputType == TensorType.float32) {
      // Return normalized float32 values [0, 1]
      var input = List.generate(
        1,
        (_) => List.generate(
          inputHeight,
          (y) => List.generate(
            inputWidth,
            (x) {
              img.Pixel pixel = resizedImage.getPixel(x, y);
              if (inputChannels == 3) {
                return [
                  pixel.r / 255.0,
                  pixel.g / 255.0,
                  pixel.b / 255.0,
                ];
              } else {
                // Grayscale
                double gray =
                    (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114) /
                        255.0;
                return [gray];
              }
            },
          ),
        ),
      );
      return input;
    } else {
      // Return uint8 values [0, 255]
      var input = List.generate(
        1,
        (_) => List.generate(
          inputHeight,
          (y) => List.generate(
            inputWidth,
            (x) {
              img.Pixel pixel = resizedImage.getPixel(x, y);
              if (inputChannels == 3) {
                return [
                  pixel.r.toInt(),
                  pixel.g.toInt(),
                  pixel.b.toInt(),
                ];
              } else {
                int gray = (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114)
                    .toInt();
                return [gray];
              }
            },
          ),
        ),
      );
      return input;
    }
  }

  // Run inference from bytes
  Future<Map<String, dynamic>?> detectSpoof(Uint8List imageBytes) async {
    try {
      if (_interpreter == null) {
        throw Exception('Model not loaded. Call loadModel() first.');
      }

      if (_outputShape == null || _outputShape!.isEmpty) {
        throw Exception(
            'Output shape is null or empty. Model may not be loaded correctly.');
      }

      // Decode bytes to image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image from bytes');
      }

      // Preprocess the image
      var input = preprocessImage(image);

      // Create output buffer matching the exact output shape
      var output;
      if (_outputShape!.length == 2) {
        // Most common: [batch_size, num_classes]
        output = List.generate(
          _outputShape![0],
          (_) => List.filled(_outputShape![1], 0.0),
        );
      } else if (_outputShape!.length == 1) {
        // Single dimension: [num_classes]
        output = List.filled(_outputShape![0], 0.0);
      } else if (_outputShape!.length == 4) {
        // 4D output: [batch, height, width, channels]
        output = List.generate(
          _outputShape![0],
          (_) => List.generate(
            _outputShape![1],
            (_) => List.generate(
              _outputShape![2],
              (_) => List.filled(_outputShape![3], 0.0),
            ),
          ),
        );
      } else {
        throw Exception('Unsupported output shape: $_outputShape');
      }

      _interpreter!.run(input, output);

      // Extract results based on output structure
      List<double> scores;
      if (output is List<List<double>>) {
        scores = output[0];
      } else if (output is List<double>) {
        scores = output;
      } else {
        // For 4D output, flatten to get final scores
        scores = (output[0][0][0] as List).cast<double>();
      }

      print('Output scores: $scores');

      // Parse results
      double realScore;
      double spoofScore;

      if (scores.length == 1) {
        // Single output: treat as probability of being real
        realScore = scores[0];
        spoofScore = 1.0 - realScore;
      } else if (scores.length >= 2) {
        // Multiple outputs: first is real, second is spoof
        realScore = scores[0];
        spoofScore = scores[1];
      } else {
        throw Exception('Unexpected number of output scores: ${scores.length}');
      }

      bool isReal = realScore > spoofScore;
      double confidence = isReal ? realScore : spoofScore;

      return {
        'isReal': isReal,
        'confidence': confidence,
        'realScore': realScore,
        'spoofScore': spoofScore,
        'rawOutput': scores,
      };
    } catch (e) {
      print('--=> ✗ Error in detectSpoof: $e');
      return null;
    }
  }

  // Alternative: Run inference from img.Image (if you already have decoded image)
  Future<Map<String, dynamic>> detectSpoofFromImage(img.Image image) async {
    if (_interpreter == null) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    if (_outputShape == null || _outputShape!.isEmpty) {
      throw Exception(
          'Output shape is null or empty. Model may not be loaded correctly.');
    }

    // Preprocess the image
    var input = preprocessImage(image);

    // Prepare output buffer based on output shape
    List<List<double>> output;

    if (_outputShape!.length == 2) {
      int numClasses = _outputShape![1];
      output = List.generate(1, (_) => List.filled(numClasses, 0.0));
    } else if (_outputShape!.length == 1) {
      int numClasses = _outputShape![0];
      output = [List.filled(numClasses, 0.0)];
    } else {
      throw Exception('Unexpected output shape: $_outputShape');
    }

    // Run inference
    _interpreter!.run(input, output);

    // Parse results
    double realScore;
    double spoofScore;

    if (output[0].length == 1) {
      realScore = output[0][0];
      spoofScore = 1.0 - realScore;
    } else if (output[0].length == 2) {
      realScore = output[0][0];
      spoofScore = output[0][1];
    } else {
      realScore = output[0][0];
      spoofScore = output[0][1];
    }

    bool isReal = realScore > spoofScore;
    double confidence = isReal ? realScore : spoofScore;

    return {
      'isReal': isReal,
      'confidence': confidence,
      'realScore': realScore,
      'spoofScore': spoofScore,
      'rawOutput': output[0],
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
