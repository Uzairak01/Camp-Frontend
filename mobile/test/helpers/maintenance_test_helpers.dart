import 'package:camp/core/data/maintenance_repository.dart';
import 'package:camp/features/maintenance/controllers/maintenance_controller.dart';
import 'package:camp/features/maintenance/domain/service_schedule_item.dart';

export 'fake_maintenance_repository.dart';

/// Test helper that writes schedule items to the repository and synchronizes
/// the in-memory MaintenanceController cache. Completely replaces the removed
/// production setSchedule() helper.
Future<void> setScheduleForTest(
  String bikeId,
  List<ServiceScheduleItem> items, {
  MaintenanceRepository? repository,
}) async {
  final repo = repository ?? MaintenanceController.instance.repository;
  await repo.saveServiceSchedule(bikeId, items);
  await MaintenanceController.instance.loadSchedule(bikeId);
}
