import 'account_model.dart';

/// Repository contract for persistent local account management.
///
/// Serves as the temporary authentication store before migrating to Firebase Auth.
/// Provides methods to look up accounts by email or ID, persist new/updated accounts,
/// manage the currently authenticated session account ID, and flush pending writes.
abstract class AccountRepository {
  /// Finds an account by email (case-insensitive). Returns `null` if not found.
  Future<AccountModel?> findByEmail(String email);

  /// Finds an account by its unique [id]. Returns `null` if not found.
  Future<AccountModel?> findById(String id);

  /// Persists a new or updated [account] record into storage.
  Future<void> saveAccount(AccountModel account);

  /// Retrieves all persisted accounts.
  Future<List<AccountModel>> getAllAccounts();

  /// Gets the ID of the currently logged-in account, or `null` if unauthenticated.
  Future<String?> getCurrentAccountId();

  /// Sets the currently active logged-in account ID for session persistence.
  Future<void> setCurrentAccountId(String? id);

  /// Clears the active account session.
  Future<void> clearCurrentAccount();

  /// Flushes pending account writes to disk.
  Future<void> flush();
}

