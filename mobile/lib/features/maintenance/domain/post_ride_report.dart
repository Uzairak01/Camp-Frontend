import 'package:flutter/foundation.dart';

/// Domain model representing a user-logged post-ride debrief.
/// Used to compute real-world wear multipliers and ride pattern insights.
@immutable
class PostRideReport {
  const PostRideReport({
    required this.id,
    required this.bikeId,
    required this.date,
    required this.distanceKm,
    required this.terrainTags,
    this.durationHours,
    this.notes,
    this.flaggedIssues,
    String? routeTitle,
    this.source = 'manual',
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.updatedAt,
  }) : explicitRouteTitle = routeTitle;

  factory PostRideReport.fromJson(Map<String, dynamic> json) {
    DateTime? parseUtc(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val)?.toUtc();
      return null;
    }

    final rawId = json['id'] as String?;
    final effectiveId = (rawId != null && rawId.trim().isNotEmpty)
        ? rawId.trim()
        : 'report-${DateTime.now().millisecondsSinceEpoch}';

    final reportDate =
        DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now();
    final createdUtc = parseUtc(json['createdAt']) ?? reportDate.toUtc();
    final updatedUtc = parseUtc(json['updatedAt']) ?? createdUtc;

    final double? parsedDuration = (json['durationHours'] as num?)?.toDouble() ??
        (json['durationMinutes'] != null
            ? (json['durationMinutes'] as num).toDouble() / 60.0
            : null);

    return PostRideReport(
      id: effectiveId,
      createdAt: createdUtc,
      updatedAt: updatedUtc,
      bikeId: json['bikeId'] as String? ?? 'unknown-bike',
      date: reportDate,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      durationHours: parsedDuration,
      terrainTags: (json['terrainTags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      notes: json['notes'] as String?,
      flaggedIssues: json['flaggedIssues'] as String?,
      routeTitle: json['routeTitle'] as String?,
      source: json['source'] as String? ?? 'manual',
      startedAt: parseUtc(json['startedAt']),
      endedAt: parseUtc(json['endedAt']),
    );
  }

  /// Unique identifier for this report log.
  final String id;

  String get effectiveId => id;

  /// Timestamp when report was created (UTC).
  final DateTime? createdAt;

  /// Timestamp when report was last updated (UTC).
  final DateTime? updatedAt;

  DateTime get effectiveCreatedAt => createdAt?.toUtc() ?? date.toUtc();
  DateTime get effectiveUpdatedAt => updatedAt?.toUtc() ?? effectiveCreatedAt;

  /// Identifier of the bike used on the expedition.
  final String bikeId;

  /// Date and time when the ride took place.
  final DateTime date;

  /// Distance covered during the ride in kilometers.
  final double distanceKm;

  /// Riding duration in hours (optional).
  final double? durationHours;

  /// Terrain classifications encountered (e.g., 'City', 'Highway', 'Off-road', 'Mountain').
  final List<String> terrainTags;

  /// General rider notes or trail observations.
  final String? notes;

  /// Optional specific mechanical symptoms or issues flagged during ride.
  final String? flaggedIssues;

  /// Explicit custom or destination route title.
  final String? explicitRouteTitle;

  /// Source provenance: 'tracked' (from FuelTrackerService) or 'manual' (from debrief).
  final String source;

  /// Wall-clock timestamp when tracking started (optional).
  final DateTime? startedAt;

  /// Wall-clock timestamp when tracking finished (optional).
  final DateTime? endedAt;

  /// Whether this report originated from live GPS ride tracking.
  bool get isTracked => source == 'tracked';

  /// Whether this report was manually logged by the rider.
  bool get isManual => source != 'tracked';

  /// Convenience getter for combined notes or flagged issues.
  String? get combinedNotes {
    if (notes != null && notes!.isNotEmpty && flaggedIssues != null && flaggedIssues!.isNotEmpty) {
      return '$notes ($flaggedIssues)';
    }
    return notes ?? flaggedIssues;
  }

  /// Formatted date string in the phone's local time (e.g., 'Oct 14, 2026').
  String get formattedDate {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final local = date.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  /// Primary terrain tag or 'Mixed'.
  String get terrain => terrainTags.isNotEmpty ? terrainTags.first : 'Mixed';

  /// Primary route title: uses explicit route title if set, or notes snippet, or date fallback.
  String get routeTitle {
    if (explicitRouteTitle != null && explicitRouteTitle!.trim().isNotEmpty) {
      return explicitRouteTitle!.trim();
    }
    if (notes != null && notes!.trim().isNotEmpty) {
      final firstLine = notes!.trim().split('\n').first;
      return firstLine.length > 40 ? '${firstLine.substring(0, 40)}...' : firstLine;
    }
    return 'Ride on $formattedDate';
  }

  /// Duration in minutes (computed from durationHours).
  int? get durationMinutes => durationHours != null ? (durationHours! * 60).round() : null;

  PostRideReport copyWith({
    String? id,
    String? bikeId,
    DateTime? date,
    double? distanceKm,
    double? durationHours,
    List<String>? terrainTags,
    String? notes,
    String? flaggedIssues,
    String? routeTitle,
    String? source,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PostRideReport(
      id: id ?? this.id,
      bikeId: bikeId ?? this.bikeId,
      date: date ?? this.date,
      distanceKm: distanceKm ?? this.distanceKm,
      durationHours: durationHours ?? this.durationHours,
      terrainTags: terrainTags ?? this.terrainTags,
      notes: notes ?? this.notes,
      flaggedIssues: flaggedIssues ?? this.flaggedIssues,
      routeTitle: routeTitle ?? explicitRouteTitle,
      source: source ?? this.source,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostRideReport &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          bikeId == other.bikeId &&
          date == other.date &&
          distanceKm == other.distanceKm &&
          durationHours == other.durationHours &&
          listEquals(terrainTags, other.terrainTags) &&
          notes == other.notes &&
          flaggedIssues == other.flaggedIssues &&
          explicitRouteTitle == other.explicitRouteTitle &&
          source == other.source &&
          startedAt == other.startedAt &&
          endedAt == other.endedAt;

  @override
  int get hashCode => Object.hash(
        id,
        bikeId,
        date,
        distanceKm,
        durationHours,
        Object.hashAll(terrainTags),
        notes,
        flaggedIssues,
        explicitRouteTitle,
        source,
        startedAt,
        endedAt,
      );

  @override
  String toString() =>
      'PostRideReport(id: $id, bike: $bikeId, title: $routeTitle, dist: ${distanceKm}km, duration: ${durationHours}h, source: $source, terrain: $terrainTags)';

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': effectiveCreatedAt.toIso8601String(),
        'updatedAt': effectiveUpdatedAt.toIso8601String(),
        'bikeId': bikeId,
        'date': date.toIso8601String(),
        'distanceKm': distanceKm,
        'durationHours': durationHours,
        'terrainTags': terrainTags,
        'notes': notes,
        'flaggedIssues': flaggedIssues,
        'routeTitle': explicitRouteTitle,
        'source': source,
        'startedAt': startedAt?.toUtc().toIso8601String(),
        'endedAt': endedAt?.toUtc().toIso8601String(),
      };
}
