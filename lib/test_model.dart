// Test version - works without TFLite model
// Use this to test if your app structure is working

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:math';

// Mock Face Recognition Service (for testing without model)
class FaceRecognitionService {
  List<List<double>> _registeredFaces = [];
  List<String> _registeredNames = [];
  
  static const int embeddingSize = 128;
  static const double threshold = 0.7;

  Future<void> loadModel() async {
    // Simulate loading delay
    await Future.delayed(Duration(seconds: 1));
    print('✓ Mock model loaded (no real model needed for testing)');
  }

  // Generate a mock embedding from image pixels
  List<double> _generateMockEmbedding(img.Image image) {
    // Create a simple hash-like embedding based on image properties
    Random random = Random(image.width * image.height);
    return List.generate(embeddingSize, (i) => random.nextDouble() * 2 - 1);
  }

  List<double> _normalizeEmbedding(List<double> embedding) {
    double norm = sqrt(embedding.fold(0.0, (sum, val) => sum + val * val));
    return embedding.map((val) => val / norm).toList();
  }

  double _cosineSimilarity(List<double> embedding1, List<double> embedding2) {
    double dotProduct = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }
    return dotProduct;
  }

  Future<bool> registerFace(img.Image faceImage, String name) async {
    print('→ Attempting to register face for: $name');
    await Future.delayed(Duration(milliseconds: 500)); // Simulate processing
    
    var embedding = _generateMockEmbedding(faceImage);
    var normalized = _normalizeEmbedding(embedding);
    
    _registeredFaces.add(normalized);
    _registeredNames.add(name);
    
    print('✓ Face registered successfully for: $name');
    print('✓ Total registered faces: ${_registeredFaces.length}');
    return true;
  }

  Future<Map<String, dynamic>?> recognizeFace(img.Image faceImage) async {
    print('→ Attempting to recognize face...');
    await Future.delayed(Duration(milliseconds: 500)); // Simulate processing
    
    if (_registeredFaces.isEmpty) {
      print('✗ No faces registered');
      return null;
    }

    var embedding = _generateMockEmbedding(faceImage);
    var normalized = _normalizeEmbedding(embedding);

    double maxSimilarity = -1.0;
    int maxIndex = -1;

    for (int i = 0; i < _registeredFaces.length; i++) {
      double similarity = _cosineSimilarity(normalized, _registeredFaces[i]);
      print('  Similarity with ${_registeredNames[i]}: ${similarity.toStringAsFixed(3)}');
      
      if (similarity > maxSimilarity) {
        maxSimilarity = similarity;
        maxIndex = i;
      }
    }

    // For testing: Add randomness to simulate real matching
    maxSimilarity = 0.6 + Random().nextDouble() * 0.35;

    if (maxSimilarity > threshold) {
      print('✓ Match found: ${_registeredNames[maxIndex]}');
      return {
        'name': _registeredNames[maxIndex],
        'confidence': maxSimilarity,
        'matched': true,
      };
    }

    print('✗ No match found (highest: ${maxSimilarity.toStringAsFixed(3)})');
    return {
      'name': 'Unknown',
      'confidence': maxSimilarity,
      'matched': false,
    };
  }

  void clearRegisteredFaces() {
    _registeredFaces.clear();
    _registeredNames.clear();
    print('✓ All registered faces cleared');
  }

  void dispose() {
    print('✓ Service disposed');
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
  String _result = 'Waiting to load model...';
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
        _result = 'Ready! Model loaded successfully.\n\nThis is a TEST version - it simulates face recognition without requiring a real TFLite model.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _result = 'Failed to load model: $e';
      });
    }
  }

  Future<img.Image?> _loadImageFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        print('✗ Failed to decode image');
      } else {
        print('✓ Image loaded: ${image.width}x${image.height}');
      }
      return image;
    } catch (e) {
      print('✗ Error loading image: $e');
      return null;
    }
  }

  Future<void> _pickAndRegisterFace() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
      );
      
      if (image == null) {
        print('No image selected');
        return;
      }

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
                ? '✓ Successfully registered: $name\n\nYou can now try to recognize this face!' 
                : '✗ Failed to register face';
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() {
          _result = '✗ Failed to load image';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _result = '✗ Error: $e';
        _isLoading = false;
      });
      print('Error in _pickAndRegisterFace: $e');
    }
  }

  Future<void> _pickAndRecognizeFace() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
      );
      
      if (image == null) {
        print('No image selected');
        return;
      }

      setState(() => _isLoading = true);

      final File imageFile = File(image.path);
      final img.Image? faceImage = await _loadImageFile(imageFile);

      if (faceImage != null) {
        Map<String, dynamic>? recognition = await _faceService.recognizeFace(faceImage);
        
        setState(() {
          _selectedImage = imageFile;
          if (recognition != null) {
            _result = recognition['matched'] 
                ? '✓ Recognized: ${recognition['name']}\nConfidence: ${(recognition['confidence'] * 100).toStringAsFixed(2)}%'
                : '✗ Unknown face\nHighest similarity: ${(recognition['confidence'] * 100).toStringAsFixed(2)}%\n\nTry registering this face first!';
          } else {
            _result = '✗ No faces registered\n\nPlease register at least one face first!';
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _result = '✗ Failed to load image';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _result = '✗ Error: $e';
        _isLoading = false;
      });
      print('Error in _pickAndRecognizeFace: $e');
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
          decoration: InputDecoration(
            hintText: 'Enter name',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => name = value,
          onSubmitted: (value) {
            name = value;
            Navigator.pop(context, name);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
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
        title: Text('Face Recognition Test'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              _faceService.clearRegisteredFaces();
              setState(() {
                _result = '✓ All faces cleared';
                _selectedImage = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('All registered faces cleared')),
              );
            },
            tooltip: 'Clear registered faces',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedImage != null)
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  
                  SizedBox(height: 20),
                  
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      _result,
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                  
                  SizedBox(height: 30),
                  
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickAndRegisterFace,
                    icon: Icon(Icons.person_add),
                    label: Text('Register New Face'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickAndRecognizeFace,
                    icon: Icon(Icons.face),
                    label: Text('Recognize Face'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  
                  SizedBox(height: 30),
                  
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Text(
                      '⚠️ TEST MODE: This uses mock embeddings. For real face recognition, you need a TFLite model.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
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