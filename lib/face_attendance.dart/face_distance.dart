part of 'main.dart';

enum FaceDistanceStatus { closer, away, still }

class FaceDistance {
  double? _previousFaceWidth;
  final double _movementThreshold = 5.0;

  FaceDistanceStatus process(Face face) {
    FaceDistanceStatus status = FaceDistanceStatus.still;
    final boundingBox = face.boundingBox;
    final currentFaceWidth = boundingBox.width;

    if (_previousFaceWidth != null) {
      final difference = currentFaceWidth - _previousFaceWidth!;

      if (difference.abs() > _movementThreshold) {
        if (difference > 0) {
          status = FaceDistanceStatus.closer;
        } else {
          status = FaceDistanceStatus.away;
        }
      } else {
        status = FaceDistanceStatus.still;
      }
    }

    _previousFaceWidth = currentFaceWidth;
    return status;
  }
}
