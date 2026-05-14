part of 'main.dart';

class FaceAntiSpoofingDetector {
  Interpreter? _interpreter;
  List<int>? _inputShape;
  List<int>? _outputShape;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/MiniFASNetV2_float16.tflite',
      );
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      print('--=> MiniFASNetV2 loaded in: $_inputShape out: $_outputShape');
    } catch (e) {
      print('--=> Error loading MiniFASNetV2: $e');
    }
  }

  List<List<List<List<double>>>> preprocessImage(img.Image image) {
    final h = _inputShape![1];
    final w = _inputShape![2];

    final resized = img.copyResize(image, width: w, height: h);

    // ImageNet normalization used during MiniFASNetV2 training
    const meanR = 0.485, meanG = 0.456, meanB = 0.406;
    const stdR = 0.229, stdG = 0.224, stdB = 0.225;

    return List.generate(
      1,
      (_) => List.generate(
        h,
        (y) => List.generate(w, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            (pixel.r / 255.0 - meanR) / stdR,
            (pixel.g / 255.0 - meanG) / stdG,
            (pixel.b / 255.0 - meanB) / stdB,
          ];
        }),
      ),
    );
  }

  Future<Map<String, dynamic>> detect(Uint8List imageBytes) async {
    if (_interpreter == null) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image from bytes');
    }

    final input = preprocessImage(image);
    final output = List.filled(_outputShape![1], 0.0)
        .reshape([1, _outputShape![1]]);

    _interpreter!.run(input, output);

    print('--=> MiniFASNetV2 output: ${output[0]}');

    // MiniFASNetV2 class order: 0=spoof, 1=live/real, 2=wrap-spoof
    final liveScore = output[0][1] as double;

    return {
      'isReal': liveScore > 0.5,
      // Return spoof score (1-live) so callers using score<=threshold stay correct
      'confidence': 1.0 - liveScore,
    };
  }

  void dispose() {
    _interpreter?.close();
  }
}
