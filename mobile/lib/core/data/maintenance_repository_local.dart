import '../../features/maintenance/domain/maintenance_item_model.dart';
import '../../features/maintenance/domain/service_schedule_item.dart';
import '../storage/local_store.dart';
import 'maintenance_repository.dart';

class MaintenanceRepositoryLocal implements MaintenanceRepository {
  MaintenanceRepositoryLocal([LocalStore? store]) : _explicitStore = store;

  final LocalStore? _explicitStore;
  LocalStore get _store => _explicitStore ?? LocalStore.instance;

  /// Known IDs of legacy seeded demo maintenance items.
  static const Set<String> seededMaintenanceIds = {
    'maint-1',
    'maint-2',
    'maint-3',
    'maint-4',
    'maint-5',
  };

  /// Determines whether a maintenance item matches the legacy demo seed records.
  /// Matches strictly by exact seed ID, never by item name alone.
  /// A real maintenance item named "Rear Brake Pad Replacement" or "Engine Oil & Filter"
  /// entered by the rider must survive.
  static bool isSeededMaintenanceItem(MaintenanceItem item) {
    return seededMaintenanceIds.contains(item.id.trim());
  }

  @override
  Future<List<MaintenanceItem>> loadMaintenanceItems() async {
    final json = await _store.readJson(LocalStore.keyMaintenanceItems);
    if (json is! List) {
      return [];
    }

    bool needsMigration = false;
    final items = <MaintenanceItem>[];

    for (int i = 0; i < json.length; i++) {
      final raw = json[i];
      if (raw is Map) {
        final map = raw is Map<String, dynamic> ? raw : raw.cast<String, dynamic>();
        final item = MaintenanceItem.fromJson(map);

        // One-time cleanup: remove saved maintenance items with the seeded IDs or exact names.
        // Items the rider entered are never touched.
        if (isSeededMaintenanceItem(item)) {
          needsMigration = true;
          continue;
        }

        if (item.id.isEmpty || map['id'] == null || (map['id'] as String).isEmpty) {
          needsMigration = true;
          items.add(item.copyWith(id: 'maint_${DateTime.now().millisecondsSinceEpoch}_$i'));
        } else {
          if (map['createdAt'] == null || map['updatedAt'] == null) {
            needsMigration = true;
          }
          items.add(item);
        }
      }
    }

    if (needsMigration) {
      await saveMaintenanceItems(items);
    }

    return items;
  }

  @override
  Future<void> saveMaintenanceItems(List<MaintenanceItem> items) async {
    final now = DateTime.now().toUtc();
    final updated = items.map((item) {
      return item.copyWith(
        id: item.effectiveId,
        createdAt: item.effectiveCreatedAt,
        updatedAt: now,
      );
    }).toList();

    await _store.writeJson(
      LocalStore.keyMaintenanceItems,
      updated.map((i) => i.toJson()).toList(),
    );
  }

  @override
  Future<void> deleteMaintenanceItem(String id) async {
    final current = await loadMaintenanceItems();
    final filtered = current.where((item) => item.effectiveId != id).toList();
    await saveMaintenanceItems(filtered);
  }

  @override
  Future<List<ServiceScheduleItem>> loadServiceSchedule(String bikeId) async {
    final json = await _store.readJson(LocalStore.keyServiceSchedule);
    if (json is! Map) return [];
    final list = json[bikeId];
    if (list is! List) return [];
    return list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => ServiceScheduleItem.fromJson(
            Map<String, dynamic>.from(m)))
        .toList();
  }

  @override
  Future<void> saveServiceSchedule(
      String bikeId, List<ServiceScheduleItem> items) async {
    final raw = await _store.readJson(LocalStore.keyServiceSchedule);
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final now = DateTime.now().toUtc();
    final updated = items.map((ServiceScheduleItem item) {
      return item.copyWith(
        id: item.effectiveId,
        createdAt: item.effectiveCreatedAt,
        updatedAt: now,
      );
    }).toList();
    map[bikeId] = updated.map((ServiceScheduleItem i) => i.toJson()).toList();
    await _store.writeJson(LocalStore.keyServiceSchedule, map);
  }

  @override
  Future<bool> loadHarshConditions(String bikeId) async {
    final json = await _store.readJson(LocalStore.keyHarshConditions);
    if (json is Map && json[bikeId] is bool) {
      return json[bikeId] as bool;
    }
    return false;
  }

  @override
  Future<void> saveHarshConditions(String bikeId, bool isHarsh) async {
    final raw = await _store.readJson(LocalStore.keyHarshConditions);
    final map = raw is Map
        ? (raw is Map<String, dynamic> ? raw : raw.cast<String, dynamic>())
        : <String, dynamic>{};
    map[bikeId] = isHarsh;
    await _store.writeJson(LocalStore.keyHarshConditions, map);
  }

  @override
  Future<void> deleteServiceSchedule(String bikeId) async {
    final raw = await _store.readJson(LocalStore.keyServiceSchedule);
    if (raw is Map) {
      final map =
          raw is Map<String, dynamic> ? raw : raw.cast<String, dynamic>();
      map.remove(bikeId);
      await _store.writeJson(LocalStore.keyServiceSchedule, map);
    }
  }

  @override
  Future<Map<String, dynamic>?> loadJettingBaseline([String? bikeId]) async {
    final json = await _store.readJson(LocalStore.keyJettingBaseline);
    if (json is! Map) return null;
    final map = json is Map<String, dynamic> ? json : json.cast<String, dynamic>();
    if (bikeId != null && bikeId.isNotEmpty) {
      final bikeData = map[bikeId];
      if (bikeData is Map) {
        return bikeData is Map<String, dynamic>
            ? bikeData
            : bikeData.cast<String, dynamic>();
      }
      return null;
    }
    return map;
  }

  @override
  Future<void> saveJettingBaseline(Map<String, dynamic>? baseline, [String? bikeId]) async {
    if (bikeId != null && bikeId.isNotEmpty) {
      final raw = await _store.readJson(LocalStore.keyJettingBaseline);
      final map = raw is Map
          ? (raw is Map<String, dynamic>
              ? Map<String, dynamic>.from(raw)
              : raw.cast<String, dynamic>())
          : <String, dynamic>{};
      if (baseline != null) {
        map[bikeId] = baseline;
      } else {
        map.remove(bikeId);
      }
      await _store.writeJson(LocalStore.keyJettingBaseline, map);
    } else {
      await _store.writeJson(LocalStore.keyJettingBaseline, baseline);
    }
  }

  @override
  Future<Map<String, bool>> loadChecklist([String? bikeId]) async {
    final json = await _store.readJson(LocalStore.keyChecklist);
    if (json is! Map) return {};
    final map = json is Map<String, dynamic> ? json : json.cast<String, dynamic>();
    if (bikeId != null && bikeId.isNotEmpty) {
      final bikeData = map[bikeId];
      if (bikeData is Map) {
        final items = bikeData['items'];
        if (items is Map) {
          return items.map((k, v) => MapEntry(k.toString(), v == true));
        }
        return bikeData.map((k, v) => MapEntry(k.toString(), v == true));
      }
      return {};
    }
    return map.map((key, value) => MapEntry(key.toString(), value == true));
  }

  @override
  Future<DateTime?> loadChecklistLastChecked([String? bikeId]) async {
    final json = await _store.readJson(LocalStore.keyChecklist);
    if (json is! Map) return null;
    final map = json is Map<String, dynamic> ? json : json.cast<String, dynamic>();
    if (bikeId != null && bikeId.isNotEmpty) {
      final bikeData = map[bikeId];
      if (bikeData is Map && bikeData['lastChecked'] is String) {
        return DateTime.tryParse(bikeData['lastChecked'] as String)?.toUtc();
      }
    } else if (map['lastChecked'] is String) {
      return DateTime.tryParse(map['lastChecked'] as String)?.toUtc();
    }
    return null;
  }

  @override
  Future<void> saveChecklist(Map<String, bool> checklist, {String? bikeId, DateTime? lastChecked}) async {
    final raw = await _store.readJson(LocalStore.keyChecklist);
    final map = raw is Map
        ? (raw is Map<String, dynamic>
            ? Map<String, dynamic>.from(raw)
            : raw.cast<String, dynamic>())
        : <String, dynamic>{};
    if (bikeId != null && bikeId.isNotEmpty) {
      final prevBike = map[bikeId] is Map
          ? Map<String, dynamic>.from(map[bikeId] as Map)
          : <String, dynamic>{};
      prevBike['items'] = checklist;
      if (lastChecked != null) {
        prevBike['lastChecked'] = lastChecked.toUtc().toIso8601String();
      }
      map[bikeId] = prevBike;
      await _store.writeJson(LocalStore.keyChecklist, map);
    } else {
      await _store.writeJson(LocalStore.keyChecklist, checklist);
    }
  }

  @override
  Future<void> resetChecklist([String? bikeId]) async {
    final raw = await _store.readJson(LocalStore.keyChecklist);
    final map = raw is Map
        ? (raw is Map<String, dynamic>
            ? Map<String, dynamic>.from(raw)
            : raw.cast<String, dynamic>())
        : <String, dynamic>{};
    if (bikeId != null && bikeId.isNotEmpty) {
      final prevBike = map[bikeId] is Map
          ? Map<String, dynamic>.from(map[bikeId] as Map)
          : <String, dynamic>{};
      final customChecks = prevBike['customChecks'];
      final bikeReset = <String, dynamic>{
        'items': <String, bool>{},
        'lastChecked': null,
      };
      if (customChecks != null) {
        bikeReset['customChecks'] = customChecks;
      }
      map[bikeId] = bikeReset;
      await _store.writeJson(LocalStore.keyChecklist, map);
    } else {
      final customChecks = map['customChecks'];
      final globalReset = <String, dynamic>{};
      if (customChecks != null) {
        globalReset['customChecks'] = customChecks;
      }
      await _store.writeJson(LocalStore.keyChecklist, globalReset);
    }
  }

  @override
  Future<List<String>> loadCustomChecks([String? bikeId]) async {
    final json = await _store.readJson(LocalStore.keyChecklist);
    if (json is! Map) return [];
    final map = json is Map<String, dynamic> ? json : json.cast<String, dynamic>();
    if (bikeId != null && bikeId.isNotEmpty) {
      final bikeData = map[bikeId];
      if (bikeData is Map && bikeData['customChecks'] is List) {
        return (bikeData['customChecks'] as List).map((e) => e.toString()).toList();
      }
      return [];
    }
    if (map['customChecks'] is List) {
      return (map['customChecks'] as List).map((e) => e.toString()).toList();
    }
    return [];
  }

  @override
  Future<void> saveCustomChecks(List<String> customChecks, [String? bikeId]) async {
    final raw = await _store.readJson(LocalStore.keyChecklist);
    final map = raw is Map
        ? (raw is Map<String, dynamic>
            ? Map<String, dynamic>.from(raw)
            : raw.cast<String, dynamic>())
        : <String, dynamic>{};
    if (bikeId != null && bikeId.isNotEmpty) {
      final prevBike = map[bikeId] is Map
          ? Map<String, dynamic>.from(map[bikeId] as Map)
          : <String, dynamic>{};
      prevBike['customChecks'] = customChecks;
      map[bikeId] = prevBike;
      await _store.writeJson(LocalStore.keyChecklist, map);
    } else {
      map['customChecks'] = customChecks;
      await _store.writeJson(LocalStore.keyChecklist, map);
    }
  }

  @override
  Future<void> clear() async {
    await _store.writeJson(LocalStore.keyMaintenanceItems, null);
    await _store.writeJson(LocalStore.keyServiceSchedule, null);
    await _store.writeJson(LocalStore.keyHarshConditions, null);
    await _store.writeJson(LocalStore.keyJettingBaseline, null);
    await _store.writeJson(LocalStore.keyChecklist, null);
  }

  @override
  Future<void> flush() async {
    await _store.flush();
  }
}

MaintenanceRepository resolveMaintenanceRepository(dynamic source, [MaintenanceRepository? fallback]) {
  if (source is MaintenanceRepository) return source;
  if (source is LocalStore) return MaintenanceRepositoryLocal(source);
  return fallback ?? MaintenanceRepositoryLocal();
}
