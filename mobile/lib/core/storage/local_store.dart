import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight wrapper around [SharedPreferences] providing typed JSON storage,
/// schema versioning, first-run detection, and ordered write sequencing for CAMP offline persistence.
class LocalStore {
  LocalStore([this._prefs]);

  static LocalStore instance = LocalStore();

  SharedPreferences? _prefs;
  Future<void> _writeQueue = Future.value();

  static const String schemaVersionKey = 'camp_schema_version';
  static const int currentSchemaVersion = 1;

  static const String keyBikes = 'camp_bikes';
  static const String keyGarageBikes = keyBikes;
  static const String keyActiveBikeId = 'camp_active_bike_id';
  static const String keySettings = 'camp_settings';
  static const String keyPostRideReports = 'camp_post_ride_reports';
  static const String keyRideReports = keyPostRideReports;
  static const String keyTripBudget = 'camp_trip_budget';
  static const String keyTripExpenses = 'camp_trip_expenses';
  static const String keyProfile = 'camp_profile';
  static const String keyProfilePhotoPath = 'camp_profile_photo_path';
  static const String keyMechanics = 'camp_mechanics';
  static const String keyMaintenanceItems = 'camp_maintenance_items';
  static const String keyServiceSchedule = 'camp_service_schedule';
  static const String keyHarshConditions = 'camp_service_harsh_conditions';
  static const String keyServiceVisits = 'camp_service_visits';
  static const String keyJettingBaseline = 'camp_jetting_baseline';
  static const String keyChecklist = 'camp_safety_checklist';
  static const String keySavedPlaces = 'camp_saved_places';
  static const String keyRecentPlaces = 'camp_recent_places';
  static const String keyFirstRunCompleted = 'camp_first_run_completed';
  static const String keyVoiceConversations = 'camp_voice_conversations';

  Future<SharedPreferences> get prefs async {
    final p = _prefs;
    if (p != null) return p;
    final resolved = await SharedPreferences.getInstance();
    _prefs = resolved;
    return resolved;
  }

  /// Initialize local store.
  Future<void> init([SharedPreferences? customPrefs]) async {
    _prefs = customPrefs ?? await SharedPreferences.getInstance();
  }

  /// Reset internal preferences reference and write queue for test harnesses.
  void resetForTesting([SharedPreferences? mockPrefs]) {
    _prefs = mockPrefs;
    _writeQueue = Future.value();
  }

  /// Queue an asynchronous write action so all writes execute in strict order.
  Future<T> _enqueueWrite<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeQueue = _writeQueue.then(
      (_) => action(),
      onError: (_) => action(),
    ).then((result) {
      completer.complete(result);
    }).catchError((Object error, StackTrace stackTrace) {
      completer.completeError(error, stackTrace);
    });
    return completer.future;
  }

  /// Await completion of all pending queued writes.
  Future<void> flush() async {
    await _writeQueue;
  }

  /// Read raw string value for [key].
  Future<String?> readString(String key) async {
    final p = await prefs;
    return p.getString(key);
  }

  /// Write raw string [value] for [key] in strictly queued order.
  Future<bool> writeString(String key, String value) {
    return _enqueueWrite(() async {
      final p = await prefs;
      return p.setString(key, value);
    });
  }

  /// Read and parse JSON from string stored at [key].
  /// Returns null if key does not exist or if content is corrupted.
  Future<dynamic> readJson(String key) async {
    try {
      final raw = await readString(key);
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw);
    } catch (_) {
      // Gracefully handle malformed or corrupted JSON without crashing
      return null;
    }
  }

  /// Encode [value] to JSON string and store at [key] in queued order.
  Future<bool> writeJson(String key, dynamic value) async {
    final encoded = jsonEncode(value);
    return writeString(key, encoded);
  }

  /// Remove entry by [key] in queued order.
  Future<bool> remove(String key) {
    return _enqueueWrite(() async {
      final p = await prefs;
      return p.remove(key);
    });
  }

  /// Check whether this is the application's first run.
  Future<bool> isFirstRun() async {
    final p = await prefs;
    return !p.containsKey(keyFirstRunCompleted) &&
        !p.containsKey(schemaVersionKey);
  }

  /// Mark first-run initialization as completed in queued order.
  Future<void> markFirstRunCompleted() {
    return _enqueueWrite(() async {
      final p = await prefs;
      await p.setBool(keyFirstRunCompleted, true);
      await p.setInt(schemaVersionKey, currentSchemaVersion);
    });
  }

  /// Read stored schema version, if present.
  Future<int?> getSchemaVersion() async {
    final p = await prefs;
    return p.getInt(schemaVersionKey);
  }

  /// Write schema version integer in queued order.
  Future<bool> setSchemaVersion(int version) {
    return _enqueueWrite(() async {
      final p = await prefs;
      return p.setInt(schemaVersionKey, version);
    });
  }

  /// Clear all stored keys in [SharedPreferences] in queued order.
  Future<bool> clear() {
    return _enqueueWrite(() async {
      final p = await prefs;
      return p.clear();
    });
  }
}
