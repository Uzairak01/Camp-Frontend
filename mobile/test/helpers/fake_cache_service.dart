import 'package:camp/features/settings/domain/cache_service.dart';

/// Test fake for [CacheService] that operates entirely in memory without file I/O.
class FakeCacheService implements CacheService {
  FakeCacheService({this.sizeBytes = 0});

  int sizeBytes;
  bool cleared = false;

  @override
  Future<int> getCacheSizeBytes() async => sizeBytes;

  @override
  Future<int> clearCache() async {
    final clearedBytes = sizeBytes;
    sizeBytes = 0;
    cleared = true;
    return clearedBytes;
  }
}
