import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'face_attendance.dart/main.dart';

class CameraRecognitionScreen extends StatefulWidget {
  final FaceRecognitionService faceService;

  const CameraRecognitionScreen({super.key, required this.faceService});

  @override
  _CameraRecognitionScreenState createState() =>
      _CameraRecognitionScreenState();
}

class _CameraRecognitionScreenState extends State<CameraRecognitionScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isProcessing = false;
  String _result = 'Point camera at a face';
  bool _isRecognizing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        setState(() => _result = 'No cameras available');
        return;
      }

      // Use front camera if available
      CameraDescription camera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.max,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing camera: $e');
      setState(() => _result = 'Camera error: $e');
    }
  }

  Future<void> _captureAndRecognize() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _result = 'Processing...';
    });

    try {
      final XFile image = await _controller!.takePicture();
      final bytes = await File(image.path).readAsBytes();
    } catch (e) {
      print('Error capturing/recognizing: $e');
      if (mounted) {
        setState(() => _result = 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _toggleContinuousRecognition() {
    setState(() {
      _isRecognizing = !_isRecognizing;
    });

    if (_isRecognizing) {
      _continuousRecognition();
    }
  }

  Future<void> _continuousRecognition() async {
    while (_isRecognizing && mounted) {
      await _captureAndRecognize();
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    final currentDirection = _controller!.description.lensDirection;
    CameraDescription newCamera;

    if (currentDirection == CameraLensDirection.back) {
      newCamera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
      );
    } else {
      newCamera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
      );
    }

    await _controller?.dispose();
    _controller = CameraController(
      newCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text('Camera Recognition')),
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Camera Recognition'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera Preview
            Center(child: CameraPreview(_controller!)),

            // Result Overlay
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _result.contains('✓')
                      ? Colors.green.withOpacity(0.9)
                      : _result.contains('✗')
                          ? Colors.red.withOpacity(0.9)
                          : Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _result,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Control Buttons
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Switch Camera
                  if (_cameras != null && _cameras!.length > 1)
                    FloatingActionButton(
                      heroTag: 'switch',
                      onPressed: _switchCamera,
                      child: Icon(Icons.flip_camera_ios),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                    ),

                  // Capture/Recognize Once
                  FloatingActionButton.extended(
                    heroTag: 'capture',
                    onPressed: _isProcessing ? null : _captureAndRecognize,
                    icon: Icon(Icons.camera),
                    label: Text('Recognize'),
                    backgroundColor: Colors.blue,
                  ),

                  // Continuous Recognition Toggle
                  FloatingActionButton(
                    heroTag: 'continuous',
                    onPressed: _toggleContinuousRecognition,
                    child: Icon(_isRecognizing ? Icons.stop : Icons.play_arrow),
                    backgroundColor: _isRecognizing ? Colors.red : Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _isRecognizing = false;
    _controller?.dispose();
    super.dispose();
  }
}
