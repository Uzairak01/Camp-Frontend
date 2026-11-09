import '../../features/maintenance/domain/post_ride_report.dart';

abstract class RideReportRepository {
  Future<bool> isFirstRun();
  Future<void> markFirstRunCompleted();
  Future<List<PostRideReport>> loadReports();
  Future<void> saveReports(List<PostRideReport> reports);
  Future<void> deleteReport(String id);
  Future<void> clear();
  Future<void> flush();
}
