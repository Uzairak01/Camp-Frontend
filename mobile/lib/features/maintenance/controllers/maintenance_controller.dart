import 'package:flutter/material.dart';

import '../../../core/data/app_repositories.dart';
import '../../../core/data/maintenance_repository.dart';
import '../../../core/data/service_visit_repository.dart';
import '../../../core/widgets/app_messenger.dart';
import '../../garage/controllers/active_bike_controller.dart';
import '../../garage/domain/bike_model.dart';
import '../../settings/controllers/settings_controller.dart';
import '../domain/expense_model.dart';
import '../domain/maintenance_item_model.dart';
import '../domain/maintenance_prediction_engine.dart';
import '../domain/service_schedule_engine.dart';
import '../domain/service_schedule_item.dart';
import '../domain/service_visit_model.dart';
import 'post_ride_report_controller.dart';
import 'service_visit_controller.dart';
import 'trip_budget_controller.dart';

/// Helper value object representing a found historical service record.
@immutable
class ServiceRecordMatch {
  const ServiceRecordMatch({this.km, this.date, this.description});
  final double? km;
  final DateTime? date;
  final String? description;
}

/// Central controller exposing rider-configured service schedules,
/// urgency predictions, and maintenance workflows across the entire app.
///
/// Serves as the single source of truth for:
/// - Home maintenance alert
/// - Home Service Status card
/// - Cockpit status line
/// - Drawer due count
/// - Maintenance hub & diagnostics
class MaintenanceController extends ChangeNotifier {
  MaintenanceController({
    MaintenanceRepository? repository,
    ServiceVisitRepository? serviceVisitRepository,
  })  : _repository =
            repository ?? AppRepositories.instance.maintenanceRepository,
        _serviceVisitRepository = serviceVisitRepository ??
            AppRepositories.instance.serviceVisitRepository {
    _init();
  }

  static MaintenanceController instance = MaintenanceController();

  final MaintenanceRepository _repository;
  MaintenanceRepository get repository => _repository;
  // ignore: unused_field — injected to keep test injection consistent with ServiceVisitController
  final ServiceVisitRepository _serviceVisitRepository;

  @override
  void dispose() {
    ActiveBikeController.instance.removeListener(_onActiveBikeChanged);
    super.dispose();
  }

  final Map<String, List<ServiceScheduleItem>> _schedules = {};
  final Map<String, bool> _harshConditions = {};
  final Map<String, bool> _carburetorOverrides = {};
  final Set<String> _loadedBikes = {};

  List<MaintenanceItem> _maintenanceItems = [];
  bool _maintenanceItemsLoaded = false;
  List<MaintenanceItem> get maintenanceItems => List.unmodifiable(_maintenanceItems);
  bool get maintenanceItemsLoaded => _maintenanceItemsLoaded;

  final Map<String, List<String>> _customChecks = {};

  List<String> getCustomChecks(String? bikeId) {
    if (bikeId == null) return [];
    return List.unmodifiable(_customChecks[bikeId] ?? []);
  }

  void resetForTesting() {
    _schedules.clear();
    _harshConditions.clear();
    _carburetorOverrides.clear();
    _loadedBikes.clear();
    _maintenanceItems = [];
    _maintenanceItemsLoaded = false;
    _customChecks.clear();
    _cachedDeletedExpenses.clear();
    notifyListeners();
  }

  void _init() {
    ActiveBikeController.instance.addListener(_onActiveBikeChanged);
    final active = ActiveBikeController.instance.activeBike;
    if (active != null) {
      loadSchedule(active.id);
      loadCustomChecks(active.id);
    }
    loadMaintenanceItems();
  }

  void _onActiveBikeChanged() {
    final active = ActiveBikeController.instance.activeBike;
    if (active != null) {
      if (!_loadedBikes.contains(active.id)) {
        loadSchedule(active.id);
      }
      loadCustomChecks(active.id);
    }
  }

  /// Load rider-added maintenance items from repository.
  Future<void> loadMaintenanceItems() async {
    try {
      final loaded = await _repository.loadMaintenanceItems();
      _maintenanceItems = List.from(loaded);
      _maintenanceItemsLoaded = true;
      notifyListeners();
    } catch (_) {}
  }

  /// Add a rider-configured maintenance item.
  /// If cost is entered, automatically creates and links a service expense in [TripBudgetController].
  Future<void> addMaintenanceItem(MaintenanceItem item, [BuildContext? context]) async {
    MaintenanceItem itemToSave = item;
    String? createdExpenseId;

    if (item.cost != null && item.cost! > 0 && item.expenseId == null) {
      final expId = 'exp-maint-${DateTime.now().millisecondsSinceEpoch}';
      createdExpenseId = expId;
      final newExp = Expense(
        id: expId,
        category: ExpenseCategory.service,
        title: '${item.name} Service',
        amount: item.cost!,
        bikeId: item.bikeId,
        maintenanceItemId: item.id,
        trackingMode: ExpenseTrackingMode.manualEntry,
        dateRecorded: DateTime.now(),
      );
      TripBudgetController.instance.addExpense(newExp);
      itemToSave = item.copyWith(expenseId: expId);
    }

    final previous = List<MaintenanceItem>.from(_maintenanceItems);
    _maintenanceItems = [..._maintenanceItems, itemToSave];
    _maintenanceItemsLoaded = true;
    notifyListeners();

    try {
      await _repository.saveMaintenanceItems(_maintenanceItems);
    } catch (e) {
      _maintenanceItems = previous;
      notifyListeners();
      if (createdExpenseId != null) {
        TripBudgetController.instance.deleteExpense(createdExpenseId);
      }
      if (context != null && context.mounted) {
        showSaveErrorSnackBar(context);
      } else {
        showSaveErrorSnackBar();
      }
      rethrow;
    }
  }

  /// Update an existing maintenance item.
  /// Synchronizes linked expense if cost or details changed.
  Future<void> updateMaintenanceItem(MaintenanceItem item, [BuildContext? context]) async {
    final index = _maintenanceItems.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    MaintenanceItem finalUpdated = item;

    if (item.cost != null && item.cost! > 0) {
      if (item.expenseId != null) {
        final existingExp = TripBudgetController.instance.expenses
            .where((e) => e.id == item.expenseId)
            .firstOrNull;
        if (existingExp != null) {
          TripBudgetController.instance.updateExpense(
            existingExp.copyWith(
              title: '${item.name} Service',
              amount: item.cost!,
              bikeId: item.bikeId,
              maintenanceItemId: item.id,
            ),
          );
        } else {
          final newExp = Expense(
            id: item.expenseId!,
            category: ExpenseCategory.service,
            title: '${item.name} Service',
            amount: item.cost!,
            bikeId: item.bikeId,
            maintenanceItemId: item.id,
            trackingMode: ExpenseTrackingMode.manualEntry,
            dateRecorded: DateTime.now(),
          );
          TripBudgetController.instance.addExpense(newExp);
        }
      } else {
        final expId = 'exp-maint-${DateTime.now().millisecondsSinceEpoch}';
        final newExp = Expense(
          id: expId,
          category: ExpenseCategory.service,
          title: '${item.name} Service',
          amount: item.cost!,
          bikeId: item.bikeId,
          maintenanceItemId: item.id,
          trackingMode: ExpenseTrackingMode.manualEntry,
          dateRecorded: DateTime.now(),
        );
        TripBudgetController.instance.addExpense(newExp);
        finalUpdated = item.copyWith(expenseId: expId);
      }
    } else {
      if (item.expenseId != null) {
        if (TripBudgetController.instance.expenses.any((e) => e.id == item.expenseId)) {
          TripBudgetController.instance.deleteExpense(item.expenseId!);
        }
        finalUpdated = item.copyWith(expenseId: null);
      }
    }

    final previous = List<MaintenanceItem>.from(_maintenanceItems);
    final updatedList = List<MaintenanceItem>.from(_maintenanceItems);
    updatedList[index] = finalUpdated;
    _maintenanceItems = updatedList;
    _maintenanceItemsLoaded = true;
    notifyListeners();

    try {
      await _repository.saveMaintenanceItems(_maintenanceItems);
    } catch (e) {
      _maintenanceItems = previous;
      notifyListeners();
      if (context != null && context.mounted) {
        showSaveErrorSnackBar(context);
      } else {
        showSaveErrorSnackBar();
      }
      rethrow;
    }
  }

  final Map<String, Expense> _cachedDeletedExpenses = {};

  /// Delete a maintenance item by ID.
  /// Removes any linked expense in [TripBudgetController].
  Future<void> deleteMaintenanceItem(String id, [BuildContext? context]) async {
    final index = _maintenanceItems.indexWhere((i) => i.id == id);
    if (index == -1) return;

    final removed = _maintenanceItems[index];
    if (removed.expenseId != null) {
      final expIdx = TripBudgetController.instance.expenses
          .indexWhere((e) => e.id == removed.expenseId);
      if (expIdx != -1) {
        _cachedDeletedExpenses[removed.id] =
            TripBudgetController.instance.expenses[expIdx];
        TripBudgetController.instance.deleteExpense(removed.expenseId!);
      }
    }

    final previous = List<MaintenanceItem>.from(_maintenanceItems);
    _maintenanceItems = _maintenanceItems.where((i) => i.id != id).toList();
    _maintenanceItemsLoaded = true;
    notifyListeners();

    try {
      await _repository.saveMaintenanceItems(_maintenanceItems);
    } catch (e) {
      _maintenanceItems = previous;
      notifyListeners();
      if (context != null && context.mounted) {
        showSaveErrorSnackBar(context);
      } else {
        showSaveErrorSnackBar();
      }
      rethrow;
    }
  }

  /// Insert a maintenance item at a specific index (e.g. for Undo operations).
  Future<void> insertMaintenanceItem(int index, MaintenanceItem item, [BuildContext? context]) async {
    final cachedExp = _cachedDeletedExpenses.remove(item.id);
    if (cachedExp != null) {
      if (!TripBudgetController.instance.expenses.any((e) => e.id == cachedExp.id)) {
        TripBudgetController.instance.insertExpense(
          TripBudgetController.instance.expenses.length,
          cachedExp,
        );
      }
    }

    final safeIndex = index.clamp(0, _maintenanceItems.length);
    final previous = List<MaintenanceItem>.from(_maintenanceItems);
    final updatedList = List<MaintenanceItem>.from(_maintenanceItems);
    updatedList.insert(safeIndex, item);
    _maintenanceItems = updatedList;
    _maintenanceItemsLoaded = true;
    notifyListeners();

    try {
      await _repository.saveMaintenanceItems(_maintenanceItems);
    } catch (e) {
      _maintenanceItems = previous;
      notifyListeners();
      if (context != null && context.mounted) {
        showSaveErrorSnackBar(context);
      } else {
        showSaveErrorSnackBar();
      }
      rethrow;
    }
  }

  /// Load custom checklist items for the specified bike.
  Future<void> loadCustomChecks(String bikeId) async {
    try {
      final checks = await _repository.loadCustomChecks(bikeId);
      _customChecks[bikeId] = checks;
      notifyListeners();
    } catch (_) {}
  }

  /// Add a custom checklist item for the specified bike.
  Future<void> addCustomCheck(String bikeId, String check, [BuildContext? context]) async {
    final prev = List<String>.from(_customChecks[bikeId] ?? []);
    final updated = [...prev, check];
    _customChecks[bikeId] = updated;
    notifyListeners();
    try {
      await _repository.saveCustomChecks(updated, bikeId);
    } catch (e) {
      _customChecks[bikeId] = prev;
      notifyListeners();
      if (context != null && context.mounted) {
        showSaveErrorSnackBar(context);
      } else {
        showSaveErrorSnackBar();
      }
      rethrow;
    }
  }

  /// Delete a custom checklist item for the specified bike.
  Future<void> deleteCustomCheck(String bikeId, String check, [BuildContext? context]) async {
    final prev = List<String>.from(_customChecks[bikeId] ?? []);
    final updated = prev.where((c) => c != check).toList();
    _customChecks[bikeId] = updated;
    notifyListeners();
    try {
      await _repository.saveCustomChecks(updated, bikeId);
    } catch (e) {
      _customChecks[bikeId] = prev;
      notifyListeners();
      if (context != null && context.mounted) {
        showSaveErrorSnackBar(context);
      } else {
        showSaveErrorSnackBar();
      }
      rethrow;
    }
  }

  /// Insert a custom checklist item at a specific index (e.g. for Undo operations).
  Future<void> insertCustomCheck(String bikeId, int index, String check, [BuildContext? context]) async {
    final prev = List<String>.from(_customChecks[bikeId] ?? []);
    final updated = List<String>.from(prev);
    final safeIndex = index.clamp(0, updated.length);
    updated.insert(safeIndex, check);
    _customChecks[bikeId] = updated;
    notifyListeners();
    try {
      await _repository.saveCustomChecks(updated, bikeId);
    } catch (e) {
      _customChecks[bikeId] = prev;
      notifyListeners();
      if (context != null && context.mounted) {
        showSaveErrorSnackBar(context);
      } else {
        showSaveErrorSnackBar();
      }
      rethrow;
    }
  }

  /// Whether the rider has configured any service schedule items with an interval for this bike.
  ///
  /// Returns false when nothing has been configured, triggering the "Set up your service schedule" state.
  bool hasMaintenanceData(Bike? bike) {
    if (bike == null) return false;
    final itemsList = _schedules[bike.id];
    if (itemsList == null || itemsList.isEmpty) {
      return false;
    }
    return itemsList.any((i) => i.enabled && i.hasInterval);
  }

  /// Load persisted schedule and conditions for the specified bike.
  Future<void> loadSchedule(String bikeId) async {
    try {
      final items = await _repository.loadServiceSchedule(bikeId);
      final isHarsh = await _repository.loadHarshConditions(bikeId);
      if (!_schedules.containsKey(bikeId) || _schedules[bikeId]!.isEmpty || items.isNotEmpty) {
        _schedules[bikeId] = items;
      }
      _harshConditions[bikeId] = isHarsh;
      _loadedBikes.add(bikeId);
      notifyListeners();
    } catch (_) {}
  }

  /// Whether harsh riding conditions (20% interval reduction) are active for the bike.
  bool isHarshConditions(String? bikeId) {
    if (bikeId == null) return false;
    return _harshConditions[bikeId] ?? false;
  }

  /// Set and persist harsh riding conditions for the bike.
  Future<void> setHarshConditions(String bikeId, bool isHarsh) async {
    _harshConditions[bikeId] = isHarsh;
    await _repository.saveHarshConditions(bikeId, isHarsh);
    notifyListeners();
  }

  /// Whether this bike is considered carbureted (from model field or user toggle override).
  bool isCarbureted(Bike? bike) {
    if (bike == null) return false;
    if (bike.fuelSystem == FuelSystem.carburetor) return true;
    return _carburetorOverrides[bike.id] ?? false;
  }

  /// Set the "My bike has a carburetor" toggle override.
  void setCarburetorOverride(String bikeId, bool hasCarb) {
    _carburetorOverrides[bikeId] = hasCarb;
    notifyListeners();
  }

  /// Returns all schedule items configured for the bike, creating unconfigured
  /// items for any missing types and appending any rider-added custom items.
  List<ServiceScheduleItem> getScheduleItems(String bikeId) {
    final bike = _resolveBike(bikeId);
    final isCarb = isCarbureted(bike);

    final stored = _schedules[bikeId] ?? [];
    final storedMap = {
      for (final item in stored.where((i) => i.type != ServiceItemType.custom))
        item.type: item,
    };

    final result = <ServiceScheduleItem>[];
    for (final type in ServiceItemType.values) {
      if (type == ServiceItemType.custom) {
        continue;
      }
      if (type == ServiceItemType.carburetor && !isCarb) {
        continue;
      }
      if (storedMap.containsKey(type)) {
        result.add(storedMap[type]!);
      } else {
        double? lastKm;
        DateTime? lastDate;
        if (type == ServiceItemType.oilAndSmallService && bike?.lastOilChange != null) {
          lastKm = bike!.lastOilChange!.km?.toDouble();
          lastDate = bike.lastOilChange!.date;
        } else if (type == ServiceItemType.tuning && bike?.lastTuneUp != null) {
          lastKm = bike!.lastTuneUp!.km?.toDouble();
          lastDate = bike.lastTuneUp!.date;
        }
        result.add(ServiceScheduleItem(
          id: 'sched_${bikeId}_${type.name}',
          bikeId: bikeId,
          type: type,
          lastDoneKm: lastKm,
          lastDoneDate: lastDate,
        ));
      }
    }

    // Append any rider-added custom items
    result.addAll(stored.where((i) => i.type == ServiceItemType.custom));

    return result;
  }

  /// Saves the full service schedule for the bike.
  Future<void> saveSchedule(
    String bikeId,
    List<ServiceScheduleItem> items, [
    BuildContext? context,
  ]) async {
    final previousSchedule = _schedules[bikeId] != null
        ? List<ServiceScheduleItem>.from(_schedules[bikeId]!)
        : null;
    _schedules[bikeId] = List.from(items);
    _loadedBikes.add(bikeId);
    notifyListeners();
    try {
      await _repository.saveServiceSchedule(bikeId, items);
    } catch (e) {
      if (previousSchedule != null) {
        _schedules[bikeId] = previousSchedule;
      } else {
        _schedules.remove(bikeId);
      }
      notifyListeners();
      if (context != null && context.mounted) {
        showSaveErrorSnackBar(context);
      } else {
        showSaveErrorSnackBar();
      }
      rethrow;
    }
  }

  /// Returns computed health and due predictions for all relevant service items of the bike.
  List<ServiceSchedulePrediction> items(String? bikeId) {
    final bike = _resolveBike(bikeId);
    if (bike == null) return const [];
    return itemsForBike(bike);
  }

  /// Returns computed health and due predictions for a given bike instance directly.
  List<ServiceSchedulePrediction> itemsForBike(Bike bike) {
    final scheduleItems = getScheduleItems(bike.id);
    final reports = PostRideReportController.instance.getReportsForBike(bike.id);
    final isHarsh = isHarshConditions(bike.id) ||
        (bike.ridingTerrain?.any((t) =>
                t.toLowerCase() == 'off-road' ||
                t.toLowerCase() == 'mountain') ??
            false);

    return scheduleItems.map((item) {
      return ServiceScheduleEngine.evaluateItem(
        item: item,
        currentOdometerKm: bike.odometerKm.toDouble(),
        isHarshConditions: isHarsh,
        recentReports: reports,
      );
    }).toList();
  }

  /// Returns all configured items for the bike that are Overdue or Due soon,
  /// sorted by urgency (Overdue highest wear first, then Due soon lowest remaining km/days first).
  List<ServiceSchedulePrediction> dueItems(String? bikeId) {
    final bike = _resolveBike(bikeId);
    if (bike == null || !hasMaintenanceData(bike)) {
      return const [];
    }

    final all = items(bike.id);
    final configured = all.where((i) =>
        i.item.enabled &&
        i.item.hasInterval &&
        i.item.hasLastDone).toList();

    final overdue = configured
        .where((i) => i.scheduleStatus == ScheduleItemStatus.overdue)
        .toList();
    overdue.sort((a, b) => b.wearPercent.compareTo(a.wearPercent));

    final dueSoon = configured
        .where((i) => i.scheduleStatus == ScheduleItemStatus.dueSoon)
        .toList();
    dueSoon.sort((a, b) => (a.remainingKm ?? 999999).compareTo(b.remainingKm ?? 999999));

    return [...overdue, ...dueSoon];
  }

  /// Returns the most urgent maintenance item (Overdue > Due soon).
  ///
  /// Returns `null` if nothing is overdue or due soon, or if no schedule is configured.
  ServiceSchedulePrediction? mostUrgentItem(String? bikeId) {
    final list = dueItems(bikeId);
    return list.isEmpty ? null : list.first;
  }

  /// Returns the total count of components that are overdue or due soon.
  int countDueItems(String? bikeId) => dueItems(bikeId).length;

  /// Marks a specific service item as done at the given odometer reading and date.
  ///
  /// Optionally records rider-entered cost as an expense into Finances.
  Future<void> markItemDone(
    String bikeId,
    String itemId, {
    required double odometerKm,
    required DateTime date,
    double? cost,
    BuildContext? context,
  }) async {
    final currentList = getScheduleItems(bikeId);
    final previousSchedule = _schedules[bikeId] != null
        ? List<ServiceScheduleItem>.from(_schedules[bikeId]!)
        : null;
    final index = currentList.indexWhere((i) => i.id == itemId);

    final itemToUpdate = index != -1
        ? currentList[index]
        : currentList.firstWhere((i) => i.type.name == itemId || i.id.contains(itemId));

    final updatedItem = itemToUpdate.copyWith(
      lastDoneKm: odometerKm,
      lastDoneDate: date,
      updatedAt: DateTime.now().toUtc(),
    );

    final updatedList = currentList.map((i) => i.id == updatedItem.id ? updatedItem : i).toList();
    _schedules[bikeId] = List.from(updatedList);
    _loadedBikes.add(bikeId);
    notifyListeners();

    try {
      await _repository.saveServiceSchedule(bikeId, updatedList);
    } catch (e) {
      if (previousSchedule != null) {
        _schedules[bikeId] = previousSchedule;
      } else {
        _schedules.remove(bikeId);
      }
      notifyListeners();
      if (context != null && context.mounted) {
        showSaveErrorSnackBar(context);
      } else {
        showSaveErrorSnackBar();
      }
      rethrow;
    }

    // Update bike's milestone if applicable
    final bike = _resolveBike(bikeId);
    if (bike != null) {
      Bike updatedBike = bike;
      if (odometerKm > bike.odometerKm) {
        updatedBike = updatedBike.copyWith(
          odometerKm: odometerKm.round(),
          preciseOdometerKm: odometerKm,
        );
      }
      if (updatedItem.type == ServiceItemType.oilAndSmallService) {
        updatedBike = updatedBike.copyWith(
          lastOilChange: ServiceRecord(km: odometerKm.round(), date: date),
        );
      } else if (updatedItem.type == ServiceItemType.tuning) {
        updatedBike = updatedBike.copyWith(
          lastTuneUp: ServiceRecord(km: odometerKm.round(), date: date),
        );
      }
      ActiveBikeController.instance.updateBike(updatedBike);
    }

    final String visitId = 'visit-${DateTime.now().millisecondsSinceEpoch}';
    final String? expId = (cost != null && cost > 0)
        ? 'exp-${DateTime.now().millisecondsSinceEpoch}'
        : null;

    // Write a service visit record through ServiceVisitController
    try {
      final newVisit = ServiceVisit(
        id: visitId,
        dateTime: date,
        shopName: '${updatedItem.type.displayName} Service',
        bikeId: bikeId,
        cost: cost,
        expenseId: expId,
        note: 'Completed at ${odometerKm.round()} km',
      );
      await ServiceVisitController.instance.addVisit(newVisit);
    } catch (_) {}

    // Record optional rider-entered cost in Finances with reciprocal link
    if (cost != null && cost > 0 && expId != null) {
      TripBudgetController.instance.addExpense(
        Expense(
          id: expId,
          category: ExpenseCategory.service,
          title: '${updatedItem.type.displayName} Service',
          amount: cost,
          dateRecorded: date,
          bikeId: bikeId,
          maintenanceItemId: visitId,
          note: 'Marked service done at ${odometerKm.round()} km',
          trackingMode: ExpenseTrackingMode.manualEntry,
        ),
      );
    }

    // Clear dismissed alert in SettingsController if this item was dismissed
    if (SettingsController.instance.dismissedAlertItemId == updatedItem.id ||
        SettingsController.instance.dismissedAlertItemId == itemId) {
      SettingsController.instance.clearDismissedAlert();
    }

    notifyListeners();
  }

  /// Locates the most recent logged service record matching this type for "Use last logged service".
  ServiceRecordMatch? findLastLoggedService(String bikeId, ServiceItemType type) {
    final bike = _resolveBike(bikeId);
    if (bike == null) return null;

    if (type == ServiceItemType.oilAndSmallService && bike.lastOilChange != null) {
      final rec = bike.lastOilChange!;
      if (rec.km != null || rec.date != null) {
        return ServiceRecordMatch(
          km: rec.km?.toDouble(),
          date: rec.date,
          description: 'Last Oil Change (${rec.km ?? 0} km)',
        );
      }
    }

    if (type == ServiceItemType.tuning && bike.lastTuneUp != null) {
      final rec = bike.lastTuneUp!;
      if (rec.km != null || rec.date != null) {
        return ServiceRecordMatch(
          km: rec.km?.toDouble(),
          date: rec.date,
          description: 'Last Tune-up (${rec.km ?? 0} km)',
        );
      }
    }

    return null;
  }

  /// Calculates the full maintenance assessment for the given bike.
  MaintenanceAssessment? getAssessment(String? bikeId) {
    final bike = _resolveBike(bikeId);
    if (bike == null) return null;

    final reports = PostRideReportController.instance.getReportsForBike(bike.id);
    return MaintenancePredictionEngine.analyze(
      bike: bike,
      rideReports: reports,
    );
  }

  /// Resolves bike by id or defaults to activeBike.
  Bike? _resolveBike(String? bikeId) {
    if (bikeId != null && bikeId.isNotEmpty) {
      return ActiveBikeController.instance.getBikeById(bikeId);
    }
    return ActiveBikeController.instance.activeBike;
  }

  /// Refreshes state and notifies listeners.
  void refresh() {
    notifyListeners();
  }
}
