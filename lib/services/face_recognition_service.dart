// File: lib/services/face_recognition_service.dart

import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:test_face_detaction/img_util.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognitionService {
  static Interpreter? interpreter;
  static List<List<double>> registeredFaces = [];
  static List<String> registeredNames = [];

  static const int inputSize = 112;
  static const int outputSize = 192;
  double threshold = 0.5;

  // Method to update threshold
  void setThreshold(double newThreshold) {
    threshold = newThreshold;
  }

  static Future<void> loadModel() async {
    try {
      interpreter =
          await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      print('✓ Model loaded successfully');

      var inputShape = interpreter!.getInputTensor(0).shape;
      var outputShape = interpreter!.getOutputTensor(0).shape;
      print('✓ Input shape: $inputShape');
      print('✓ Output shape: $outputShape');
    } catch (e) {
      print('✗ Error loading model: $e');
      print(
          'Make sure you have placed the model file at: assets/models/mobilefacenet.tflite');
      rethrow;
    }
  }

  static List<List<List<List<double>>>> preprocessImage(img.Image image) {
    // Resize image to model input size with better interpolation
    img.Image resizedImage = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.cubic,
    );

    // Convert to RGB if needed
    if (resizedImage.numChannels == 4) {
      resizedImage = img.Image.from(resizedImage);
    }

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
            // Normalize to [-1, 1] range
            return (rgb[c] - 127.5) / 127.5;
          }),
        ),
      ),
    );

    return input;
  }

  static Future<List<double>?> getFaceEmbedding(img.Image faceImage) async {
    if (interpreter == null) {
      print('✗ Model not loaded');
      return null;
    }

    try {
      print('→ Preprocessing image...');
      var input = preprocessImage(faceImage);

      print('→ Running inference...');
      var output = List.filled(outputSize, 0.0).reshape([1, outputSize]);
      interpreter!.run(input, output);

      print('✓ Inference complete');
      List<double> embedding = List<double>.from(output[0]);
      return normalizeEmbedding(embedding);
    } catch (e) {
      print('✗ Error getting face embedding: $e');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  static List<double> normalizeEmbedding(List<double> embedding) {
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

  // Get register faces
  static Future<void> loadRegisterFaces() async {
    final images = await ImageStorageUtil.loadAllImages();
    List<List<double>> registerFaces0 = [];
    List<String> registeredNames0 = [];

    for (final e in images) {
      final bytes = await File(e.path).readAsBytes();
      final faceImage = img.decodeImage(bytes);

      if (faceImage == null) continue;

      List<double>? embedding = await getFaceEmbedding(faceImage);

      if (embedding == null) continue;

      registerFaces0.add(embedding);
      registeredNames0.add('value');
    }

    registeredFaces = registerFaces0;
    registeredNames = registeredNames0;
  }

  Future<bool> registerFace(img.Image faceImage, String name) async {
    print('→ Attempting to register face for: $name');
    List<double>? embedding = await getFaceEmbedding(faceImage);

    if (embedding == null) {
      print('✗ Failed to get embedding');
      return false;
    }

    registeredFaces.add(embedding);
    registeredNames.add(name);
    print('✓ Face registered successfully for: $name');
    print('✓ Total registered faces: ${registeredFaces.length}');
    return true;
  }

  Future<Map<String, dynamic>?> recognizeFace(img.Image faceImage) async {
    final task = Stopwatch()..start();
    try {
      print('\n========== RECOGNITION STARTED ==========');
      List<double>? embedding = await getFaceEmbedding(faceImage);

      if (embedding == null || registeredFaces.isEmpty) {
        print('✗ No embedding or no registered faces');
        return null;
      }

      double maxSimilarity = -1.0;
      int maxIndex = -1;
      List<Map<String, dynamic>> allMatches = [];

      print('\n--- Comparing with registered faces ---');
      // Compare with all registered faces
      for (int i = 0; i < registeredFaces.length; i++) {
        double similarity = cosineSimilarity(embedding, registeredFaces[i]);

        allMatches.add({
          'name': registeredNames[i],
          'similarity': similarity,
        });

        print(
            '${i + 1}. ${registeredNames[i]}: ${(similarity * 100).toStringAsFixed(2)}%');

        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
          maxIndex = i;
        }
      }

      print('\n--- Results ---');
      print('Best match: ${registeredNames[maxIndex]}');
      print('Similarity: ${(maxSimilarity * 100).toStringAsFixed(2)}%');
      print('Threshold: ${(threshold * 100).toStringAsFixed(0)}%');
      print(
          'Match status: ${maxSimilarity > threshold ? "✓ MATCHED" : "✗ NOT MATCHED"}');
      print('========== RECOGNITION ENDED ==========\n');

      if (maxSimilarity > threshold) {
        return {
          'name': registeredNames[maxIndex],
          'confidence': maxSimilarity,
          'matched': true,
          'allMatches': allMatches,
        };
      }

      return {
        'name': 'Unknown',
        'confidence': maxSimilarity,
        'matched': false,
        'allMatches': allMatches,
      };
    } finally {
      task.stop();
      print(task.elapsed);
    }
  }

  void clearRegisteredFaces() {
    registeredFaces.clear();
    registeredNames.clear();
    print('✓ All registered faces cleared');
  }

  void dispose() {
    interpreter?.close();
  }
}
