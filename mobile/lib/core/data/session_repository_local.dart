import '../storage/local_store.dart';
import 'session_repository.dart';

class SessionRepositoryLocal implements SessionRepository {
  SessionRepositoryLocal([LocalStore? store]) : _explicitStore = store;

  final LocalStore? _explicitStore;
  LocalStore get _store => _explicitStore ?? LocalStore.instance;

  static const String keyUserSessionActive = 'user_session_active';

  @override
  Future<bool> isLoggedIn() async {
    final value = await _store.readJson(keyUserSessionActive);
    if (value is bool) return value;
    return true;
  }

  @override
  Future<void> setLoggedIn(bool value) async {
    await _store.writeJson(keyUserSessionActive, value);
  }

  @override
  Future<void> clearSession() async {
    await _store.writeJson(keyUserSessionActive, false);
  }

  @override
  Future<void> flush() async {
    await _store.flush();
  }
}
