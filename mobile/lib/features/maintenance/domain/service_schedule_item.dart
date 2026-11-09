import 'package:flutter/material.dart';

/// Supported maintenance service item types.
enum ServiceItemType {
  oilAndSmallService,
  oilFilter,
  airFilter,
  chain,
  sparkPlug,
  tuning,
  brakes,
  rearBrakes,
  tyres,
  battery,
  carburetor,
  custom;

  String get displayName {
    switch (this) {
      case ServiceItemType.oilAndSmallService:
        return 'Engine Oil & Filter';
      case ServiceItemType.oilFilter:
        return 'Oil Filter';
      case ServiceItemType.airFilter:
        return 'Air Filter Element';
      case ServiceItemType.chain:
        return 'Drive Chain & Sprocket';
      case ServiceItemType.sparkPlug:
        return 'Spark Plug';
      case ServiceItemType.tuning:
        return 'Tuning / Valve Clearance';
      case ServiceItemType.brakes:
        return 'Front Brake Pads';
      case ServiceItemType.rearBrakes:
        return 'Rear Brake Shoes / Pads';
      case ServiceItemType.tyres:
        return 'Tyres';
      case ServiceItemType.battery:
        return 'Battery';
      case ServiceItemType.carburetor:
        return 'Carburetor';
      case ServiceItemType.custom:
        return 'Custom Service';
    }
  }

  String get canonicalId {
    switch (this) {
      case ServiceItemType.oilAndSmallService:
        return 'engine-oil';
      case ServiceItemType.oilFilter:
        return 'oil-filter';
      case ServiceItemType.airFilter:
        return 'air-filter';
      case ServiceItemType.chain:
        return 'chain-sprocket';
      case ServiceItemType.sparkPlug:
        return 'spark-plug';
      case ServiceItemType.tuning:
        return 'general-tuning';
      case ServiceItemType.brakes:
        return 'brake-pads';
      case ServiceItemType.rearBrakes:
        return 'rear-brake-pads';
      case ServiceItemType.tyres:
        return 'tyres';
      case ServiceItemType.battery:
        return 'battery';
      case ServiceItemType.carburetor:
        return 'carburetor';
      case ServiceItemType.custom:
        return 'custom-item';
    }
  }

  IconData get icon {
    switch (this) {
      case ServiceItemType.oilAndSmallService:
        return Icons.opacity_rounded;
      case ServiceItemType.oilFilter:
        return Icons.filter_alt_rounded;
      case ServiceItemType.airFilter:
        return Icons.air_rounded;
      case ServiceItemType.chain:
        return Icons.link_rounded;
      case ServiceItemType.sparkPlug:
        return Icons.bolt_rounded;
      case ServiceItemType.tuning:
        return Icons.tune_rounded;
      case ServiceItemType.brakes:
        return Icons.radio_button_checked_rounded;
      case ServiceItemType.rearBrakes:
        return Icons.radio_button_unchecked_rounded;
      case ServiceItemType.tyres:
        return Icons.donut_large_rounded;
      case ServiceItemType.battery:
        return Icons.battery_charging_full_rounded;
      case ServiceItemType.carburetor:
        return Icons.speed_rounded;
      case ServiceItemType.custom:
        return Icons.handyman_rounded;
    }
  }

  /// Quick-pick interval suggestions for distance (km).
  List<int> get quickKmSuggestions {
    switch (this) {
      case ServiceItemType.oilAndSmallService:
        return const [1000, 1200, 1500, 2000];
      case ServiceItemType.oilFilter:
        return const [2000, 3000, 4000, 5000];
      case ServiceItemType.airFilter:
        return const [4000, 5000, 8000, 10000];
      case ServiceItemType.chain:
        return const [500, 1000, 1500, 2000];
      case ServiceItemType.sparkPlug:
        return const [5000, 8000, 10000, 12000];
      case ServiceItemType.tuning:
        return const [5000, 8000, 10000];
      case ServiceItemType.brakes:
      case ServiceItemType.rearBrakes:
        return const [5000, 8000, 10000, 15000];
      case ServiceItemType.tyres:
        return const [10000, 15000, 20000];
      case ServiceItemType.battery:
        return const [10000, 20000];
      case ServiceItemType.carburetor:
        return const [3000, 5000, 8000];
      case ServiceItemType.custom:
        return const [3000, 5000, 10000];
    }
  }

  /// Quick-pick interval suggestions for time (months).
  List<int> get quickMonthSuggestions => const [3, 6, 12];
}

/// Status classification of an individual service schedule item.
enum ScheduleItemStatus {
  ok,
  dueSoon,
  overdue,
  addLastDone,
  notSetUp,
}

/// Rider-configured service schedule item for a specific motorcycle.
@immutable
class ServiceScheduleItem {
  const ServiceScheduleItem({
    required this.id,
    required this.bikeId,
    required this.type,
    this.customTitle,
    this.intervalKm,
    this.intervalMonths,
    this.lastDoneKm,
    this.lastDoneDate,
    this.enabled = true,
    this.createdAt,
    this.updatedAt,
  });

  factory ServiceScheduleItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseUtc(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val)?.toUtc();
      return null;
    }

    final rawId = json['id'] as String?;
    final effectiveId = (rawId != null && rawId.trim().isNotEmpty)
        ? rawId.trim()
        : 'sched-${DateTime.now().millisecondsSinceEpoch}';

    final bikeId = json['bikeId'] as String? ?? '';
    final customTitle = json['customTitle'] as String?;

    // Tolerant parser for ServiceItemType
    final rawType = json['type']?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '') ?? '';
    ServiceItemType resolvedType = ServiceItemType.oilAndSmallService;
    for (final t in ServiceItemType.values) {
      final sanitized = t.name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      if (sanitized == rawType || rawType.contains(sanitized) || sanitized.contains(rawType)) {
        resolvedType = t;
        break;
      }
    }

    final intervalKm = (json['intervalKm'] as num?)?.round();
    final intervalMonths = (json['intervalMonths'] as num?)?.round();
    final lastDoneKm = (json['lastDoneKm'] as num?)?.toDouble();
    final lastDoneDate = parseUtc(json['lastDoneDate']);

    final rawEnabled = json['enabled'];
    final bool enabled = rawEnabled is bool
        ? rawEnabled
        : (rawEnabled is String
            ? (rawEnabled.toLowerCase() == 'true' || rawEnabled == '1')
            : true);

    final createdUtc = parseUtc(json['createdAt']) ?? DateTime.now().toUtc();
    final updatedUtc = parseUtc(json['updatedAt']) ?? createdUtc;

    return ServiceScheduleItem(
      id: effectiveId,
      bikeId: bikeId,
      type: resolvedType,
      customTitle: customTitle,
      intervalKm: intervalKm,
      intervalMonths: intervalMonths,
      lastDoneKm: lastDoneKm,
      lastDoneDate: lastDoneDate,
      enabled: enabled,
      createdAt: createdUtc,
      updatedAt: updatedUtc,
    );
  }

  final String id;
  final String bikeId;
  final ServiceItemType type;
  final String? customTitle;
  final int? intervalKm;
  final int? intervalMonths;
  final double? lastDoneKm;
  final DateTime? lastDoneDate;
  final bool enabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get effectiveId => id;
  DateTime get effectiveCreatedAt => createdAt?.toUtc() ?? DateTime(2024, 1, 1).toUtc();
  DateTime get effectiveUpdatedAt => updatedAt?.toUtc() ?? effectiveCreatedAt;

  /// User-facing display name, resolving customTitle for custom items.
  String get displayName => (type == ServiceItemType.custom && customTitle != null && customTitle!.isNotEmpty)
      ? customTitle!
      : type.displayName;

  /// Whether the rider has entered at least one interval (distance or time).
  bool get hasInterval => (intervalKm != null && intervalKm! > 0) || (intervalMonths != null && intervalMonths! > 0);

  /// Whether the rider has entered at least one last done datum.
  bool get hasLastDone => lastDoneKm != null || lastDoneDate != null;

  /// Effective interval in km, applying 20% reduction under harsh conditions.
  int? effectiveIntervalKm(bool isHarshConditions) {
    if (intervalKm == null) return null;
    if (isHarshConditions) {
      return (intervalKm! * 0.80).round();
    }
    return intervalKm;
  }

  ServiceScheduleItem copyWith({
    String? id,
    String? bikeId,
    ServiceItemType? type,
    String? customTitle,
    int? intervalKm,
    int? intervalMonths,
    double? lastDoneKm,
    DateTime? lastDoneDate,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearLastDoneKm = false,
    bool clearLastDoneDate = false,
    bool clearIntervalKm = false,
    bool clearIntervalMonths = false,
    bool clearCustomTitle = false,
  }) {
    return ServiceScheduleItem(
      id: id ?? this.id,
      bikeId: bikeId ?? this.bikeId,
      type: type ?? this.type,
      customTitle: clearCustomTitle ? null : (customTitle ?? this.customTitle),
      intervalKm: clearIntervalKm ? null : (intervalKm ?? this.intervalKm),
      intervalMonths: clearIntervalMonths ? null : (intervalMonths ?? this.intervalMonths),
      lastDoneKm: clearLastDoneKm ? null : (lastDoneKm ?? this.lastDoneKm),
      lastDoneDate: clearLastDoneDate ? null : (lastDoneDate ?? this.lastDoneDate),
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bikeId': bikeId,
        'type': type.name,
        if (customTitle != null) 'customTitle': customTitle,
        'intervalKm': intervalKm,
        'intervalMonths': intervalMonths,
        'lastDoneKm': lastDoneKm,
        'lastDoneDate': lastDoneDate?.toIso8601String(),
        'enabled': enabled,
        'createdAt': effectiveCreatedAt.toIso8601String(),
        'updatedAt': effectiveUpdatedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceScheduleItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          bikeId == other.bikeId &&
          type == other.type &&
          customTitle == other.customTitle &&
          intervalKm == other.intervalKm &&
          intervalMonths == other.intervalMonths &&
          lastDoneKm == other.lastDoneKm &&
          lastDoneDate == other.lastDoneDate &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
        id,
        bikeId,
        type,
        customTitle,
        intervalKm,
        intervalMonths,
        lastDoneKm,
        lastDoneDate,
        enabled,
      );
}
