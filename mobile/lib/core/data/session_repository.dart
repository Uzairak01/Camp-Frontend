abstract class SessionRepository {
  Future<bool> isLoggedIn();
  Future<void> setLoggedIn(bool value);
  Future<void> clearSession();
  Future<void> flush();
}
