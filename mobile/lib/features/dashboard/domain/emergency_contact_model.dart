import 'package:flutter/foundation.dart';

import 'emergency_phone_helper.dart';

/// Persisted domain model representing a single emergency contact.
///
/// Up to 5 contacts can be saved per rider profile. The first contact in the
/// rider's list is the primary contact used for direct calls.
@immutable
class EmergencyContact {
  EmergencyContact({
    required this.name,
    required this.phone,
    String? id,
    this.relation = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? 'ec_${DateTime.now().millisecondsSinceEpoch}_${phone.hashCode.abs()}',
        createdAt = (createdAt ?? DateTime.now()).toUtc(),
        updatedAt = (updatedAt ?? DateTime.now()).toUtc();

  /// Tolerant JSON deserialization handling missing or dynamic types.
  /// Automatically migrates legacy Pakistani numbers (03XXXXXXXXX -> +923XXXXXXXXX).
  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    DateTime? parseUtc(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val)?.toUtc();
      return null;
    }

    final created = parseUtc(json['createdAt']) ?? DateTime.now().toUtc();
    final updated = parseUtc(json['updatedAt']) ?? created;
    final rawPhone = json['phone']?.toString() ?? '';
    final migratedPhone = EmergencyPhoneHelper.migrateLegacyPhoneNumber(rawPhone);

    return EmergencyContact(
      id: json['id']?.toString() ?? 'ec_${created.millisecondsSinceEpoch}',
      name: json['name']?.toString() ?? '',
      relation: json['relation']?.toString() ?? '',
      phone: migratedPhone,
      createdAt: created,
      updatedAt: updated,
    );
  }

  /// Unique stable identifier for the emergency contact.
  final String id;

  /// Full name or moniker of the emergency contact (e.g. "Sarah Khan").
  final String name;

  /// Relationship to the rider (optional free text, e.g. "Father", "Spouse", "Brother").
  final String relation;

  /// Validated phone number (digits and optional leading '+').
  final String phone;

  /// UTC timestamp when the contact was originally created.
  final DateTime createdAt;

  /// UTC timestamp when the contact was last modified.
  final DateTime updatedAt;

  /// Serializes contact into a JSON-compatible map with ISO-8601 UTC timestamps.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relation': relation,
        'phone': phone,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  /// Returns an updated copy of this contact instance.
  EmergencyContact copyWith({
    String? id,
    String? name,
    String? relation,
    String? phone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmergencyContact &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          relation == other.relation &&
          phone == other.phone;

  @override
  int get hashCode => Object.hash(id, name, relation, phone);

  @override
  String toString() =>
      'EmergencyContact(id: $id, name: $name, relation: $relation, phone: $phone)';
}
