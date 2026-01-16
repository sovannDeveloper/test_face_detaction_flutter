import 'dart:io';

import 'package:camera/camera.dart';
import 'package:division/division.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'face_attendance.dart/main.dart';

class FaceDetectionPage extends StatefulWidget {
  const FaceDetectionPage({super.key});

  @override
  State<FaceDetectionPage> createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> {
  late final _faceDetection = FaceDetectionService();
  final _recognition = FaceRecognitionService();
  File? _selectedImage;
  bool _isProcessing = false;
  String? _errorMessage;
  String _resultText = '';
  List<CameraDescription> _cameras = [];
  CameraDescription? _camera;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      _cameras = await availableCameras();
      _camera = _cameras
          .firstWhere((e) => e.lensDirection == CameraLensDirection.front);
      _faceDetection.initCameraRotation(_camera!);
      _recognition.initCameraRotation(_camera!);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _faceDetection.dispose();
    super.dispose();
  }

  Future<void> _pickAndDetectFaces(ImageSource source) async {
    try {
      _isProcessing = true;
      _errorMessage = null;
      setState(() {});

      final img = await ImagePicker().pickImage(source: source);

      if (img == null) {
        throw 'No image';
      }

      _selectedImage = File(img.path);
      setState(() {});
    } catch (e) {
      _errorMessage = 'Error: ${e.toString()}';
    } finally {
      _isProcessing = false;
      setState(() {});
    }
  }

  void _openLiveCamera() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveDetectionScreen(
            camera: _camera!,
            recognition: _recognition,
            detection: _faceDetection),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Face Recognize')),
        body: _camera == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                          onPressed: () {
                            _openLiveCamera();
                          },
                          child: Text('Open Camera')),
                      const SizedBox(height: 10),
                      ElevatedButton(
                          onPressed: () {
                            _pickAndDetectFaces(ImageSource.gallery);
                          },
                          child: Text('Upload File')),
                      if (_isProcessing)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      if (_errorMessage != null)
                        Card(
                          color: Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade900),
                            ),
                          ),
                        ),
                      if (_selectedImage != null) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: Parent(
                            style: ParentStyle()..width(150),
                            child: Image.file(_selectedImage!,
                                fit: BoxFit.contain),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(_resultText),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
