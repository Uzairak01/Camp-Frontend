import 'dart:convert';

import '../../features/garage/domain/bike_model.dart';
import '../storage/local_store.dart';
import 'bike_repository.dart';

class BikeRepositoryLocal implements BikeRepository {
  BikeRepositoryLocal([LocalStore? store]) : _explicitStore = store;

  final LocalStore? _explicitStore;
  LocalStore get _store => _explicitStore ?? LocalStore.instance;

  @override
  Future<bool> isFirstRun() => _store.isFirstRun();

  @override
  Future<void> markFirstRunCompleted() => _store.markFirstRunCompleted();

  /// Known IDs of legacy seeded demo bikes.
  static const Set<String> seededBikeIds = {
    'bike-bmw-1250',
    'bike-rebel-500',
  };

  /// Determines whether a bike record matches the legacy demo seed fleet.
  /// Matches strictly by exact seed ID, never by nickname, plate, or vin alone.
  static bool isSeededBike(Bike bike) {
    return seededBikeIds.contains(bike.id.trim());
  }

  @override
  Future<List<Bike>> loadBikes() async {
    final isFirst = await _store.isFirstRun();
    if (!isFirst) {
      final schemaVer = await _store.getSchemaVersion();
      if (schemaVer == null || schemaVer > LocalStore.currentSchemaVersion) {
        throw const FormatException('Incompatible schema version');
      }
    }

    final json = await _store.readJson(LocalStore.keyGarageBikes);
    if (json == null || json is! List) {
      if (!isFirst) {
        throw const FormatException('Corrupted garage data');
      }
      return [];
    }

    bool needsMigration = false;
    final bikes = <Bike>[];

    for (int i = 0; i < json.length; i++) {
      final raw = json[i];
      if (raw is Map) {
        final map = raw is Map<String, dynamic> ? raw : raw.cast<String, dynamic>();
        final bike = Bike.fromJson(map);

        // One-time cleanup: remove saved bikes matching the seeded IDs or exact attributes.
        // Bikes the rider entered are never touched.
        if (isSeededBike(bike)) {
          needsMigration = true;
          continue;
        }

        if (bike.id.isEmpty || map['id'] == null || (map['id'] as String).isEmpty) {
          needsMigration = true;
          bikes.add(bike.copyWith(id: 'bike_${DateTime.now().millisecondsSinceEpoch}_$i'));
        } else {
          if (map['createdAt'] == null || map['updatedAt'] == null) {
            needsMigration = true;
          }
          bikes.add(bike);
        }
      }
    }

    if (needsMigration) {
      await saveBikes(bikes);
      final activeId = await loadActiveBikeId();
      if (activeId != null && seededBikeIds.contains(activeId)) {
        await saveActiveBikeId(bikes.isNotEmpty ? bikes.first.id : null);
      }
    }

    return bikes;
  }

  @override
  Future<void> saveBikes(List<Bike> bikes) async {
    final now = DateTime.now().toUtc();
    final updated = bikes.map((b) {
      return b.copyWith(
        id: b.effectiveId,
        createdAt: b.effectiveCreatedAt,
        updatedAt: now,
      );
    }).toList();

    await _store.writeJson(
      LocalStore.keyGarageBikes,
      updated.map((b) => b.toJson()).toList(),
    );
  }

  @override
  Future<String?> loadActiveBikeId() async {
    final raw = await _store.readString(LocalStore.keyActiveBikeId);
    if (raw == null || raw.isEmpty) return null;
    String activeId = raw;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is String) activeId = decoded;
    } catch (_) {}

    if (seededBikeIds.contains(activeId)) {
      await saveActiveBikeId(null);
      return null;
    }
    return activeId;
  }

  @override
  Future<void> saveActiveBikeId(String? id) async {
    if (id == null) {
      await _store.remove(LocalStore.keyActiveBikeId);
    } else {
      await _store.writeString(LocalStore.keyActiveBikeId, id);
    }
  }

  @override
  Future<void> deleteBike(String id) async {
    final current = await loadBikes();
    final filtered = current.where((b) => b.effectiveId != id).toList();
    await saveBikes(filtered);

    final activeId = await loadActiveBikeId();
    if (activeId == id) {
      await saveActiveBikeId(filtered.isNotEmpty ? filtered.first.effectiveId : null);
    }
  }

  @override
  Future<void> clear() async {
    await _store.writeJson(LocalStore.keyGarageBikes, null);
    await _store.writeJson(LocalStore.keyActiveBikeId, null);
  }

  @override
  Future<void> flush() async {
    await _store.flush();
  }
}

BikeRepository resolveBikeRepository(dynamic source, [BikeRepository? fallback]) {
  if (source is BikeRepository) return source;
  if (source is LocalStore) return BikeRepositoryLocal(source);
  return fallback ?? BikeRepositoryLocal();
}
