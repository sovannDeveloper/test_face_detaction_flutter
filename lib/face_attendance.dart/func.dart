part of 'main.dart';

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
