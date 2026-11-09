import '../../features/maintenance/controllers/post_ride_report_controller.dart';
import '../../features/maintenance/domain/post_ride_report.dart';
import '../storage/local_store.dart';
import 'ride_report_repository.dart';

class RideReportRepositoryLocal implements RideReportRepository {
  RideReportRepositoryLocal([LocalStore? store]) : _explicitStore = store;

  final LocalStore? _explicitStore;
  LocalStore get _store => _explicitStore ?? LocalStore.instance;

  @override
  Future<bool> isFirstRun() => _store.isFirstRun();

  @override
  Future<void> markFirstRunCompleted() => _store.markFirstRunCompleted();

  @override
  Future<List<PostRideReport>> loadReports() async {
    final isFirst = await _store.isFirstRun();
    if (!isFirst) {
      final schemaVer = await _store.getSchemaVersion();
      if (schemaVer == null || schemaVer > LocalStore.currentSchemaVersion) {
        throw const FormatException('Incompatible schema version');
      }
    }

    final json = await _store.readJson(LocalStore.keyRideReports);
    if (json == null || json is! List) {
      if (!isFirst) {
        throw const FormatException('Corrupted ride reports data');
      }
      return [];
    }

    bool needsMigration = false;
    final reports = <PostRideReport>[];

    for (int i = 0; i < json.length; i++) {
      final raw = json[i];
      if (raw is Map) {
        final map = raw is Map<String, dynamic> ? raw : raw.cast<String, dynamic>();
        final report = PostRideReport.fromJson(map);
        if (PostRideReportController.isSeededReport(report)) {
          needsMigration = true;
          continue;
        }
        if (report.id.isEmpty || map['id'] == null || (map['id'] as String).isEmpty) {
          needsMigration = true;
          reports.add(report.copyWith(id: 'report_${DateTime.now().millisecondsSinceEpoch}_$i'));
        } else {
          if (map['createdAt'] == null || map['updatedAt'] == null) {
            needsMigration = true;
          }
          reports.add(report);
        }
      }
    }

    if (needsMigration) {
      await saveReports(reports);
    }

    return reports;
  }

  @override
  Future<void> saveReports(List<PostRideReport> reports) async {
    final now = DateTime.now().toUtc();
    final updated = reports.map((r) {
      return r.copyWith(
        id: r.effectiveId,
        createdAt: r.effectiveCreatedAt,
        updatedAt: now,
      );
    }).toList();

    await _store.writeJson(
      LocalStore.keyRideReports,
      updated.map((r) => r.toJson()).toList(),
    );
  }

  @override
  Future<void> deleteReport(String id) async {
    final current = await loadReports();
    final filtered = current.where((r) => r.effectiveId != id).toList();
    await saveReports(filtered);
  }

  @override
  Future<void> clear() async {
    await _store.writeJson(LocalStore.keyRideReports, null);
  }

  @override
  Future<void> flush() async {
    await _store.flush();
  }
}

RideReportRepository resolveRideReportRepository(dynamic source, [RideReportRepository? fallback]) {
  if (source is RideReportRepository) return source;
  if (source is LocalStore) return RideReportRepositoryLocal(source);
  return fallback ?? RideReportRepositoryLocal();
}
