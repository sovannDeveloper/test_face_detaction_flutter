part of 'main.dart';

class FacePainter extends CustomPainter {
  final Face face;
  final Size imageSize;

  FacePainter(this.face, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final faceWidth = face.boundingBox.width;
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final baseDotRadius = faceWidth * scale * 0.01;
    void drawContourByIndex(
      FaceContourType type,
      List<int> Function(List<Point<int>>) indexSelector,
    ) {
      final contour = face.contours[type];
      final points = contour?.points ?? [];

      if (points.isEmpty) return;

      for (final i in indexSelector(points)) {
        final point = points.elementAtOrNull(i);

        if (point == null) continue;

        final offset =
            scalePoint(point: point, size: imageSize, widgetSize: size);
        final randomRadius =
            baseDotRadius * (0.3 + (1 * (point.x % 100) / 100));
        final randomOpacity = 128 + ((point.y % 128));
        final dotPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = Color.fromARGB(randomOpacity, 255, 255, 255);

        canvas.drawCircle(offset, randomRadius, dotPaint);
      }
    }

    // Draw face contours
    drawContourByIndex(FaceContourType.face, _getFacePoints);
    drawContourByIndex(FaceContourType.leftEyebrowTop, _getCenterPoint);
    drawContourByIndex(FaceContourType.rightEyebrowTop, _getCenterPoint);
    drawContourByIndex(FaceContourType.leftEye, _getLeftEyePoints);
    drawContourByIndex(FaceContourType.rightEye, _getRightEyePoints);
    drawContourByIndex(FaceContourType.noseBridge, _getLastPoint);
    drawContourByIndex(FaceContourType.upperLipTop, _getFirstCenterLastPoints);
    drawContourByIndex(FaceContourType.lowerLipBottom, _getCenterPoint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  static Offset scalePoint({
    required Point<int> point,
    required Size size,
    required Size widgetSize,
  }) {
    final scaleX = widgetSize.width / size.width;
    final scaleY = widgetSize.height / size.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final scaledWidth = size.width * scale;
    final scaledHeight = size.height * scale;

    final offsetX = (widgetSize.width - scaledWidth) / 2;
    final offsetY = (widgetSize.height - scaledHeight) / 2;

    return Offset(
      point.x * scale + offsetX,
      point.y * scale + offsetY,
    );
  }

  // Point selection helpers
  List<int> _getFacePoints(List<Point<int>> points) {
    final bottom = (points.length / 2).ceil();
    final left = (bottom / 2).ceil();
    final right = (3 * left).ceil();
    return [0, left, bottom, right];
  }

  List<int> _getCenterPoint(List<Point<int>> points) {
    final center = (points.length / 2).ceil() - 1;
    return [center];
  }

  List<int> _getLastPoint(List<Point<int>> points) {
    return [points.length - 1];
  }

  List<int> _getFirstCenterLastPoints(List<Point<int>> points) {
    return [0, ..._getCenterPoint(points), ..._getLastPoint(points)];
  }

  List<int> _getLeftEyePoints(List<Point<int>> points) {
    return [..._getCenterPoint(points), 0];
  }

  List<int> _getRightEyePoints(List<Point<int>> points) {
    return [0, ..._getCenterPoint(points)];
  }
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

class RPSCustomPainter extends CustomPainter {
  final Color? borderColor;
  final Color? backgroundColor;
  final String? topText;
  final String? bottomText;

  RPSCustomPainter({
    this.borderColor,
    this.backgroundColor,
    this.topText,
    this.bottomText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Semi-transparent overlay
    Path path = Path();
    path.moveTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.close();

    double centerY = size.height * 0.45;
    double radiusX = size.width * 0.40;
    double radiusY = size.height * 0.23;

    // Add ellipse cutout
    path.addOval(Rect.fromCenter(
      center: Offset(size.width * 0.5, centerY),
      width: radiusX * 2,
      height: radiusY * 2,
    ));

    path.fillType = PathFillType.evenOdd;

    Paint paintFill = Paint()..style = PaintingStyle.fill;
    paintFill.color = backgroundColor ?? const Color.fromARGB(255, 0, 0, 0);
    canvas.drawPath(path, paintFill);

    // Draw ellipse stroke (background)
    Paint paintStroke0 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.03;
    paintStroke0.color = backgroundColor ?? const Color.fromARGB(255, 0, 0, 0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, centerY),
        width: radiusX * 2,
        height: radiusY * 2,
      ),
      paintStroke0,
    );

    // Draw ellipse stroke (border)
    Paint paintStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.015;
    paintStroke.color = borderColor ?? Colors.red;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, centerY),
        width: radiusX * 2,
        height: radiusY * 2,
      ),
      paintStroke,
    );

    // Draw top text
    if (topText != null && topText!.isNotEmpty) {
      final textPainterTop = TextPainter(
        text: TextSpan(
          text: topText,
          style: TextStyle(
            color: const Color.fromARGB(255, 26, 26, 26),
            fontSize: size.width * 0.05,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainterTop.layout();
      textPainterTop.paint(
        canvas,
        Offset(
          (size.width - textPainterTop.width) / 2,
          centerY - radiusY - size.height * 0.08,
        ),
      );
    }

    // Draw bottom text
    if (bottomText != null && bottomText!.isNotEmpty) {
      final textPainterBottom = TextPainter(
        text: TextSpan(
          text: bottomText,
          style: TextStyle(
            color: const Color.fromARGB(255, 26, 26, 26),
            fontSize: size.width * 0.045,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainterBottom.layout();
      textPainterBottom.paint(
        canvas,
        Offset(
          (size.width - textPainterBottom.width) / 2,
          centerY + radiusY + size.height * 0.03,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

/// Eye blink icon
class EyeBlinkWidget extends StatefulWidget {
  final String text;
  final double size;
  final Color color;
  final bool autoBlink;
  final Duration blinkInterval;
  final Duration blinkDuration;
  final VoidCallback? onTap;
  final bool initiallyBlinking;
  final bool hideEye;

  const EyeBlinkWidget({
    super.key,
    this.text = '',
    this.size = 30.0,
    this.color = const Color.fromARGB(255, 23, 23, 23),
    this.autoBlink = true,
    this.blinkInterval = const Duration(seconds: 2),
    this.blinkDuration = const Duration(milliseconds: 200),
    this.onTap,
    this.initiallyBlinking = false,
    this.hideEye = false,
  });

  @override
  State<EyeBlinkWidget> createState() => _EyeBlinkWidgetState();
}

class _EyeBlinkWidgetState extends State<EyeBlinkWidget> {
  bool _isBlinking = false;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _isBlinking = widget.initiallyBlinking;
    if (widget.autoBlink) {
      _startAutoBlink();
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(EyeBlinkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoBlink != oldWidget.autoBlink) {
      if (widget.autoBlink) {
        _startAutoBlink();
      } else {
        _blinkTimer?.cancel();
      }
    }
  }

  void _startAutoBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(widget.blinkInterval, (timer) {
      _blink();
    });
  }

  void _blink() {
    if (!mounted) return;

    setState(() {
      _isBlinking = true;
    });

    Future.delayed(widget.blinkDuration, () {
      if (mounted) {
        setState(() {
          _isBlinking = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _blink();
        widget.onTap?.call();
      },
      child: AnimatedSwitcher(
        duration: widget.blinkDuration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.hideEye)
              Icon(
                _isBlinking ? RemixIcons.eye_close_fill : RemixIcons.eye_fill,
                key: ValueKey(_isBlinking),
                size: widget.size,
                color: widget.color,
              ),
            if (!widget.hideEye) const SizedBox(width: 8),
            Text(widget.text,
                style: TextStyle(
                  color: widget.color,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.size * 0.6,
                )),
          ],
        ),
      ),
    );
  }
}
