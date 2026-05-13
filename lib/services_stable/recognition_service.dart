part of 'main.dart';

class RecognitionServiceData {
  final double confidence;
  final bool matched;
  final int? matchedIndex;

  const RecognitionServiceData({
    required this.confidence,
    required this.matched,
    this.matchedIndex,
  });

  @override
  String toString() =>
      'RecognitionServiceData(confidence: ${confidence.toStringAsFixed(4)}, '
      'matched: $matched, matchedIndex: $matchedIndex)';
}

class FaceRecognitionService {
  Interpreter? _interpreter;

  List<List<List<double>>> registeredFaces = [];

  final int _inputSize = 112;
  final int _outputSize = 192;
  // This threshold min: 65 -> 85
  double _threshold = 0.70;

  void setThreshold(double newThreshold) {
    assert(
      newThreshold > 0.0 && newThreshold <= 1.0,
      'Threshold must be in (0, 1]',
    );
    _threshold = newThreshold;
  }

  bool get isModelLoaded => _interpreter != null;

  Future<void> loadModel() async {
    if (_interpreter != null) return;

    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/mobile_face_net.tflite',
      );
      print('--=> MobileFaceNet loaded successfully');
    } catch (e) {
      _interpreter = null;
      print('--=> Error loading model: $e');
      rethrow;
    }
  }

  Future<(bool, String?)> loadRegisterFaces(
    List<File> files, {
    Function(int current, int total)? onProgress,
  }) async {
    registeredFaces.clear();

    if (_interpreter == null) {
      return (false, 'Model not loaded');
    }
    if (files.isEmpty) {
      registeredFaces.clear();
      return (false, 'No files provided');
    }

    final List<List<double>> embeddings = [];
    final List<String> errors = [];

    for (int i = 0; i < files.length; i++) {
      try {
        final bytes = await files[i].readAsBytes();
        final embedding = await _getEmbedding(bytes);

        if (embedding == null) {
          errors.add(
            '[$i] null embedding – image may be unreadable or have no face',
          );
          continue;
        }

        embeddings.add(embedding);
        onProgress?.call(i + 1, files.length);
      } catch (e) {
        print('✗ Error processing image at index $i: $e');
        errors.add('[$i] $e');
      }
    }

    if (embeddings.isEmpty) {
      return (false, errors.join('; '));
    }

    registeredFaces = [embeddings];
    return (true, errors.isEmpty ? null : errors.join('; '));
  }

  void registerPersonEmbeddings(List<List<double>> embeddings) {
    if (embeddings.isNotEmpty) {
      registeredFaces.add(embeddings);
    }
  }

  void clearRegistry() => registeredFaces.clear();

  Future<RecognitionServiceData?> recognize(Uint8List image) async {
    try {
      final embedding = await _getEmbedding(image);
      if (embedding == null) return null;

      if (registeredFaces.isEmpty) {
        return const RecognitionServiceData(confidence: 0.0, matched: false);
      }

      double bestSimilarity = -1.0;
      int bestPersonIndex = -1;

      for (int personIdx = 0; personIdx < registeredFaces.length; personIdx++) {
        final personEmbeddings = registeredFaces[personIdx];

        double personBest = -1.0;
        for (final registered in personEmbeddings) {
          final sim = _cosineSimilarity(embedding, registered);
          if (sim > personBest) personBest = sim;
        }

        if (personBest > bestSimilarity) {
          bestSimilarity = personBest;
          bestPersonIndex = personIdx;
        }
      }

      final isMatch = bestSimilarity >= _threshold;

      return RecognitionServiceData(
        confidence: bestSimilarity,
        matched: isMatch,
        matchedIndex: isMatch ? bestPersonIndex : null,
      );
    } catch (e) {
      print('✗ Error in recognition: $e');
      return null;
    }
  }

  Future<List<double>?> _getEmbedding(Uint8List bytes) async {
    if (_interpreter == null) {
      print('✗ getEmbedding called before model is loaded');
      return null;
    }

    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _inputSize,
        targetHeight: _inputSize,
      );
      final frame = await codec.getNextFrame();
      final uiImage = frame.image;

      final byteData = await uiImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData == null) {
        print('✗ toByteData returned null');
        return null;
      }

      frame.image.dispose();

      final pixels = byteData.buffer.asUint8List();
      final input = Float32List(_inputSize * _inputSize * 3);
      int idx = 0;

      for (int i = 0; i < pixels.length; i += 4) {
        input[idx++] = (pixels[i] - 127.5) / 128.0; // R
        input[idx++] = (pixels[i + 1] - 127.5) / 128.0; // G
        input[idx++] = (pixels[i + 2] - 127.5) / 128.0; // B
        // skip alpha pixels[i + 3]
      }

      final inputReshaped = input.reshape([1, _inputSize, _inputSize, 3]);

      final outputBuffer = Float32List(_outputSize);
      final output = outputBuffer.reshape([1, _outputSize]);

      _interpreter!.run(inputReshaped, output);

      final embedding = List<double>.from(output[0] as List);
      final normalized = _normalizeEmbedding(embedding);

      return normalized;
    } catch (e) {
      print('✗ Error getting embedding: $e');
      return null;
    }
  }

  List<double> _normalizeEmbedding(List<double> embedding) {
    double sumSq = 0.0;
    for (final v in embedding) {
      sumSq += v * v;
    }

    final magnitude = sqrt(sumSq);
    if (magnitude < 1e-12) return embedding;

    for (int i = 0; i < embedding.length; i++) {
      embedding[i] /= magnitude;
    }
    return embedding;
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      print('✗ Embedding length mismatch: ${a.length} vs ${b.length}');
      return 0.0;
    }

    double dot = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }

    return dot.clamp(-1.0, 1.0);
  }
}
