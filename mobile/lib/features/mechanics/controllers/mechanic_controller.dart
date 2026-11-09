import 'package:flutter/foundation.dart';
import '../../../core/data/app_repositories.dart';
import '../../../core/data/mechanic_repository.dart';
import '../../../core/data/mechanic_repository_local.dart';
import '../domain/mechanic_model.dart';

/// Central state controller managing mechanics and emergency field workshops.
/// Persisted via [MechanicRepository].
class MechanicController extends ChangeNotifier {
  MechanicController({MechanicRepository? repository})
      : _repository = repository ?? AppRepositories.instance.mechanicRepository;

  static MechanicController instance = MechanicController();

  MechanicRepository _repository;

  @visibleForTesting
  set repository(MechanicRepository repo) => _repository = repo;

  final List<Mechanic> _mechanics = [];

  List<Mechanic> get mechanics => List.unmodifiable(_mechanics);

  void addMechanic(Mechanic mechanic) {
    _mechanics.insert(0, mechanic);
    notifyListeners();
    save();
  }

  void updateMechanic(Mechanic mechanic) {
    final index = _mechanics.indexWhere((m) => m.id == mechanic.id);
    if (index != -1) {
      _mechanics[index] = mechanic;
      notifyListeners();
      save();
    }
  }

  void editMechanic(Mechanic mechanic) => updateMechanic(mechanic);

  void deleteMechanic(String id) {
    _mechanics.removeWhere((m) => m.id == id);
    notifyListeners();
    save();
  }

  /// Await completion of all pending storage writes.
  Future<void> flush() => _repository.flush();

  @visibleForTesting
  void resetForTesting() {
    _mechanics.clear();
    _repository = AppRepositories.instance.mechanicRepository;
    notifyListeners();
  }

  /// Load mechanics list from repository.
  /// Honest pass: no demo seeding, release and debug builds both start empty.
  Future<void> load([dynamic source]) async {
    final repo = resolveMechanicRepository(source, _repository);
    if (source != null) {
      _repository = repo;
    }
    final isFirst = await repo.isFirstRun();

    if (isFirst) {
      _mechanics.clear();
      await repo.markFirstRunCompleted();
      await save(repo);
      notifyListeners();
      return;
    }

    try {
      final loaded = await repo.loadMechanics();
      _mechanics.clear();
      _mechanics.addAll(loaded);
      notifyListeners();
    } catch (_) {
      // Gracefully fall back
    }
  }

  /// Save mechanics list to repository.
  Future<void> save([dynamic source]) async {
    final repo = resolveMechanicRepository(source, _repository);
    await repo.saveMechanics(_mechanics);
  }
}

