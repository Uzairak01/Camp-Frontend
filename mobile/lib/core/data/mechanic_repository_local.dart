import '../../features/mechanics/domain/mechanic_model.dart';
import '../storage/local_store.dart';
import 'mechanic_repository.dart';

class MechanicRepositoryLocal implements MechanicRepository {
  MechanicRepositoryLocal([LocalStore? store]) : _explicitStore = store;

  final LocalStore? _explicitStore;
  LocalStore get _store => _explicitStore ?? LocalStore.instance;

  @override
  Future<bool> isFirstRun() => _store.isFirstRun();

  @override
  Future<void> markFirstRunCompleted() => _store.markFirstRunCompleted();

  /// Seeded mechanic IDs from the initial demo dataset.
  static const Set<String> seededIds = {'1', '2', '3'};

  /// Exact names of the seeded demo mechanics.
  static const Set<String> seededNames = {
    'Peak Moto & Adventure Rig Prep',
    'Highland Moto Rescue & Spares',
    'Alpine Rally Works & Garage',
  };

  /// Returns true if a mechanic matches the seeded demo records.
  static bool isSeeded(String? id, String? name) {
    if (id != null && seededIds.contains(id.trim())) return true;
    if (name != null && seededNames.contains(name.trim())) return true;
    return false;
  }

  @override
  Future<List<Mechanic>> loadMechanics() async {
    final json = await _store.readJson(LocalStore.keyMechanics);
    if (json is! List) {
      return [];
    }

    bool needsSave = false;
    final mechanics = <Mechanic>[];

    for (int i = 0; i < json.length; i++) {
      final raw = json[i];
      if (raw is Map) {
        final map = raw is Map<String, dynamic> ? raw : raw.cast<String, dynamic>();
        final id = map['id']?.toString();
        final name = map['name']?.toString();

        // One-time cleanup: remove saved mechanics with the seeded IDs or exact names.
        // Mechanics the rider added are never touched.
        if (isSeeded(id, name)) {
          needsSave = true;
          continue;
        }

        final mechanic = Mechanic.fromJson(map);
        if (mechanic.id.isEmpty || map['id'] == null || (map['id'] as String).isEmpty) {
          needsSave = true;
          mechanics.add(mechanic.copyWith(id: 'mechanic_${DateTime.now().millisecondsSinceEpoch}_$i'));
        } else {
          if (map['createdAt'] == null || map['updatedAt'] == null) {
            needsSave = true;
          }
          mechanics.add(mechanic);
        }
      }
    }

    if (needsSave) {
      await saveMechanics(mechanics);
    }

    return mechanics;
  }

  @override
  Future<void> saveMechanics(List<Mechanic> mechanics) async {
    final now = DateTime.now().toUtc();
    final updated = mechanics.map((m) {
      return m.copyWith(
        id: m.effectiveId,
        createdAt: m.effectiveCreatedAt,
        updatedAt: now,
      );
    }).toList();

    await _store.writeJson(
      LocalStore.keyMechanics,
      updated.map((m) => m.toJson()).toList(),
    );
  }

  @override
  Future<void> deleteMechanic(String id) async {
    final current = await loadMechanics();
    final filtered = current.where((m) => m.effectiveId != id).toList();
    await saveMechanics(filtered);
  }

  @override
  Future<void> clear() async {
    await _store.writeJson(LocalStore.keyMechanics, null);
  }

  @override
  Future<void> flush() async {
    await _store.flush();
  }
}

MechanicRepository resolveMechanicRepository(dynamic source, [MechanicRepository? fallback]) {
  if (source is MechanicRepository) return source;
  if (source is LocalStore) return MechanicRepositoryLocal(source);
  return fallback ?? MechanicRepositoryLocal();
}
