import '../../features/settings/domain/app_settings.dart';
import '../storage/local_store.dart';
import 'settings_repository.dart';

class SettingsRepositoryLocal implements SettingsRepository {
  SettingsRepositoryLocal([LocalStore? store]) : _explicitStore = store;

  final LocalStore? _explicitStore;
  LocalStore get _store => _explicitStore ?? LocalStore.instance;

  @override
  Future<AppSettings> loadSettings() async {
    final isFirst = await _store.isFirstRun();
    if (!isFirst) {
      final schemaVer = await _store.getSchemaVersion();
      if (schemaVer == null || schemaVer > LocalStore.currentSchemaVersion) {
        return AppSettings();
      }
    }

    final json = await _store.readJson(LocalStore.keySettings);
    if (json == null || json is! Map) {
      return AppSettings();
    }
    final map = json is Map<String, dynamic> ? json : json.cast<String, dynamic>();

    final settings = AppSettings.fromJson(map);
    final hasGeneratedId = (map['id'] == null || (map['id'] as String).isEmpty);
    final hasMissingDates = map['createdAt'] == null || map['updatedAt'] == null;
    if (hasGeneratedId || hasMissingDates) {
      await saveSettings(settings);
    }
    return settings;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final updated = settings.copyWith(
      id: settings.effectiveId,
      createdAt: settings.effectiveCreatedAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await _store.writeJson(LocalStore.keySettings, updated.toJson());
  }

  @override
  Future<void> deleteSettings() async {
    await _store.writeJson(LocalStore.keySettings, null);
  }

  @override
  Future<void> flush() async {
    await _store.flush();
  }
}

SettingsRepository resolveSettingsRepository(dynamic source, [SettingsRepository? fallback]) {
  if (source is SettingsRepository) return source;
  if (source is LocalStore) return SettingsRepositoryLocal(source);
  return fallback ?? SettingsRepositoryLocal();
}
