part of 'main.dart';

class MyRecognition {
  Interpreter? _interpreter;
  final _inputSize = 112;
  final _outputSize = 192;
  Interpreter? get interpreter => _interpreter;

  MyRecognition(String path) {
    if (_interpreter != null) return;

    try {
      final file = File(path);
      _interpreter = Interpreter.fromFile(file);
      print('--=> Model Recognized loaded successfully');
    } catch (e) {
      print('--=> Error loading model: $e');
      rethrow;
    }
  }

  static String _currentModelPath = '';
  static String get modelPath => _currentModelPath;

  static Future<void> initModel() async {
    final ByteData data = await rootBundle.load(
      'assets/models/mobile_face_net.tflite',
    );
    final Uint8List bytes = data.buffer.asUint8List();
    final tempDir = await getTemporaryDirectory();
    _currentModelPath = '${tempDir.path}/mobile_face_net.tflite';
    final file = File(_currentModelPath);

    await file.writeAsBytes(bytes);
  }

  Future<List<double>?> getEmbedding(Uint8List bytes) async {
    if (_interpreter == null) {
      return null;
    }

    try {
      final image = img.decodeImage(bytes);

      if (image == null) {
        return null;
      }

      final resizedImage = img.copyResize(
        image,
        width: _inputSize,
        height: _inputSize,
        interpolation: img.Interpolation.cubic,
      );

      var input = Float32List(_inputSize * _inputSize * 3);
      int pixelIndex = 0;

      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final pixel = resizedImage.getPixel(x, y);

          input[pixelIndex++] = (pixel.r - 127.5) / 128.0;
          input[pixelIndex++] = (pixel.g - 127.5) / 128.0;
          input[pixelIndex++] = (pixel.b - 127.5) / 128.0;
        }
      }

      var inputReshaped = input.reshape([1, _inputSize, _inputSize, 3]);

      final outputBuffer = Float32List(_outputSize);
      var output = outputBuffer.reshape([1, _outputSize]);

      _interpreter!.run(inputReshaped, output);

      List<double> embedding = List<double>.from(output[0]);

      return _normalizeEmbedding(embedding);
    } catch (e) {
      print('✗ Error getting embedding: $e');
      return null;
    }
  }

  List<double> _normalizeEmbedding(List<double> embedding) {
    double sumSquared = 0.0;
    for (int i = 0; i < embedding.length; i++) {
      sumSquared += embedding[i] * embedding[i];
    }

    double magnitude = sqrt(sumSquared);

    if (magnitude < 1e-12) return embedding;

    for (int i = 0; i < embedding.length; i++) {
      embedding[i] /= magnitude;
    }

    return embedding;
  }

  void dispose() {
    print('--=> Recognition dispose');
    _interpreter?.close();
    _interpreter = null;
  }
}
