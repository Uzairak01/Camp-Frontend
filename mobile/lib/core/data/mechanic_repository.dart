import '../../features/mechanics/domain/mechanic_model.dart';

abstract class MechanicRepository {
  Future<bool> isFirstRun();
  Future<void> markFirstRunCompleted();
  Future<List<Mechanic>> loadMechanics();
  Future<void> saveMechanics(List<Mechanic> mechanics);
  Future<void> deleteMechanic(String id);
  Future<void> clear();
  Future<void> flush();
}
