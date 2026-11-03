import '../storage/local_store.dart';
import 'account_model.dart';
import 'account_repository.dart';

/// Local implementation of [AccountRepository] backed by [LocalStore].
///
/// Accounts are persisted as a list of JSON objects under key [keyAccounts].
/// The active session account ID is stored under [keyCurrentAccountId].
class AccountRepositoryLocal implements AccountRepository {
  /// Creates an [AccountRepositoryLocal] instance with an optional [LocalStore]
  /// for dependency injection in automated tests.
  AccountRepositoryLocal([LocalStore? store]) : _explicitStore = store;

  final LocalStore? _explicitStore;
  LocalStore get _store => _explicitStore ?? LocalStore.instance;

  /// Persistence key for the accounts registry.
  static const String keyAccounts = 'camp_accounts';

  /// Persistence key for the currently authenticated account ID.
  static const String keyCurrentAccountId = 'camp_current_account_id';

  @override
  Future<List<AccountModel>> getAllAccounts() async {
    final raw = await _store.readJson(keyAccounts);
    if (raw is! List) return [];

    final accounts = <AccountModel>[];
    for (final item in raw) {
      if (item is Map) {
        try {
          final map = item is Map<String, dynamic>
              ? item
              : item.cast<String, dynamic>();
          accounts.add(AccountModel.fromJson(map));
        } catch (_) {
          // Gracefully ignore corrupt entries (tolerant JSON handling)
        }
      }
    }
    return accounts;
  }

  @override
  Future<AccountModel?> findByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final accounts = await getAllAccounts();
    for (final acc in accounts) {
      if (acc.email == normalized) {
        return acc;
      }
    }
    return null;
  }

  @override
  Future<AccountModel?> findById(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return null;

    final accounts = await getAllAccounts();
    for (final acc in accounts) {
      if (acc.id == cleanId) {
        return acc;
      }
    }
    return null;
  }

  @override
  Future<void> saveAccount(AccountModel account) async {
    final accounts = await getAllAccounts();
    final updated = <AccountModel>[];
    bool replaced = false;

    for (final existing in accounts) {
      if (existing.id == account.id || existing.email == account.email) {
        updated.add(account);
        replaced = true;
      } else {
        updated.add(existing);
      }
    }

    if (!replaced) {
      updated.add(account);
    }

    final payload = updated.map((a) => a.toJson()).toList();
    await _store.writeJson(keyAccounts, payload);
  }

  @override
  Future<String?> getCurrentAccountId() async {
    final raw = await _store.readJson(keyCurrentAccountId);
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    return null;
  }

  @override
  Future<void> setCurrentAccountId(String? id) async {
    if (id != null && id.trim().isNotEmpty) {
      await _store.writeJson(keyCurrentAccountId, id.trim());
    } else {
      await _store.remove(keyCurrentAccountId);
    }
  }

  @override
  Future<void> clearCurrentAccount() async {
    await _store.remove(keyCurrentAccountId);
  }

  @override
  Future<void> flush() async {
    await _store.flush();
  }
}
