import 'package:flutter/foundation.dart';
import 'units_system.dart';

/// Application configuration and preferences domain model.
@immutable
class AppSettings {
  AppSettings({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.units = UnitsSystem.metric,
    this.notificationsEnabled = true,
    this.privacySharingEnabled = true,
    this.cachedPacksSizeGb = 0.0,
    this.cachedPacksSubtitle = '',
    this.localCacheSizeGb = 0.0,
    this.language = 'English',
    this.emergencyNumber = '1122',
    this.fuelPricePerLiter,
    this.showBikeOnEmergencyQr = true,
    this.recentActivityClearedAt,
    this.dismissedAlertItemId,
    this.dismissedAlertStatus,
    this.wifiAutoUpdateRoutePacks = true,
    this.gpsOnlyLocationProvider = false,
  })  : id = id ?? 'settings-default',
        createdAt = (createdAt ?? DateTime.now()).toUtc(),
        updatedAt = (updatedAt ?? DateTime.now()).toUtc();

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    DateTime? parseUtc(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val)?.toUtc();
      return null;
    }

    final created = parseUtc(json['createdAt']) ?? DateTime.now().toUtc();
    final updated = parseUtc(json['updatedAt']) ?? created;

    return AppSettings(
      id: json['id'] as String? ?? 'settings-default',
      createdAt: created,
      updatedAt: updated,
      units: json['units'] == 'imperial'
          ? UnitsSystem.imperial
          : UnitsSystem.metric,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      privacySharingEnabled: json['privacySharingEnabled'] as bool? ?? true,
      cachedPacksSizeGb:
          (json['cachedPacksSizeGb'] as num?)?.toDouble() ?? 0.0,
      cachedPacksSubtitle: json['cachedPacksSubtitle'] as String? ?? '',
      localCacheSizeGb: (json['localCacheSizeGb'] as num?)?.toDouble() ?? 0.0,
      language: json['language'] as String? ?? 'English',
      emergencyNumber: json['emergencyNumber'] as String? ?? '1122',
      fuelPricePerLiter: (json['fuelPricePerLiter'] as num?)?.toDouble(),
      showBikeOnEmergencyQr: json['showBikeOnEmergencyQr'] as bool? ?? true,
      recentActivityClearedAt: parseUtc(json['recentActivityClearedAt']),
      dismissedAlertItemId: json['dismissedAlertItemId'] as String?,
      dismissedAlertStatus: json['dismissedAlertStatus'] as String?,
      wifiAutoUpdateRoutePacks:
          json['wifiAutoUpdateRoutePacks'] as bool? ?? true,
      gpsOnlyLocationProvider:
          json['gpsOnlyLocationProvider'] as bool? ?? false,
    );
  }

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get effectiveId => id;
  DateTime get effectiveCreatedAt => createdAt;
  DateTime get effectiveUpdatedAt => updatedAt;
  final UnitsSystem units;
  final bool notificationsEnabled;
  final bool privacySharingEnabled;
  final double cachedPacksSizeGb;
  final String cachedPacksSubtitle;
  final double localCacheSizeGb;
  final String language;
  final String emergencyNumber;
  final double? fuelPricePerLiter;
  final bool showBikeOnEmergencyQr;
  final DateTime? recentActivityClearedAt;
  final String? dismissedAlertItemId;
  final String? dismissedAlertStatus;
  final bool wifiAutoUpdateRoutePacks;
  final bool gpsOnlyLocationProvider;

  AppSettings copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    UnitsSystem? units,
    bool? notificationsEnabled,
    bool? privacySharingEnabled,
    double? cachedPacksSizeGb,
    String? cachedPacksSubtitle,
    double? localCacheSizeGb,
    String? language,
    String? emergencyNumber,
    double? fuelPricePerLiter,
    bool? showBikeOnEmergencyQr,
    DateTime? recentActivityClearedAt,
    bool clearRecentActivityClearedAt = false,
    String? dismissedAlertItemId,
    String? dismissedAlertStatus,
    bool clearDismissedAlert = false,
    bool? wifiAutoUpdateRoutePacks,
    bool? gpsOnlyLocationProvider,
  }) {
    return AppSettings(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      units: units ?? this.units,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      privacySharingEnabled:
          privacySharingEnabled ?? this.privacySharingEnabled,
      cachedPacksSizeGb: cachedPacksSizeGb ?? this.cachedPacksSizeGb,
      cachedPacksSubtitle: cachedPacksSubtitle ?? this.cachedPacksSubtitle,
      localCacheSizeGb: localCacheSizeGb ?? this.localCacheSizeGb,
      language: language ?? this.language,
      emergencyNumber: emergencyNumber ?? this.emergencyNumber,
      fuelPricePerLiter: fuelPricePerLiter ?? this.fuelPricePerLiter,
      showBikeOnEmergencyQr:
          showBikeOnEmergencyQr ?? this.showBikeOnEmergencyQr,
      recentActivityClearedAt: clearRecentActivityClearedAt
          ? null
          : (recentActivityClearedAt ?? this.recentActivityClearedAt),
      dismissedAlertItemId: clearDismissedAlert
          ? null
          : (dismissedAlertItemId ?? this.dismissedAlertItemId),
      dismissedAlertStatus: clearDismissedAlert
          ? null
          : (dismissedAlertStatus ?? this.dismissedAlertStatus),
      wifiAutoUpdateRoutePacks:
          wifiAutoUpdateRoutePacks ?? this.wifiAutoUpdateRoutePacks,
      gpsOnlyLocationProvider:
          gpsOnlyLocationProvider ?? this.gpsOnlyLocationProvider,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'units': units.name,
        'notificationsEnabled': notificationsEnabled,
        'privacySharingEnabled': privacySharingEnabled,
        'cachedPacksSizeGb': cachedPacksSizeGb,
        'cachedPacksSubtitle': cachedPacksSubtitle,
        'localCacheSizeGb': localCacheSizeGb,
        'language': language,
        'emergencyNumber': emergencyNumber,
        'fuelPricePerLiter': fuelPricePerLiter,
        'showBikeOnEmergencyQr': showBikeOnEmergencyQr,
        'recentActivityClearedAt':
            recentActivityClearedAt?.toUtc().toIso8601String(),
        'dismissedAlertItemId': dismissedAlertItemId,
        'dismissedAlertStatus': dismissedAlertStatus,
        'wifiAutoUpdateRoutePacks': wifiAutoUpdateRoutePacks,
        'gpsOnlyLocationProvider': gpsOnlyLocationProvider,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          units == other.units &&
          notificationsEnabled == other.notificationsEnabled &&
          privacySharingEnabled == other.privacySharingEnabled &&
          cachedPacksSizeGb == other.cachedPacksSizeGb &&
          cachedPacksSubtitle == other.cachedPacksSubtitle &&
          localCacheSizeGb == other.localCacheSizeGb &&
          language == other.language &&
          emergencyNumber == other.emergencyNumber &&
          fuelPricePerLiter == other.fuelPricePerLiter &&
          showBikeOnEmergencyQr == other.showBikeOnEmergencyQr &&
          recentActivityClearedAt == other.recentActivityClearedAt &&
          dismissedAlertItemId == other.dismissedAlertItemId &&
          dismissedAlertStatus == other.dismissedAlertStatus &&
          wifiAutoUpdateRoutePacks == other.wifiAutoUpdateRoutePacks &&
          gpsOnlyLocationProvider == other.gpsOnlyLocationProvider;

  @override
  int get hashCode => Object.hash(
        id,
        units,
        notificationsEnabled,
        privacySharingEnabled,
        cachedPacksSizeGb,
        cachedPacksSubtitle,
        localCacheSizeGb,
        language,
        emergencyNumber,
        fuelPricePerLiter,
        showBikeOnEmergencyQr,
        recentActivityClearedAt,
        Object.hash(
          dismissedAlertItemId,
          dismissedAlertStatus,
          wifiAutoUpdateRoutePacks,
          gpsOnlyLocationProvider,
        ),
      );
}
