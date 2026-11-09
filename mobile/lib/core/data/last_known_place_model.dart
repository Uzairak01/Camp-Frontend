/// Domain model representing the persisted last-known place label and coordinates.
///
/// Used for cold-start instant location rendering on Home, SOS, and Maps screens
/// before a live GPS fix and reverse-geocoding response arrive from phone sensors.
class LastKnownPlace {
  /// Creates an immutable [LastKnownPlace] snapshot.
  const LastKnownPlace({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Tolerant factory converting a raw JSON map into a [LastKnownPlace] instance.
  /// Handles numeric conversions, null safety, and missing timestamps gracefully.
  factory LastKnownPlace.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    final rawId = json['id'] as String?;
    final rawLabel = json['label'] as String?;
    final lat = (json['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (json['longitude'] as num?)?.toDouble() ?? 0.0;

    final parsedTimestamp = json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'].toString())?.toUtc()
        : null;
    final parsedCreatedAt = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString())?.toUtc()
        : null;
    final parsedUpdatedAt = json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'].toString())?.toUtc()
        : null;

    final created = parsedCreatedAt ?? parsedTimestamp ?? now;

    return LastKnownPlace(
      id: (rawId != null && rawId.trim().isNotEmpty)
          ? rawId.trim()
          : 'last_known_place',
      label: rawLabel?.trim() ?? '',
      latitude: lat,
      longitude: lng,
      timestamp: parsedTimestamp ?? now,
      createdAt: created,
      updatedAt: parsedUpdatedAt ?? created,
    );
  }

  /// Unique identifier of the cached place snapshot.
  final String id;

  /// The human-readable place label (e.g., "PUEHS Town II, Lahore").
  final String label;

  /// Latitude coordinate of the place snapshot.
  final double latitude;

  /// Longitude coordinate of the place snapshot.
  final double longitude;

  /// The wall-clock time when the label was resolved.
  final DateTime timestamp;

  /// Record creation timestamp in UTC.
  final DateTime createdAt;

  /// Record last update timestamp in UTC.
  final DateTime updatedAt;

  /// Converts this [LastKnownPlace] instance into a JSON-encodable map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Returns a copy of this [LastKnownPlace] with the specified fields replaced.
  LastKnownPlace copyWith({
    String? id,
    String? label,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LastKnownPlace(
      id: id ?? this.id,
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

