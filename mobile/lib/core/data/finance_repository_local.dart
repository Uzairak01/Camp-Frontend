import '../../features/maintenance/domain/expense_model.dart';
import '../../features/maintenance/domain/trip_budget_model.dart';
import '../storage/local_store.dart';
import 'finance_repository.dart';

class FinanceRepositoryLocal implements FinanceRepository {
  FinanceRepositoryLocal([LocalStore? store]) : _explicitStore = store;

  final LocalStore? _explicitStore;
  LocalStore get _store => _explicitStore ?? LocalStore.instance;

  @override
  Future<bool> isFirstRun() => _store.isFirstRun();

  @override
  Future<void> markFirstRunCompleted() => _store.markFirstRunCompleted();

  /// Known trip names of legacy seeded demo budgets.
  static const Set<String> seededTripNames = {
    'Alpine Ridge Tour',
    'Karakoram Highway Expedition',
  };

  /// Known IDs of legacy seeded demo expenses.
  static const Set<String> seededExpenseIds = {
    'exp-1',
    'exp-2',
    'exp-3',
    'exp-4',
    'exp-5',
    'exp-6',
  };

  /// Determines whether a budget matches the legacy demo seed budget.
  /// Matches strictly by exact seed ID plus exact seed trip name and seed cap amount,
  /// never by trip name alone. A real trip named "Alpine Ridge Tour" or
  /// "Karakoram Highway Expedition" entered by the rider must survive.
  static bool isSeededBudget(TripBudget budget) {
    final isSeedId = budget.id == 'budget-active' || budget.id == 'budget-seed-alpine';
    final isSeedName = seededTripNames.contains(budget.tripName.trim());
    final isSeedCap = (budget.capAmount == 250.0 && budget.allocatedSoFar == 145.0) ||
        (budget.capAmount == 75000.0 && budget.allocatedSoFar == 46125.0);
    return isSeedId && isSeedName && isSeedCap;
  }

  /// Determines whether an expense matches the legacy demo seed expenses.
  /// Matches strictly by exact seed ID, never by note or subtitle pattern alone.
  static bool isSeededExpense(Expense expense) {
    return seededExpenseIds.contains(expense.id.trim());
  }

  @override
  Future<TripBudget?> loadBudget() async {
    final isFirst = await _store.isFirstRun();
    if (!isFirst) {
      final schemaVer = await _store.getSchemaVersion();
      if (schemaVer == null || schemaVer > LocalStore.currentSchemaVersion) {
        throw const FormatException('Incompatible schema version');
      }
    }

    final json = await _store.readJson(LocalStore.keyTripBudget);
    if (json == null) {
      return null;
    }
    if (json is! Map) {
      if (!isFirst) {
        throw const FormatException('Corrupted trip budget data');
      }
      return null;
    }
    final map = json is Map<String, dynamic> ? json : json.cast<String, dynamic>();
    if (map['tripName'] == null || (map['capAmount'] != null && map['capAmount'] is! num)) {
      throw const FormatException('Corrupted trip budget data');
    }

    final budget = TripBudget.fromJson(map);

    // One-time cleanup: remove saved legacy demo budget.
    // Budgets entered by the rider are never touched.
    if (isSeededBudget(budget)) {
      await deleteBudget();
      return null;
    }

    final hasGeneratedId = (map['id'] == null || (map['id'] as String).isEmpty);
    final hasMissingDates = map['createdAt'] == null || map['updatedAt'] == null;
    if (hasGeneratedId || hasMissingDates) {
      await saveBudget(budget);
    }
    return budget;
  }

  @override
  Future<void> saveBudget(TripBudget? budget) async {
    if (budget == null) {
      await deleteBudget();
      return;
    }

    final updated = budget.copyWith(
      id: budget.effectiveId,
      createdAt: budget.effectiveCreatedAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await _store.writeJson(LocalStore.keyTripBudget, updated.toJson());
  }

  @override
  Future<void> deleteBudget() async {
    await _store.writeJson(LocalStore.keyTripBudget, null);
  }

  @override
  Future<List<Expense>> loadExpenses() async {
    final isFirst = await _store.isFirstRun();
    if (!isFirst) {
      final schemaVer = await _store.getSchemaVersion();
      if (schemaVer == null || schemaVer > LocalStore.currentSchemaVersion) {
        throw const FormatException('Incompatible schema version');
      }
    }

    final json = await _store.readJson(LocalStore.keyTripExpenses);
    if (json == null || json is! List) {
      if (!isFirst) {
        throw const FormatException('Corrupted expenses data');
      }
      return [];
    }

    bool needsMigration = false;
    final expenses = <Expense>[];

    for (int i = 0; i < json.length; i++) {
      final raw = json[i];
      if (raw is Map) {
        final map = raw is Map<String, dynamic> ? raw : raw.cast<String, dynamic>();
        final expense = Expense.fromJson(map);

        // One-time cleanup: remove saved legacy demo expenses.
        // Expenses entered by the rider are never touched.
        if (isSeededExpense(expense)) {
          needsMigration = true;
          continue;
        }

        if (expense.id.isEmpty || map['id'] == null || (map['id'] as String).isEmpty) {
          needsMigration = true;
          expenses.add(expense.copyWith(id: 'expense_${DateTime.now().millisecondsSinceEpoch}_$i'));
        } else {
          if (map['createdAt'] == null || map['updatedAt'] == null) {
            needsMigration = true;
          }
          expenses.add(expense);
        }
      }
    }

    if (needsMigration) {
      await saveExpenses(expenses);
    }

    return expenses;
  }

  @override
  Future<void> saveExpenses(List<Expense> expenses) async {
    final now = DateTime.now().toUtc();
    final updated = expenses.map((e) {
      return e.copyWith(
        id: e.effectiveId,
        createdAt: e.effectiveCreatedAt,
        updatedAt: now,
      );
    }).toList();

    await _store.writeJson(
      LocalStore.keyTripExpenses,
      updated.map((e) => e.toJson()).toList(),
    );
  }

  @override
  Future<void> deleteExpense(String id) async {
    final current = await loadExpenses();
    final filtered = current.where((e) => e.effectiveId != id).toList();
    await saveExpenses(filtered);
  }

  @override
  Future<void> clear() async {
    await _store.writeJson(LocalStore.keyTripBudget, null);
    await _store.writeJson(LocalStore.keyTripExpenses, null);
  }

  @override
  Future<void> flush() async {
    await _store.flush();
  }
}

FinanceRepository resolveFinanceRepository(dynamic source, [FinanceRepository? fallback]) {
  if (source is FinanceRepository) return source;
  if (source is LocalStore) return FinanceRepositoryLocal(source);
  return fallback ?? FinanceRepositoryLocal();
}
