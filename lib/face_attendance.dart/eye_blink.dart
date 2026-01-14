part of 'main.dart';

class BlinkEvent {
  final BlinkType type;
  final DateTime timestamp;
  final Duration? duration;

  BlinkEvent({required this.type, required this.timestamp, this.duration});
}

enum BlinkType { none, leftEye, rightEye, bothEyes }

class AdvancedBlinkDetector {
  double _eyeClosedThreshold = 0.35;
  final List<double> _leftEyeHistory = [];
  final List<double> _rightEyeHistory = [];
  final int _historySize = 20;
  bool _isCalibrated = false;
  bool _wasBothEyesClosed = false;
  int _blinkCount = 0;
  DateTime? _lastBlinkTime;
  DateTime? _eyesClosedTime;

  static const int _minBlinkInterval = 80;
  static const int _minBlinkDuration = 30;
  static const int _maxBlinkDuration = 800;

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

      _eyeClosedThreshold = ((avgLeft + avgRight) / 2) * 0.50;
      _isCalibrated = true;
    }
  }

  BlinkEvent processFrame(Face face) {
    if (!_isCalibrated && _leftEyeHistory.length < 5) {
      _eyeClosedThreshold = 0.35;
    }

    if (_leftEyeHistory.length < _historySize) {
      calibrate(face);
    }

    final leftProb = face.leftEyeOpenProbability ?? 1.0;
    final rightProb = face.rightEyeOpenProbability ?? 1.0;

    final leftEyeClosed = leftProb < _eyeClosedThreshold;
    final rightEyeClosed = rightProb < _eyeClosedThreshold;
    final bothEyesClosed = leftEyeClosed && rightEyeClosed;
    final now = DateTime.now();

    if (bothEyesClosed && !_wasBothEyesClosed) {
      _wasBothEyesClosed = true;
      _eyesClosedTime = now;
      return BlinkEvent(type: BlinkType.none, timestamp: now);
    }

    if (!bothEyesClosed && _wasBothEyesClosed) {
      _wasBothEyesClosed = false;

      final duration =
          _eyesClosedTime != null ? now.difference(_eyesClosedTime!) : null;
      final durationMs = duration?.inMilliseconds ?? 0;

      bool isValidBlink = true;

      if (_lastBlinkTime != null) {
        final timeSinceLastBlink =
            now.difference(_lastBlinkTime!).inMilliseconds;
        if (timeSinceLastBlink < _minBlinkInterval) {
          isValidBlink = false;
        }
      }

      if (durationMs > 0 && durationMs < _minBlinkDuration) {
        isValidBlink = false;
      } else if (durationMs > _maxBlinkDuration) {
        isValidBlink = false;
      }

      if (isValidBlink) {
        _blinkCount++;
        _lastBlinkTime = now;
        _eyesClosedTime = null;

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
