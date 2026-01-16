part of 'main.dart';

class RecognitionServiceData {
  final double confidence;
  final bool matched;

  RecognitionServiceData({
    required this.confidence,
    required this.matched,
  });
}

class FaceRecognitionService {
  static Interpreter? interpreter;
  static List<List<double>> registeredFaces = [];
  static const int inputSize = 112;
  static const int outputSize = 192;
  static Float32List? _inputBuffer;
  static Float32List? _outputBuffer;
  late InputImageRotation _rotation;
  double threshold = 0.5;

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

  void setThreshold(double newThreshold) {
    threshold = newThreshold;
  }

  static Future<void> loadModel() async {
    try {
      interpreter =
          await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      _inputBuffer = Float32List(1 * inputSize * inputSize * 3);
      _outputBuffer = Float32List(outputSize);
    } catch (e) {
      print('✗ Error loading model: $e');
      rethrow;
    }
  }

  static Float32List _preprocessImageOptimized(img.Image image) {
    img.Image resizedImage = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    _inputBuffer ??= Float32List(1 * inputSize * inputSize * 3);

    int pixelIndex = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        img.Pixel pixel = resizedImage.getPixel(x, y);

        _inputBuffer![pixelIndex++] = (pixel.r.toDouble() - 127.5) / 127.5;
        _inputBuffer![pixelIndex++] = (pixel.g.toDouble() - 127.5) / 127.5;
        _inputBuffer![pixelIndex++] = (pixel.b.toDouble() - 127.5) / 127.5;
      }
    }

    return _inputBuffer!;
  }

  static Future<List<double>?> getFaceEmbedding(img.Image faceImage) async {
    if (interpreter == null) {
      return null;
    }

    try {
      var input = _preprocessImageOptimized(faceImage);
      var inputReshaped = input.reshape([1, inputSize, inputSize, 3]);

      _outputBuffer ??= Float32List(outputSize);
      var output = _outputBuffer!.reshape([1, outputSize]);

      interpreter!.run(inputReshaped, output);

      List<double> embedding = List<double>.from(output[0]);
      return _normalizeEmbeddingFast(embedding);
    } catch (e) {
      print('✗ Error getting face embedding: $e');
      return null;
    }
  }

  static List<double> _normalizeEmbeddingFast(List<double> embedding) {
    double sumSquared = 0.0;
    for (int i = 0; i < embedding.length; i++) {
      sumSquared += embedding[i] * embedding[i];
    }
    double norm = sqrt(sumSquared);

    if (norm == 0.0) return embedding;

    for (int i = 0; i < embedding.length; i++) {
      embedding[i] /= norm;
    }
    return embedding;
  }

  double _cosineSimilarity(List<double> embedding1, List<double> embedding2) {
    double dotProduct = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }
    return dotProduct;
  }

  Future<RecognitionServiceData?> processAsync(CameraImage image) async {
    try {
      final convertedImage =
          ImageUtil.convertCameraImageToImgWithRotation(image, _rotation);

      if (convertedImage == null) {
        return null;
      }

      final recognize = await recognizeFace(convertedImage)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);

      if (recognize == null) {
        return null;
      }

      return RecognitionServiceData(
        confidence: recognize['confidence'] ?? 0,
        matched: recognize['matched'] ?? false,
      );
    } catch (e) {
      print('✗ Recognition error: $e');
      return null;
    }
  }

  static Future<(bool, String?)> loadRegisterFaces(
    List<File> files, {
    Function(int current, int total)? onProgress,
  }) async {
    if (files.isEmpty || interpreter == null) {
      registeredFaces.clear();
      return (false, 'File: ${files.length} or Model not loaded');
    }

    List<List<double>> registerFaces0 = [];
    List<String> error = ['Model: ${interpreter != null}'];
    String errorToText() => error.join(', ');

    for (int i = 0; i < files.length; i++) {
      try {
        final e = files[i];
        final file = File(e.path);
        final bytes = file.readAsBytesSync();
        final embedding = await getEmbedding(bytes);

        if (embedding == null) {
          continue;
        }

        registerFaces0.add(embedding);
      } catch (e) {
        print('✗ Error processing image at index $i: $e');
        error.add('$i-Error: $e');
        continue;
      }
    }

    registeredFaces = registerFaces0;

    if (registeredFaces.isEmpty) {
      return (false, errorToText());
    }

    return (true, errorToText());
  }

  static Future<(bool, String?)> loadRegisterFacesFromBytes(
    List<Uint8List> imageBytes, {
    Function(int current, int total)? onProgress,
  }) async {
    if (imageBytes.isEmpty || interpreter == null) {
      registeredFaces.clear();
      return (false, 'Images: ${imageBytes.length} or Model not loaded');
    }

    List<List<double>> registerFaces0 = [];
    List<String> error = ['Model: ${interpreter != null}'];
    String errorToText() => error.join(', ');

    for (int i = 0; i < imageBytes.length; i++) {
      try {
        final bytes = imageBytes[i];
        final faceImage = img.decodeImage(bytes);

        error.add('$i-Decoded: ${faceImage != null}');

        if (faceImage == null) {
          continue;
        }

        final embedding = await getFaceEmbedding(faceImage);

        error.add('$i-Embedding: ${embedding != null}');

        if (embedding == null) {
          continue;
        }

        registerFaces0.add(embedding);

        onProgress?.call(i + 1, imageBytes.length);
      } catch (e) {
        print('✗ Error processing image at index $i: $e');
        error.add('$i-Error: $e');
        continue;
      }
    }

    registeredFaces = registerFaces0;

    if (registeredFaces.isEmpty) {
      return (false, errorToText());
    }

    return (true, errorToText());
  }

  Future<Map<String, dynamic>?> recognizeFace(img.Image faceImage) async {
    try {
      List<double>? embedding = await getFaceEmbedding(faceImage);

      if (embedding == null) {
        return null;
      }

      if (registeredFaces.isEmpty) {
        return {'confidence': 0.0, 'matched': false};
      }

      double maxSimilarity = -1.0;
      int maxIndex = -1;

      for (int i = 0; i < registeredFaces.length; i++) {
        double similarity = _cosineSimilarity(embedding, registeredFaces[i]);

        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
          maxIndex = i;
        }
      }

      if (maxSimilarity > threshold) {
        return {
          'confidence': maxSimilarity,
          'matched': true,
          'index': maxIndex,
        };
      }

      return {
        'confidence': maxSimilarity,
        'matched': false,
        'bestMatch': maxIndex >= 0 ? '' : null,
      };
    } catch (e) {
      print('✗ Error in recognition: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>?>> recognizeMultipleFaces(
    List<img.Image> faceImages,
  ) async {
    return Future.wait(faceImages.map((image) => recognizeFace(image)));
  }

  /// ================================================================================
  /// ======================== Recognition Service Version 2 =========================
  /// ================================================================================
  Future<Map<String, dynamic>?> recognizeWithBytes(Uint8List image) async {
    try {
      List<double>? embedding = await getEmbedding(image);

      if (embedding == null) {
        return null;
      }

      if (registeredFaces.isEmpty) {
        return {'confidence': 0.0, 'matched': false};
      }

      double maxSimilarity = -1.0;
      int maxIndex = -1;

      for (int i = 0; i < registeredFaces.length; i++) {
        double similarity = _cosineSimilarity(embedding, registeredFaces[i]);

        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
          maxIndex = i;
        }
      }

      if (maxSimilarity > threshold) {
        return {
          'confidence': maxSimilarity,
          'matched': true,
          'index': maxIndex,
        };
      }

      return {
        'confidence': maxSimilarity,
        'matched': false,
        'bestMatch': maxIndex >= 0 ? '' : null,
      };
    } catch (e) {
      print('✗ Error in recognition: $e');
      return null;
    }
  }

  static Future<List<double>?> getEmbedding(Uint8List bytes) async {
    if (interpreter == null) {
      return null;
    }

    try {
      final image = img.decodeImage(bytes);

      if (image == null) {
        return null;
      }

      final resizedImage = img.copyResize(
        image,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear,
      );

      var input = Float32List(inputSize * inputSize * 3);
      int pixelIndex = 0;

      for (int y = 0; y < inputSize; y++) {
        for (int x = 0; x < inputSize; x++) {
          final pixel = resizedImage.getPixel(x, y);
          input[pixelIndex++] = pixel.r / 255.0;
          input[pixelIndex++] = pixel.g / 255.0;
          input[pixelIndex++] = pixel.b / 255.0;
        }
      }

      var inputReshaped = input.reshape([1, inputSize, inputSize, 3]);

      _outputBuffer ??= Float32List(outputSize);
      var output = _outputBuffer!.reshape([1, outputSize]);

      interpreter!.run(inputReshaped, output);

      List<double> embedding = List<double>.from(output[0]);
      return _normalizeEmbeddingFast(embedding);
    } catch (e) {
      print('✗ Error getting embedding: $e');
      return null;
    }
  }
}
