import 'bike_model.dart';

/// Pure logic for motorcycle fuel estimation and consumption calculations.
/// IMPORTANT: Contains NO Flutter UI imports.
class FuelEstimator {
  const FuelEstimator._();

  /// Computes the current remaining fuel volume in liters from the bike's
  /// baseline fuel volume, baseline odometer reading, and current odometer reading:
  /// clamp(fuelRemainingLiters - (currentOdometer - fuelLevelOdometerKm) / fuelAverageKmPerLiter, 0, tankCapacity)
  static double? currentLiters(Bike? bike) {
    if (bike == null) return null;
    final baseLiters = bike.fuelRemainingLiters;
    if (baseLiters == null) return null;
    final currentOdo = bike.preciseOdometerKm ?? bike.odometerKm.toDouble();
    final baseOdo = bike.fuelLevelOdometerKm ?? currentOdo;
    return computeCurrentLiters(
      fuelRemainingLiters: baseLiters,
      currentOdometer: currentOdo,
      fuelLevelOdometerKm: baseOdo,
      fuelAverageKmPerLiter: bike.fuelAverageKmPerLiter,
      tankCapacity: bike.fuelTankCapacityLiters,
    );
  }

  /// Pure mathematical computation of current fuel level:
  /// clamp(fuelRemainingLiters - (currentOdometer - fuelLevelOdometerKm) / fuelAverageKmPerLiter, 0, tankCapacity)
  static double? computeCurrentLiters({
    required double? fuelRemainingLiters,
    required double? currentOdometer,
    required double? fuelLevelOdometerKm,
    required double? fuelAverageKmPerLiter,
    required double? tankCapacity,
  }) {
    if (fuelRemainingLiters == null) return null;
    final currentOdo = currentOdometer ?? 0.0;
    final baseOdo = fuelLevelOdometerKm ?? currentOdo;
    final distanceSinceSet = currentOdo - baseOdo;

    if (fuelAverageKmPerLiter == null ||
        fuelAverageKmPerLiter <= 0 ||
        distanceSinceSet <= 0) {
      if (tankCapacity != null && tankCapacity > 0) {
        return fuelRemainingLiters.clamp(0.0, tankCapacity);
      }
      return fuelRemainingLiters < 0.0 ? 0.0 : fuelRemainingLiters;
    }

    final consumed = distanceSinceSet / fuelAverageKmPerLiter;
    final remaining = fuelRemainingLiters - consumed;
    final maxCap = (tankCapacity != null && tankCapacity > 0)
        ? tankCapacity
        : double.infinity;
    return remaining.clamp(0.0, maxCap);
  }

  /// Applies distance traveled [km] to [currentLiters] given consumption [kmPerLiter].
  /// Returns updated fuel in liters, clamped to never fall below 0.0.
  /// If [currentLiters] is null, returns null.
  /// If [kmPerLiter] is null or <= 0, or [km] <= 0, returns [currentLiters].
  static double? applyDistance(
    double? currentLiters,
    double km,
    double? kmPerLiter,
  ) {
    if (currentLiters == null) return null;
    if (kmPerLiter == null || kmPerLiter <= 0 || km <= 0) return currentLiters;
    final consumed = km / kmPerLiter;
    final remaining = currentLiters - consumed;
    return remaining < 0.0 ? 0.0 : remaining;
  }

  /// Calculates estimated range in km: liters * kmPerLiter.
  /// Returns null when liters is null or kmPerLiter is missing/non-positive.
  static double? rangeKm(double? liters, double? kmPerLiter) {
    if (liters == null || kmPerLiter == null || kmPerLiter <= 0) return null;
    return liters * kmPerLiter;
  }

  /// Calculates fuel percentage (0.0 to 100.0) based on [liters] and [tankCapacityL].
  /// Returns null when liters is null or tankCapacityL is missing/non-positive.
  static double? percent(double? liters, double? tankCapacityL) {
    if (liters == null || tankCapacityL == null || tankCapacityL <= 0) {
      return null;
    }
    return ((liters / tankCapacityL) * 100.0).clamp(0.0, 100.0);
  }

  /// Computes actual fuel consumption efficiency (km/L) between two full refills:
  /// distance tracked between them / liters added.
  /// Returns null if distance or liters added is non-positive.
  static double? computeFullToFullEfficiency(
    double distanceKm,
    double litersAdded,
  ) {
    if (distanceKm <= 0 || litersAdded <= 0) return null;
    return distanceKm / litersAdded;
  }
}
