import '../../features/settings/domain/app_settings.dart';

abstract class SettingsRepository {
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
  Future<void> deleteSettings();
  Future<void> flush();
}
