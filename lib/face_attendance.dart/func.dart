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

Future<Uint8List> addTextWatermark(File imageFile, String watermarkText) async {
  final originalImage = img.decodeImage(await imageFile.readAsBytes());

  if (originalImage == null) return Uint8List(0);

  final x = 10;
  final y = originalImage.height - 60;
  final strokeColor = img.ColorRgba8(0, 0, 0, 200);
  final strokeWidth = 2;

  // Draw stroke in 4 cardinal directions
  img.drawString(originalImage, watermarkText,
      font: img.arial48, x: x - strokeWidth, y: y, color: strokeColor);
  img.drawString(originalImage, watermarkText,
      font: img.arial48, x: x + strokeWidth, y: y, color: strokeColor);
  img.drawString(originalImage, watermarkText,
      font: img.arial48, x: x, y: y - strokeWidth, color: strokeColor);
  img.drawString(originalImage, watermarkText,
      font: img.arial48, x: x, y: y + strokeWidth, color: strokeColor);

  // Draw main text
  img.drawString(
    originalImage,
    watermarkText,
    font: img.arial48,
    x: x,
    y: y,
    color: img.ColorRgba8(255, 255, 255, 255),
  );

  return Uint8List.fromList(img.encodePng(originalImage));
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
