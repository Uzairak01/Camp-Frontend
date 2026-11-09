import 'in_progress_ride_model.dart';

/// Abstract contract for reading and writing active in-progress ride state.
///
/// Follows the repository pattern used by other CAMP services, supporting
/// both local on-device persistence and mock test fakes.
abstract class InProgressRideRepository {
  /// Loads the saved in-progress ride state, or returns null if no ride was running.
  Future<InProgressRide?> loadInProgressRide();

  /// Saves or updates the currently active in-progress ride state.
  Future<void> saveInProgressRide(InProgressRide ride);

  /// Clears the persisted in-progress ride (called upon finishing or discarding).
  Future<void> clear();

  /// Awaits all pending disk writes.
  Future<void> flush();
}

