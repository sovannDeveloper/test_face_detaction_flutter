part of 'main.dart';

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size videoSize;

  FacePainter(this.faces, this.videoSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color.fromARGB(255, 255, 0, 0);

    for (int i = 0; i < faces.length; i++) {
      final face = faces[i];
      final rect = _scaleRect(
        rect: face.boundingBox,
        videoSize: videoSize,
        widgetSize: size,
      );

      // Draw rectangle
      canvas.drawRect(rect, paint);

      // Draw text label
      _drawText(
        canvas: canvas,
        text: 'Unknown ${i + 1}',
        position: Offset(rect.left - 1, rect.top - 20),
        backgroundColor: const Color.fromARGB(255, 255, 0, 0),
      );

      // Draw smile probability if available
      if (face.smilingProbability != null) {
        _drawText(
          canvas: canvas,
          text:
              'Smile: ${(face.smilingProbability! * 100).toStringAsFixed(0)}%',
          position: Offset(rect.left - 1, rect.bottom + 1),
          backgroundColor: Colors.blue,
        );
      }

      // Draw eye open probabilities
      if (face.leftEyeOpenProbability != null ||
          face.rightEyeOpenProbability != null) {
        String eyeText = '';
        if (face.leftEyeOpenProbability != null) {
          eyeText +=
              'L: ${(face.leftEyeOpenProbability! * 100).toStringAsFixed(0)}%';
        }
        if (face.rightEyeOpenProbability != null) {
          if (eyeText.isNotEmpty) eyeText += ' ';
          eyeText +=
              'R: ${(face.rightEyeOpenProbability! * 100).toStringAsFixed(0)}%';
        }

        _drawText(
          canvas: canvas,
          text: eyeText,
          position: Offset(rect.left - 1, rect.bottom + 20),
          backgroundColor: Colors.orange,
        );
      }

      paint.style = PaintingStyle.stroke;
    }
  }

  void _drawText({
    required Canvas canvas,
    required String text,
    required Offset position,
    required Color backgroundColor,
    Color textColor = Colors.white,
    double fontSize = 14,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Draw background
    final backgroundRect = Rect.fromLTWH(
      position.dx,
      position.dy,
      textPainter.width + 8,
      textPainter.height + 4,
    );

    final backgroundPaint = Paint()
      ..color = backgroundColor.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    canvas.drawRect(backgroundRect, backgroundPaint);

    // Draw text
    textPainter.paint(canvas, position + const Offset(4, 2));
  }

  Rect _scaleRect({
    required Rect rect,
    required Size videoSize,
    required Size widgetSize,
  }) {
    final double scaleX = widgetSize.width / videoSize.width;
    final double scaleY = widgetSize.height / videoSize.height;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate centered position offsets
    final double scaledWidth = videoSize.width * scale;
    final double scaledHeight = videoSize.height * scale;
    final double offsetX = (widgetSize.width - scaledWidth) / 2;
    final double offsetY = (widgetSize.height - scaledHeight) / 2;

    // Scale the rectangle
    double left = rect.left * scale + offsetX;
    double top = rect.top * scale + offsetY;
    double right = rect.right * scale + offsetX;
    double bottom = rect.bottom * scale + offsetY;

    return Rect.fromLTRB(
      left.clamp(0, left),
      top.clamp(0, top),
      right.clamp(0, right),
      bottom.clamp(0, bottom),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
