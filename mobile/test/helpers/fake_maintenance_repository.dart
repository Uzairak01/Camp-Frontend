import 'package:camp/core/data/maintenance_repository.dart';
import 'package:camp/core/data/service_visit_repository.dart';
import 'package:camp/features/maintenance/domain/maintenance_item_model.dart';
import 'package:camp/features/maintenance/domain/service_schedule_item.dart';
import 'package:camp/features/maintenance/domain/service_visit_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake implementation of MaintenanceRepository for test isolation.
class FakeMaintenanceRepository extends Fake implements MaintenanceRepository {
  final Map<String, List<ServiceScheduleItem>> schedules = {};
  final Map<String, bool> harshConditions = {};
  final List<MaintenanceItem> items = [];
  final Map<String, Map<String, bool>> bikeChecklists = {};
  final Map<String, DateTime?> bikeChecklistDates = {};
  final Map<String, Map<String, dynamic>?> bikeJetting = {};
  Map<String, bool> checklist = {};
  Map<String, dynamic>? jettingBaseline;

  @override
  Future<List<ServiceScheduleItem>> loadServiceSchedule(String bikeId) async =>
      List.from(schedules[bikeId] ?? []);

  @override
  Future<void> saveServiceSchedule(String bikeId, List<ServiceScheduleItem> list) async {
    schedules[bikeId] = List.from(list);
  }

  @override
  Future<bool> loadHarshConditions(String bikeId) async => harshConditions[bikeId] ?? false;

  @override
  Future<void> saveHarshConditions(String bikeId, bool isHarsh) async {
    harshConditions[bikeId] = isHarsh;
  }

  @override
  Future<List<MaintenanceItem>> loadMaintenanceItems() async => List.from(items);

  @override
  Future<void> saveMaintenanceItems(List<MaintenanceItem> newItems) async {
    items.clear();
    items.addAll(newItems);
  }

  @override
  Future<void> deleteMaintenanceItem(String id) async {
    items.removeWhere((i) => i.id == id);
  }

  @override
  Future<Map<String, bool>> loadChecklist([String? bikeId]) async {
    if (bikeId != null && bikeId.isNotEmpty) {
      return Map.from(bikeChecklists[bikeId] ?? {});
    }
    return Map.from(checklist);
  }

  @override
  Future<DateTime?> loadChecklistLastChecked([String? bikeId]) async {
    if (bikeId != null && bikeId.isNotEmpty) {
      return bikeChecklistDates[bikeId];
    }
    return null;
  }

  @override
  Future<void> saveChecklist(Map<String, bool> list, {String? bikeId, DateTime? lastChecked}) async {
    if (bikeId != null && bikeId.isNotEmpty) {
      bikeChecklists[bikeId] = Map.from(list);
      if (lastChecked != null) {
        bikeChecklistDates[bikeId] = lastChecked;
      }
    } else {
      checklist = Map.from(list);
    }
  }

  final Map<String, List<String>> bikeCustomChecks = {};
  List<String> customChecks = [];

  @override
  Future<void> resetChecklist([String? bikeId]) async {
    if (bikeId != null && bikeId.isNotEmpty) {
      bikeChecklists[bikeId] = {};
      bikeChecklistDates[bikeId] = null;
    } else {
      checklist = {};
    }
  }

  @override
  Future<List<String>> loadCustomChecks([String? bikeId]) async {
    if (bikeId != null && bikeId.isNotEmpty) {
      return List.from(bikeCustomChecks[bikeId] ?? []);
    }
    return List.from(customChecks);
  }

  @override
  Future<void> saveCustomChecks(List<String> list, [String? bikeId]) async {
    if (bikeId != null && bikeId.isNotEmpty) {
      bikeCustomChecks[bikeId] = List.from(list);
    } else {
      customChecks = List.from(list);
    }
  }

  @override
  Future<Map<String, dynamic>?> loadJettingBaseline([String? bikeId]) async {
    if (bikeId != null && bikeId.isNotEmpty) {
      return bikeJetting[bikeId];
    }
    return jettingBaseline;
  }

  @override
  Future<void> saveJettingBaseline(Map<String, dynamic>? baseline, [String? bikeId]) async {
    if (bikeId != null && bikeId.isNotEmpty) {
      bikeJetting[bikeId] = baseline;
    } else {
      jettingBaseline = baseline;
    }
  }

  @override
  Future<void> deleteServiceSchedule(String bikeId) async {
    schedules.remove(bikeId);
  }

  @override
  Future<void> clear() async {
    schedules.clear();
    harshConditions.clear();
    items.clear();
  }

  @override
  Future<void> flush() async {}
}

/// In-memory fake implementation of ServiceVisitRepository for test isolation.
class FakeServiceVisitRepository extends Fake implements ServiceVisitRepository {
  final List<ServiceVisit> visits = [];

  @override
  Future<List<ServiceVisit>> loadServiceVisits() async => List.from(visits);

  @override
  Future<void> saveServiceVisits(List<ServiceVisit> newVisits) async {
    visits.clear();
    visits.addAll(newVisits);
  }

  @override
  Future<void> deleteServiceVisit(String id) async {
    visits.removeWhere((v) => v.id == id);
  }

  @override
  Future<void> clear() async {
    visits.clear();
  }

  @override
  Future<void> flush() async {}
}

