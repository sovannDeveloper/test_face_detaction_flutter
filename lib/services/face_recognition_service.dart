// File: lib/services/face_recognition_service.dart

import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognitionService {
  Interpreter? _interpreter;
  List<List<double>> _registeredFaces = [];
  List<String> _registeredNames = [];

  static const int inputSize = 112;
  static const int outputSize = 192;
  static const double threshold = 0.7;

  Future<void> loadModel() async {
    try {
      _interpreter =
          await Interpreter.fromAsset('models/mobile_face_net.tflite');
      print('Model loaded successfully');

      var inputShape = _interpreter!.getInputTensor(0).shape;
      var outputShape = _interpreter!.getOutputTensor(0).shape;
      print('Input shape: $inputShape');
      print('Output shape: $outputShape');
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  List<List<List<List<double>>>> preprocessImage(img.Image image) {
    img.Image resizedImage = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
    );

    var input = List.generate(
      1,
      (b) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) => List.generate(3, (c) {
            img.Pixel pixel = resizedImage.getPixel(x, y);
            int r = pixel.r.toInt();
            int g = pixel.g.toInt();
            int b = pixel.b.toInt();

            List<int> rgb = [r, g, b];
            return (rgb[c] - 127.5) / 127.5;
          }),
        ),
      ),
    );

    return input;
  }

  Future<List<double>?> getFaceEmbedding(img.Image faceImage) async {
    if (_interpreter == null) {
      print('Model not loaded');
      return null;
    }

    try {
      var input = preprocessImage(faceImage);
      var output = List.filled(outputSize, 0.0).reshape([1, outputSize]);

      _interpreter!.run(input, output);

      List<double> embedding = List<double>.from(output[0]);
      return normalizeEmbedding(embedding);
    } catch (e) {
      print('Error getting face embedding: $e');
      return null;
    }
  }

  List<double> normalizeEmbedding(List<double> embedding) {
    double norm = sqrt(embedding.fold(0.0, (sum, val) => sum + val * val));
    return embedding.map((val) => val / norm).toList();
  }

  double cosineSimilarity(List<double> embedding1, List<double> embedding2) {
    double dotProduct = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }
    return dotProduct;
  }

  Future<bool> registerFace(img.Image faceImage, String name) async {
    List<double>? embedding = await getFaceEmbedding(faceImage);

    if (embedding == null) {
      return false;
    }

    _registeredFaces.add(embedding);
    _registeredNames.add(name);
    print('Face registered for: $name');
    return true;
  }

  Future<Map<String, dynamic>?> recognizeFace(img.Image faceImage) async {
    List<double>? embedding = await getFaceEmbedding(faceImage);

    if (embedding == null || _registeredFaces.isEmpty) {
      return null;
    }

    double maxSimilarity = -1.0;
    int maxIndex = -1;

    for (int i = 0; i < _registeredFaces.length; i++) {
      double similarity = cosineSimilarity(embedding, _registeredFaces[i]);

      if (similarity > maxSimilarity) {
        maxSimilarity = similarity;
        maxIndex = i;
      }
    }

    if (maxSimilarity > threshold) {
      return {
        'name': _registeredNames[maxIndex],
        'confidence': maxSimilarity,
        'matched': true,
      };
    }

    return {
      'name': 'Unknown',
      'confidence': maxSimilarity,
      'matched': false,
    };
  }

  void clearRegisteredFaces() {
    _registeredFaces.clear();
    _registeredNames.clear();
  }

  void dispose() {
    _interpreter?.close();
  }
}
