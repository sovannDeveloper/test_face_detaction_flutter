part of 'main.dart';

Future<List<Uint8List>> cropFaces(
  String imagePath, {
  List<Face> faces = const [],
  bool flipHorizontal = false,
}) async {
  if (faces.isEmpty) {
    final inputImage = InputImage.fromFilePath(imagePath);
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: false,
        enableContours: false,
        enableClassification: false,
        enableTracking: true,
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    faces = await detector
        .processImage(inputImage)
        .timeout(const Duration(seconds: 2), onTimeout: () => <Face>[]);
    faces.sort((a, b) => (a.trackingId ?? 0).compareTo(b.trackingId ?? 0));
  }

  final ByteData data = await File(imagePath).readAsBytes().then(
    (bytes) => ByteData.sublistView(Uint8List.fromList(bytes)),
  );
  final Uint8List bytes = data.buffer.asUint8List();
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frameInfo = await codec.getNextFrame();
  final ui.Image originalImage = frameInfo.image;
  final List<Uint8List> croppedFacePaths = [];

  for (int i = 0; i < faces.length; i++) {
    final face = faces[i];
    final boundingBox = face.boundingBox;

    const padding = 0;
    final paddingX = boundingBox.width * padding;
    final paddingY = boundingBox.height * padding;

    final left = (boundingBox.left - paddingX).clamp(
      0,
      originalImage.width.toDouble(),
    );
    final top = (boundingBox.top - paddingY).clamp(
      0,
      originalImage.height.toDouble(),
    );
    final width = (boundingBox.width + paddingX * 2).clamp(
      0,
      originalImage.width - left,
    );
    final height = (boundingBox.height + paddingY * 2).clamp(
      0,
      originalImage.height - top,
    );

    final squareSize = (width < height ? width : height).toDouble();
    final centerX = left + width / 2;
    final centerY = top + height / 2;

    final squareLeft = (centerX - squareSize / 2)
        .clamp(0, originalImage.width.toDouble() - squareSize)
        .toDouble();
    final squareTop = (centerY - squareSize / 2)
        .clamp(0, originalImage.height.toDouble() - squareSize)
        .toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    if (flipHorizontal) {
      canvas.translate(squareSize, 0);
      canvas.scale(-1, 1);
    }

    canvas.drawImageRect(
      originalImage,
      Rect.fromLTWH(squareLeft, squareTop, squareSize, squareSize),
      Rect.fromLTWH(0, 0, squareSize, squareSize),
      Paint(),
    );

    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(
      squareSize.toInt(),
      squareSize.toInt(),
    );
    final byteData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final pngBytes = byteData!.buffer.asUint8List();

    croppedFacePaths.add(pngBytes);
  }

  return croppedFacePaths;
}
