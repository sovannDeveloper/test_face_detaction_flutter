// File: lib/screens/face_recognition_screen.dart
// Complete single-file solution with improvements

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'services/face_recognition_service.dart';

// Main Screen
class FaceRecognitionScreen extends StatefulWidget {
  const FaceRecognitionScreen({super.key});

  @override
  _FaceRecognitionScreenState createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen> {
  final FaceRecognitionService0 _faceService = FaceRecognitionService0();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  String _result = '';
  bool _isLoading = false;
  double _currentThreshold = 0.5;

  @override
  void initState() {
    super.initState();
  }

  Future<img.Image?> _loadImageFile(File file) async {
    final bytes = await file.readAsBytes();
    return img.decodeImage(bytes);
  }

  Future<void> _pickAndRegisterFace() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100, // Use high quality
    );

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
              ? '✓ Successfully registered: $name\n\nTip: Register 2-3 photos of the same person for better accuracy!'
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
  }

  Future<void> _pickAndRecognizeFace() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100, // Use high quality
    );

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
          String resultText = recognition['matched']
              ? '✓ Recognized: ${recognition['name']}\nConfidence: ${(recognition['confidence'] * 100).toStringAsFixed(2)}%'
              : '✗ Unknown face\nBest match: ${(recognition['confidence'] * 100).toStringAsFixed(2)}%';

          // Show all matches for debugging
          if (recognition['allMatches'] != null) {
            resultText += '\n\n--- All Comparisons ---';
            for (var match in recognition['allMatches']) {
              String emoji =
                  match['similarity'] > _currentThreshold ? '✓' : '✗';
              resultText +=
                  '\n$emoji ${match['name']}: ${(match['similarity'] * 100).toStringAsFixed(2)}%';
            }
            resultText +=
                '\n\nThreshold: ${(_currentThreshold * 100).toStringAsFixed(0)}%';
          }

          _result = resultText;
        } else {
          _result = '✗ No faces registered or recognition failed';
        }
        _isLoading = false;
      });
    } else {
      setState(() {
        _result = '✗ Failed to load image';
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
          decoration: InputDecoration(
            hintText: 'Enter name',
            border: OutlineInputBorder(),
          ),
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

  Future<void> _showThresholdDialog() async {
    double tempThreshold = _currentThreshold;
    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Adjust Recognition Threshold'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current: ${(tempThreshold * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Lower = More lenient (may match different people)\nHigher = More strict (may not match same person)',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Slider(
                value: tempThreshold,
                min: 0.3,
                max: 0.9,
                divisions: 60,
                label: '${(tempThreshold * 100).toStringAsFixed(0)}%',
                onChanged: (value) {
                  setDialogState(() {
                    tempThreshold = value;
                  });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('30%', style: TextStyle(fontSize: 12)),
                  Text('90%', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentThreshold = tempThreshold;
                  _faceService.setThreshold(tempThreshold);
                  _result =
                      '✓ Threshold updated to ${(tempThreshold * 100).toStringAsFixed(0)}%';
                });
                Navigator.pop(context);
              },
              child: Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Recognition'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.tune),
            onPressed: _showThresholdDialog,
            tooltip: 'Adjust threshold',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: () {
              _faceService.clearRegisteredFaces();
              setState(() {
                _result = '✓ All faces cleared';
                _selectedImage = null;
              });
            },
            tooltip: 'Clear registered faces',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
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
                    if (_result.isNotEmpty)
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _result.contains('✓')
                              ? Colors.green.shade50
                              : _result.contains('✗')
                                  ? Colors.red.shade50
                                  : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _result.contains('✓')
                                ? Colors.green
                                : _result.contains('✗')
                                    ? Colors.red
                                    : Colors.blue,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _result,
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickAndRegisterFace,
                      icon: Icon(Icons.person_add),
                      label: Text('Register New Face'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _pickAndRecognizeFace,
                      icon: Icon(Icons.face),
                      label: Text('Recognize Face'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
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
