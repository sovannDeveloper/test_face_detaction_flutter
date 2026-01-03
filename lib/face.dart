// File: lib/screens/face_recognition_screen.dart
// Complete single-file solution

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// Face Recognition Service
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
          await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      print('✓ Model loaded successfully');

      var inputShape = _interpreter!.getInputTensor(0).shape;
      var outputShape = _interpreter!.getOutputTensor(0).shape;
      print('✓ Input shape: $inputShape');
      print('✓ Output shape: $outputShape');
    } catch (e) {
      print('✗ Error loading model: $e');
      print(
          'Make sure you have placed the model file at: assets/models/mobilefacenet.tflite');
      rethrow;
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
      print('✗ Model not loaded');
      return null;
    }

    try {
      print('→ Preprocessing image...');
      var input = preprocessImage(faceImage);

      print('→ Running inference...');
      var output = List.filled(outputSize, 0.0).reshape([1, outputSize]);
      _interpreter!.run(input, output);

      print('✓ Inference complete');
      List<double> embedding = List<double>.from(output[0]);
      return normalizeEmbedding(embedding);
    } catch (e) {
      print('✗ Error getting face embedding: $e');
      print('Stack trace: ${StackTrace.current}');
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
    print('→ Attempting to register face for: $name');
    List<double>? embedding = await getFaceEmbedding(faceImage);

    if (embedding == null) {
      print('✗ Failed to get embedding');
      return false;
    }

    _registeredFaces.add(embedding);
    _registeredNames.add(name);
    print('✓ Face registered successfully for: $name');
    print('✓ Total registered faces: ${_registeredFaces.length}');
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

// Main Screen
class FaceRecognitionScreen extends StatefulWidget {
  @override
  _FaceRecognitionScreenState createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen> {
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  String _result = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    setState(() => _isLoading = true);
    try {
      await _faceService.loadModel();
      setState(() {
        _isLoading = false;
        _result = 'Model loaded successfully';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _result = 'Failed to load model: $e';
      });
    }
  }

  Future<img.Image?> _loadImageFile(File file) async {
    final bytes = await file.readAsBytes();
    return img.decodeImage(bytes);
  }

  Future<void> _pickAndRegisterFace() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _isLoading = true);

    final File imageFile = File(image.path);
    final img.Image? faceImage = await _loadImageFile(imageFile);

    if (faceImage != null) {
      String? name = await _showNameDialog();

      if (name != null && name.isNotEmpty) {
        bool success = await _faceService.registerFace(faceImage, name);

        setState(() {
          _selectedImage = imageFile;
          _result = success
              ? 'Successfully registered: $name'
              : 'Failed to register face';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() {
        _result = 'Failed to load image';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndRecognizeFace() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _isLoading = true);

    final File imageFile = File(image.path);
    final img.Image? faceImage = await _loadImageFile(imageFile);

    if (faceImage != null) {
      Map<String, dynamic>? recognition =
          await _faceService.recognizeFace(faceImage);

      setState(() {
        _selectedImage = imageFile;
        if (recognition != null) {
          _result = recognition['matched']
              ? 'Recognized: ${recognition['name']}\nConfidence: ${(recognition['confidence'] * 100).toStringAsFixed(2)}%'
              : 'Unknown face\nHighest similarity: ${(recognition['confidence'] * 100).toStringAsFixed(2)}%';
        } else {
          _result = 'No faces registered or recognition failed';
        }
        _isLoading = false;
      });
    } else {
      setState(() {
        _result = 'Failed to load image';
        _isLoading = false;
      });
    }
  }

  Future<String?> _showNameDialog() async {
    String? name;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Register Face'),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(hintText: 'Enter name'),
          onChanged: (value) => name = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, name),
            child: Text('Register'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Recognition'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              _faceService.clearRegisteredFaces();
              setState(() {
                _result = 'All faces cleared';
                _selectedImage = null;
              });
            },
            tooltip: 'Clear registered faces',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedImage != null)
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  SizedBox(height: 20),
                  if (_result.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _result,
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _pickAndRegisterFace,
                    icon: Icon(Icons.person_add),
                    label: Text('Register New Face'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _pickAndRecognizeFace,
                    icon: Icon(Icons.face),
                    label: Text('Recognize Face'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _faceService.dispose();
    super.dispose();
  }
}
