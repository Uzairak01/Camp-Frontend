import 'package:flutter/foundation.dart';

/// State model representing an in-progress tracked ride persisted to storage.
///
/// Ensures ride progress (start time, distance in km, active bike, route title)
/// survives sudden process kills, screen lock suspensions, or OS background kills,
/// allowing the rider to finish or discard the ride on next app start.
@immutable
class InProgressRide {
  const InProgressRide({
    required this.id,
    required this.startedAt,
    required this.distanceKm,
    this.bikeId,
    this.routeTitle,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor parsing tolerant JSON from persistent local storage.
  factory InProgressRide.fromJson(Map<String, dynamic> json) {
    DateTime? parseUtc(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val)?.toUtc();
      return null;
    }

    final rawId = json['id'] as String?;
    final effectiveId = (rawId != null && rawId.trim().isNotEmpty)
        ? rawId.trim()
        : 'in-progress-${DateTime.now().millisecondsSinceEpoch}';

    final started = parseUtc(json['startedAt']) ?? DateTime.now().toUtc();
    final createdUtc = parseUtc(json['createdAt']) ?? started;
    final updatedUtc = parseUtc(json['updatedAt']) ?? createdUtc;

    return InProgressRide(
      id: effectiveId,
      startedAt: started,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      bikeId: json['bikeId'] as String?,
      routeTitle: json['routeTitle'] as String?,
      createdAt: createdUtc,
      updatedAt: updatedUtc,
    );
  }

  /// Persistent identifier for this in-progress ride state.
  final String id;

  /// Timestamp when tracking started.
  final DateTime startedAt;

  /// Distance accumulated so far in kilometers.
  final double distanceKm;

  /// Identifier of the motorcycle being ridden.
  final String? bikeId;

  /// Optional route or destination title.
  final String? routeTitle;

  /// Timestamp when record was created (UTC).
  final DateTime? createdAt;

  /// Timestamp when record was last updated (UTC).
  final DateTime? updatedAt;

  DateTime get effectiveCreatedAt => createdAt?.toUtc() ?? startedAt.toUtc();
  DateTime get effectiveUpdatedAt => updatedAt?.toUtc() ?? effectiveCreatedAt;

  InProgressRide copyWith({
    String? id,
    DateTime? startedAt,
    double? distanceKm,
    String? bikeId,
    String? routeTitle,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InProgressRide(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      distanceKm: distanceKm ?? this.distanceKm,
      bikeId: bikeId ?? this.bikeId,
      routeTitle: routeTitle ?? this.routeTitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InProgressRide &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          startedAt == other.startedAt &&
          distanceKm == other.distanceKm &&
          bikeId == other.bikeId &&
          routeTitle == other.routeTitle;

  @override
  int get hashCode => Object.hash(
        id,
        startedAt,
        distanceKm,
        bikeId,
        routeTitle,
      );

  @override
  String toString() =>
      'InProgressRide(id: $id, dist: ${distanceKm}km, started: $startedAt, title: $routeTitle)';

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'distanceKm': distanceKm,
        'bikeId': bikeId,
        'routeTitle': routeTitle,
        'createdAt': effectiveCreatedAt.toIso8601String(),
        'updatedAt': effectiveUpdatedAt.toIso8601String(),
      };
}

