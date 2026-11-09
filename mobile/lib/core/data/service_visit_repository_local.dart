import '../../features/maintenance/domain/service_visit_model.dart';
import '../storage/local_store.dart';
import 'service_visit_repository.dart';

class ServiceVisitRepositoryLocal implements ServiceVisitRepository {
  ServiceVisitRepositoryLocal([LocalStore? store]) : _explicitStore = store;

  final LocalStore? _explicitStore;
  LocalStore get _store => _explicitStore ?? LocalStore.instance;

  @override
  Future<List<ServiceVisit>> loadServiceVisits() async {
    final json = await _store.readJson(LocalStore.keyServiceVisits);
    if (json is! List) {
      return [];
    }

    final visits = <ServiceVisit>[];
    for (int i = 0; i < json.length; i++) {
      final raw = json[i];
      if (raw is Map) {
        final map =
            raw is Map<String, dynamic> ? raw : raw.cast<String, dynamic>();
        visits.add(ServiceVisit.fromJson(map));
      }
    }
    return visits;
  }

  @override
  Future<void> saveServiceVisits(List<ServiceVisit> visits) async {
    final now = DateTime.now().toUtc();
    final updated = visits.map((v) {
      return v.copyWith(
        id: v.effectiveId,
        createdAt: v.effectiveCreatedAt,
        updatedAt: now,
      );
    }).toList();

    await _store.writeJson(
      LocalStore.keyServiceVisits,
      updated.map((v) => v.toJson()).toList(),
    );
  }

  @override
  Future<void> deleteServiceVisit(String id) async {
    final visits = await loadServiceVisits();
    visits.removeWhere((v) => v.id == id);
    await saveServiceVisits(visits);
  }

  @override
  Future<void> clear() async {
    await _store.remove(LocalStore.keyServiceVisits);
  }

  @override
  Future<void> flush() async {
    await _store.flush();
  }
}
