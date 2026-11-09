import 'package:flutter/material.dart';

import '../../../core/data/app_repositories.dart';
import '../../../core/data/service_visit_repository.dart';
import '../../../core/widgets/app_messenger.dart';
import '../../garage/controllers/active_bike_controller.dart';
import '../domain/expense_model.dart';
import '../domain/service_visit_model.dart';
import 'trip_budget_controller.dart';

/// Central state controller managing scheduled and historical workshop service visits.
/// Follows the singleton ChangeNotifier pattern established by ActiveBikeController,
/// TripBudgetController, and SettingsController.
class ServiceVisitController extends ChangeNotifier {
  ServiceVisitController({ServiceVisitRepository? repository})
      : _repository =
            repository ?? AppRepositories.instance.serviceVisitRepository;

  static ServiceVisitController instance = ServiceVisitController();

  ServiceVisitRepository _repository;

  @visibleForTesting
  set repository(ServiceVisitRepository repo) => _repository = repo;

  final List<ServiceVisit> _visits = [];

  List<ServiceVisit> get visits => List.unmodifiable(_visits);

  /// Returns the earliest upcoming planned service visit, or null if none.
  /// Past visits automatically move off this card.
  ServiceVisit? get nextPlannedVisit {
    final upcoming = _visits.where((v) => !v.isPast).toList();
    if (upcoming.isEmpty) return null;
    upcoming.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return upcoming.first;
  }

  /// All upcoming visits sorted by earliest date.
  List<ServiceVisit> get upcomingVisits {
    final list = _visits.where((v) => !v.isPast).toList();
    list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return List.unmodifiable(list);
  }

  /// All past visits sorted by active bike first, then most recent first.
  List<ServiceVisit> get pastVisits {
    final activeId = ActiveBikeController.instance.activeBike?.id;
    final list = _visits.where((v) => v.isPast).toList();
    list.sort((a, b) {
      if (activeId != null && activeId.isNotEmpty) {
        final aActive = a.bikeId != null && a.bikeId == activeId;
        final bActive = b.bikeId != null && b.bikeId == activeId;
        if (aActive && !bActive) return -1;
        if (!aActive && bActive) return 1;
      }
      return b.dateTime.compareTo(a.dateTime);
    });
    return List.unmodifiable(list);
  }

  final Map<String, Expense> _cachedDeletedExpenses = {};

  @visibleForTesting
  Map<String, Expense> get cachedDeletedExpenses =>
      Map.unmodifiable(_cachedDeletedExpenses);

  /// Add a newly scheduled service visit.
  Future<void> addVisit(ServiceVisit visit, [BuildContext? context]) async {
    final previous = List<ServiceVisit>.from(_visits);
    _visits.add(visit);
    notifyListeners();
    try {
      await _repository.saveServiceVisits(_visits);
    } catch (e) {
      _visits.clear();
      _visits.addAll(previous);
      notifyListeners();
      if (context != null && context.mounted) {
        showSaveErrorSnackBar(context);
      } else {
        showSaveErrorSnackBar();
      }
      rethrow;
    }
  }

  /// Update an existing service visit.
  /// If the visit is marked done and has a cost, ensures the linked expense stays in sync.
  Future<void> updateVisit(ServiceVisit visit, [BuildContext? context]) async {
    final index = _visits.indexWhere((v) => v.id == visit.id);
    if (index == -1) return;

    ServiceVisit visitToSave = visit;

    if (visit.isDone) {
      if (visit.cost != null && visit.cost! > 0) {
        if (visit.expenseId != null && visit.expenseId!.isNotEmpty) {
          final expIdx = TripBudgetController.instance.expenses.indexWhere(
              (e) => e.id == visit.expenseId || e.maintenanceItemId == visit.id);
          if (expIdx != -1) {
            final existingExp = TripBudgetController.instance.expenses[expIdx];
            if (existingExp.amount != visit.cost! ||
                existingExp.bikeId != visit.bikeId ||
                existingExp.title != '${visit.shopName} Service') {
              TripBudgetController.instance.updateExpense(
                existingExp.copyWith(
                  amount: visit.cost!,
                  bikeId: visit.bikeId,
                  title: '${visit.shopName} Service',
                  category: ExpenseCategory.service,
                  updatedAt: DateTime.now().toUtc(),
                ),
              );
            }
          } else {
            final newExp = Expense(
              id: visit.expenseId!,
              title: '${visit.shopName} Service',
              amount: visit.cost!,
              category: ExpenseCategory.service,
              trackingMode: ExpenseTrackingMode.manualEntry,
              dateRecorded: visit.dateTime,
              bikeId: visit.bikeId,
              maintenanceItemId: visit.id,
              createdAt: DateTime.now().toUtc(),
              updatedAt: DateTime.now().toUtc(),
            );
            TripBudgetController.instance.addExpense(newExp);
          }
        } else {
          final newExpId = 'exp-visit-${DateTime.now().millisecondsSinceEpoch}';
          final newExp = Expense(
            id: newExpId,
            title: '${visit.shopName} Service',
            amount: visit.cost!,
            category: ExpenseCategory.service,
            trackingMode: ExpenseTrackingMode.manualEntry,
            dateRecorded: visit.dateTime,
            bikeId: visit.bikeId,
            maintenanceItemId: visit.id,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          );
          TripBudgetController.instance.addExpense(newExp);
          visitToSave = visit.copyWith(expenseId: newExpId);
        }
      } else {
        if (visit.expenseId != null && visit.expenseId!.isNotEmpty) {
          final expExists = TripBudgetController.instance.expenses
              .any((e) => e.id == visit.expenseId);
          if (expExists) {
            TripBudgetController.instance.deleteExpense(visit.expenseId!);
          }
          visitToSave = visit.copyWith(expenseId: null, cost: null);
        }
      }
    }

    final previous = List<ServiceVisit>.from(_visits);
    _visits[index] = visitToSave;
    notifyListeners();
    try {
      await _repository.saveServiceVisits(_visits);
    } catch (e) {
      _visits.clear();
      _visits.addAll(previous);
      notifyListeners();
      if (context != null && context.mounted) {
        showSaveErrorSnackBar(context);
      } else {
        showSaveErrorSnackBar();
      }
      rethrow;
    }
  }

  bool isSyncingWithFinances = false;

  /// Remove a service visit by its ID.
  Future<void> deleteVisit(String id, [BuildContext? context]) async {
    final index = _visits.indexWhere((v) => v.id == id);
    if (index == -1) return;
    final visit = _visits[index];

    if (visit.expenseId != null && visit.expenseId!.isNotEmpty) {
      final expIdx = TripBudgetController.instance.expenses.indexWhere(
          (Expense e) =>
              e.id == visit.expenseId || e.maintenanceItemId == visit.id);
      if (expIdx != -1) {
        final exp = TripBudgetController.instance.expenses[expIdx];
        _cachedDeletedExpenses[visit.id] = exp;
        isSyncingWithFinances = true;
        try {
          TripBudgetController.instance.deleteExpense(visit.expenseId!);
        } finally {
          isSyncingWithFinances = false;
        }
      }
    }

    final previous = List<ServiceVisit>.from(_visits);
    _visits.removeAt(index);
    notifyListeners();
    try {
      await _repository.saveServiceVisits(_visits);
    } catch (e) {
      _visits.clear();
      _visits.addAll(previous);
      notifyListeners();
      if (context != null && context.mounted) {
        showSaveErrorSnackBar(context);
      } else {
        showSaveErrorSnackBar();
      }
      rethrow;
    }
  }

  /// Insert a service visit at a specific index (e.g. for Undo operations).
  Future<void> insertVisit(int index, ServiceVisit visit,
      [BuildContext? context]) async {
    final cachedExp = _cachedDeletedExpenses.remove(visit.id);
    if (cachedExp != null) {
      if (!TripBudgetController.instance.expenses
          .any((e) => e.id == cachedExp.id)) {
        isSyncingWithFinances = true;
        try {
          TripBudgetController.instance.insertExpense(
            TripBudgetController.instance.expenses.length,
            cachedExp,
          );
        } finally {
          isSyncingWithFinances = false;
        }
      }
    } else if (visit.isDone &&
        visit.expenseId != null &&
        visit.cost != null &&
        visit.cost! > 0) {
      if (!TripBudgetController.instance.expenses
          .any((e) => e.id == visit.expenseId)) {
        final restoredExp = Expense(
          id: visit.expenseId!,
          title: '${visit.shopName} Service',
          amount: visit.cost!,
          category: ExpenseCategory.service,
          trackingMode: ExpenseTrackingMode.manualEntry,
          dateRecorded: visit.dateTime,
          bikeId: visit.bikeId,
          maintenanceItemId: visit.id,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        isSyncingWithFinances = true;
        try {
          TripBudgetController.instance.insertExpense(
            TripBudgetController.instance.expenses.length,
            restoredExp,
          );
        } finally {
          isSyncingWithFinances = false;
        }
      }
    }

    final safeIndex = index.clamp(0, _visits.length);
    final previous = List<ServiceVisit>.from(_visits);
    _visits.insert(safeIndex, visit);
    notifyListeners();
    try {
      await _repository.saveServiceVisits(_visits);
    } catch (e) {
      _visits.clear();
      _visits.addAll(previous);
      notifyListeners();
      if (context != null && context.mounted) {
        showSaveErrorSnackBar(context);
      } else {
        showSaveErrorSnackBar();
      }
      rethrow;
    }
  }

  /// Marks a service visit as done.
  ///
  /// If [actualCost] is provided and > 0, creates exactly one linked expense
  /// in Finances (category Service, bikeId of the visit) and stores the expenseId
  /// on the visit. If no cost is provided, no expense is created.
  Future<void> markVisitDone({
    required ServiceVisit visit,
    double? actualCost,
    String? bikeId,
    BuildContext? context,
  }) async {
    final effectiveBikeId = bikeId ?? visit.bikeId;
    final hasCost = actualCost != null && actualCost > 0;
    String? effectiveExpenseId = visit.expenseId;

    if (hasCost) {
      final existingExp =
          (effectiveExpenseId != null && effectiveExpenseId.isNotEmpty)
              ? TripBudgetController.instance.expenses
                  .cast<Expense?>()
                  .firstWhere((e) => e?.id == effectiveExpenseId,
                      orElse: () => null)
              : null;

      final expenseDate = visit.dateTime.isAfter(DateTime.now())
          ? DateTime.now()
          : visit.dateTime;

      if (existingExp != null) {
        TripBudgetController.instance.updateExpense(
          existingExp.copyWith(
            amount: actualCost,
            bikeId: effectiveBikeId,
            title: '${visit.shopName} Service',
            category: ExpenseCategory.service,
            dateRecorded: expenseDate,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      } else {
        final newExpId =
            (effectiveExpenseId != null && effectiveExpenseId.isNotEmpty)
                ? effectiveExpenseId
                : 'exp-visit-${DateTime.now().millisecondsSinceEpoch}';
        final newExp = Expense(
          id: newExpId,
          title: '${visit.shopName} Service',
          amount: actualCost,
          category: ExpenseCategory.service,
          trackingMode: ExpenseTrackingMode.manualEntry,
          dateRecorded: expenseDate,
          bikeId: effectiveBikeId,
          maintenanceItemId: visit.id,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        TripBudgetController.instance.addExpense(newExp);
        effectiveExpenseId = newExpId;
      }
    } else {
      if (effectiveExpenseId != null && effectiveExpenseId.isNotEmpty) {
        final existingExp = TripBudgetController.instance.expenses
            .cast<Expense?>()
            .firstWhere((e) => e?.id == effectiveExpenseId, orElse: () => null);
        if (existingExp != null) {
          TripBudgetController.instance.deleteExpense(effectiveExpenseId);
        }
        effectiveExpenseId = null;
      }
    }

    final updatedVisit = visit.copyWith(
      isDone: true,
      cost: hasCost ? actualCost : null,
      bikeId: effectiveBikeId,
      expenseId: effectiveExpenseId,
      updatedAt: DateTime.now().toUtc(),
    );

    await updateVisit(updatedVisit, context);
  }

  /// Load persisted service visits from storage.
  Future<void> load([ServiceVisitRepository? customRepo]) async {
    final repo = customRepo ?? _repository;
    _repository = repo;
    try {
      final loaded = await repo.loadServiceVisits();
      _visits.clear();
      _visits.addAll(loaded);
      notifyListeners();
    } catch (_) {}
  }

  /// Persist current visits list to storage.
  Future<void> save([ServiceVisitRepository? customRepo]) async {
    final repo = customRepo ?? _repository;
    await repo.saveServiceVisits(_visits);
  }
}
