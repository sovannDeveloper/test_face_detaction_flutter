part of 'main.dart';

const double eyeOpenThreshold = 0.65;
const double eyeClosedThreshold = 0.25;
const int blinkMaxDurationMs = 400;

enum BlinkState { eyesOpen, eyesClosed }

class BlinkDetector {
  BlinkState _state = BlinkState.eyesOpen;
  DateTime? _closedAt;
  int blinkCount = 0;

  bool update({
    required double? leftEye,
    required double? rightEye,
  }) {
    // If ML Kit can't detect eyes reliably
    if (leftEye == null || rightEye == null) return false;

    final bothOpen = leftEye > eyeOpenThreshold && rightEye > eyeOpenThreshold;

    final bothClosed =
        leftEye < eyeClosedThreshold && rightEye < eyeClosedThreshold;

    final now = DateTime.now();

    if (_state == BlinkState.eyesOpen && bothClosed) {
      _state = BlinkState.eyesClosed;
      _closedAt = now;
    } else if (_state == BlinkState.eyesClosed && bothOpen) {
      final closedDuration = now.difference(_closedAt!).inMilliseconds;

      if (closedDuration <= blinkMaxDurationMs) {
        blinkCount++;
        return true;
      }
      _state = BlinkState.eyesOpen;
    }

    return false;
  }
}
