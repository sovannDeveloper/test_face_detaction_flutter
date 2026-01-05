import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'services/face_detection_service.dart';

// Import your FaceDetectionService
// import 'your_path/face_detection_service.dart';

class FaceLivenessDetector extends StatefulWidget {
  const FaceLivenessDetector({Key? key}) : super(key: key);

  @override
  State<FaceLivenessDetector> createState() => _FaceLivenessDetectorState();
}

class _FaceLivenessDetectorState extends State<FaceLivenessDetector> {
  late FaceDetectionService _faceService;
  StreamSubscription<FaceData>? _faceSubscription;
  StreamSubscription<CameraState>? _cameraSubscription;

  bool _isCameraReady = false;
  String _livenessStatus = 'Position your face';
  String _instruction = 'Look at the camera';
  Color _statusColor = Colors.blue;

  // Liveness check parameters
  double? _previousLeftEyeOpenProb;
  double? _previousRightEyeOpenProb;
  List<double> _headRotations = [];

  // Challenge system
  String _currentChallenge = '';
  final List<String> _challenges = [
    'Blink your eyes',
    'Turn head left',
    'Turn head right',
    'Smile'
  ];
  int _currentChallengeIndex = 0;
  bool _livenessVerified = false;

  @override
  void initState() {
    super.initState();
    _initializeFaceDetection();
    _startNewChallenge();
  }

  void _initializeFaceDetection() {
    _faceService = FaceDetectionService();

    _cameraSubscription = _faceService.cameraState.stream.listen((state) {
      setState(() {
        _isCameraReady = state == CameraState.done;
      });
    });

    _faceSubscription = _faceService.onDetection.stream.listen((faceData) {
      _analyzeFaceData(faceData);
    });
  }

  void _startNewChallenge() {
    if (_currentChallengeIndex < _challenges.length) {
      setState(() {
        _currentChallenge = _challenges[_currentChallengeIndex];
        _instruction = _currentChallenge;
      });
    }
  }

  void _analyzeFaceData(FaceData faceData) {
    if (_livenessVerified) return;

    if (faceData.faces.isEmpty) {
      setState(() {
        _livenessStatus = 'No face detected';
        _statusColor = Colors.orange;
      });
      return;
    }

    if (faceData.faces.length > 1) {
      setState(() {
        _livenessStatus = 'Multiple faces detected';
        _statusColor = Colors.orange;
      });
      return;
    }

    final face = faceData.faces.first;

    // Check face size (anti-spoofing)
    final faceArea = face.boundingBox.width * face.boundingBox.height;
    final imageArea = faceData.imageSize.width * faceData.imageSize.height;
    final faceRatio = faceArea / imageArea;

    if (faceRatio < 0.1) {
      setState(() {
        _livenessStatus = 'Move closer';
        _statusColor = Colors.orange;
      });
      return;
    }

    // Perform liveness checks based on current challenge
    switch (_currentChallenge) {
      case 'Blink your eyes':
        _checkBlinkDetection(face);
        break;
      case 'Turn head left':
        _checkHeadRotation(face, -15, 'left');
        break;
      case 'Turn head right':
        _checkHeadRotation(face, 15, 'right');
        break;
      case 'Smile':
        _checkSmile(face);
        break;
    }
  }

  void _checkBlinkDetection(Face face) {
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;

    if (leftEye != null && rightEye != null) {
      // Detect blink (both eyes closed)
      if (leftEye < 0.3 && rightEye < 0.3) {
        if (_previousLeftEyeOpenProb != null &&
            _previousRightEyeOpenProb != null &&
            _previousLeftEyeOpenProb! > 0.6 &&
            _previousRightEyeOpenProb! > 0.6) {
          setState(() {
            _livenessStatus = 'Blink detected! ✓';
            _statusColor = Colors.green;
          });
          _moveToNextChallenge();
        }
      }
      _previousLeftEyeOpenProb = leftEye;
      _previousRightEyeOpenProb = rightEye;
    }
  }

  void _checkHeadRotation(Face face, double targetAngle, String direction) {
    final headYaw = face.headEulerAngleY ?? 0;

    _headRotations.add(headYaw);
    if (_headRotations.length > 5) {
      _headRotations.removeAt(0);
    }

    bool rotationDetected = false;
    if (direction == 'left' && headYaw < targetAngle) {
      rotationDetected = true;
    } else if (direction == 'right' && headYaw > targetAngle) {
      rotationDetected = true;
    }

    if (rotationDetected) {
      setState(() {
        _livenessStatus = 'Head movement detected! ✓';
        _statusColor = Colors.green;
      });
      _moveToNextChallenge();
    }
  }

  void _checkSmile(Face face) {
    final smileProb = face.smilingProbability;

    if (smileProb != null && smileProb > 0.9) {
      setState(() {
        _livenessStatus = 'Smile detected! ✓';
        _statusColor = Colors.green;
      });
      _moveToNextChallenge();
    }
  }

  void _moveToNextChallenge() {
    Future.delayed(const Duration(seconds: 1), () {
      _currentChallengeIndex++;
      if (_currentChallengeIndex >= _challenges.length) {
        setState(() {
          _livenessVerified = true;
          _livenessStatus = 'REAL FACE VERIFIED ✓';
          _statusColor = Colors.green;
          _instruction = 'Liveness check passed!';
        });
        _onLivenessVerified();
      } else {
        _startNewChallenge();
      }
    });
  }

  void _onLivenessVerified() {
    print('Face liveness verified successfully!');
  }

  void _resetChallenge() {
    setState(() {
      _currentChallengeIndex = 0;
      _livenessVerified = false;
      _previousLeftEyeOpenProb = null;
      _previousRightEyeOpenProb = null;
      _headRotations.clear();
    });
    _startNewChallenge();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraReady) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing camera...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SizedBox.expand(
            child: CameraPreview(_faceService.cameraController),
          ),

          Center(
            child: Container(
              width: 250,
              height: 350,
              decoration: BoxDecoration(
                border: Border.all(color: _statusColor, width: 3),
                borderRadius: BorderRadius.circular(150),
              ),
            ),
          ),

          // Status overlay
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _livenessStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    _instruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (!_livenessVerified)
                  Text(
                    'Challenge ${_currentChallengeIndex + 1}/${_challenges.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),

          // Action buttons
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _resetChallenge,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _faceSubscription?.cancel();
    _cameraSubscription?.cancel();
    _faceService.dispose();
    super.dispose();
  }
}
