

part of 'main.dart';

/// Utility class for managing images in the app's document directory
class ImageStorageUtil {
  static final ImagePicker _picker = ImagePicker();

  // Folder name for storing images
  static const String _imageFolderName = 'images';

  /// Get the images directory path
  static Future<String> get _imageDirectory async {
    final directory = await getApplicationDocumentsDirectory();
    return path.join(directory.path, _imageFolderName);
  }

  /// Ensure the images directory exists
  static Future<Directory> _ensureImageDirectory() async {
    final imageDir = await _imageDirectory;
    final Directory dir = Directory(imageDir);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  /// Pick image from gallery
  static Future<XFile?> pickFromGallery({
    int imageQuality = 100,
    double? maxWidth,
    double? maxHeight,
  }) async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Pick image from camera
  static Future<XFile?> pickFromCamera({
    int imageQuality = 100,
    double? maxWidth,
    double? maxHeight,
  }) async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      return null;
    }
  }

  /// Pick multiple images from gallery
  static Future<List<XFile>> pickMultipleImages({
    int imageQuality = 100,
    double? maxWidth,
    double? maxHeight,
  }) async {
    try {
      return await _picker.pickMultiImage(
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
      return [];
    }
  }

  /// Save image from XFile to document directory
  static Future<String?> saveImage(XFile image,
      {String? customFileName}) async {
    try {
      await _ensureImageDirectory();
      final imageDir = await _imageDirectory;

      // Generate filename
      final String fileName = customFileName ??
          'image_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';

      final String savePath = path.join(imageDir, fileName);

      // Copy file
      final File imageFile = File(image.path);
      await imageFile.copy(savePath);

      debugPrint('Image saved to: $savePath');
      return savePath;
    } catch (e) {
      debugPrint('Error saving image: $e');
      return null;
    }
  }

  /// Save image from bytes to document directory
  static Future<String?> saveImageFromBytes(
    Uint8List bytes, {
    String? fileName,
    String extension = '.jpg',
  }) async {
    try {
      await _ensureImageDirectory();
      final imageDir = await _imageDirectory;

      final String finalFileName = fileName ??
          'image_${DateTime.now().millisecondsSinceEpoch}$extension';

      final String savePath = path.join(imageDir, finalFileName);

      // Write bytes to file
      final File file = File(savePath);
      await file.writeAsBytes(bytes);

      debugPrint('Image saved from bytes to: $savePath');
      return savePath;
    } catch (e) {
      debugPrint('Error saving image from bytes: $e');
      return null;
    }
  }

  /// Save image from File to document directory
  static Future<String?> saveImageFromFile(File file,
      {String? customFileName}) async {
    try {
      await _ensureImageDirectory();
      final imageDir = await _imageDirectory;

      final String fileName = customFileName ??
          'image_${DateTime.now().millisecondsSinceEpoch}${path.extension(file.path)}';

      final String savePath = path.join(imageDir, fileName);

      // Copy file
      await file.copy(savePath);

      debugPrint('Image file saved to: $savePath');
      return savePath;
    } catch (e) {
      debugPrint('Error saving image file: $e');
      return null;
    }
  }

  /// Load all images from document directory
  static Future<List<File>> loadAllImages() async {
    try {
      final imageDir = await _imageDirectory;
      final Directory dir = Directory(imageDir);

      if (!await dir.exists()) {
        debugPrint('Images directory does not exist');
        return [];
      }

      final List<FileSystemEntity> files = dir.listSync();

      final List<File> imageFiles = files
          .where((file) => file is File)
          .map((file) => file as File)
          .where((file) => _isImageFile(file.path))
          .toList();

      // Sort by modification date (newest first)
      imageFiles
          .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      debugPrint('Found ${imageFiles.length} images');
      return imageFiles;
    } catch (e) {
      debugPrint('Error loading images: $e');
      return [];
    }
  }

  /// Load image by filename
  static Future<File?> loadImageByName(String fileName) async {
    try {
      final imageDir = await _imageDirectory;
      final String imagePath = path.join(imageDir, fileName);
      final File imageFile = File(imagePath);

      if (await imageFile.exists()) {
        return imageFile;
      } else {
        debugPrint('Image not found: $imagePath');
        return null;
      }
    } catch (e) {
      debugPrint('Error loading image: $e');
      return null;
    }
  }

  /// Load image by full path
  static Future<File?> loadImageByPath(String imagePath) async {
    try {
      final File imageFile = File(imagePath);

      if (await imageFile.exists()) {
        return imageFile;
      } else {
        debugPrint('Image not found: $imagePath');
        return null;
      }
    } catch (e) {
      debugPrint('Error loading image: $e');
      return null;
    }
  }

  /// Delete a specific image
  static Future<bool> deleteImage(String imagePath) async {
    try {
      final File file = File(imagePath);

      if (await file.exists()) {
        await file.delete();
        debugPrint('Image deleted: $imagePath');
        return true;
      } else {
        debugPrint('Image not found: $imagePath');
        return false;
      }
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }

  /// Delete image by filename
  static Future<bool> deleteImageByName(String fileName) async {
    try {
      final imageDir = await _imageDirectory;
      final String imagePath = path.join(imageDir, fileName);
      return await deleteImage(imagePath);
    } catch (e) {
      debugPrint('Error deleting image by name: $e');
      return false;
    }
  }

  /// Delete multiple images
  static Future<int> deleteMultipleImages(List<String> imagePaths) async {
    int deletedCount = 0;

    for (String imagePath in imagePaths) {
      final bool deleted = await deleteImage(imagePath);
      if (deleted) deletedCount++;
    }

    debugPrint('Deleted $deletedCount of ${imagePaths.length} images');
    return deletedCount;
  }

  /// Clear all images from the directory
  static Future<bool> clearAllImages() async {
    try {
      final imageDir = await _imageDirectory;
      final Directory dir = Directory(imageDir);

      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint('All images cleared');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error clearing images: $e');
      return false;
    }
  }

  /// Get count of stored images
  static Future<int> getImageCount() async {
    final images = await loadAllImages();
    return images.length;
  }

  /// Get total size of all images in bytes
  static Future<int> getTotalImagesSize() async {
    try {
      final images = await loadAllImages();
      int totalSize = 0;

      for (File image in images) {
        totalSize += await image.length();
      }

      debugPrint('Total images size: ${_formatBytes(totalSize)}');
      return totalSize;
    } catch (e) {
      debugPrint('Error calculating images size: $e');
      return 0;
    }
  }

  /// Check if a file is an image based on extension
  static bool _isImageFile(String filePath) {
    final String ext = path.extension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext);
  }

  /// Format bytes to human-readable string
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Get image file size
  static Future<int> getImageSize(String imagePath) async {
    try {
      final File file = File(imagePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting image size: $e');
      return 0;
    }
  }

  /// Get formatted image file size
  static Future<String> getFormattedImageSize(String imagePath) async {
    final size = await getImageSize(imagePath);
    return _formatBytes(size);
  }

  /// Check if image exists
  static Future<bool> imageExists(String imagePath) async {
    try {
      final File file = File(imagePath);
      return await file.exists();
    } catch (e) {
      debugPrint('Error checking image existence: $e');
      return false;
    }
  }

  /// Rename image file
  static Future<String?> renameImage(String oldPath, String newFileName) async {
    try {
      final File oldFile = File(oldPath);

      if (!await oldFile.exists()) {
        debugPrint('Image not found: $oldPath');
        return null;
      }

      final String directory = path.dirname(oldPath);
      final String newPath = path.join(directory, newFileName);

      final File newFile = await oldFile.rename(newPath);
      debugPrint('Image renamed from $oldPath to $newPath');

      return newFile.path;
    } catch (e) {
      debugPrint('Error renaming image: $e');
      return null;
    }
  }

  /// Get image metadata
  static Future<Map<String, dynamic>> getImageMetadata(String imagePath) async {
    try {
      final File file = File(imagePath);

      if (!await file.exists()) {
        return {};
      }

      final stat = await file.stat();
      final size = await file.length();

      return {
        'path': imagePath,
        'fileName': path.basename(imagePath),
        'size': size,
        'formattedSize': _formatBytes(size),
        'modified': stat.modified,
        'accessed': stat.accessed,
        'extension': path.extension(imagePath),
      };
    } catch (e) {
      debugPrint('Error getting image metadata: $e');
      return {};
    }
  }

  /// Copy image to another location
  static Future<String?> copyImage(
      String sourcePath, String destinationPath) async {
    try {
      final File sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        debugPrint('Source image not found: $sourcePath');
        return null;
      }

      final File copiedFile = await sourceFile.copy(destinationPath);
      debugPrint('Image copied from $sourcePath to $destinationPath');

      return copiedFile.path;
    } catch (e) {
      debugPrint('Error copying image: $e');
      return null;
    }
  }

  /// Move image to another location
  static Future<String?> moveImage(
      String sourcePath, String destinationPath) async {
    try {
      final File sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        debugPrint('Source image not found: $sourcePath');
        return null;
      }

      final File movedFile = await sourceFile.rename(destinationPath);
      debugPrint('Image moved from $sourcePath to $destinationPath');

      return movedFile.path;
    } catch (e) {
      debugPrint('Error moving image: $e');
      return null;
    }
  }

  /// Filter images by date range
  static Future<List<File>> getImagesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final allImages = await loadAllImages();

      return allImages.where((file) {
        final modified = file.lastModifiedSync();
        return modified.isAfter(startDate) && modified.isBefore(endDate);
      }).toList();
    } catch (e) {
      debugPrint('Error filtering images by date: $e');
      return [];
    }
  }

  /// Get images modified today
  static Future<List<File>> getTodayImages() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return await getImagesByDateRange(today, tomorrow);
  }

  /// Get oldest images
  static Future<List<File>> getOldestImages({int limit = 10}) async {
    try {
      final images = await loadAllImages();

      // Sort oldest first
      images
          .sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

      return images.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting oldest images: $e');
      return [];
    }
  }

  /// Get newest images
  static Future<List<File>> getNewestImages({int limit = 10}) async {
    try {
      final images = await loadAllImages();

      // Already sorted newest first in loadAllImages
      return images.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting newest images: $e');
      return [];
    }
  }
}
