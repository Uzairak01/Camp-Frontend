import 'package:flutter/foundation.dart';

import '../../../core/data/app_repositories.dart';
import '../../../core/data/ride_report_repository.dart';
import '../../../core/data/ride_report_repository_local.dart';
import '../domain/post_ride_report.dart';

/// Central state controller managing user-logged post-ride debriefs.
/// Follows the singleton ChangeNotifier pattern established by ActiveBikeController
/// and SettingsController, serving as the single source of truth for ride logs
/// and pattern insight computations.
class PostRideReportController extends ChangeNotifier {
  PostRideReportController({RideReportRepository? repository})
      : _repository = repository ?? AppRepositories.instance.rideReportRepository;

  /// Global singleton instance.
  static PostRideReportController instance = PostRideReportController();

  /// Known IDs of legacy seeded demo rides.
  static const Set<String> seededRideIds = {
    'rep-bmw-1',
    'rep-bmw-2',
    'rep-bmw-3',
    'rep-bmw-4',
    'rep-bmw-5',
    'demo-latest',
  };

  /// Exact notes or titles of legacy seeded demo rides.
  static const Set<String> seededRideNotes = {
    'Babusar Pass ascent over rocky trail and loose scree.',
    'Expressway transit leg at steady 110 km/h cruising.',
    'River valley gravel track and stream ford crossings.',
    'Urban stop-and-go commute in moderate ambient heat.',
    'Alpine ridge loop with elevation climb from 1,200m to 3,100m.',
    'Babusar Pass Summit & Alpine Ridge',
    'Karakoram High-Altitude Corridor',
    'Makran Coastal Highway & Mud Volcanoes',
    'Cholistan Desert Sand Nav Loop',
  };

  /// Determines whether a report is one of the legacy demo seed rides.
  static bool isSeededReport(PostRideReport report) {
    if (seededRideIds.contains(report.id)) return true;
    final notes = report.notes?.trim();
    if (notes != null && seededRideNotes.contains(notes)) return true;
    return false;
  }

  RideReportRepository _repository;

  @visibleForTesting
  set repository(RideReportRepository repo) => _repository = repo;

  final List<PostRideReport> _reports = [];

  /// All stored post-ride reports across all bikes.
  List<PostRideReport> get reports => List.unmodifiable(_reports);

  /// Get all reports for a specific bike, ordered by most recent first.
  List<PostRideReport> getReportsForBike(String bikeId) {
    final bikeReports = _reports.where((r) => r.bikeId == bikeId).toList();
    bikeReports.sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(bikeReports);
  }

  /// Add a new post-ride report for a motorcycle.
  void addReport(PostRideReport report) {
    _reports.insert(0, report);
    notifyListeners();
    save();
  }

  /// Update an existing post-ride report in-place, preserving position in the list.
  /// If the report does not exist in memory, it is inserted at the top.
  void updateReport(PostRideReport updatedReport) {
    final index = _reports.indexWhere((r) => r.id == updatedReport.id);
    if (index != -1) {
      _reports[index] = updatedReport;
      notifyListeners();
      save();
    } else {
      addReport(updatedReport);
    }
  }

  /// Insert a post-ride report at a specific index (used for undo operations).
  void insertReport(int index, PostRideReport report) {
    final clampedIndex = index.clamp(0, _reports.length);
    _reports.insert(clampedIndex, report);
    notifyListeners();
    save();
  }

  /// Remove a specific post-ride report by ID.
  void removeReport(String reportId) {
    final index = _reports.indexWhere((r) => r.id == reportId);
    if (index != -1) {
      _reports.removeAt(index);
      notifyListeners();
      save();
    }
  }

  /// Clear all logged reports for a bike.
  void clearReportsForBike(String bikeId) {
    _reports.removeWhere((r) => r.bikeId == bikeId);
    notifyListeners();
    save();
  }

  /// Reset the controller back to an empty list.
  void reset() {
    _reports.clear();
    notifyListeners();
  }

  /// Reset to completely empty list and persist to disk (restricted to tests).
  @visibleForTesting
  Future<void> clearAll() async {
    _reports.clear();
    notifyListeners();
    await save();
  }

  /// Await completion of all pending storage writes.
  Future<void> flush() => _repository.flush();

  /// Load post-ride reports from repository.
  Future<void> load([dynamic source]) async {
    final repo = resolveRideReportRepository(source, _repository);
    if (source != null) {
      _repository = repo;
    }
    final isFirst = await repo.isFirstRun();

    if (isFirst) {
      _reports.clear();
      await save(repo);
      return;
    }

    try {
      final loadedReports = await repo.loadReports();
      final cleanedReports =
          loadedReports.where((r) => !isSeededReport(r)).toList();
      final hadSeeded = cleanedReports.length != loadedReports.length;

      _reports.clear();
      _reports.addAll(cleanedReports);
      notifyListeners();

      if (hadSeeded) {
        // Persist cleaned list to disk to permanently clean test phones
        await save(repo);
      }
    } catch (_) {
      // Fallback on corrupt data
      _reports.clear();
      notifyListeners();
    }
  }

  /// Persist post-ride reports to repository.
  Future<void> save([dynamic source]) async {
    final repo = resolveRideReportRepository(source, _repository);
    try {
      await repo.saveReports(_reports);
    } catch (_) {
      // Ignore background write errors
    }
  }
}
