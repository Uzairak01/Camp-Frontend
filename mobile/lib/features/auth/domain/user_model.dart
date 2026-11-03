import '../../../core/data/account_model.dart';

/// CAMP Rider User Model representing an authenticated rider profile.
///
/// Contains user identity details loaded from the active [AccountModel].
/// No hardcoded default account exists.
class RiderUser {
  /// Creates an immutable rider user instance.
  const RiderUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.memberSince,
  });

  /// Factory creating an authenticated [RiderUser] from an [AccountModel].
  factory RiderUser.fromAccount(AccountModel account) {
    return RiderUser(
      id: account.id,
      name: account.name,
      email: account.email,
      phone: account.phone,
      memberSince: account.createdAt,
    );
  }

  /// Unique rider identifier.
  final String id;

  /// Full display name of the rider.
  final String name;

  /// Contact email address.
  final String email;

  /// Contact telephone number.
  final String phone;

  /// Registration date of the rider account.
  final DateTime? memberSince;

  /// Creates a copy of this rider with updated fields.
  RiderUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    DateTime? memberSince,
  }) {
    return RiderUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      memberSince: memberSince ?? this.memberSince,
    );
  }
}
