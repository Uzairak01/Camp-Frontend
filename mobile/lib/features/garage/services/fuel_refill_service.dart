import '../../maintenance/controllers/trip_budget_controller.dart';
import '../../maintenance/domain/expense_model.dart';
import '../controllers/active_bike_controller.dart';
import '../domain/fuel_estimator.dart';
import 'fuel_tracker_service.dart';

/// Single source of truth for recording and adjusting motorcycle fuel refills.
///
/// Ensures fuel level calculations and expense records are executed consistently
/// across the Home refill sheet, the Add Expense screen, and expense edits.
class FuelRefillService {
  const FuelRefillService._();

  /// Record a new refill or edit an existing refill.
  ///
  /// - Saves exactly one expense into [TripBudgetController].
  /// - Updates the target bike's fuel level in [ActiveBikeController].
  /// - If [isFullTank] is true on a new refill (or newly turned on during edit),
  ///   the fuel level is set to the tank capacity.
  /// - On edit, adjusts the fuel level only by the difference in litres.
  /// - On new refill, rises by the litres entered, capped at tank capacity.
  /// - Resets low fuel warning if fuel percentage is >= 15%.
  static Future<Expense> recordRefill({
    required String? bikeId,
    required double litres,
    required double pricePerLitre,
    required double total,
    required bool isFullTank,
    Expense? existingExpense,
    DateTime? dateRecorded,
    String? subtitle,
    String? note,
    ExpenseTrackingMode trackingMode = ExpenseTrackingMode.manualEntry,
    double? fuelAverageKmPerLiter,
  }) async {
    final bikeController = ActiveBikeController.instance;
    final targetBike = (bikeId != null ? bikeController.getBikeById(bikeId) : null) ??
        bikeController.activeBike;

    if (targetBike != null) {
      final tankCapacity = (targetBike.fuelTankCapacityLiters != null &&
              targetBike.fuelTankCapacityLiters! > 0)
          ? targetBike.fuelTankCapacityLiters!
          : 20.0;
      final currentRemaining = targetBike.fuelRemainingLiters ?? 0.0;
      final currentOdo = targetBike.preciseOdometerKm ??
          targetBike.odometerKm.toDouble();

      final double newRemaining;
      if (existingExpense != null) {
        // Editing a refill adjusts the fuel level only by the difference in litres.
        final oldIsFull = existingExpense.isFullTank;
        final oldLitres = existingExpense.litres ?? 0.0;
        final diff = litres - oldLitres;

        if (!oldIsFull && isFullTank) {
          // Flag was just toggled on to full tank
          newRemaining = tankCapacity;
        } else {
          newRemaining = (currentRemaining + diff).clamp(0.0, tankCapacity);
        }
      } else {
        if (isFullTank) {
          newRemaining = tankCapacity;
        } else {
          newRemaining = (currentRemaining + litres).clamp(0.0, tankCapacity);
        }
      }

      final isFull = isFullTank || (newRemaining >= tankCapacity - 0.2);
      final updatedBike = targetBike.copyWith(
        fuelRemainingLiters: double.parse(newRemaining.toStringAsFixed(1)),
        fuelLevelOdometerKm: currentOdo,
        fuelAverageKmPerLiter: fuelAverageKmPerLiter ?? targetBike.fuelAverageKmPerLiter,
        lastFullRefillOdometer:
            isFull ? currentOdo : targetBike.lastFullRefillOdometer,
        lastFuelUpdate: DateTime.now(),
      );
      bikeController.updateBike(updatedBike);

      final pct = FuelEstimator.percent(newRemaining, tankCapacity);
      if (pct != null && pct >= 15.0) {
        FuelTrackerService.instance.resetLowFuelFlag();
      }
    }

    final litresStr = litres.truncateToDouble() == litres
        ? litres.toInt().toString()
        : litres.toStringAsFixed(1);
    final roundedPrice = double.parse(pricePerLitre.toStringAsFixed(2));
    final roundedTotal = total.roundToDouble();
    final expenseTitle = 'Fuel Refill ($litresStr L)';
    final effectiveBikeId = targetBike?.id ?? bikeId;

    if (existingExpense != null) {
      final updated = existingExpense.copyWith(
        title: expenseTitle,
        amount: roundedTotal,
        litres: litres,
        pricePerLitre: roundedPrice,
        isFullTank: isFullTank,
        bikeId: effectiveBikeId,
        dateRecorded: dateRecorded ?? existingExpense.dateRecorded,
        subtitle: subtitle ?? existingExpense.subtitle,
        note: note ?? existingExpense.note,
        updatedAt: DateTime.now().toUtc(),
      );
      TripBudgetController.instance.updateExpense(updated);
      return updated;
    } else {
      final newExp = Expense(
        id: 'exp-fuel-${DateTime.now().millisecondsSinceEpoch}',
        title: expenseTitle,
        amount: roundedTotal,
        litres: litres,
        pricePerLitre: roundedPrice,
        isFullTank: isFullTank,
        category: ExpenseCategory.fuel,
        bikeId: effectiveBikeId,
        dateRecorded: dateRecorded ?? DateTime.now(),
        trackingMode: trackingMode,
        subtitle: subtitle ??
            (targetBike != null
                ? '${targetBike.make} ${targetBike.modelName}'
                : null),
        note: note,
      );
      TripBudgetController.instance.addExpense(newExp);
      return newExp;
    }
  }

  /// Sets the fuel level directly (e.g. from the Home fuel gauge slider),
  /// clamping to tank capacity and resetting the low fuel alert if >= 15%.
  static void setFuelLevel({
    required String? bikeId,
    required double litres,
  }) {
    final bikeController = ActiveBikeController.instance;
    final targetBike = (bikeId != null ? bikeController.getBikeById(bikeId) : null) ??
        bikeController.activeBike;
    if (targetBike == null) return;

    final tankCapacity = (targetBike.fuelTankCapacityLiters != null &&
            targetBike.fuelTankCapacityLiters! > 0)
        ? targetBike.fuelTankCapacityLiters!
        : 20.0;
    final currentOdo = targetBike.preciseOdometerKm ?? targetBike.odometerKm.toDouble();
    final clamped = litres.clamp(0.0, tankCapacity);
    final updated = targetBike.copyWith(
      fuelRemainingLiters: double.parse(clamped.toStringAsFixed(1)),
      fuelLevelOdometerKm: currentOdo,
      lastFuelUpdate: DateTime.now(),
    );
    bikeController.updateBike(updated);

    final pct = FuelEstimator.percent(clamped, tankCapacity);
    if (pct != null && pct >= 15.0) {
      FuelTrackerService.instance.resetLowFuelFlag();
    }
  }
}
