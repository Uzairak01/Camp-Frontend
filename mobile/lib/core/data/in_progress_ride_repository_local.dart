import '../storage/local_store.dart';
import 'in_progress_ride_model.dart';
import 'in_progress_ride_repository.dart';

/// Local persistence implementation for [InProgressRideRepository] backed by [LocalStore].
///
/// Ensures tracked ride distance and metadata survive process termination.
class InProgressRideRepositoryLocal implements InProgressRideRepository {
  /// Creates a local repository instance backed by [store] or [LocalStore.instance].
  InProgressRideRepositoryLocal([LocalStore? store]) : _explicitStore = store;

  final LocalStore? _explicitStore;
  LocalStore get _store => _explicitStore ?? LocalStore.instance;

  /// Key under which in-progress ride state is saved in [LocalStore].
  static const String keyInProgressRide = 'camp_in_progress_ride';

  @override
  Future<InProgressRide?> loadInProgressRide() async {
    final json = await _store.readJson(keyInProgressRide);
    if (json is! Map) {
      return null;
    }
    final map = json is Map<String, dynamic> ? json : json.cast<String, dynamic>();
    return InProgressRide.fromJson(map);
  }

  @override
  Future<void> saveInProgressRide(InProgressRide ride) async {
    await _store.writeJson(keyInProgressRide, ride.toJson());
  }

  @override
  Future<void> clear() async {
    await _store.remove(keyInProgressRide);
  }

  @override
  Future<void> flush() async {
    await _store.flush();
  }
}

