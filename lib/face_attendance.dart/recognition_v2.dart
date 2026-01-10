part of 'main.dart';

class FaceRecognitionV2 {
  static Interpreter? interpreter;
  static List<List<double>> registeredFaces = [];
  static List<String> registeredNames = [];
  static const int inputSize = 112;
  static const int outputSize = 192;
  static Float32List? _inputBuffer;
  static Float32List? _outputBuffer;

  double threshold = 0.5;

  void setThreshold(double newThreshold) {
    threshold = newThreshold;
  }

  static Future<void> loadModel() async {
    try {
      final options = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = true;
      interpreter = await Interpreter.fromAsset(
        'assets/models/mobilefacenet.tflite',
        options: options,
      );

      _inputBuffer = Float32List(1 * inputSize * inputSize * 3);
      _outputBuffer = Float32List(outputSize);
      print('✓ Buffers pre-allocated');
    } catch (e) {
      print('✗ Error loading model: $e');
      rethrow;
    }
  }

  static Float32List preprocessImageOptimized(img.Image image) {
    // Resize image
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
      var input = preprocessImageOptimized(faceImage);
      var inputReshaped = input.reshape([1, inputSize, inputSize, 3]);

      _outputBuffer ??= Float32List(outputSize);
      var output = _outputBuffer!.reshape([1, outputSize]);

      interpreter!.run(inputReshaped, output);

      List<double> embedding = List<double>.from(output[0]);
      return normalizeEmbeddingFast(embedding);
    } catch (e) {
      print('✗ Error getting face embedding: $e');
      return null;
    }
  }

  static List<double> normalizeEmbeddingFast(List<double> embedding) {
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

  double cosineSimilarity(List<double> embedding1, List<double> embedding2) {
    double dotProduct = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }
    return dotProduct;
  }

  static Future<void> loadRegisterFaces({
    Function(int current, int total)? onProgress,
  }) async {
    try {
      final images = await ImageStorageUtil.loadAllImages();

      if (images.isEmpty) {
        print('No images found to register');
        registeredFaces = [];
        registeredNames = [];
        return;
      }

      List<List<double>> registerFaces0 = [];
      List<String> registeredNames0 = [];

      for (int i = 0; i < images.length; i++) {
        try {
          final e = images[i];
          final file = File(e.path);
          final bytes = file.readAsBytesSync();
          final faceImage = img.decodeImage(bytes);

          if (faceImage == null || !file.existsSync()) {
            print('Failed to decode image: ${e.path}');
            continue;
          }

          final embedding = await getFaceEmbedding(faceImage);

          if (embedding == null) {
            print('No face detected in image: ${e.path}');
            continue;
          }

          registerFaces0.add(embedding);
          final name = _extractNameFromPath(e.path) ?? 'User ${i + 1}';
          registeredNames0.add(name);

          onProgress?.call(i + 1, images.length);
          print('Registered face ${i + 1}/${images.length}: $name');
        } catch (e) {
          print('Error processing image at index $i: $e');
          continue;
        }
      }

      registeredFaces = registerFaces0;
      registeredNames = registeredNames0;
    } catch (e) {
      print('Error loading registered faces: $e');
      registeredFaces = [];
      registeredNames = [];
    }
  }

  static String? _extractNameFromPath(String path) {
    try {
      final fileName = path.split('/').last.split('.').first;
      return fileName.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    } catch (e) {
      return null;
    }
  }

  Future<bool> registerFace(img.Image faceImage, String name) async {
    List<double>? embedding = await getFaceEmbedding(faceImage);

    if (embedding == null) {
      return false;
    }

    registeredFaces.add(embedding);
    registeredNames.add(name);
    return true;
  }

  Future<Map<String, dynamic>?> recognizeFace(
    img.Image faceImage, {
    bool verbose = false,
  }) async {
    try {
      if (verbose) print('\n========== RECOGNITION STARTED ==========');

      List<double>? embedding = await getFaceEmbedding(faceImage);

      if (embedding == null) {
        if (verbose) print('✗ No embedding generated');
        return null;
      }

      if (registeredFaces.isEmpty) {
        if (verbose) print('✗ No registered faces');
        return {
          'name': 'No registered faces',
          'confidence': 0.0,
          'matched': false
        };
      }

      double maxSimilarity = -1.0;
      int maxIndex = -1;

      // Fast comparison loop
      for (int i = 0; i < registeredFaces.length; i++) {
        double similarity = cosineSimilarity(embedding, registeredFaces[i]);

        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
          maxIndex = i;
        }
      }

      if (verbose) {
        print('\n--- Results ---');
        print('Best match: ${registeredNames[maxIndex]}');
        print('Similarity: ${(maxSimilarity * 100).toStringAsFixed(2)}%');
        print('Threshold: ${(threshold * 100).toStringAsFixed(0)}%');
        print(
            'Match status: ${maxSimilarity > threshold ? "✓ MATCHED" : "✗ NOT MATCHED"}');
        print('========== RECOGNITION ENDED ==========\n');
      }

      if (maxSimilarity > threshold) {
        return {
          'name': registeredNames[maxIndex],
          'confidence': maxSimilarity,
          'matched': true,
          'index': maxIndex,
        };
      }

      return {
        'name': 'Unknown',
        'confidence': maxSimilarity,
        'matched': false,
        'bestMatch': maxIndex >= 0 ? registeredNames[maxIndex] : null,
      };
    } catch (e) {
      if (verbose) print('✗ Error in recognition: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>?>> recognizeMultipleFaces(
    List<img.Image> faceImages,
  ) async {
    return Future.wait(
      faceImages.map((image) => recognizeFace(image, verbose: false)),
    );
  }

  void clearRegisteredFaces() {
    registeredFaces.clear();
    registeredNames.clear();
    print('✓ All registered faces cleared');
  }

  void dispose() {
    interpreter?.close();
    _inputBuffer = null;
    _outputBuffer = null;
  }

  Future<List<Map<String, dynamic>>?> getAllSimilarities(
    img.Image faceImage,
  ) async {
    List<double>? embedding = await getFaceEmbedding(faceImage);

    if (embedding == null || registeredFaces.isEmpty) {
      return null;
    }

    List<Map<String, dynamic>> results = [];
    for (int i = 0; i < registeredFaces.length; i++) {
      double similarity = cosineSimilarity(embedding, registeredFaces[i]);
      results.add({
        'name': registeredNames[i],
        'similarity': similarity,
        'percentage': (similarity * 100).toStringAsFixed(2),
      });
    }

    results.sort((a, b) =>
        (b['similarity'] as double).compareTo(a['similarity'] as double));
    return results;
  }
}
