import '../../features/maintenance/domain/service_visit_model.dart';

abstract class ServiceVisitRepository {
  Future<List<ServiceVisit>> loadServiceVisits();
  Future<void> saveServiceVisits(List<ServiceVisit> visits);
  Future<void> deleteServiceVisit(String id);
  Future<void> clear();
  Future<void> flush();
}
