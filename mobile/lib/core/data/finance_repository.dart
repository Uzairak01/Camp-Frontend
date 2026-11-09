import '../../features/maintenance/domain/expense_model.dart';
import '../../features/maintenance/domain/trip_budget_model.dart';

abstract class FinanceRepository {
  Future<bool> isFirstRun();
  Future<void> markFirstRunCompleted();
  Future<TripBudget?> loadBudget();
  Future<void> saveBudget(TripBudget? budget);
  Future<void> deleteBudget();
  Future<List<Expense>> loadExpenses();
  Future<void> saveExpenses(List<Expense> expenses);
  Future<void> deleteExpense(String id);
  Future<void> clear();
  Future<void> flush();
}
