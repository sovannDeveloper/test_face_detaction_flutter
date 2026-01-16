part of 'main.dart';

Face? getSingleFace(List<Face>? faces) {
  if (faces == null || faces.isEmpty) return null;

  double maxWidth = 0;
  Face? selected;

  for (final face in faces) {
    final width = face.boundingBox.width;

    if (width > maxWidth) {
      maxWidth = width;
      selected = face;
    }
  }

  return selected;
}

Future<Uint8List> addImageWatermark(
    File originalFile, File watermarkFile) async {
  final original = img.decodeImage(await originalFile.readAsBytes());
  final watermark = img.decodeImage(await watermarkFile.readAsBytes());

  if (original == null || watermark == null) return Uint8List(0);

  final resizedWatermark = img.copyResize(watermark, width: 100);

  img.compositeImage(
    original,
    resizedWatermark,
    dstX: original.width - resizedWatermark.width - 10,
    dstY: original.height - resizedWatermark.height - 10,
  );

  return Uint8List.fromList(img.encodePng(original));
}

bool isFaceCentered(Face? face, Size imageSize, {double threshold = 0.07}) {
  if (face == null) return false;

  final boundingBox = face.boundingBox;

  final faceCenterX = boundingBox.left + boundingBox.width / 2;
  final faceCenterY = boundingBox.top + boundingBox.height / 2;

  final imageCenterX = imageSize.width / 2;
  final imageCenterY = imageSize.height / 2;

  final offsetX = (faceCenterX - imageCenterX).abs();
  final offsetY = (faceCenterY - imageCenterY).abs();

  final allowedOffsetX = imageSize.width * threshold;
  final allowedOffsetY = imageSize.height * threshold;

  return offsetX <= allowedOffsetX && offsetY <= allowedOffsetY;
}

bool isFaceLookingStraight(Face? face, {double angleThreshold = 10.0}) {
  if (face == null) return false;

  final eulerY = face.headEulerAngleY ?? 0;
  final eulerX = face.headEulerAngleX ?? 0;
  final eulerZ = face.headEulerAngleZ ?? 0;

  return eulerY.abs() <= angleThreshold &&
      eulerX.abs() <= angleThreshold &&
      eulerZ.abs() <= angleThreshold;
}

Future<Uint8List> addTextWatermark(File imageFile, String watermarkText,
    {int fontSize = 18}) async {
  final originalImage = img.decodeImage(await imageFile.readAsBytes());
  if (originalImage == null) return Uint8List(0);

  // Select font based on size
  final font = _selectFont(fontSize);

  const padding = 10;
  const strokeWidth = 2;
  final textColor = img.ColorRgba8(255, 255, 255, 255);
  final strokeColor = img.ColorRgba8(0, 0, 0, 200);

  // Max width for text (leave padding on both sides)
  final maxTextWidth = originalImage.width - (padding * 2);

  // Wrap text into lines
  final lines = _wrapText(watermarkText, font, maxTextWidth);

  // Calculate starting Y so text block sits above bottom
  final lineHeight = font.lineHeight;
  final totalTextHeight = lines.length * lineHeight;
  int y = originalImage.height - totalTextHeight - padding;

  for (final line in lines) {
    // Stroke (4 directions)
    img.drawString(originalImage, line,
        font: font, x: padding - strokeWidth, y: y, color: strokeColor);
    img.drawString(originalImage, line,
        font: font, x: padding + strokeWidth, y: y, color: strokeColor);
    img.drawString(originalImage, line,
        font: font, x: padding, y: y - strokeWidth, color: strokeColor);
    img.drawString(originalImage, line,
        font: font, x: padding, y: y + strokeWidth, color: strokeColor);

    // Main text
    img.drawString(originalImage, line,
        font: font, x: padding, y: y, color: textColor);

    y += lineHeight;
  }

  return Uint8List.fromList(img.encodePng(originalImage));
}

// Helper function to select appropriate font based on desired size
img.BitmapFont _selectFont(int fontSize) {
  if (fontSize <= 14) return img.arial14;
  if (fontSize <= 24) return img.arial24;
  if (fontSize <= 48) return img.arial48;
  return img.arial48; // Default to largest available
}

List<String> _wrapText(String text, img.BitmapFont font, int maxWidth) {
  final words = text.split(' ');
  final lines = <String>[];
  var currentLine = '';

  // Approximate average character width from the font's line height
  final avgCharWidth = font.lineHeight * 0.6;

  for (final word in words) {
    final testLine = currentLine.isEmpty ? word : '$currentLine $word';
    final testWidth = (testLine.length * avgCharWidth).round();

    if (testWidth <= maxWidth) {
      currentLine = testLine;
    } else {
      if (currentLine.isNotEmpty) {
        lines.add(currentLine);
      }
      currentLine = word;
    }
  }

  if (currentLine.isNotEmpty) {
    lines.add(currentLine);
  }

  return lines;
}

List<int> _actions = [];

bool isNoAction(Face? face) {
  if (face == null) return true;

  final contour = face.contours[FaceContourType.noseBottom];

  if (contour == null || contour.points.isEmpty) return true;

  final nosePoint = contour.points.first;
  _actions.add(nosePoint.y.toInt());

  if (_actions.length > 10) {
    _actions.removeAt(0);
  }

  print('--=> Actions: $_actions');

  final diffs = <int>[];
  for (int i = 1; i < _actions.length; i++) {
    diffs.add((_actions[i] - _actions[i - 1]).abs());
  }

  final avgDiff = diffs.reduce((a, b) => a + b) / diffs.length;

  return avgDiff < 2;
}
