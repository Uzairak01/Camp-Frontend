import 'package:flutter/foundation.dart';

/// Fuel delivery system types for a motorcycle.
enum FuelSystem {
  carburetor,
  efi,
}

/// Mode selection for recording last serviced milestone.
enum TrackingMode {
  byDistance,
  byDate,
}

/// Value object representing a service milestone (distance or calendar date).
@immutable
class ServiceRecord {
  const ServiceRecord({
    this.mode = TrackingMode.byDistance,
    this.km,
    this.date,
  });

  factory ServiceRecord.fromJson(Map<String, dynamic> json) {
    return ServiceRecord(
      mode: json['mode'] == 'byDate'
          ? TrackingMode.byDate
          : TrackingMode.byDistance,
      km: json['km'] as int?,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String)
          : null,
    );
  }

  final TrackingMode mode;
  final int? km;
  final DateTime? date;

  ServiceRecord copyWith({
    TrackingMode? mode,
    int? km,
    DateTime? date,
  }) {
    return ServiceRecord(
      mode: mode ?? this.mode,
      km: km ?? this.km,
      date: date ?? this.date,
    );
  }

  @override
  String toString() => 'ServiceRecord(mode: $mode, km: $km, date: $date)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceRecord &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          km == other.km &&
          date == other.date;

  @override
  int get hashCode => Object.hash(mode, km, date);

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'km': km,
        'date': date?.toIso8601String(),
      };
}

/// Motorcycle domain model representing a registered vehicle in CAMP.
@immutable
class Bike {
  const Bike({
    required this.id,
    required this.make,
    required this.modelName,
    required this.modelYear,
    required this.odometerKm,
    this.preciseOdometerKm,
    this.fuelLevelOdometerKm,
    this.displacement,
    this.bikeType,
    this.fuelSystem = FuelSystem.carburetor,
    this.carburetorType,
    this.fuelTankCapacityLiters,
    this.fuelAverageKmPerLiter,
    this.ridingTerrain,
    this.edition,
    this.imagePath,
    double? fuelRemainingLiters,
    this.lastFuelUpdate,
    this.lastFullRefillOdometer,
    double? currentFuelLiters,
    int? fuelLevelPercent,
    this.lastOilChange,
    this.lastTuneUp,
    this.vin,
    this.nickname,
    this.plateNumber,
    this.color,
    this.lastUpdated,
    this.createdAt,
    this.updatedAt,
  })  : fuelRemainingLiters = fuelRemainingLiters ?? currentFuelLiters,
        currentFuelLiters = currentFuelLiters ?? fuelRemainingLiters,
        _explicitFuelLevelPercent = fuelLevelPercent;

  factory Bike.fromJson(Map<String, dynamic> json) {
    final tankCapacity = (json['fuelTankCapacityLiters'] as num?)?.toDouble();
    double? remainingLiters = (json['fuelRemainingLiters'] as num?)?.toDouble();
    if (remainingLiters == null && json['currentFuelLiters'] != null) {
      remainingLiters = (json['currentFuelLiters'] as num?)?.toDouble();
    }
    final legacyPct = (json['fuelLevelPercent'] as num?)?.toDouble();
    if (remainingLiters == null && legacyPct != null && tankCapacity != null && tankCapacity > 0) {
      remainingLiters = (legacyPct * tankCapacity / 100.0);
    }
    if (remainingLiters != null && tankCapacity != null && tankCapacity > 0) {
      remainingLiters = remainingLiters.clamp(0.0, tankCapacity);
    }

    final rawOdo = json['odometerKm'] as int? ?? 0;
    final preciseOdo = (json['preciseOdometerKm'] as num?)?.toDouble();
    final fuelLevelOdo = (json['fuelLevelOdometerKm'] as num?)?.toDouble() ??
        preciseOdo ??
        rawOdo.toDouble();

    final idStr = (json['id'] as String?)?.trim();
    final effectiveId = (idStr != null && idStr.isNotEmpty)
        ? idStr
        : 'bike-${DateTime.now().millisecondsSinceEpoch}';

    DateTime? parseUtc(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val)?.toUtc();
      return null;
    }

    final createdUtc = parseUtc(json['createdAt']) ??
        parseUtc(json['lastUpdated']) ??
        DateTime.now().toUtc();
    final updatedUtc = parseUtc(json['updatedAt']) ??
        parseUtc(json['lastUpdated']) ??
        createdUtc;

    return Bike(
      id: effectiveId,
      createdAt: createdUtc,
      updatedAt: updatedUtc,
      make: json['make'] as String? ?? 'Unknown',
      modelName: json['modelName'] as String? ?? 'Unknown',
      modelYear: json['modelYear'] as int? ?? DateTime.now().year,
      odometerKm: rawOdo,
      preciseOdometerKm: preciseOdo,
      fuelLevelOdometerKm: fuelLevelOdo,
      displacement: json['displacement'] as int?,
      bikeType: json['bikeType'] as String?,
      fuelSystem: json['fuelSystem'] == 'efi'
          ? FuelSystem.efi
          : FuelSystem.carburetor,
      carburetorType: json['carburetorType'] as String?,
      fuelTankCapacityLiters: tankCapacity,
      fuelAverageKmPerLiter:
          (json['fuelAverageKmPerLiter'] as num?)?.toDouble(),
      ridingTerrain: (json['ridingTerrain'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      edition: json['edition'] as String?,
      imagePath: json['imagePath'] as String?,
      fuelRemainingLiters: remainingLiters,
      lastFuelUpdate: json['lastFuelUpdate'] != null
          ? DateTime.tryParse(json['lastFuelUpdate'] as String)
          : null,
      lastFullRefillOdometer:
          (json['lastFullRefillOdometer'] as num?)?.toDouble(),
      currentFuelLiters: remainingLiters,
      fuelLevelPercent: (json['fuelLevelPercent'] as num?)?.toInt(),
      lastOilChange: json['lastOilChange'] != null
          ? ServiceRecord.fromJson(
              Map<String, dynamic>.from(json['lastOilChange'] as Map))
          : null,
      lastTuneUp: json['lastTuneUp'] != null
          ? ServiceRecord.fromJson(
              Map<String, dynamic>.from(json['lastTuneUp'] as Map))
          : null,
      vin: json['vin'] as String?,
      nickname: json['nickname'] as String?,
      plateNumber: (json['plateNumber'] ?? json['plate'] ?? json['licensePlate']) as String?,
      color: (json['color'] ?? json['colour']) as String?,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'] as String)
          : null,
    );
  }

  /// Unique identifier for the bike.
  final String id;

  /// Timestamp when bike record was originally created (UTC).
  final DateTime? createdAt;

  /// Timestamp when bike record was last updated (UTC).
  final DateTime? updatedAt;

  DateTime get effectiveCreatedAt =>
      createdAt?.toUtc() ?? lastUpdated?.toUtc() ?? DateTime(2024, 1, 1).toUtc();

  DateTime get effectiveUpdatedAt =>
      updatedAt?.toUtc() ?? lastUpdated?.toUtc() ?? effectiveCreatedAt;

  /// Manufacturer/Make (e.g. Honda, BMW, Yamaha).
  final String make;

  /// Specific model name (e.g. Africa Twin, CB650R).
  final String modelName;

  /// Model production year (e.g. 2024).
  final int modelYear;

  /// Displacement in cubic centimeters (cc).
  final int? displacement;

  /// Category/classification (e.g. Adventure, Commuter, Sport, Cruiser, Scooter, Electric).
  final String? bikeType;

  /// Fuel delivery system (Carburetor or Fuel Injection EFI).
  final FuelSystem fuelSystem;

  /// Carburetor brand/spec (e.g. Mikuni, Keihin, CV) — only valid if fuelSystem == carburetor.
  final String? carburetorType;

  /// Total fuel tank capacity in liters.
  final double? fuelTankCapacityLiters;

  /// User reported average fuel consumption in km per liter.
  final double? fuelAverageKmPerLiter;

  /// Configured primary riding terrain types (e.g. City, Highway, Off-road, Mountain).
  final List<String>? ridingTerrain;

  /// Special trim or edition name (e.g. Edition Triple Black).
  final String? edition;

  /// Local asset image path or remote URL for bike photograph.
  final String? imagePath;

  /// Mandatory operational field: current total odometer reading in km.
  final int odometerKm;

  /// High-precision odometer reading in km (e.g. 14820.4 km).
  final double? preciseOdometerKm;

  /// Odometer reading in km at the moment the fuel level was set or refilled.
  /// Used to compute current fuel remaining dynamically against current odometer.
  final double? fuelLevelOdometerKm;

  /// Current estimated fuel volume in liters (clamped 0..fuelTankCapacityLiters).
  final double? fuelRemainingLiters;

  /// Timestamp of the last fuel level update (refill or manual adjustment).
  final DateTime? lastFuelUpdate;

  /// Odometer reading in km at the last full tank refill, used for full-to-full learning.
  final double? lastFullRefillOdometer;

  /// Legacy field kept for backward compatibility; mirrors fuelRemainingLiters.
  final double? currentFuelLiters;

  final int? _explicitFuelLevelPercent;

  /// User-set or estimated fuel level percentage (0 to 100).
  int? get fuelLevelPercent {
    if (fuelRemainingLiters != null &&
        fuelTankCapacityLiters != null &&
        fuelTankCapacityLiters! > 0) {
      return ((fuelRemainingLiters! / fuelTankCapacityLiters!) * 100.0)
          .round()
          .clamp(0, 100);
    }
    return _explicitFuelLevelPercent;
  }

  /// Last oil change milestone (either distance in km or date).
  final ServiceRecord? lastOilChange;

  /// Last comprehensive tune-up milestone (either distance in km or date).
  final ServiceRecord? lastTuneUp;

  /// Serial / Vehicle Identification Number (VIN).
  final String? vin;

  /// Optional rider nickname for the motorcycle (e.g. Black Beast).
  final String? nickname;

  /// Vehicle registration plate number (e.g. "ABC-1234").
  final String? plateNumber;

  /// Vehicle body colour (e.g. "Grand Prix Red").
  final String? color;

  /// Convenience getter for vehicle colour.
  String? get colour => color;

  /// Timestamp of when the motorcycle profile/mileage/service was last updated.
  final DateTime? lastUpdated;

  String get effectiveId => id;

  /// Friendly display name (nickname if present, else "$make $modelName").
  String get name =>
      nickname?.isNotEmpty == true ? nickname! : '$make $modelName';

  /// Convenience getter for modelYear.
  int get year => modelYear;

  /// Convenience getter for mileage in kilometers.
  int get mileageKm => odometerKm;

  /// Formatted subtitle as `<year> <make>`, hiding parts that are missing.
  String get formattedSubtitle => formatSubtitle(year: modelYear, make: make);

  /// Static helper to format `<year> <make>`, hiding parts that are missing.
  static String formatSubtitle({int? year, String? make}) {
    final parts = <String>[];
    if (year != null && year > 0) {
      parts.add(year.toString());
    }
    final trimmedMake = make?.trim();
    if (trimmedMake != null && trimmedMake.isNotEmpty) {
      parts.add(trimmedMake);
    }
    return parts.join(' • ');
  }

  /// Fallback getter ensuring a non-null timestamp for relative time display.
  DateTime get lastUpdatedAt =>
      lastUpdated ?? DateTime.now().subtract(const Duration(hours: 2, minutes: 15));

  Bike copyWith({
    String? id,
    String? make,
    String? modelName,
    int? modelYear,
    int? displacement,
    String? bikeType,
    FuelSystem? fuelSystem,
    String? carburetorType,
    double? fuelTankCapacityLiters,
    double? fuelAverageKmPerLiter,
    List<String>? ridingTerrain,
    String? edition,
    String? imagePath,
    int? odometerKm,
    double? preciseOdometerKm,
    double? fuelLevelOdometerKm,
    double? fuelRemainingLiters,
    DateTime? lastFuelUpdate,
    double? lastFullRefillOdometer,
    double? currentFuelLiters,
    int? fuelLevelPercent,
    ServiceRecord? lastOilChange,
    ServiceRecord? lastTuneUp,
    String? vin,
    String? nickname,
    String? plateNumber,
    String? color,
    DateTime? lastUpdated,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final newTankCapacity =
        fuelTankCapacityLiters ?? this.fuelTankCapacityLiters;
    double? newFuelLiters =
        fuelRemainingLiters ?? currentFuelLiters ?? this.fuelRemainingLiters;
    if (newFuelLiters == null &&
        fuelLevelPercent != null &&
        newTankCapacity != null &&
        newTankCapacity > 0) {
      newFuelLiters = fuelLevelPercent * newTankCapacity / 100.0;
    }
    if (newFuelLiters != null &&
        newTankCapacity != null &&
        newTankCapacity > 0) {
      newFuelLiters = newFuelLiters.clamp(0.0, newTankCapacity);
    }

    return Bike(
      id: id ?? this.id,
      make: make ?? this.make,
      modelName: modelName ?? this.modelName,
      modelYear: modelYear ?? this.modelYear,
      displacement: displacement ?? this.displacement,
      bikeType: bikeType ?? this.bikeType,
      fuelSystem: fuelSystem ?? this.fuelSystem,
      carburetorType: carburetorType ?? this.carburetorType,
      fuelTankCapacityLiters: newTankCapacity,
      fuelAverageKmPerLiter:
          fuelAverageKmPerLiter ?? this.fuelAverageKmPerLiter,
      ridingTerrain: ridingTerrain ?? this.ridingTerrain,
      edition: edition ?? this.edition,
      imagePath: imagePath ?? this.imagePath,
      odometerKm: odometerKm ?? this.odometerKm,
      preciseOdometerKm: preciseOdometerKm ?? this.preciseOdometerKm,
      fuelLevelOdometerKm: fuelLevelOdometerKm ?? this.fuelLevelOdometerKm,
      fuelRemainingLiters: newFuelLiters,
      lastFuelUpdate: lastFuelUpdate ?? this.lastFuelUpdate,
      lastFullRefillOdometer:
          lastFullRefillOdometer ?? this.lastFullRefillOdometer,
      currentFuelLiters: newFuelLiters,
      fuelLevelPercent: fuelLevelPercent ?? _explicitFuelLevelPercent,
      lastOilChange: lastOilChange ?? this.lastOilChange,
      lastTuneUp: lastTuneUp ?? this.lastTuneUp,
      vin: vin ?? this.vin,
      nickname: nickname ?? this.nickname,
      plateNumber: plateNumber ?? this.plateNumber,
      color: color ?? this.color,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  @override
  String toString() =>
      'Bike(id: $id, make: $make, modelName: $modelName, year: $modelYear, odo: $odometerKm)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bike &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          make == other.make &&
          modelName == other.modelName &&
          modelYear == other.modelYear &&
          displacement == other.displacement &&
          bikeType == other.bikeType &&
          fuelSystem == other.fuelSystem &&
          carburetorType == other.carburetorType &&
          fuelTankCapacityLiters == other.fuelTankCapacityLiters &&
          fuelAverageKmPerLiter == other.fuelAverageKmPerLiter &&
          listEquals(ridingTerrain, other.ridingTerrain) &&
          edition == other.edition &&
          imagePath == other.imagePath &&
          odometerKm == other.odometerKm &&
          preciseOdometerKm == other.preciseOdometerKm &&
          fuelLevelOdometerKm == other.fuelLevelOdometerKm &&
          fuelRemainingLiters == other.fuelRemainingLiters &&
          lastFuelUpdate == other.lastFuelUpdate &&
          lastFullRefillOdometer == other.lastFullRefillOdometer &&
          fuelLevelPercent == other.fuelLevelPercent &&
          lastOilChange == other.lastOilChange &&
          lastTuneUp == other.lastTuneUp &&
          vin == other.vin &&
          nickname == other.nickname &&
          plateNumber == other.plateNumber &&
          color == other.color &&
          lastUpdated == other.lastUpdated;

  @override
  int get hashCode => Object.hashAll([
        id,
        make,
        modelName,
        modelYear,
        displacement,
        bikeType,
        fuelSystem,
        carburetorType,
        fuelTankCapacityLiters,
        fuelAverageKmPerLiter,
        ridingTerrain == null ? null : Object.hashAll(ridingTerrain!),
        edition,
        imagePath,
        odometerKm,
        preciseOdometerKm,
        fuelLevelOdometerKm,
        fuelRemainingLiters,
        lastFuelUpdate,
        lastFullRefillOdometer,
        fuelLevelPercent,
        lastOilChange,
        lastTuneUp,
        vin,
        nickname,
        plateNumber,
        color,
        lastUpdated,
      ]);

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': effectiveCreatedAt.toIso8601String(),
        'updatedAt': effectiveUpdatedAt.toIso8601String(),
        'make': make,
        'modelName': modelName,
        'modelYear': modelYear,
        'odometerKm': odometerKm,
        'preciseOdometerKm': preciseOdometerKm,
        'fuelLevelOdometerKm': fuelLevelOdometerKm,
        'displacement': displacement,
        'bikeType': bikeType,
        'fuelSystem': fuelSystem.name,
        'carburetorType': carburetorType,
        'fuelTankCapacityLiters': fuelTankCapacityLiters,
        'fuelAverageKmPerLiter': fuelAverageKmPerLiter,
        'ridingTerrain': ridingTerrain,
        'edition': edition,
        'imagePath': imagePath,
        'fuelRemainingLiters': fuelRemainingLiters,
        'lastFuelUpdate': lastFuelUpdate?.toIso8601String(),
        'lastFullRefillOdometer': lastFullRefillOdometer,
        'currentFuelLiters': fuelRemainingLiters,
        'fuelLevelPercent': fuelLevelPercent,
        'lastOilChange': lastOilChange?.toJson(),
        'lastTuneUp': lastTuneUp?.toJson(),
        'vin': vin,
        'nickname': nickname,
        'plateNumber': plateNumber,
        'color': color,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };
}
