part of 'main.dart';

class FaceAntiSpoofingDetector {
  Interpreter? _interpreter;
  List<int>? _inputShape;
  List<int>? _outputShape;

  static const _cropScale = 2.7;

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

  /// MiniFASNetV2 crop: scale=2.7 centered on bounding box (mirrors Python _crop_face)
  img.Image cropFace(img.Image image, Rect bbox) {
    final boxW = bbox.width;
    final boxH = bbox.height;
    final cx = bbox.center.dx;
    final cy = bbox.center.dy;

    final imgH = image.height.toDouble();
    final imgW = image.width.toDouble();
    final scale = [(imgH - 1) / boxH, (imgW - 1) / boxW, _cropScale]
        .reduce(min);

    final cropW = scale * boxW;
    final cropH = scale * boxH;

    final left   = (cx - cropW / 2).clamp(0, imgW - 1).toInt();
    final top    = (cy - cropH / 2).clamp(0, imgH - 1).toInt();
    final right  = (cx + cropW / 2).clamp(0, imgW).toInt();
    final bottom = (cy + cropH / 2).clamp(0, imgH).toInt();

    return img.copyCrop(
      image,
      x: left,
      y: top,
      width: (right - left).clamp(1, image.width - left),
      height: (bottom - top).clamp(1, image.height - top),
    );
  }

  /// Preprocess: resize → NHWC float32 [0, 255] — no normalization
  /// TFLite converts ONNX NCHW to NHWC internally, so input shape is [1, H, W, 3]
  List<List<List<List<double>>>> preprocessImage(img.Image image) {
    final h = _inputShape![1];
    final w = _inputShape![2];
    final resized = img.copyResize(image, width: w, height: h);

    return List.generate(
      1,
      (_) => List.generate(
        h,
        (y) => List.generate(
          w,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [
              pixel.r.toDouble(),
              pixel.g.toDouble(),
              pixel.b.toDouble(),
            ];
          },
        ),
      ),
    );
  }

  List<double> _softmax(List<dynamic> logits) {
    final vals = logits.map((v) => (v as num).toDouble()).toList();
    final maxV = vals.reduce(max);
    final exps = vals.map((v) => exp(v - maxV)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((v) => v / sum).toList();
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

    final probs = _softmax(output[0] as List);
    print('--=> MiniFASNetV2 logits: ${output[0]}  probs: $probs');

    // Class order: 0=spoof, 1=live/real, 2=wrap-spoof
    final liveScore = probs[1];
    final isReal = probs.indexOf(probs.reduce(max)) == 1;

    return {
      'isReal': isReal,
      'confidence': 1.0 - liveScore, // spoof score: low=real, high=spoof
    };
  }

  /// Crop with MiniFASNetV2 scale, run inference, and return crop bytes + result
  Future<Map<String, dynamic>> detectWithBbox(
      img.Image fullImage, Rect bbox) async {
    final crop = cropFace(fullImage, bbox);
    final cropBytes = Uint8List.fromList(img.encodeJpg(crop, quality: 95));
    final result = await detect(cropBytes);
    return {...result, 'cropBytes': cropBytes};
  }

  void dispose() {
    _interpreter?.close();
  }
}
