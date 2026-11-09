import 'package:camp/core/data/in_progress_ride_model.dart';
import 'package:camp/core/data/in_progress_ride_repository.dart';

/// Test fake for [InProgressRideRepository] maintaining state in memory.
class FakeInProgressRideRepository implements InProgressRideRepository {
  InProgressRide? _savedRide;
  int saveCount = 0;
  int clearCount = 0;

  InProgressRide? get savedRide => _savedRide;

  @override
  Future<InProgressRide?> loadInProgressRide() async {
    return _savedRide;
  }

  @override
  Future<void> saveInProgressRide(InProgressRide ride) async {
    _savedRide = ride;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    _savedRide = null;
    clearCount++;
  }

  @override
  Future<void> flush() async {}
}

