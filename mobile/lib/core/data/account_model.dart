import 'package:flutter/foundation.dart';

/// Model representing a locally stored rider user account.
///
/// Passwords are never stored in plain text; instead, each account stores a
/// cryptographically generated [salt] and salted [passwordHash]. Email addresses
/// are normalized to lowercase on creation and deserialization.
@immutable
class AccountModel {
  /// Creates an immutable [AccountModel] instance.
  AccountModel({
    required this.id,
    required this.name,
    required String email,
    required this.phone,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
    required this.updatedAt,
  }) : email = email.trim().toLowerCase();

  /// Deserializes a JSON map into an [AccountModel] with tolerant fallback parsing.
  factory AccountModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed.toUtc();
      }
      return DateTime.now().toUtc();
    }

    final rawEmail = json['email'] as String? ?? '';
    final cleanEmail = rawEmail.trim().toLowerCase();

    final rawId = json['id'] as String?;
    final id = (rawId != null && rawId.trim().isNotEmpty)
        ? rawId.trim()
        : 'acc-${DateTime.now().millisecondsSinceEpoch}';

    return AccountModel(
      id: id,
      name: (json['name'] as String?)?.trim() ?? '',
      email: cleanEmail,
      phone: (json['phone'] as String?)?.trim() ?? '',
      passwordHash: (json['passwordHash'] as String?) ??
          (json['password_hash'] as String?) ??
          '',
      salt: (json['salt'] as String?) ?? '',
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  /// Unique account identifier (e.g. 'acc-1730300000').
  final String id;

  /// Full display name of the rider.
  final String name;

  /// Contact email address, always stored in lowercase for reliable lookups.
  final String email;

  /// Contact phone number for emergency / profile synchronization.
  final String phone;

  /// Salted HMAC-SHA256 digest of the user's password.
  final String passwordHash;

  /// Cryptographically random salt string used during password hashing.
  final String salt;

  /// Timestamp when the account was registered.
  final DateTime createdAt;

  /// Timestamp when the account details were last modified.
  final DateTime updatedAt;

  /// Creates a copy of this account model with updated values.
  AccountModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? passwordHash,
    String? salt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Serializes the account model into a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'passwordHash': passwordHash,
      'salt': salt,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          passwordHash == other.passwordHash &&
          salt == other.salt;

  @override
  int get hashCode => Object.hash(id, email, passwordHash, salt);
}
