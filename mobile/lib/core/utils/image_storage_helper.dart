import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Helper for copying camera/gallery photos into persistent application documents storage.
Future<String> persistBikePhoto(String originalPath) async {
  try {
    if (originalPath.isEmpty || originalPath.startsWith('assets/')) {
      return originalPath;
    }
    final file = File(originalPath);
    if (!await file.exists()) return originalPath;

    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/bike_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    // If already in bike_photos, return as is
    if (originalPath.contains(photosDir.path)) {
      return originalPath;
    }

    final ext = originalPath.split('.').last;
    final newPath =
        '${photosDir.path}/bike_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final saved = await file.copy(newPath);
    return saved.path;
  } catch (_) {
    return originalPath;
  }
}
