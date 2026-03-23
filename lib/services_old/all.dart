import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognitionService {
  Interpreter? _detectorInterpreter;
  Interpreter? _recognitionInterpreter;

  // Model configurations
  static const int _detectorInputSize = 300;
  static const int _recognitionInputSize = 112;
  static const double _detectionThreshold = 0.7;

  // Storage for registered faces
  final Map<String, List<double>> _registeredFaces = {};

  /// Initialize the face recognition service
  Future<void> initialize() async {
    try {
      // Load face detection model (MobileNet SSD or similar)
      _detectorInterpreter = await Interpreter.fromAsset(
        'assets/models/face_detection.tflite',
        options: InterpreterOptions()..threads = 4,
      );

      // Load face recognition model (FaceNet or MobileFaceNet)
      _recognitionInterpreter = await Interpreter.fromAsset(
        'assets/models/face_recognition.tflite',
        options: InterpreterOptions()..threads = 4,
      );

      print('Face recognition service initialized successfully');
    } catch (e) {
      print('Error initializing face recognition: $e');
      rethrow;
    }
  }

  /// Detect faces in an image
  Future<List<FaceDetection>> detectFaces(String imagePath) async {
    if (_detectorInterpreter == null) {
      throw Exception('Detector not initialized');
    }

    // Load and preprocess image
    final imageData = await _preprocessImageForDetection(imagePath);

    // Prepare output buffers
    final outputLocations = List.filled(1 * 10 * 4, 0.0).reshape([1, 10, 4]);
    final outputClasses = List.filled(1 * 10, 0.0).reshape([1, 10]);
    final outputScores = List.filled(1 * 10, 0.0).reshape([1, 10]);
    final numDetections = List.filled(1, 0.0).reshape([1]);

    final outputs = {
      0: outputLocations,
      1: outputClasses,
      2: outputScores,
      3: numDetections,
    };

    // Run inference
    _detectorInterpreter!.runForMultipleInputs([imageData], outputs);

    // Parse results
    final detections = <FaceDetection>[];
    final numDet = numDetections[0][0].toInt();

    for (int i = 0; i < numDet && i < 10; i++) {
      final score = outputScores[0][i];
      if (score > _detectionThreshold) {
        detections.add(FaceDetection(
          boundingBox: Rect(
            top: outputLocations[0][i][0],
            left: outputLocations[0][i][1],
            bottom: outputLocations[0][i][2],
            right: outputLocations[0][i][3],
          ),
          confidence: score,
        ));
      }
    }

    return detections;
  }

  /// Extract face embedding from a cropped face image
  Future<List<double>> extractFaceEmbedding(
      String imagePath, Rect? faceRect) async {
    if (_recognitionInterpreter == null) {
      throw Exception('Recognition model not initialized');
    }

    // Preprocess image for recognition
    final input = await _preprocessImageForRecognition(imagePath, faceRect);

    // Prepare output buffer (typically 128 or 512 dimensions)
    final outputShape = _recognitionInterpreter!.getOutputTensor(0).shape;
    final embeddingSize = outputShape[1];
    final output =
        List.filled(1 * embeddingSize, 0.0).reshape([1, embeddingSize]);

    // Run inference
    _recognitionInterpreter!.run(input, output);

    // Normalize the embedding
    final embedding = output[0] as List<double>;
    return _normalizeEmbedding(embedding);
  }

  /// Register a new face with a name
  Future<bool> registerFace(String name, String imagePath) async {
    try {
      // Detect faces in the image
      final detections = await detectFaces(imagePath);

      if (detections.isEmpty) {
        print('No face detected in the image');
        return false;
      }

      // Use the first detected face
      final faceRect = detections.first.boundingBox;

      // Extract embedding
      final embedding = await extractFaceEmbedding(imagePath, faceRect);

      // Store the embedding
      _registeredFaces[name] = embedding;

      print('Face registered successfully for: $name');
      return true;
    } catch (e) {
      print('Error registering face: $e');
      return false;
    }
  }

  /// Recognize a face from an image
  Future<FaceRecognitionResult?> recognizeFace(String imagePath) async {
    if (_registeredFaces.isEmpty) {
      print('No registered faces');
      return null;
    }

    try {
      // Detect faces
      final detections = await detectFaces(imagePath);

      if (detections.isEmpty) {
        return null;
      }

      // Use the first detected face
      final faceRect = detections.first.boundingBox;

      // Extract embedding
      final embedding = await extractFaceEmbedding(imagePath, faceRect);

      // Compare with registered faces
      String? bestMatch;
      double bestSimilarity = 0.0;
      const double matchThreshold = 0.6; // Adjust based on your needs

      for (final entry in _registeredFaces.entries) {
        final similarity = _cosineSimilarity(embedding, entry.value);
        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestMatch = entry.key;
        }
      }

      if (bestMatch != null && bestSimilarity > matchThreshold) {
        return FaceRecognitionResult(
          name: bestMatch,
          confidence: bestSimilarity,
          boundingBox: faceRect,
        );
      }

      return null;
    } catch (e) {
      print('Error recognizing face: $e');
      return null;
    }
  }

  /// Preprocess image for face detection
  Future<List<List<List<List<double>>>>> _preprocessImageForDetection(
      String imagePath) async {
    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Resize to model input size
    image = img.copyResize(image,
        width: _detectorInputSize, height: _detectorInputSize);

    // Convert to tensor format [1, height, width, 3]
    final input = List.generate(
      1,
      (_) => List.generate(
        _detectorInputSize,
        (y) => List.generate(
          _detectorInputSize,
          (x) {
            final pixel = image!.getPixel(x, y);
            return [
              (pixel.r / 127.5) - 1.0,
              (pixel.g / 127.5) - 1.0,
              (pixel.b / 127.5) - 1.0,
            ];
          },
        ),
      ),
    );

    return input;
  }

  /// Preprocess image for face recognition
  Future<List<List<List<List<double>>>>> _preprocessImageForRecognition(
    String imagePath,
    Rect? faceRect,
  ) async {
    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Crop face if bounding box provided
    if (faceRect != null) {
      final x = (faceRect.left * image.width).toInt().clamp(0, image.width - 1);
      final y =
          (faceRect.top * image.height).toInt().clamp(0, image.height - 1);
      final w = ((faceRect.right - faceRect.left) * image.width).toInt();
      final h = ((faceRect.bottom - faceRect.top) * image.height).toInt();

      image = img.copyCrop(image, x: x, y: y, width: w, height: h);
    }

    // Resize to recognition model input size
    image = img.copyResize(image,
        width: _recognitionInputSize, height: _recognitionInputSize);

    // Convert to tensor format
    final input = List.generate(
      1,
      (_) => List.generate(
        _recognitionInputSize,
        (y) => List.generate(
          _recognitionInputSize,
          (x) {
            final pixel = image!.getPixel(x, y);
            return [
              (pixel.r / 127.5) - 1.0,
              (pixel.g / 127.5) - 1.0,
              (pixel.b / 127.5) - 1.0,
            ];
          },
        ),
      ),
    );

    return input;
  }

  /// Normalize embedding vector
  List<double> _normalizeEmbedding(List<double> embedding) {
    final magnitude =
        sqrt(embedding.fold<double>(0, (sum, val) => sum + val * val));
    return embedding.map((val) => val / magnitude).toList();
  }

  /// Calculate cosine similarity between two embeddings
  double _cosineSimilarity(List<double> a, List<double> b) {
    double dotProduct = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
    }
    return dotProduct; // Already normalized, so this is cosine similarity
  }

  /// Get all registered face names
  List<String> getRegisteredNames() {
    return _registeredFaces.keys.toList();
  }

  /// Remove a registered face
  void removeFace(String name) {
    _registeredFaces.remove(name);
  }

  /// Clear all registered faces
  void clearAll() {
    _registeredFaces.clear();
  }

  /// Dispose resources
  void dispose() {
    _detectorInterpreter?.close();
    _recognitionInterpreter?.close();
  }
}

// Data classes
class FaceDetection {
  final Rect boundingBox;
  final double confidence;

  FaceDetection({
    required this.boundingBox,
    required this.confidence,
  });
}

class FaceRecognitionResult {
  final String name;
  final double confidence;
  final Rect boundingBox;

  FaceRecognitionResult({
    required this.name,
    required this.confidence,
    required this.boundingBox,
  });
}

class Rect {
  final double top;
  final double left;
  final double bottom;
  final double right;

  Rect({
    required this.top,
    required this.left,
    required this.bottom,
    required this.right,
  });
}
