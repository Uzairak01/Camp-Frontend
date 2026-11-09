import 'user_model.dart';

/// Authentication state stages.
enum AuthStatus {
  initial,
  authenticating,
  authenticated,
  unauthenticated,
  error,
}

/// Represents the current authentication state and active rider session.
class AuthState {
  /// Creates an immutable authentication state snapshot.
  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.currentUser,
    this.errorMessage,
  });

  /// Current authentication stage.
  final AuthStatus status;

  /// Currently authenticated rider user profile, if any.
  final RiderUser? currentUser;

  /// Human-readable error message on authentication failure.
  final String? errorMessage;

  /// Whether a valid authenticated user session exists.
  bool get isAuthenticated =>
      status == AuthStatus.authenticated && currentUser != null;

  /// Whether an authentication request is currently pending.
  bool get isLoading => status == AuthStatus.authenticating;

  /// Creates a copy of this state with optional updated parameters.
  AuthState copyWith({
    AuthStatus? status,
    RiderUser? currentUser,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      currentUser: currentUser ?? this.currentUser,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
