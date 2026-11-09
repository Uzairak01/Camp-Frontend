import 'package:camp/core/data/ride_report_repository.dart';
import 'package:camp/features/maintenance/domain/post_ride_report.dart';

class FakeRideReportRepository implements RideReportRepository {
  FakeRideReportRepository({List<PostRideReport>? initialReports, bool firstRun = false})
      : _reports = List<PostRideReport>.from(initialReports ?? []),
        _isFirstRun = firstRun;

  final List<PostRideReport> _reports;
  bool _isFirstRun;

  @override
  Future<bool> isFirstRun() async => _isFirstRun;

  @override
  Future<void> markFirstRunCompleted() async {
    _isFirstRun = false;
  }

  @override
  Future<List<PostRideReport>> loadReports() async {
    return List.unmodifiable(_reports);
  }

  @override
  Future<void> saveReports(List<PostRideReport> reports) async {
    _reports.clear();
    _reports.addAll(reports);
  }

  @override
  Future<void> deleteReport(String id) async {
    _reports.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> clear() async {
    _reports.clear();
  }

  @override
  Future<void> flush() async {}
}
