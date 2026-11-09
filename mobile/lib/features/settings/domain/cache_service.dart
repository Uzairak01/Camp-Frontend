import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Interface for measuring and clearing temporary local cache.
abstract class CacheService {
  /// Returns the total bytes stored in the local cache.
  Future<int> getCacheSizeBytes();

  /// Deletes temporary cache files and returns the total bytes deleted.
  Future<int> clearCache();
}

/// Production implementation of [CacheService] operating on the device temporary directory.
class PlatformCacheService implements CacheService {
  const PlatformCacheService();

  @override
  Future<int> getCacheSizeBytes() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (!cacheDir.existsSync()) return 0;
      int total = 0;
      await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<int> clearCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (!cacheDir.existsSync()) return 0;
      int cleared = 0;
      final entities = cacheDir.listSync(followLinks: false);
      for (final entity in entities) {
        try {
          if (entity is File) {
            cleared += entity.lengthSync();
            entity.deleteSync();
          } else if (entity is Directory) {
            try {
              for (final sub in entity.listSync(recursive: true, followLinks: false)) {
                if (sub is File) cleared += sub.lengthSync();
              }
            } catch (_) {}
            entity.deleteSync(recursive: true);
          }
        } catch (_) {}
      }
      return cleared;
    } catch (_) {
      return 0;
    }
  }
}
