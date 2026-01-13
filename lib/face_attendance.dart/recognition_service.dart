part of 'main.dart';

class RecognitionServiceData {
  final double confidence;
  final bool matched;
  final bool isVerify;

  RecognitionServiceData(
      {required this.confidence,
      required this.matched,
      required this.isVerify});
}

class FaceRecognitionService {
  final _onRecognition = StreamController<RecognitionServiceData?>.broadcast();
  static final onLoad = StreamController<String?>.broadcast();
  static Interpreter? interpreter;
  static List<List<double>> registeredFaces = [];
  static const int inputSize = 112;
  static const int outputSize = 192;
  static Float32List? _inputBuffer;
  static Float32List? _outputBuffer;
  late InputImageRotation _rotation;
  bool _isRecognizing = false;
  bool _isVerify = false;
  int _frameCount = 0;

  bool get isVerify => _isVerify;

  void reset() {
    _isVerify = false;
  }

  double threshold = 0.5;

  Stream<RecognitionServiceData?> get stream => _onRecognition.stream;

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
      onLoad.add('Loading model');
      final options = InterpreterOptions()..threads = 4;
      interpreter =
          await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      _inputBuffer = Float32List(1 * inputSize * inputSize * 3);
      _outputBuffer = Float32List(outputSize);
      onLoad.add('Successful loaded');
    } catch (e) {
      print('✗ Error loading model: $e');
      onLoad.add('Error: $e');
      rethrow;
    }
  }

  static Float32List preprocessImageOptimized(img.Image image) {
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

  Future<void> processCameraImage(CameraImage image) async {
    if (_isRecognizing || _isVerify) return;

    _isRecognizing = true;

    try {
      _frameCount++;

      if (_frameCount % 10 != 0) {
        _isRecognizing = false;
        return;
      }

      final convertedImage =
          ImageUtil.convertCameraImageToImgWithRotation(image, _rotation);

      if (convertedImage == null) return;

      final recognize = await recognizeFace(convertedImage);
      double confidence = recognize?['confidence'] ?? 0;
      int confidencePercent = (confidence * 100).round();

      _onRecognition.add(RecognitionServiceData(
        confidence: confidence,
        matched: recognize?['matched'] ?? false,
        isVerify: confidencePercent > 50,
      ));

      _isVerify = confidencePercent > 50;
    } catch (e) {
      print('Error in async recognition: $e');
    } finally {
      _isRecognizing = false;
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
        final faceImage = img.decodeImage(bytes);

        error.add('$i-Exist: ${file.existsSync()}');

        if (faceImage == null || !file.existsSync()) {
          continue;
        }

        final embedding = await getFaceEmbedding(faceImage);

        error.add('$i-Embedding: ${embedding != null}');

        if (embedding == null) {
          continue;
        }

        registerFaces0.add(embedding);

        onProgress?.call(i + 1, files.length);
      } catch (e) {
        print('Error processing image at index $i: $e');
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
        return {
          'name': 'No registered faces',
          'confidence': 0.0,
          'matched': false
        };
      }

      double maxSimilarity = -1.0;
      int maxIndex = -1;

      for (int i = 0; i < registeredFaces.length; i++) {
        double similarity = cosineSimilarity(embedding, registeredFaces[i]);

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
        'name': 'Unknown',
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

  void clearRegisteredFaces() {
    registeredFaces.clear();
  }

  void dispose() {
    _onRecognition.close();
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
        'similarity': similarity,
        'percentage': (similarity * 100).toStringAsFixed(2),
      });
    }

    results.sort((a, b) =>
        (b['similarity'] as double).compareTo(a['similarity'] as double));
    return results;
  }

  static Future<img.Image> loadImageFromFile(String filePath) async {
    final imageFile = File(filePath);
    final bytes = await imageFile.readAsBytes();

    img.Image image = img.decodeImage(Uint8List.fromList(bytes))!;
    return image;
  }
}
