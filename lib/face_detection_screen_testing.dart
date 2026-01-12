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
  late final _faceDetection = FaceDetectionServiceV2();
  final _recognition = FaceRecognitionV2();
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
    _recognition.dispose();
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
        builder: (context) => LiveCameraPage(
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
        floatingActionButton: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedImage != null)
              FloatingActionButton.extended(
                onPressed: () async {
                  if (_selectedImage == null) return;

                  final faceImage = await FaceRecognitionV2.loadImageFromFile(
                      _selectedImage!.path);
                  final result = await _recognition.recognizeFace(faceImage);

                  _resultText = '$result';
                  setState(() {});
                },
                icon: const Icon(Icons.star),
                label: const Text('Recognition'),
              ),
          ],
        ),
      ),
    );
  }
}

class LiveCameraPage extends StatefulWidget {
  final CameraDescription camera;
  final FaceRecognitionV2 recognition;
  final FaceDetectionServiceV2 detection;

  const LiveCameraPage({
    super.key,
    required this.camera,
    required this.detection,
    required this.recognition,
  });

  @override
  State<LiveCameraPage> createState() => _LiveCameraPageState();
}

class _LiveCameraPageState extends State<LiveCameraPage> {
  late final _detector = widget.detection;
  late final _recognition = widget.recognition..reset();
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    _initializeControllerFuture = _controller.initialize().then((_) {
      _controller.startImageStream((image) {
        _detector.processCameraImage(image);
        _recognition.processCameraImage(image);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Live Face Detection'),
          backgroundColor: Colors.blue,
        ),
        body: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return StreamBuilder(
                  stream: _detector.stream,
                  builder: (_, s) {
                    final faces = s.data ?? [];

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_controller),
                        if (faces.isNotEmpty)
                          CustomPaint(
                            painter: FacePainter(
                                faces.first,
                                Size(
                                  _controller.value.previewSize!.height,
                                  _controller.value.previewSize!.width,
                                ),
                                true),
                          ),
                        Positioned(
                            right: 10,
                            left: 10,
                            bottom: 10,
                            child: StreamBuilder(
                                stream: _recognition.stream,
                                builder: (_, s) {
                                  return Parent(
                                      style: ParentStyle()
                                        ..background.color(Colors.black54)
                                        ..padding(all: 16),
                                      child: Text(
                                        '${s.data}',
                                        style: TextStyle(color: Colors.white),
                                      ));
                                })),
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Faces: ${faces.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  });
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}
