import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class ImageUtil {
  ImageUtil._();

  /// YUV420 to RGB conversion - OPTIMIZED
  static img.Image _convertYUV420(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final img.Image imgImage = img.Image(width: width, height: height);

    final Uint8List yPlane = image.planes[0].bytes;
    final Uint8List uPlane = image.planes[1].bytes;
    final Uint8List vPlane = image.planes[2].bytes;

    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    // Pre-calculate values for better performance
    for (int h = 0; h < height; h++) {
      for (int w = 0; w < width; w++) {
        final int uvIndex = uvPixelStride * (w >> 1) + uvRowStride * (h >> 1);
        final int index = h * width + w;

        final int y = yPlane[index];
        final int u = uPlane[uvIndex];
        final int v = vPlane[uvIndex];

        // Optimized YUV to RGB conversion
        final int c = y - 16;
        final int d = u - 128;
        final int e = v - 128;

        final int r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
        final int g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
        final int b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);

        imgImage.setPixelRgb(w, h, r, g, b);
      }
    }

    return imgImage;
  }

  /// BGRA8888 to RGB conversion - OPTIMIZED
  static img.Image _convertBGRA8888(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final img.Image imgImage = img.Image(width: width, height: height);
    final Uint8List bytes = image.planes[0].bytes;

    for (int h = 0; h < height; h++) {
      final int rowStart = h * width * 4;
      for (int w = 0; w < width; w++) {
        final int index = rowStart + (w * 4);

        imgImage.setPixelRgba(
          w, h,
          bytes[index + 2], // R
          bytes[index + 1], // G
          bytes[index], // B
          bytes[index + 3], // A
        );
      }
    }

    return imgImage;
  }

  /// NV21 to RGB conversion - OPTIMIZED
  static img.Image _convertNV21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final img.Image imgImage = img.Image(width: width, height: height);

    final Uint8List yPlane = image.planes[0].bytes;
    final Uint8List uvPlane = image.planes[1].bytes;
    final int uvRowStride = image.planes[1].bytesPerRow;

    for (int h = 0; h < height; h++) {
      for (int w = 0; w < width; w++) {
        final int uvIndex = (h >> 1) * uvRowStride + (w >> 1) * 2;
        final int index = h * width + w;

        final int y = yPlane[index];
        final int v = uvPlane[uvIndex];
        final int u = uvPlane[uvIndex + 1];

        // Optimized NV21 to RGB
        final int c = y - 16;
        final int d = u - 128;
        final int e = v - 128;

        final int r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
        final int g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
        final int b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);

        imgImage.setPixelRgb(w, h, r, g, b);
      }
    }

    return imgImage;
  }

  /// Convert CameraImage to img.Image - FAST
  static img.Image? convertCameraImageToImg(CameraImage image) {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888(image);
      } else if (image.format.group == ImageFormatGroup.nv21) {
        return _convertNV21(image);
      } else if (image.format.group == ImageFormatGroup.jpeg) {
        return img.decodeJpg(image.planes[0].bytes);
      }
    } catch (e) {
      print('Error converting image: $e');
    }
    return null;
  }

  /// Convert with rotation - FAST (no isolate overhead)
  static img.Image? convertCameraImageToImgWithRotation(
    CameraImage image,
    InputImageRotation rotation,
  ) {
    try {
      img.Image? convertedImage = convertCameraImageToImg(image);
      if (convertedImage == null) return null;

      // Only rotate if needed
      if (rotation == InputImageRotation.rotation0deg) {
        return convertedImage;
      }

      return rotateImage(convertedImage, rotation);
    } catch (e) {
      print('Error converting image with rotation: $e');
    }
    return null;
  }

  /// Downsample image for faster processing
  static img.Image? convertCameraImageToImgDownsampled(
    CameraImage image, {
    int? maxWidth,
    int? maxHeight,
  }) {
    try {
      img.Image? convertedImage = convertCameraImageToImg(image);
      if (convertedImage == null) return null;

      // Downsample if size is specified
      if (maxWidth != null || maxHeight != null) {
        return img.copyResize(
          convertedImage,
          width: maxWidth,
          height: maxHeight,
          maintainAspect: true,
        );
      }

      return convertedImage;
    } catch (e) {
      print('Error converting downsampled image: $e');
    }
    return null;
  }

  /// Convert with rotation AND downsampling - FASTEST for recognition
  static img.Image? convertForRecognition(
    CameraImage image,
    InputImageRotation rotation, {
    int maxSize = 640, // Smaller = faster
  }) {
    try {
      // Convert
      img.Image? convertedImage = convertCameraImageToImg(image);
      if (convertedImage == null) return null;

      // Rotate if needed
      if (rotation != InputImageRotation.rotation0deg) {
        convertedImage = rotateImage(convertedImage, rotation);
      }

      // Downsample for speed
      if (convertedImage.width > maxSize || convertedImage.height > maxSize) {
        convertedImage = img.copyResize(
          convertedImage,
          width: convertedImage.width > convertedImage.height ? maxSize : null,
          height: convertedImage.height > convertedImage.width ? maxSize : null,
          maintainAspect: true,
        );
      }

      return convertedImage;
    } catch (e) {
      print('Error in convertForRecognition: $e');
    }
    return null;
  }

  /// Rotate image based on InputImageRotation
  static img.Image rotateImage(
    img.Image image,
    InputImageRotation rotation,
  ) {
    switch (rotation) {
      case InputImageRotation.rotation0deg:
        return image;
      case InputImageRotation.rotation90deg:
        return img.copyRotate(image, angle: 90);
      case InputImageRotation.rotation180deg:
        return img.copyRotate(image, angle: 180);
      case InputImageRotation.rotation270deg:
        return img.copyRotate(image, angle: 270);
    }
  }

  /// Get rotation angle from InputImageRotation
  static int getRotationAngle(InputImageRotation rotation) {
    switch (rotation) {
      case InputImageRotation.rotation0deg:
        return 0;
      case InputImageRotation.rotation90deg:
        return 90;
      case InputImageRotation.rotation180deg:
        return 180;
      case InputImageRotation.rotation270deg:
        return 270;
    }
  }

  /// Convert to bytes - FAST
  static Uint8List? convertCameraImageToByte(
    CameraImage cameraImage, {
    int quality = 85,
  }) {
    final image = convertCameraImageToImg(cameraImage);
    if (image == null) return null;
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  /// Convert to bytes with rotation - FAST
  static Uint8List? convertCameraImageToByteWithRotation(
    CameraImage cameraImage,
    InputImageRotation rotation, {
    int quality = 85,
  }) {
    final image = convertCameraImageToImgWithRotation(cameraImage, rotation);
    if (image == null) return null;
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  /// Convert with all options - OPTIMIZED
  static Uint8List? convertCameraImageToByteWithOptions(
    CameraImage cameraImage, {
    InputImageRotation? rotation,
    int quality = 85,
    int? maxSize,
  }) {
    try {
      img.Image? image = convertCameraImageToImg(cameraImage);
      if (image == null) return null;

      // Rotate if specified
      if (rotation != null && rotation != InputImageRotation.rotation0deg) {
        image = rotateImage(image, rotation);
      }

      // Downsample if specified
      if (maxSize != null &&
          (image.width > maxSize || image.height > maxSize)) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? maxSize : null,
          height: image.height > image.width ? maxSize : null,
          maintainAspect: true,
        );
      }

      return Uint8List.fromList(img.encodeJpg(image, quality: quality));
    } catch (e) {
      print('Error in convertCameraImageToByteWithOptions: $e');
      return null;
    }
  }

  /// Test to verify it's color
  static void testImageColor(img.Image testImage) {
    int redSum = 0, greenSum = 0, blueSum = 0;

    for (int y = 0; y < testImage.height; y++) {
      for (int x = 0; x < testImage.width; x++) {
        final pixel = testImage.getPixel(x, y);
        redSum += pixel.r.toInt();
        greenSum += pixel.g.toInt();
        blueSum += pixel.b.toInt();
      }
    }

    final totalPixels = testImage.width * testImage.height;
    print('Average R: ${redSum / totalPixels}');
    print('Average G: ${greenSum / totalPixels}');
    print('Average B: ${blueSum / totalPixels}');

    if ((redSum - greenSum).abs() < totalPixels * 5 &&
        (greenSum - blueSum).abs() < totalPixels * 5) {
      print('⚠️ WARNING: Image appears to be grayscale!');
    } else {
      print('✅ Image is full color');
    }
  }
}
