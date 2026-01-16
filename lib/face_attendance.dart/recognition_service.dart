part of 'main.dart';

class RecognitionServiceData {
  final double confidence;
  final bool matched;
  final int? matchedIndex;

  RecognitionServiceData({
    required this.confidence,
    required this.matched,
    this.matchedIndex,
  });
}

class FaceRecognitionService {
  static Interpreter? interpreter;
  static List<List<double>> registeredFaces = [];
  static const int inputSize = 112;
  static const int outputSize = 192;
  static Float32List? _outputBuffer;
  double threshold = 0.6;

  void setThreshold(double newThreshold) {
    threshold = newThreshold;
  }

  static Future<void> loadModel() async {
    try {
      interpreter =
          await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
    } catch (e) {
      print('✗ Error loading model: $e');
      rethrow;
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
        final embedding = await _getEmbedding(bytes);

        if (embedding == null) {
          continue;
        }

        registerFaces0.add(embedding);
        onProgress?.call(i + 1, files.length);
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

  Future<Map<String, dynamic>?> recognize(Uint8List image) async {
    try {
      List<double>? embedding = await _getEmbedding(image);

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

      bool isMatch = maxSimilarity >= threshold;

      return {
        'confidence': maxSimilarity,
        'matched': isMatch,
        'index': isMatch ? maxIndex : -1,
      };
    } catch (e) {
      print('✗ Error in recognition: $e');
      return null;
    }
  }

  static Future<List<double>?> _getEmbedding(Uint8List bytes) async {
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
        interpolation: img.Interpolation.cubic,
      );

      var input = Float32List(inputSize * inputSize * 3);
      int pixelIndex = 0;

      for (int y = 0; y < inputSize; y++) {
        for (int x = 0; x < inputSize; x++) {
          final pixel = resizedImage.getPixel(x, y);

          input[pixelIndex++] = (pixel.r - 127.5) / 128.0;
          input[pixelIndex++] = (pixel.g - 127.5) / 128.0;
          input[pixelIndex++] = (pixel.b - 127.5) / 128.0;
        }
      }

      var inputReshaped = input.reshape([1, inputSize, inputSize, 3]);

      _outputBuffer ??= Float32List(outputSize);
      var output = _outputBuffer!.reshape([1, outputSize]);

      interpreter!.run(inputReshaped, output);

      List<double> embedding = List<double>.from(output[0]);

      return _normalizeEmbedding(embedding);
    } catch (e) {
      print('✗ Error getting embedding: $e');
      return null;
    }
  }

  /// Normalize embedding to unit vector (L2 normalization)
  static List<double> _normalizeEmbedding(List<double> embedding) {
    double sumSquared = 0.0;
    for (int i = 0; i < embedding.length; i++) {
      sumSquared += embedding[i] * embedding[i];
    }

    double magnitude = sqrt(sumSquared);

    // Avoid division by zero
    if (magnitude < 1e-12) return embedding;

    // Normalize to unit vector
    for (int i = 0; i < embedding.length; i++) {
      embedding[i] /= magnitude;
    }

    return embedding;
  }

  static double _cosineSimilarity(
      List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      return 0.0;
    }

    double dotProduct = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }

    return dotProduct;
  }
}
