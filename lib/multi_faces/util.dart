part of 'main.dart';

/// path, Size
Future<String> _getImageSizeFromAsset(String assetPath) async {
  final ByteData data = await rootBundle.load(assetPath);
  final Uint8List bytes = data.buffer.asUint8List();
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/${assetPath.split('/').last}');

  await file.writeAsBytes(bytes);

  return file.path;
}

/// Crop faces from image and save them
Future<List<String>> cropFacesFromImage(
  String imagePath,
  List<Face> faces,
) async {
  final ByteData data = await File(imagePath).readAsBytes().then(
    (bytes) => ByteData.sublistView(Uint8List.fromList(bytes)),
  );
  final Uint8List bytes = data.buffer.asUint8List();

  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frameInfo = await codec.getNextFrame();
  final ui.Image originalImage = frameInfo.image;

  final List<String> croppedFacePaths = [];
  final tempDir = await getTemporaryDirectory();

  for (int i = 0; i < faces.length; i++) {
    final face = faces[i];
    final boundingBox = face.boundingBox;

    // Add padding around face (optional, 20% padding)
    const padding = 0.2;
    final paddingX = boundingBox.width * padding;
    final paddingY = boundingBox.height * padding;

    final left = (boundingBox.left - paddingX)
        .clamp(0, originalImage.width.toDouble())
        .toInt();
    final top = (boundingBox.top - paddingY)
        .clamp(0, originalImage.height.toDouble())
        .toInt();
    final width = (boundingBox.width + paddingX * 2)
        .clamp(0, originalImage.width - left.toDouble())
        .toInt();
    final height = (boundingBox.height + paddingY * 2)
        .clamp(0, originalImage.height - top.toDouble())
        .toInt();

    // Crop the face
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImageRect(
      originalImage,
      Rect.fromLTWH(
        left.toDouble(),
        top.toDouble(),
        width.toDouble(),
        height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint(),
    );

    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(width, height);

    // Convert to bytes and save
    final byteData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final pngBytes = byteData!.buffer.asUint8List();
    final id = face.trackingId ?? 0;

    final file = File(
      '${tempDir.path}/$id-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(pngBytes);

    croppedFacePaths.add(file.path);
  }

  return croppedFacePaths;
}
