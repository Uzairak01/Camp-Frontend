import '../../features/garage/domain/bike_model.dart';

abstract class BikeRepository {
  Future<bool> isFirstRun();
  Future<void> markFirstRunCompleted();
  Future<List<Bike>> loadBikes();
  Future<void> saveBikes(List<Bike> bikes);
  Future<String?> loadActiveBikeId();
  Future<void> saveActiveBikeId(String? id);
  Future<void> deleteBike(String id);
  Future<void> clear();
  Future<void> flush();
}
