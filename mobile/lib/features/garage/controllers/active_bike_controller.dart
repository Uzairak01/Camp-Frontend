import 'package:flutter/foundation.dart';

import '../../../core/data/app_repositories.dart';
import '../../../core/data/bike_repository.dart';
import '../../../core/data/bike_repository_local.dart';
import '../domain/bike_model.dart';

/// Central state controller managing the rider's garage fleet and the current active telemetry rig.
/// Provides reactive state for both the Garage overview screen and individual BikeProfileScreens.
class ActiveBikeController extends ChangeNotifier {
  ActiveBikeController({BikeRepository? repository})
      : _repository = repository ?? AppRepositories.instance.bikeRepository;

  /// Shared singleton instance across the application.
  static ActiveBikeController instance = ActiveBikeController();

  BikeRepository _repository;

  @visibleForTesting
  set repository(BikeRepository repo) => _repository = repo;

  /// Registered motorcycles in the rider's garage fleet.
  final List<Bike> _bikes = [];

  /// Unique identifier of the motorcycle currently selected as the active rig.
  String? _activeBikeId;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<Bike> get bikes => List.unmodifiable(_bikes);

  String? get activeBikeId => _activeBikeId;

  Bike? get activeBike {
    if (_activeBikeId == null) {
      return _bikes.isNotEmpty ? _bikes.first : null;
    }
    return _bikes.cast<Bike?>().firstWhere(
          (b) => b?.id == _activeBikeId,
          orElse: () => _bikes.isNotEmpty ? _bikes.first : null,
        );
  }

  bool isActive(String bikeId) => _activeBikeId == bikeId;

  Bike? getBikeById(String id) {
    return _bikes.cast<Bike?>().firstWhere(
          (b) => b?.id == id,
          orElse: () => null,
        );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Designate a motorcycle as the active telemetry rig.
  void setActiveBike(String bikeId) {
    if (_activeBikeId == bikeId) return;
    final exists = _bikes.any((b) => b.id == bikeId);
    if (exists) {
      _activeBikeId = bikeId;
      notifyListeners();
      save();
    }
  }

  /// Remove a motorcycle from the garage.
  /// If the removed bike was active, sets the active rig to the first remaining bike.
  void removeBike(String bikeId) {
    final index = _bikes.indexWhere((b) => b.id == bikeId);
    if (index != -1) {
      _bikes.removeAt(index);
      if (_activeBikeId == bikeId) {
        _activeBikeId = _bikes.isNotEmpty ? _bikes.first.id : null;
      }
      notifyListeners();
      save();
    }
  }

  /// Register a new motorcycle into the garage fleet.
  void addBike(Bike bike, {bool setActive = false}) {
    _bikes.add(bike);
    if (setActive || _bikes.length == 1) {
      _activeBikeId = bike.id;
    }
    notifyListeners();
    save();
  }

  /// Update specifications or telemetry milestone records of an existing bike.
  /// If the odometer reading is corrected downwards below [fuelLevelOdometerKm],
  /// [fuelLevelOdometerKm] is automatically reset to the new odometer reading so fuel
  /// does not estimate above what was set.
  void updateBike(Bike updatedBike) {
    final currentOdo =
        updatedBike.preciseOdometerKm ?? updatedBike.odometerKm.toDouble();
    var bikeToSave = updatedBike;
    if (bikeToSave.fuelLevelOdometerKm != null &&
        currentOdo < bikeToSave.fuelLevelOdometerKm!) {
      bikeToSave = bikeToSave.copyWith(
        fuelLevelOdometerKm: currentOdo,
      );
    }

    final index = _bikes.indexWhere((b) => b.id == bikeToSave.id);
    if (index != -1) {
      _bikes[index] = bikeToSave;
      notifyListeners();
      save();
    }
  }

  /// Reset the controller to an empty garage fleet.
  void reset() {
    _bikes.clear();
    _activeBikeId = null;
    notifyListeners();
  }

  /// Reset in-memory state for testing without persisting.
  void resetForTesting() {
    _bikes.clear();
    _activeBikeId = null;
    _repository = AppRepositories.instance.bikeRepository;
    notifyListeners();
  }

  /// Await completion of all pending storage writes.
  Future<void> flush() => _repository.flush();

  /// Load garage fleet and active bike selection from persistent store.
  Future<void> load([dynamic source]) async {
    final repo = resolveBikeRepository(source, _repository);
    if (source != null) {
      _repository = repo;
    }
    try {
      final isFirst = await repo.isFirstRun();
      if (isFirst) {
        _bikes.clear();
        _activeBikeId = null;
        await repo.markFirstRunCompleted();
        notifyListeners();
        return;
      }

      final loadedBikes = await repo.loadBikes();
      final activeId = await repo.loadActiveBikeId();

      if (loadedBikes.isEmpty) {
        _bikes.clear();
        _activeBikeId = null;
        notifyListeners();
        return;
      }

      _bikes.clear();
      _bikes.addAll(loadedBikes);
      _activeBikeId = activeId;

      if (_bikes.isNotEmpty &&
          (_activeBikeId == null || !_bikes.any((b) => b.id == _activeBikeId))) {
        _activeBikeId = _bikes.first.id;
      }

      notifyListeners();
    } catch (_) {
      // Fallback without crashing
      _bikes.clear();
      _activeBikeId = null;
      notifyListeners();
    }
  }

  /// Persist current garage fleet and active bike selection.
  Future<void> save([dynamic source]) async {
    final repo = resolveBikeRepository(source, _repository);
    final bikesToSave = List<Bike>.from(_bikes);
    final activeIdToSave = _activeBikeId;
    try {
      await repo.saveBikes(bikesToSave);
      await repo.saveActiveBikeId(activeIdToSave);
    } catch (_) {
      // Ignore background write errors
    }
  }
}
