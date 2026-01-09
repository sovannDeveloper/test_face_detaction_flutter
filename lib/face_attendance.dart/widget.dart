part of 'main.dart';

class FacePainter extends CustomPainter {
  final Face face;
  final Size imageSize;
  final bool isVerify;

  FacePainter(this.face, this.imageSize, this.isVerify);

  @override
  void paint(Canvas canvas, Size size) {
    Color color = const Color.fromARGB(255, 255, 0, 0);

    if (isVerify) {
      color = const Color.fromARGB(255, 0, 255, 102);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color
      ..strokeCap = StrokeCap.round;

    final rect = FaceDetectionService.scaleRect(
        rect: face.boundingBox, size: imageSize, widgetSize: size);

    // Draw corner brackets instead of full rectangle
    final cornerLength = rect.width * 0.2; // 20% of width for corner length

    // Top-left corner
    canvas.drawLine(
        rect.topLeft, Offset(rect.left + cornerLength, rect.top), paint);
    canvas.drawLine(
        rect.topLeft, Offset(rect.left, rect.top + cornerLength), paint);

    // Top-right corner
    canvas.drawLine(Offset(rect.right, rect.top),
        Offset(rect.right - cornerLength, rect.top), paint);
    canvas.drawLine(Offset(rect.right, rect.top),
        Offset(rect.right, rect.top + cornerLength), paint);

    // Bottom-left corner
    canvas.drawLine(Offset(rect.left, rect.bottom),
        Offset(rect.left + cornerLength, rect.bottom), paint);
    canvas.drawLine(Offset(rect.left, rect.bottom),
        Offset(rect.left, rect.bottom - cornerLength), paint);

    // Bottom-right corner
    canvas.drawLine(Offset(rect.right, rect.bottom),
        Offset(rect.right - cornerLength, rect.bottom), paint);
    canvas.drawLine(Offset(rect.right, rect.bottom),
        Offset(rect.right, rect.bottom - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Group6Painter extends CustomPainter {
  final Color backgroundColor;
  final Color activeColor;

  Group6Painter(this.backgroundColor, this.activeColor);

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / 391;
    final double scaleY = size.height / 391;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    /// 1. Background square with circular hole
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final path = Path()
      ..fillType = PathFillType.evenOdd
      // outer rectangle
      ..addRect(const Rect.fromLTWH(0, 0, 391, 391))
      // inner circular hole
      ..addOval(Rect.fromCircle(
        center: const Offset(196, 196),
        radius: 133,
      ));

    canvas.drawPath(path, backgroundPaint);

    /// 2. Red stroked circle
    final circlePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    canvas.drawCircle(
      const Offset(196, 196),
      135.5,
      circlePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
