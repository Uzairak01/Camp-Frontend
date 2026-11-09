import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

/// Computes straight-line great-circle distance between two GPS coordinates using the Haversine formula:
///   a = sin²(Δlat/2) + cos(lat1) * cos(lat2) * sin²(Δlon/2)
///   c = 2 * atan2(sqrt(a), sqrt(1-a))
///   d = R * c
/// where R is Earth's mean radius (6371.0 km).
/// Returns distance in kilometers.
double computeStraightLineDistanceKm({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) {
  const earthRadiusKm = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180.0;
  final dLon = (lon2 - lon1) * math.pi / 180.0;

  final rLat1 = lat1 * math.pi / 180.0;
  final rLat2 = lat2 * math.pi / 180.0;

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rLat1) * math.cos(rLat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

/// Formats distance according to CAMP honesty rules:
/// "about 2.3 km away" (1 decimal place).
String formatDistance(double km) {
  return 'about ${km.toStringAsFixed(1)} km away';
}

enum BadgeType {
  verified,
  emergency,
}

class Mechanic {
  const Mechanic({
    required this.id,
    required this.name,
    required this.durationOrLocation,
    this.distance,
    this.latitude,
    this.longitude,
    this.badgeType = BadgeType.verified,
    this.badgeLabel = 'Added by you',
    this.beaconStatus = '',
    this.beaconColor = AppColors.statusGreen,
    this.categoryTitle1 = 'SPECIALTIES',
    this.tags1 = const [],
    this.categoryTitle2 = 'LOCATION',
    this.tags2 = const [],
    this.rating = 0.0,
    this.reviewCount = 0,
    this.openStatus = '',
    String? phoneNumber,
    String? phone,
    this.address,
    this.notes,
    this.photoPath,
    this.openDays = const [],
    this.openMinutes,
    this.closeMinutes,
    this.open24Hours = false,
    this.createdAt,
    this.updatedAt,
  }) : phoneNumber = phoneNumber ?? phone;

  factory Mechanic.fromJson(Map<String, dynamic> json) {
    DateTime? parseUtc(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val)?.toUtc();
      return null;
    }

    final rawId = json['id'] as String?;
    final effectiveId = (rawId != null && rawId.trim().isNotEmpty)
        ? rawId.trim()
        : 'mechanic-${DateTime.now().millisecondsSinceEpoch}';

    final createdUtc = parseUtc(json['createdAt']) ?? DateTime.now().toUtc();
    final updatedUtc = parseUtc(json['updatedAt']) ?? createdUtc;

    final rawPhone = (json['phoneNumber'] ?? json['phone']) as String?;
    final effectivePhone =
        (rawPhone != null && rawPhone.trim().isNotEmpty) ? rawPhone.trim() : null;

    final rawBadge = json['badgeLabel'] as String? ?? 'Added by you';
    final effectiveBadge =
        rawBadge == 'Community Added' ? 'Added by you' : rawBadge;

    return Mechanic(
      id: effectiveId,
      createdAt: createdUtc,
      updatedAt: updatedUtc,
      name: json['name'] as String? ?? 'Mechanic',
      distance: json['distance'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      durationOrLocation: json['durationOrLocation'] as String? ?? '',
      badgeType: (json['badgeType'] as String?) == 'emergency'
          ? BadgeType.emergency
          : BadgeType.verified,
      badgeLabel: effectiveBadge,
      beaconStatus: json['beaconStatus'] as String? ?? '',
      beaconColor: json['beaconColor'] != null
          ? Color(json['beaconColor'] as int)
          : AppColors.statusGreen,
      categoryTitle1: json['categoryTitle1'] as String? ?? 'SPECIALTIES',
      tags1: (json['tags1'] as List?)?.cast<String>() ?? const [],
      categoryTitle2: json['categoryTitle2'] as String? ?? 'LOCATION',
      tags2: (json['tags2'] as List?)?.cast<String>() ?? const [],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      openStatus: json['openStatus'] as String? ?? '',
      phoneNumber: effectivePhone,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      photoPath: (json['photoPath'] ?? json['photo']) as String?,
      openDays: (json['openDays'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      openMinutes: (json['openMinutes'] as num?)?.toInt(),
      closeMinutes: (json['closeMinutes'] as num?)?.toInt(),
      open24Hours: json['open24Hours'] as bool? ?? false,
    );
  }

  final String id;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get effectiveId => id;

  DateTime get effectiveCreatedAt =>
      createdAt?.toUtc() ?? DateTime(2024, 1, 1).toUtc();

  DateTime get effectiveUpdatedAt =>
      updatedAt?.toUtc() ?? effectiveCreatedAt;
  final String name;
  final String? distance;
  final double? latitude;
  final double? longitude;
  final String durationOrLocation;
  final BadgeType badgeType;
  final String badgeLabel;
  final String beaconStatus;
  final Color beaconColor;
  final String categoryTitle1;
  final List<String> tags1;
  final String categoryTitle2;
  final List<String> tags2;
  final double rating;
  final int reviewCount;
  final String openStatus;
  final String? phoneNumber;

  /// Legacy accessor for backwards compatibility.
  String get phone => phoneNumber ?? '';

  final String? address;
  final String? notes;
  final String? photoPath;
  final List<int> openDays;
  final int? openMinutes;
  final int? closeMinutes;
  final bool open24Hours;

  /// Whether this shop has saved coordinates.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Whether this shop has a valid phone number saved.
  bool get hasPhone => phoneNumber != null && phoneNumber!.trim().isNotEmpty;

  Mechanic copyWith({
    String? id,
    String? name,
    String? distance,
    double? latitude,
    double? longitude,
    String? durationOrLocation,
    BadgeType? badgeType,
    String? badgeLabel,
    String? beaconStatus,
    Color? beaconColor,
    String? categoryTitle1,
    List<String>? tags1,
    String? categoryTitle2,
    List<String>? tags2,
    double? rating,
    int? reviewCount,
    String? openStatus,
    String? phone,
    String? phoneNumber,
    String? address,
    String? notes,
    String? photoPath,
    List<int>? openDays,
    int? openMinutes,
    int? closeMinutes,
    bool? open24Hours,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final effectivePhone = phoneNumber ?? phone ?? this.phoneNumber;

    return Mechanic(
      id: id ?? this.id,
      name: name ?? this.name,
      distance: distance ?? this.distance,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      durationOrLocation: durationOrLocation ?? this.durationOrLocation,
      badgeType: badgeType ?? this.badgeType,
      badgeLabel: badgeLabel ?? this.badgeLabel,
      beaconStatus: beaconStatus ?? this.beaconStatus,
      beaconColor: beaconColor ?? this.beaconColor,
      categoryTitle1: categoryTitle1 ?? this.categoryTitle1,
      tags1: tags1 ?? this.tags1,
      categoryTitle2: categoryTitle2 ?? this.categoryTitle2,
      tags2: tags2 ?? this.tags2,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      openStatus: openStatus ?? this.openStatus,
      phoneNumber: effectivePhone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      photoPath: photoPath ?? this.photoPath,
      openDays: openDays ?? this.openDays,
      openMinutes: openMinutes ?? this.openMinutes,
      closeMinutes: closeMinutes ?? this.closeMinutes,
      open24Hours: open24Hours ?? this.open24Hours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': effectiveCreatedAt.toIso8601String(),
        'updatedAt': effectiveUpdatedAt.toIso8601String(),
        'name': name,
        'distance': distance,
        'latitude': latitude,
        'longitude': longitude,
        'durationOrLocation': durationOrLocation,
        'badgeType': badgeType.name,
        'badgeLabel': badgeLabel,
        'beaconStatus': beaconStatus,
        'beaconColor': beaconColor.toARGB32(),
        'categoryTitle1': categoryTitle1,
        'tags1': tags1,
        'categoryTitle2': categoryTitle2,
        'tags2': tags2,
        'rating': rating,
        'reviewCount': reviewCount,
        'openStatus': openStatus,
        'phoneNumber': phoneNumber,
        'phone': phoneNumber ?? '',
        'address': address,
        'notes': notes,
        'photoPath': photoPath,
        'openDays': openDays,
        'openMinutes': openMinutes,
        'closeMinutes': closeMinutes,
        'open24Hours': open24Hours,
      };
}
