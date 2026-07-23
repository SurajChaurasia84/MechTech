import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;

class ImageCompressorService {
  /// Compresses an image file on the app side to a target size of ~50KB - 100KB
  /// without sacrificing visual quality on HD screens.
  static Future<File> compressImage(File file, {int targetMinKb = 50, int targetMaxKb = 100}) async {
    try {
      final originalSizeBytes = await file.length();
      final originalKb = originalSizeBytes / 1024;
      debugPrint('[ImageCompressor] Original image size: ${originalKb.toStringAsFixed(2)} KB');

      // If original image is already within target max range, return as is
      if (originalKb <= targetMaxKb) {
        debugPrint('[ImageCompressor] Image is already <= ${targetMaxKb}KB (${originalKb.toStringAsFixed(2)} KB). No compression needed.');
        return file;
      }

      final tempDir = await path_provider.getTemporaryDirectory();
      final fileName = p.basenameWithoutExtension(file.path);
      final extension = p.extension(file.path).toLowerCase();

      // Use JPEG for compressed uploads for maximum quality-to-size ratio
      CompressFormat format = CompressFormat.jpeg;
      String outExt = '.jpg';
      if (extension == '.webp') {
        format = CompressFormat.webp;
        outExt = '.webp';
      }

      int minWidth = 1280;
      int minHeight = 1280;
      int quality = 80;

      File currentFile = file;

      // Iterative compression loop (max 4 attempts) to hit ~50-100KB target
      for (int attempt = 0; attempt < 4; attempt++) {
        final targetPath = '${tempDir.path}/${fileName}_compressed_${attempt}_${DateTime.now().millisecondsSinceEpoch}$outExt';

        final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
          currentFile.path,
          targetPath,
          quality: quality,
          minWidth: minWidth,
          minHeight: minHeight,
          format: format,
        );

        if (compressedXFile == null) break;

        final compressedFile = File(compressedXFile.path);
        final compressedSizeKb = (await compressedFile.length()) / 1024;
        debugPrint('[ImageCompressor] Attempt ${attempt + 1}: output size = ${compressedSizeKb.toStringAsFixed(2)} KB (quality: $quality, maxDim: $minWidth)');

        if (compressedSizeKb <= targetMaxKb) {
          return compressedFile;
        }

        currentFile = compressedFile;
        // Step down quality or resolution dynamically
        if (quality > 60) {
          quality -= 12;
        } else {
          minWidth = (minWidth * 0.8).round();
          minHeight = (minHeight * 0.8).round();
        }
      }

      return currentFile;
    } catch (e) {
      debugPrint('[ImageCompressor] Compression error: $e. Returning original file.');
      return file;
    }
  }
}
