part of 'main.dart';

class BlinkEvent {
  final BlinkType type;
  final DateTime timestamp;
  final Duration? duration;

  BlinkEvent({
    required this.type,
    required this.timestamp,
    this.duration,
  });

  @override
  String toString() {
    return 'BlinkEvent(type: $type, time: $timestamp, duration: ${duration?.inMilliseconds}ms)';
  }
}

enum BlinkType {
  none,
  leftEye,
  rightEye,
  bothEyes,
}

class AdvancedBlinkDetector {
  double _eyeClosedThreshold = 0.35; // Lower threshold for faster detection
  final List<double> _leftEyeHistory = [];
  final List<double> _rightEyeHistory = [];
  final int _historySize = 20; // Reduced for faster calibration

  bool _isCalibrated = false;
  bool _wasBothEyesClosed = false;

  int _blinkCount = 0;
  DateTime? _lastBlinkTime;
  DateTime? _eyesClosedTime;

  // More lenient timing for faster detection
  static const int _minBlinkInterval = 80; // Reduced from 100ms
  static const int _minBlinkDuration = 30; // Reduced from 50ms
  static const int _maxBlinkDuration = 800; // Increased from 600ms

  void calibrate(Face face) {
    final leftProb = face.leftEyeOpenProbability;
    final rightProb = face.rightEyeOpenProbability;

    if (leftProb != null) {
      _leftEyeHistory.add(leftProb);
      if (_leftEyeHistory.length > _historySize) {
        _leftEyeHistory.removeAt(0);
      }
    }

    if (rightProb != null) {
      _rightEyeHistory.add(rightProb);
      if (_rightEyeHistory.length > _historySize) {
        _rightEyeHistory.removeAt(0);
      }
    }

    if (_leftEyeHistory.length >= _historySize &&
        _rightEyeHistory.length >= _historySize) {
      final avgLeft =
          _leftEyeHistory.reduce((a, b) => a + b) / _leftEyeHistory.length;
      final avgRight =
          _rightEyeHistory.reduce((a, b) => a + b) / _rightEyeHistory.length;

      // More aggressive threshold (50% instead of 55%)
      _eyeClosedThreshold = ((avgLeft + avgRight) / 2) * 0.50;
      _isCalibrated = true;

      print(
          '✓ Calibrated! Threshold: ${_eyeClosedThreshold.toStringAsFixed(3)}');
    }
  }

  BlinkEvent processFrame(Face face) {
    // Skip calibration and use default threshold for immediate detection
    if (!_isCalibrated && _leftEyeHistory.length < 5) {
      // Use default threshold immediately for first few frames
      _eyeClosedThreshold = 0.35;
    }

    // Continue calibration in background
    if (_leftEyeHistory.length < _historySize) {
      calibrate(face);
    }

    final leftProb = face.leftEyeOpenProbability ?? 1.0;
    final rightProb = face.rightEyeOpenProbability ?? 1.0;

    final leftEyeClosed = leftProb < _eyeClosedThreshold;
    final rightEyeClosed = rightProb < _eyeClosedThreshold;
    final bothEyesClosed = leftEyeClosed && rightEyeClosed;
    final now = DateTime.now();

    // Eyes closing
    if (bothEyesClosed && !_wasBothEyesClosed) {
      _wasBothEyesClosed = true;
      _eyesClosedTime = now;
      return BlinkEvent(type: BlinkType.none, timestamp: now);
    }

    // Eyes opening - blink completed
    if (!bothEyesClosed && _wasBothEyesClosed) {
      _wasBothEyesClosed = false;

      final duration =
          _eyesClosedTime != null ? now.difference(_eyesClosedTime!) : null;
      final durationMs = duration?.inMilliseconds ?? 0;

      bool isValidBlink = true;

      // Check minimum interval
      if (_lastBlinkTime != null) {
        final timeSinceLastBlink =
            now.difference(_lastBlinkTime!).inMilliseconds;
        if (timeSinceLastBlink < _minBlinkInterval) {
          isValidBlink = false;
        }
      }

      // More lenient duration check
      if (durationMs > 0 && durationMs < _minBlinkDuration) {
        isValidBlink = false;
      } else if (durationMs > _maxBlinkDuration) {
        isValidBlink = false;
      }

      if (isValidBlink) {
        _blinkCount++;
        _lastBlinkTime = now;
        _eyesClosedTime = null;

        print(
            '👁️ Blink #$_blinkCount | Duration: ${durationMs}ms | L:${leftProb.toStringAsFixed(2)} R:${rightProb.toStringAsFixed(2)}');

        return BlinkEvent(
          type: BlinkType.bothEyes,
          timestamp: now,
          duration: duration,
        );
      }

      _eyesClosedTime = null;
    }

    return BlinkEvent(type: BlinkType.none, timestamp: now);
  }

  bool areEyesClosed(Face face) {
    final leftProb = face.leftEyeOpenProbability ?? 1.0;
    final rightProb = face.rightEyeOpenProbability ?? 1.0;
    return leftProb < _eyeClosedThreshold && rightProb < _eyeClosedThreshold;
  }

  Map<String, dynamic> getEyeState(Face face) {
    final leftProb = face.leftEyeOpenProbability ?? 1.0;
    final rightProb = face.rightEyeOpenProbability ?? 1.0;

    return {
      'leftEyeOpen': leftProb >= _eyeClosedThreshold,
      'rightEyeOpen': rightProb >= _eyeClosedThreshold,
      'leftEyeProbability': leftProb,
      'rightEyeProbability': rightProb,
      'bothEyesClosed':
          leftProb < _eyeClosedThreshold && rightProb < _eyeClosedThreshold,
      'isWinking':
          (leftProb < _eyeClosedThreshold) != (rightProb < _eyeClosedThreshold),
      'threshold': _eyeClosedThreshold,
    };
  }

  bool get isCalibrated => _isCalibrated;
  int get blinkCount => _blinkCount;
  double get threshold => _eyeClosedThreshold;
  int get calibrationProgress =>
      ((_leftEyeHistory.length / _historySize) * 100).round();

  void reset() {
    _blinkCount = 0;
    _lastBlinkTime = null;
    _eyesClosedTime = null;
    _wasBothEyesClosed = false;
  }

  void resetCalibration() {
    _isCalibrated = false;
    _leftEyeHistory.clear();
    _rightEyeHistory.clear();
    _eyeClosedThreshold = 0.35;
    reset();
  }

  void dispose() {
    _leftEyeHistory.clear();
    _rightEyeHistory.clear();
  }
}
