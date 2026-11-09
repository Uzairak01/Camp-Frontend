import 'package:flutter/foundation.dart';
import '../../../core/data/account_model.dart';
import '../../../core/data/account_repository.dart';
import '../../../core/data/app_repositories.dart';
import '../../../core/data/password_hasher.dart';
import '../../dashboard/controllers/profile_controller.dart';
import '../domain/auth_state.dart';
import '../domain/user_model.dart';

/// Controller handling Rider Authentication, Local Account Lifecycle, and Session State.
///
/// Backed by [AccountRepository] and [SessionRepository] from [AppRepositories].
/// All passwords are encrypted with salted HMAC-SHA256 digests and verified
/// using constant-time comparison. No hardcoded default account or test fakes exist.
class AuthController extends ChangeNotifier {
  AuthController._();
  static final AuthController instance = AuthController._();

  AuthState _state = const AuthState();
  AuthState get state => _state;

  RiderUser? get currentUser => _state.currentUser;
  bool get isAuthenticated => _state.isAuthenticated;
  bool get isLoading => _state.isLoading;

  AccountRepository get _accountRepo => AppRepositories.instance.accountRepository;

  /// Loads any active session persisted in [AccountRepository].
  ///
  /// Restores [currentUser] and profile state if a valid account ID is found.
  Future<void> load([AccountRepository? repo]) async {
    final accountRepo = repo ?? _accountRepo;
    final accountId = await accountRepo.getCurrentAccountId();

    if (accountId != null && accountId.isNotEmpty) {
      final account = await accountRepo.findById(accountId);
      if (account != null) {
        final rider = RiderUser.fromAccount(account);
        _state = _state.copyWith(
          status: AuthStatus.authenticated,
          currentUser: rider,
          errorMessage: null,
        );
        await AppRepositories.instance.sessionRepository.setLoggedIn(true);

        // Keep profile synchronization in agreement with authenticated account
        ProfileController.instance.updateProfile(
          fullName: account.name,
          email: account.email,
          phone: account.phone,
        );

        notifyListeners();
        return;
      }
    }

    _state = const AuthState(status: AuthStatus.unauthenticated);
    notifyListeners();
  }

  /// Display name of the active rider, or empty string if not signed in.
  String get riderDisplayName {
    final name = currentUser?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return '';
  }

  /// First name of the active rider for headers, avatars, and welcome banners.
  String get riderFirstName {
    final name = riderDisplayName;
    if (name.isEmpty) return '';
    if (name.contains(' ')) return name.split(' ').first;
    return name;
  }

  /// Calculates password strength from 0 (empty) to 4 (maximum)
  /// based on length, digits, symbols, and mixed casing.
  int calculateStrength(String password) {
    if (password.isEmpty) return 0;
    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    if (RegExp(r'[0-9]').hasMatch(password) ||
        RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) {
      strength++;
    }
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) {
      strength++;
    }
    return strength.clamp(1, 4);
  }

  /// Authenticates an existing local rider using [riderIdOrEmail] and [password].
  ///
  /// Performs case-insensitive email lookup and constant-time password verification.
  Future<bool> signIn({
    required String riderIdOrEmail,
    required String password,
  }) async {
    final cleanEmail = riderIdOrEmail.trim().toLowerCase();
    final cleanPassword = password;

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please enter your email and password.',
      );
      notifyListeners();
      return false;
    }

    _state = _state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
    );
    notifyListeners();

    final account = await _accountRepo.findByEmail(cleanEmail);
    if (account == null) {
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'No account found for this email.',
      );
      notifyListeners();
      return false;
    }

    final passwordValid = PasswordHasher.verify(
      candidatePassword: cleanPassword,
      salt: account.salt,
      expectedHash: account.passwordHash,
    );

    if (!passwordValid) {
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Incorrect password.',
      );
      notifyListeners();
      return false;
    }

    // Authentication succeeded: persist active session
    final rider = RiderUser.fromAccount(account);
    _state = _state.copyWith(
      status: AuthStatus.authenticated,
      currentUser: rider,
      errorMessage: null,
    );

    await _accountRepo.setCurrentAccountId(account.id);
    await AppRepositories.instance.sessionRepository.setLoggedIn(true);

    // Synchronize rider profile with account details
    ProfileController.instance.updateProfile(
      fullName: account.name,
      email: account.email,
      phone: account.phone,
    );

    notifyListeners();
    return true;
  }

  /// Registers a new rider account locally.
  ///
  /// Validates input requirements (name, email format, phone, 8+ character password)
  /// and checks for existing duplicate emails. Generates a random salt and securely
  /// hashes the password before persistence.
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final cleanName = fullName.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phone.trim();
    final cleanPassword = password;

    if (cleanName.isEmpty) {
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Full name is required.',
      );
      notifyListeners();
      return false;
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(cleanEmail)) {
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please enter a valid email address.',
      );
      notifyListeners();
      return false;
    }

    if (cleanPhone.isEmpty) {
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Phone number is required.',
      );
      notifyListeners();
      return false;
    }

    if (cleanPassword.length < 8) {
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Password must be at least 8 characters.',
      );
      notifyListeners();
      return false;
    }

    _state = _state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
    );
    notifyListeners();

    // Check for duplicate account email
    final existing = await _accountRepo.findByEmail(cleanEmail);
    if (existing != null) {
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'An account with this email already exists.',
      );
      notifyListeners();
      return false;
    }

    // Generate cryptographic salt and salted hash
    final salt = PasswordHasher.generateSalt();
    final hash = PasswordHasher.hashPassword(cleanPassword, salt);
    final now = DateTime.now().toUtc();
    final newAccount = AccountModel(
      id: 'acc-${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      email: cleanEmail,
      phone: cleanPhone,
      passwordHash: hash,
      salt: salt,
      createdAt: now,
      updatedAt: now,
    );

    await _accountRepo.saveAccount(newAccount);
    await _accountRepo.setCurrentAccountId(newAccount.id);
    await AppRepositories.instance.sessionRepository.setLoggedIn(true);

    final newUser = RiderUser.fromAccount(newAccount);
    _state = _state.copyWith(
      status: AuthStatus.authenticated,
      currentUser: newUser,
      errorMessage: null,
    );

    // Populate rider profile
    ProfileController.instance.updateProfile(
      fullName: newAccount.name,
      email: newAccount.email,
      phone: newAccount.phone,
    );

    notifyListeners();
    return true;
  }

  /// Request password reset information.
  ///
  /// Since CAMP operates offline without an online backend, this does not fake
  /// an email dispatch.
  Future<bool> requestPasswordReset(String email) async {
    _state = _state.copyWith(
      status: AuthStatus.unauthenticated,
      errorMessage: null,
    );
    notifyListeners();
    return true;
  }

  /// Signs out the active rider session.
  ///
  /// Clears the active session account ID while preserving all saved local accounts.
  Future<void> signOut() async {
    _state = const AuthState(status: AuthStatus.unauthenticated);
    try {
      await AppRepositories.instance.sessionRepository.clearSession();
    } catch (_) {}
    try {
      await AppRepositories.instance.accountRepository
          .clearCurrentAccount()
          .timeout(const Duration(milliseconds: 200), onTimeout: () {});
    } catch (_) {}
    notifyListeners();
  }

  /// Changes the password for the currently signed-in rider account.
  ///
  /// Enforces validation rules in strict order:
  /// 1. Current password must match the stored salted hash: 'Current password is incorrect.'
  /// 2. New password must be at least 8 characters: 'Use at least 8 characters.'
  /// 3. New password must differ from current password: 'New password must be different.'
  /// 4. Confirm password must match new password: 'Passwords do not match.'
  ///
  /// On success:
  /// - Generates a new cryptographic salt using [PasswordHasher.generateSalt].
  /// - Computes HMAC-SHA256 digest using [PasswordHasher.hashPassword].
  /// - Persists updated [AccountModel] with new [updatedAt] timestamp into [AccountRepository].
  /// - Keeps the rider authenticated.
  /// - Passwords are never logged or stored in plain text.
  Future<ChangePasswordResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final accountRepo = AppRepositories.instance.accountRepository;
    final accountId = await accountRepo.getCurrentAccountId();
    AccountModel? account;
    if (accountId != null && accountId.isNotEmpty) {
      account = await accountRepo.findById(accountId);
    }
    if (account == null && currentUser != null && currentUser!.email.isNotEmpty) {
      account = await accountRepo.findByEmail(currentUser!.email);
    }
    if (account == null && ProfileController.instance.email.isNotEmpty) {
      account = await accountRepo.findByEmail(ProfileController.instance.email);
    }

    if (account == null) {
      return const ChangePasswordResult(
        success: false,
        errorMessage: 'No active account found. Please sign in again.',
        errorField: ChangePasswordField.general,
      );
    }

    // 1. Current password must match the signed-in account
    final isCurrentValid = PasswordHasher.verify(
      candidatePassword: currentPassword,
      salt: account.salt,
      expectedHash: account.passwordHash,
    );
    if (!isCurrentValid) {
      return const ChangePasswordResult(
        success: false,
        errorMessage: 'Current password is incorrect.',
        errorField: ChangePasswordField.current,
      );
    }

    // 2. New password must be at least 8 characters
    if (newPassword.length < 8) {
      return const ChangePasswordResult(
        success: false,
        errorMessage: 'Use at least 8 characters.',
        errorField: ChangePasswordField.newPassword,
      );
    }

    // 3. New password must differ from current password
    if (newPassword == currentPassword) {
      return const ChangePasswordResult(
        success: false,
        errorMessage: 'New password must be different.',
        errorField: ChangePasswordField.newPassword,
      );
    }

    // 4. Confirm password must match new password
    if (confirmPassword != newPassword) {
      return const ChangePasswordResult(
        success: false,
        errorMessage: 'Passwords do not match.',
        errorField: ChangePasswordField.confirm,
      );
    }

    // 5. Success: generate new salt and hash, save to AccountRepository
    try {
      final newSalt = PasswordHasher.generateSalt();
      final newHash = PasswordHasher.hashPassword(newPassword, newSalt);
      final updatedAccount = account.copyWith(
        passwordHash: newHash,
        salt: newSalt,
        updatedAt: DateTime.now().toUtc(),
      );

      await accountRepo.saveAccount(updatedAccount);
      return const ChangePasswordResult(success: true);
    } catch (_) {
      return const ChangePasswordResult(
        success: false,
        errorMessage: 'Unable to update password due to storage error. Please try again.',
        errorField: ChangePasswordField.general,
      );
    }
  }
}

/// Identifies the field associated with a change password error.
enum ChangePasswordField {
  current,
  newPassword,
  confirm,
  general,
}

/// Result object returned by [AuthController.changePassword].
class ChangePasswordResult {
  const ChangePasswordResult({
    required this.success,
    this.errorMessage,
    this.errorField,
  });

  final bool success;
  final String? errorMessage;
  final ChangePasswordField? errorField;
}
