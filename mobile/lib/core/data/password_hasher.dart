import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Cryptographic helper for secure password hashing and constant-time verification.
///
/// Plaintext passwords must never be stored to disk. This utility generates
/// a cryptographically secure random salt, computes a keyed HMAC-SHA256 digest,
/// and verifies candidates in constant time to safeguard against timing attacks.
class PasswordHasher {
  PasswordHasher._();

  /// Generates a cryptographically random salt string encoded in hexadecimal.
  ///
  /// [byteLength] defaults to 16 bytes (128 bits), yielding a 32-character hex string.
  static String generateSalt([int byteLength = 16]) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hashes the plaintext [password] combined with the specified [salt]
  /// using HMAC-SHA256.
  static String hashPassword(String password, String salt) {
    final keyBytes = utf8.encode(salt);
    final passwordBytes = utf8.encode(password);
    final hmac = Hmac(sha256, keyBytes);
    return hmac.convert(passwordBytes).toString();
  }

  /// Compares two strings in constant time to avoid timing-channel leakage.
  ///
  /// Returns `false` if lengths differ or if any character does not match,
  /// executing a constant number of operations across the string length.
  static bool constantTimeCompare(String a, String b) {
    if (a.length != b.length) {
      return false;
    }
    int accumulator = 0;
    for (int i = 0; i < a.length; i++) {
      accumulator |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return accumulator == 0;
  }

  /// Verifies whether [candidatePassword] matches the [salt] and [expectedHash]
  /// using constant-time comparison.
  static bool verify({
    required String candidatePassword,
    required String salt,
    required String expectedHash,
  }) {
    if (candidatePassword.isEmpty || salt.isEmpty || expectedHash.isEmpty) {
      return false;
    }
    final candidateHash = hashPassword(candidatePassword, salt);
    return constantTimeCompare(candidateHash, expectedHash);
  }
}

