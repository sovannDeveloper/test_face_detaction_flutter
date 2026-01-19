part of 'main.dart';

class FaceAntiSpoofingDetector {
  Interpreter? _interpreter;
  List<int>? _inputShape;
  List<int>? _outputShape;

  // Initialize the model
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
          'assets/models/face_anti_spoofing.tflite');
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;

      print(
          '--=> Model Spoofing loaded successfully in: $_inputShape out: $_outputShape');
    } catch (e) {
      print('--=> Error Spoofing loading model: $e');
    }
  }

  // Preprocess image for the model
  List<List<List<List<double>>>> preprocessImage(img.Image image) {
    int inputHeight = _inputShape![1];
    int inputWidth = _inputShape![2];

    img.Image resizedImage = img.copyResize(
      image,
      width: inputWidth,
      height: inputHeight,
    );

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
  Future<Map<String, dynamic>> detect(Uint8List imageBytes) async {
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

    print('--=> Inference: ${output[0]}');

    return {
      'isReal': realScore <= 0.5,
      'confidence': realScore,
    };
  }

  // Clean up resources
  void dispose() {
    _interpreter?.close();
  }
}
