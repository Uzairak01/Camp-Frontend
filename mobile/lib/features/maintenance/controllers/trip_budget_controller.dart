import 'package:flutter/foundation.dart';

import '../../../core/data/app_repositories.dart';
import '../../../core/data/finance_repository.dart';
import '../../../core/data/finance_repository_local.dart';
import '../domain/expense_model.dart';
import '../domain/maintenance_item_model.dart';
import '../domain/service_visit_model.dart';
import '../domain/trip_budget_model.dart';
import 'maintenance_controller.dart';
import 'service_visit_controller.dart';

/// Central state controller managing trip budget cap, allocations, and expense ledger.
/// Follows the singleton ChangeNotifier pattern established by ActiveBikeController,
/// SettingsController, and PostRideReportController.
class TripBudgetController extends ChangeNotifier {
  TripBudgetController({FinanceRepository? repository})
      : _repository = repository ?? AppRepositories.instance.financeRepository {
    _initializeDefaults();
  }

  static TripBudgetController instance = TripBudgetController();

  FinanceRepository _repository;

  @visibleForTesting
  set repository(FinanceRepository repo) => _repository = repo;

  TripBudget _budget = const TripBudget(
    tripName: '',
    capAmount: 0.0,
    allocatedSoFar: 0.0,
  );
  final List<Expense> _expenses = [];

  final Map<String, MaintenanceItem> _cachedDeletedItems = {};
  final Map<String, ServiceVisit> _cachedDeletedVisits = {};

  TripBudget get budget => _budget;
  List<Expense> get expenses => List.unmodifiable(_expenses);

  void _initializeDefaults() {
    _budget = const TripBudget(
      tripName: '',
      capAmount: 0.0,
      allocatedSoFar: 0.0,
    );
    _expenses.clear();
  }

  /// Update the trip budget.
  void setBudget(TripBudget budget) {
    _budget = budget;
    notifyListeners();
    save();
  }

  /// Add a new expense line item to the ledger.
  void addExpense(Expense expense) {
    final existingIndex = _expenses.indexWhere((e) => e.id == expense.id);
    if (existingIndex != -1) {
      _expenses[existingIndex] = expense;
    } else {
      _expenses.insert(0, expense);
    }
    _budget = _budget.copyWith(
      allocatedSoFar: _expenses.fold<double>(0.0, (s, e) => s + e.amount),
    );
    notifyListeners();
    save();
  }

  /// Update an existing expense in the ledger.
  void updateExpense(Expense expense) {
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      _expenses[index] = expense;
      _budget = _budget.copyWith(
        allocatedSoFar: _expenses.fold<double>(0.0, (s, e) => s + e.amount),
      );
      notifyListeners();
      save();
      _syncLinkedMaintenanceOnUpdate(expense);
    }
  }

  /// Remove an expense from the ledger by ID.
  void deleteExpense(String id) {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index != -1) {
      final removed = _expenses.removeAt(index);
      _budget = _budget.copyWith(
        allocatedSoFar: _expenses.fold<double>(0.0, (s, e) => s + e.amount),
      );
      notifyListeners();
      save();
      _syncLinkedMaintenanceOnDelete(removed);
    }
  }

  /// Insert an expense at a specific index (e.g. for Undo operations).
  void insertExpense(int index, Expense expense) {
    final safeIndex = index.clamp(0, _expenses.length);
    _expenses.insert(safeIndex, expense);
    _budget = _budget.copyWith(
      allocatedSoFar: _expenses.fold<double>(0.0, (s, e) => s + e.amount),
    );
    notifyListeners();
    save();
    _syncLinkedMaintenanceOnRestore(expense);
  }

  Future<void> _syncLinkedMaintenanceOnUpdate(Expense expense) async {
    final linkId = expense.maintenanceItemId;
    if (linkId == null || linkId.isEmpty) return;

    try {
      final items = MaintenanceController.instance.maintenanceItems;
      final idx = items.indexWhere((i) => i.id == linkId || i.expenseId == expense.id);
      if (idx != -1) {
        final existing = items[idx];
        final updated = existing.copyWith(
          cost: expense.amount,
          bikeId: expense.bikeId ?? existing.bikeId,
          expenseId: expense.id,
          updatedAt: DateTime.now().toUtc(),
        );
        await MaintenanceController.instance.updateMaintenanceItem(updated);
        return;
      } else {
        // Fallback to repository
        final repo = AppRepositories.instance.maintenanceRepository;
        final repoItems = await repo.loadMaintenanceItems();
        final rIdx = repoItems.indexWhere((i) => i.id == linkId || i.expenseId == expense.id);
        if (rIdx != -1) {
          final existing = repoItems[rIdx];
          final updated = existing.copyWith(
            cost: expense.amount,
            bikeId: expense.bikeId ?? existing.bikeId,
            expenseId: expense.id,
            updatedAt: DateTime.now().toUtc(),
          );
          repoItems[rIdx] = updated;
          await repo.saveMaintenanceItems(repoItems);
          await MaintenanceController.instance.loadMaintenanceItems();
          return;
        }
      }
    } catch (_) {}

    try {
      final visits = ServiceVisitController.instance.visits;
      final idx = visits.indexWhere((v) => v.id == linkId || v.expenseId == expense.id);
      if (idx != -1) {
        final existing = visits[idx];
        final updated = existing.copyWith(
          cost: expense.amount,
          bikeId: expense.bikeId ?? existing.bikeId,
          expenseId: expense.id,
          updatedAt: DateTime.now().toUtc(),
        );
        await ServiceVisitController.instance.updateVisit(updated);
        return;
      } else {
        final vRepo = AppRepositories.instance.serviceVisitRepository;
        final repoVisits = await vRepo.loadServiceVisits();
        final rIdx = repoVisits.indexWhere((v) => v.id == linkId || v.expenseId == expense.id);
        if (rIdx != -1) {
          final existing = repoVisits[rIdx];
          final updated = existing.copyWith(
            cost: expense.amount,
            bikeId: expense.bikeId ?? existing.bikeId,
            expenseId: expense.id,
            updatedAt: DateTime.now().toUtc(),
          );
          repoVisits[rIdx] = updated;
          await vRepo.saveServiceVisits(repoVisits);
          await ServiceVisitController.instance.load();
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _syncLinkedMaintenanceOnDelete(Expense expense) async {
    final linkId = expense.maintenanceItemId;
    if (linkId == null || linkId.isEmpty) return;
    if (ServiceVisitController.instance.isSyncingWithFinances) return;

    try {
      final items = MaintenanceController.instance.maintenanceItems;
      final idx = items.indexWhere((i) => i.id == linkId || i.expenseId == expense.id);
      if (idx != -1) {
        final item = items[idx];
        _cachedDeletedItems[expense.id] = item;
        await MaintenanceController.instance.deleteMaintenanceItem(item.id);
        return;
      } else {
        final repo = AppRepositories.instance.maintenanceRepository;
        final repoItems = await repo.loadMaintenanceItems();
        final rIdx = repoItems.indexWhere((i) => i.id == linkId || i.expenseId == expense.id);
        if (rIdx != -1) {
          final item = repoItems.removeAt(rIdx);
          _cachedDeletedItems[expense.id] = item;
          await repo.saveMaintenanceItems(repoItems);
          await MaintenanceController.instance.loadMaintenanceItems();
          return;
        }
      }
    } catch (_) {}

    try {
      final visits = ServiceVisitController.instance.visits;
      final idx = visits.indexWhere((v) => v.id == linkId || v.expenseId == expense.id);
      if (idx != -1) {
        final visit = visits[idx];
        _cachedDeletedVisits[expense.id] = visit;
        await ServiceVisitController.instance.deleteVisit(visit.id);
        return;
      } else {
        final vRepo = AppRepositories.instance.serviceVisitRepository;
        final repoVisits = await vRepo.loadServiceVisits();
        final rIdx = repoVisits.indexWhere((v) => v.id == linkId || v.expenseId == expense.id);
        if (rIdx != -1) {
          final visit = repoVisits.removeAt(rIdx);
          _cachedDeletedVisits[expense.id] = visit;
          await vRepo.saveServiceVisits(repoVisits);
          await ServiceVisitController.instance.load();
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _syncLinkedMaintenanceOnRestore(Expense expense) async {
    final linkId = expense.maintenanceItemId;
    if (linkId == null || linkId.isEmpty) return;
    if (ServiceVisitController.instance.isSyncingWithFinances) return;

    final cachedItem = _cachedDeletedItems.remove(expense.id);
    if (cachedItem != null) {
      try {
        if (!MaintenanceController.instance.maintenanceItems.any((i) => i.id == cachedItem.id)) {
          final repo = AppRepositories.instance.maintenanceRepository;
          final repoItems = await repo.loadMaintenanceItems();
          if (!repoItems.any((i) => i.id == cachedItem.id)) {
            repoItems.add(cachedItem);
            await repo.saveMaintenanceItems(repoItems);
          }
          await MaintenanceController.instance.loadMaintenanceItems();
        }
      } catch (_) {}
      return;
    }

    final cachedVisit = _cachedDeletedVisits.remove(expense.id);
    if (cachedVisit != null) {
      try {
        if (!ServiceVisitController.instance.visits.any((v) => v.id == cachedVisit.id)) {
          final vRepo = AppRepositories.instance.serviceVisitRepository;
          final repoVisits = await vRepo.loadServiceVisits();
          if (!repoVisits.any((v) => v.id == cachedVisit.id)) {
            repoVisits.add(cachedVisit);
            await vRepo.saveServiceVisits(repoVisits);
          }
          await ServiceVisitController.instance.load();
        }
      } catch (_) {}
    }
  }

  /// Remove/delete the current trip and clear expenses ledger.
  void deleteTrip() {
    _budget = const TripBudget(
      tripName: 'New Expedition',
      capAmount: 0.0,
      allocatedSoFar: 0.0,
    );
    _expenses.clear();
    notifyListeners();
    save();
  }

  /// Reset to empty budget.
  void reset() {
    _initializeDefaults();
    notifyListeners();
  }

  /// Reset in-memory budget and expenses for testing.
  void resetForTesting() {
    _budget = const TripBudget(
      tripName: '',
      capAmount: 0.0,
      allocatedSoFar: 0.0,
    );
    _expenses.clear();
    _cachedDeletedItems.clear();
    _cachedDeletedVisits.clear();
    _repository = AppRepositories.instance.financeRepository;
    notifyListeners();
  }

  /// Await completion of all pending storage writes.
  Future<void> flush() => _repository.flush();

  /// Load budget and expenses from repository.
  Future<void> load([dynamic source]) async {
    final repo = resolveFinanceRepository(source, _repository);
    if (source != null) {
      _repository = repo;
    }
    final isFirst = await repo.isFirstRun();

    if (isFirst) {
      _initializeDefaults();
      await repo.markFirstRunCompleted();
      notifyListeners();
      return;
    }

    try {
      final loadedBudget = await repo.loadBudget();
      final loadedExpenses = await repo.loadExpenses();

      if (loadedBudget == null) {
        _initializeDefaults();
        return;
      }

      _budget = loadedBudget;
      _expenses.clear();
      _expenses.addAll(loadedExpenses);
      _budget = _budget.copyWith(
        allocatedSoFar: _expenses.fold<double>(0.0, (s, e) => s + e.amount),
      );
      notifyListeners();
    } catch (_) {
      // Fallback on corrupt or invalid data
      _initializeDefaults();
      notifyListeners();
    }
  }

  /// Persist budget and expenses to repository.
  Future<void> save([dynamic source]) async {
    final repo = resolveFinanceRepository(source, _repository);
    try {
      await repo.saveBudget(_budget);
      await repo.saveExpenses(_expenses);
    } catch (_) {
      // Ignore storage errors in quiet background saves
    }
  }
}
