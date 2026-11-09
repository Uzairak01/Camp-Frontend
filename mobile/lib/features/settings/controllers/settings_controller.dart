import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/data/app_repositories.dart';
import '../../../core/data/settings_repository.dart';
import '../../../core/data/settings_repository_local.dart';
import '../domain/app_settings.dart';
import '../domain/cache_service.dart';
import '../domain/units_system.dart';

/// Central state controller managing application settings:
/// Units (Metric only: km, L, PKR), Notifications (low fuel alerts),
/// Language (English / Urdu), and Local Cache metrics.
///
/// Follows the same reactive ChangeNotifier singleton pattern as [ActiveBikeController].
class SettingsController extends ChangeNotifier {
  SettingsController({
    SettingsRepository? repository,
    CacheService? cacheService,
  })  : _repository = repository ?? AppRepositories.instance.settingsRepository,
        _cacheService = cacheService ?? const PlatformCacheService();

  /// Shared singleton instance across the application.
  static SettingsController instance = SettingsController();

  SettingsRepository _repository;
  CacheService _cacheService;

  @visibleForTesting
  SettingsRepository get repository => _repository;

  @visibleForTesting
  set repository(SettingsRepository repo) => _repository = repo;

  @visibleForTesting
  CacheService get cacheService => _cacheService;

  @visibleForTesting
  set cacheService(CacheService service) => _cacheService = service;

  final UnitsSystem _units = UnitsSystem.metric;
  bool _notificationsEnabled = true;
  bool _privacySharingEnabled = true;
  int _cacheSizeBytes = 0;
  String _language = 'English';
  String _emergencyNumber = '1122';
  double? _fuelPricePerLiter;
  bool _showBikeOnEmergencyQr = true;
  DateTime? _recentActivityClearedAt;

  String? _dismissedAlertItemId;
  String? _dismissedAlertStatus;
  bool _gpsOnlyLocationProvider = false;

  /// Callbacks notified whenever [gpsOnlyLocationProvider] changes so active
  /// GPS streams (navigation, ride tracker, place label) restart immediately.
  final Set<VoidCallback> _locationModeListeners = <VoidCallback>{};

  /// Registers a callback invoked when [gpsOnlyLocationProvider] is toggled.
  void addLocationModeListener(VoidCallback listener) {
    _locationModeListeners.add(listener);
  }

  /// Unregisters a previously added location-mode listener.
  void removeLocationModeListener(VoidCallback listener) {
    _locationModeListeners.remove(listener);
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  UnitsSystem get units => _units;
  bool get isMetric => true;
  bool get isImperial => false;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get privacySharingEnabled => _privacySharingEnabled;
  bool get showBikeOnEmergencyQr => _showBikeOnEmergencyQr;
  int get cacheSizeBytes => _cacheSizeBytes;
  double get localCacheSizeGb => _cacheSizeBytes / (1024 * 1024 * 1024);
  String get language => _language;
  String get emergencyNumber => _emergencyNumber;
  double? get fuelPricePerLiter => _fuelPricePerLiter;
  DateTime? get recentActivityClearedAt => _recentActivityClearedAt;
  String? get dismissedAlertItemId => _dismissedAlertItemId;
  String? get dismissedAlertStatus => _dismissedAlertStatus;

  /// Whether the experimental debug-only GPS-only location provider mode
  /// (`AndroidSettings.forceLocationManager = true`) is enabled. Defaults to `false`.
  bool get gpsOnlyLocationProvider => _gpsOnlyLocationProvider;

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Human-readable representation of local cache size
  String get localCacheDisplay => formatBytes(_cacheSizeBytes);

  // ── Modifiers ─────────────────────────────────────────────────────────────

  /// Toggle or update the push notification preference (controls low fuel alerts).
  void setNotificationsEnabled(bool enabled) {
    if (_notificationsEnabled == enabled) return;
    _notificationsEnabled = enabled;
    notifyListeners();
    save();
  }

  void toggleNotifications() {
    _notificationsEnabled = !_notificationsEnabled;
    notifyListeners();
    save();
  }

  /// Toggle or update privacy sharing preference.
  void setPrivacySharingEnabled(bool enabled) {
    if (_privacySharingEnabled == enabled) return;
    _privacySharingEnabled = enabled;
    notifyListeners();
    save();
  }

  void togglePrivacySharing() {
    _privacySharingEnabled = !_privacySharingEnabled;
    notifyListeners();
    save();
  }

  /// Compute real bytes in the platform temporary cache directory.
  Future<int> refreshCacheSize() async {
    final size = await _cacheService.getCacheSizeBytes();
    _cacheSizeBytes = size;
    notifyListeners();
    return size;
  }

  /// Clear temporary cache directory, releasing local device space.
  /// NOTE: This only clears temporary cache, never garage, reports, or settings.
  Future<int> clearTemporaryCache() async {
    final cleared = await _cacheService.clearCache();
    _cacheSizeBytes = 0;
    notifyListeners();
    return cleared;
  }

  /// Synchronous fallback for test mocks and callers.
  void clearLocalCache() {
    _cacheSizeBytes = 0;
    notifyListeners();
    clearTemporaryCache();
  }

  /// Update the user display language and persist through SettingsRepository.
  void setLanguage(String language) {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    save();
  }

  /// Checks if a maintenance alert is currently dismissed for this item and status.
  bool isAlertDismissed(String itemId, String status) {
    return _dismissedAlertItemId == itemId && _dismissedAlertStatus == status;
  }

  /// Dismisses a maintenance alert for a specific item id and status.
  void dismissAlert(String itemId, String status) {
    _dismissedAlertItemId = itemId;
    _dismissedAlertStatus = status;
    notifyListeners();
    save();
  }

  /// Resets dismissed alert state (e.g. after marking an item done).
  void clearDismissedAlert() {
    if (_dismissedAlertItemId == null && _dismissedAlertStatus == null) return;
    _dismissedAlertItemId = null;
    _dismissedAlertStatus = null;
    notifyListeners();
    save();
  }

  /// Fetch real application version from package info.
  Future<String> getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'v${info.version} (${info.buildNumber})';
    } catch (_) {
      return 'v1.0.0+1';
    }
  }

  /// Update the emergency rescue dispatch number.
  void setEmergencyNumber(String number) {
    final clean = number.trim();
    if (clean.isEmpty || _emergencyNumber == clean) return;
    _emergencyNumber = clean;
    notifyListeners();
    save();
  }

  /// Update the rider's saved fuel price per litre in PKR.
  void setFuelPricePerLiter(double? price) {
    if (_fuelPricePerLiter == price) return;
    _fuelPricePerLiter = price;
    notifyListeners();
    save();
  }

  /// Toggle or update the bike details visibility on Emergency QR card.
  void setShowBikeOnEmergencyQr(bool value) {
    if (_showBikeOnEmergencyQr == value) return;
    _showBikeOnEmergencyQr = value;
    notifyListeners();
    save();
  }

  /// Updates the experimental debug-only GPS-only location provider mode,
  /// persists it to local settings, and restarts all active location streams.
  Future<void> setGpsOnlyLocationProvider(bool enabled) async {
    if (_gpsOnlyLocationProvider == enabled) return;
    _gpsOnlyLocationProvider = enabled;
    notifyListeners();
    for (final listener in List<VoidCallback>.from(_locationModeListeners)) {
      try {
        listener();
      } catch (_) {}
    }
    await save();
  }

  /// Sets the cutoff timestamp for hiding prior entries from the Home recent activity feed.
  /// Never deletes underlying records in other repositories.
  Future<void> clearRecentActivity() async {
    _recentActivityClearedAt = DateTime.now().toUtc();
    notifyListeners();
    await save();
  }

  /// Reset all preferences to factory defaults (useful for tests).
  void reset() {
    _notificationsEnabled = true;
    _privacySharingEnabled = true;
    _cacheSizeBytes = 0;
    _language = 'English';
    _emergencyNumber = '1122';
    _fuelPricePerLiter = null;
    _showBikeOnEmergencyQr = true;
    _recentActivityClearedAt = null;
    _dismissedAlertItemId = null;
    _dismissedAlertStatus = null;
    _gpsOnlyLocationProvider = false;
    notifyListeners();
  }

  /// Reset in-memory preferences for testing.
  void resetForTesting() {
    reset();
    _repository = AppRepositories.instance.settingsRepository;
  }

  /// Await completion of all pending storage writes.
  Future<void> flush() => _repository.flush();

  /// Load user settings from repository.
  Future<void> load([dynamic source]) async {
    final repo = resolveSettingsRepository(source, _repository);
    if (source != null) {
      _repository = repo;
    }
    try {
      final settings = await repo.loadSettings();
      _notificationsEnabled = settings.notificationsEnabled;
      _privacySharingEnabled = settings.privacySharingEnabled;
      _language = settings.language;
      _emergencyNumber = settings.emergencyNumber;
      _fuelPricePerLiter = settings.fuelPricePerLiter;
      _showBikeOnEmergencyQr = settings.showBikeOnEmergencyQr;
      _recentActivityClearedAt = settings.recentActivityClearedAt;
      _dismissedAlertItemId = settings.dismissedAlertItemId;
      _dismissedAlertStatus = settings.dismissedAlertStatus;
      _gpsOnlyLocationProvider = settings.gpsOnlyLocationProvider;
      notifyListeners();
    } catch (_) {
      _notificationsEnabled = true;
      _privacySharingEnabled = true;
      _language = 'English';
      _emergencyNumber = '1122';
      _fuelPricePerLiter = null;
      _showBikeOnEmergencyQr = true;
      _recentActivityClearedAt = null;
      _dismissedAlertItemId = null;
      _dismissedAlertStatus = null;
      _gpsOnlyLocationProvider = false;
      notifyListeners();
    }
  }

  /// Persist user settings to repository.
  Future<void> save([dynamic source]) async {
    final repo = resolveSettingsRepository(source, _repository);
    try {
      final settings = AppSettings(
        units: _units,
        notificationsEnabled: _notificationsEnabled,
        privacySharingEnabled: _privacySharingEnabled,
        language: _language,
        emergencyNumber: _emergencyNumber,
        fuelPricePerLiter: _fuelPricePerLiter,
        showBikeOnEmergencyQr: _showBikeOnEmergencyQr,
        recentActivityClearedAt: _recentActivityClearedAt,
        dismissedAlertItemId: _dismissedAlertItemId,
        dismissedAlertStatus: _dismissedAlertStatus,
        gpsOnlyLocationProvider: _gpsOnlyLocationProvider,
      );
      await repo.saveSettings(settings);
    } catch (_) {
      // Ignore background write errors
    }
  }
}
