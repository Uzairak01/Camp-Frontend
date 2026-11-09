import 'package:camp/core/data/settings_repository.dart';
import 'package:camp/features/settings/domain/app_settings.dart';

class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({AppSettings? initialSettings})
      : _settings = initialSettings ?? AppSettings();

  AppSettings _settings;

  AppSettings get currentSettings => _settings;

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }

  @override
  Future<void> deleteSettings() async {
    _settings = AppSettings();
  }

  @override
  Future<void> flush() async {}
}
