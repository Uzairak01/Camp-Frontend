import 'package:flutter/foundation.dart';

import 'emergency_contact_model.dart';
import 'emergency_phone_helper.dart';

/// Persisted user profile domain model with stable ID, createdAt, and updatedAt.
@immutable
class UserProfile {
  UserProfile({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.fullName,
    this.username,
    this.email,
    this.phone,
    this.homeCity,
    this.dob,
    this.avatarPath,
    this.ridingTier = '',
    this.experienceIndex = 2,
    Set<String>? ridingStyles,
    this.unitIndex = 0,
    List<EmergencyContact>? emergencyContacts,
    String? emergencyContactName,
    String? emergencyContactRelation,
    String? emergencyContactPhone,
    String? bloodGroup,
    this.allergies,
    this.medicalNotes,
  })  : id = id ?? 'profile-default',
        createdAt = (createdAt ?? DateTime.now()).toUtc(),
        updatedAt = (updatedAt ?? DateTime.now()).toUtc(),
        ridingStyles = ridingStyles ?? const {'Touring'},
        bloodGroup = normalizeBloodType(bloodGroup),
        emergencyContacts = (emergencyContacts != null && emergencyContacts.isNotEmpty)
            ? List.unmodifiable(emergencyContacts)
            : ((emergencyContactPhone != null && emergencyContactPhone.trim().isNotEmpty) ||
                    (emergencyContactName != null && emergencyContactName.trim().isNotEmpty) ||
                    (emergencyContactRelation != null && emergencyContactRelation.trim().isNotEmpty))
                ? List.unmodifiable([
                    EmergencyContact(
                      id: 'ec_migrated_primary',
                      name: (emergencyContactName ?? '').trim(),
                      relation: (emergencyContactRelation ?? '').trim(),
                      phone: (emergencyContactPhone ?? '').trim(),
                      createdAt: (createdAt ?? DateTime.now()).toUtc(),
                      updatedAt: (updatedAt ?? DateTime.now()).toUtc(),
                    ),
                  ])
                : const [];

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    DateTime? parseUtc(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val)?.toUtc();
      return null;
    }

    final created = parseUtc(json['createdAt']) ?? DateTime.now().toUtc();
    final updated = parseUtc(json['updatedAt']) ?? created;

    Set<String> styles = {'Touring'};
    if (json['ridingStyles'] is List) {
      styles = (json['ridingStyles'] as List).cast<String>().toSet();
    }

    // Deserialise emergency contacts list (supporting tolerant types)
    List<EmergencyContact> contacts = [];
    if (json['emergencyContacts'] is List) {
      contacts = (json['emergencyContacts'] as List)
          .whereType<Map<dynamic, dynamic>>()
          .map((c) => EmergencyContact.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    }

    // One-time migration: convert legacy single emergency contact fields into
    // the first EmergencyContact if list was missing/empty.
    if (contacts.isEmpty) {
      final legacyPhone = json['emergencyContactPhone']?.toString().trim() ?? '';
      final legacyName = json['emergencyContactName']?.toString().trim() ?? '';
      final legacyRelation = json['emergencyContactRelation']?.toString().trim() ?? '';
      if (legacyPhone.isNotEmpty || legacyName.isNotEmpty) {
        contacts = [
          EmergencyContact(
            id: 'ec_migrated_primary',
            name: legacyName.isNotEmpty ? legacyName : 'Emergency Contact',
            relation: legacyRelation,
            phone: EmergencyPhoneHelper.migrateLegacyPhoneNumber(legacyPhone),
            createdAt: created,
            updatedAt: updated,
          ),
        ];
      }
    }

    return UserProfile(
      id: json['id'] as String? ?? 'profile-default',
      createdAt: created,
      updatedAt: updated,
      fullName: json['fullName'] as String?,
      username: json['username'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      homeCity: json['homeCity'] as String?,
      dob: json['dob'] as String?,
      avatarPath: json['avatarPath'] as String?,
      ridingTier: json['ridingTier'] as String? ?? '',
      experienceIndex: (json['experienceIndex'] as num?)?.toInt() ?? 2,
      ridingStyles: styles,
      unitIndex: (json['unitIndex'] as num?)?.toInt() ?? 0,
      emergencyContacts: contacts,
      bloodGroup: json['bloodGroup'] as String?,
      allergies: json['allergies'] as String?,
      medicalNotes: (json['medicalNotes'] ?? json['medical_notes']) as String?,
    );
  }

  static const List<String> kNormalizedBloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    'Unknown',
  ];

  /// Normalises blood type string to standard values (A+, A-, B+, B-, AB+, AB-, O+, O-, Unknown),
  /// or returns empty string if raw input is null/empty.
  static String normalizeBloodType(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('A+')) return 'A+';
    if (trimmed.startsWith('A-')) return 'A-';
    if (trimmed.startsWith('B+')) return 'B+';
    if (trimmed.startsWith('B-')) return 'B-';
    if (trimmed.startsWith('AB+')) return 'AB+';
    if (trimmed.startsWith('AB-')) return 'AB-';
    if (trimmed.startsWith('O+')) return 'O+';
    if (trimmed.startsWith('O-')) return 'O-';
    if (trimmed.toLowerCase().contains('unknown') ||
        trimmed.toLowerCase().contains('not tested')) {
      return 'Unknown';
    }
    for (final b in kNormalizedBloodTypes) {
      if (b.toLowerCase() == trimmed.toLowerCase()) return b;
    }
    return 'Unknown';
  }

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get effectiveId => id;
  DateTime get effectiveCreatedAt => createdAt;
  DateTime get effectiveUpdatedAt => updatedAt;

  final String? fullName;
  final String? username;
  final String? email;
  final String? phone;
  final String? homeCity;
  final String? dob;
  final String? avatarPath;
  final String ridingTier;
  final int experienceIndex;
  final Set<String> ridingStyles;
  final int unitIndex;

  /// Emergency contacts list (maximum 5 saved per rider).
  final List<EmergencyContact> emergencyContacts;

  /// Backwards-compatible getter for primary emergency contact name.
  String get emergencyContactName =>
      emergencyContacts.isNotEmpty ? emergencyContacts.first.name : '';

  /// Backwards-compatible getter for primary emergency contact relationship.
  String get emergencyContactRelation =>
      emergencyContacts.isNotEmpty ? emergencyContacts.first.relation : '';

  /// Backwards-compatible getter for primary emergency contact phone number.
  String get emergencyContactPhone =>
      emergencyContacts.isNotEmpty ? emergencyContacts.first.phone : '';

  final String bloodGroup;
  final String? allergies;
  final String? medicalNotes;

  UserProfile copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? fullName,
    String? username,
    String? email,
    String? phone,
    String? homeCity,
    String? dob,
    String? avatarPath,
    String? ridingTier,
    int? experienceIndex,
    Set<String>? ridingStyles,
    int? unitIndex,
    List<EmergencyContact>? emergencyContacts,
    String? emergencyContactName,
    String? emergencyContactRelation,
    String? emergencyContactPhone,
    String? bloodGroup,
    String? allergies,
    String? medicalNotes,
  }) {
    List<EmergencyContact>? contacts = emergencyContacts;
    if (contacts == null &&
        (emergencyContactName != null ||
            emergencyContactPhone != null ||
            emergencyContactRelation != null)) {
      contacts = [
        EmergencyContact(
          id: 'ec_migrated_primary',
          name: (emergencyContactName ?? this.emergencyContactName).trim(),
          relation: (emergencyContactRelation ?? this.emergencyContactRelation).trim(),
          phone: (emergencyContactPhone ?? this.emergencyContactPhone).trim(),
        ),
      ];
    }

    return UserProfile(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      homeCity: homeCity ?? this.homeCity,
      dob: dob ?? this.dob,
      avatarPath: avatarPath ?? this.avatarPath,
      ridingTier: ridingTier ?? this.ridingTier,
      experienceIndex: experienceIndex ?? this.experienceIndex,
      ridingStyles: ridingStyles ?? this.ridingStyles,
      unitIndex: unitIndex ?? this.unitIndex,
      emergencyContacts: contacts ?? this.emergencyContacts,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      medicalNotes: medicalNotes ?? this.medicalNotes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'fullName': fullName,
        'username': username,
        'email': email,
        'phone': phone,
        'homeCity': homeCity,
        'dob': dob,
        'avatarPath': avatarPath,
        'ridingTier': ridingTier,
        'experienceIndex': experienceIndex,
        'ridingStyles': ridingStyles.toList(),
        'unitIndex': unitIndex,
        'emergencyContacts': emergencyContacts.map((c) => c.toJson()).toList(),
        'bloodGroup': bloodGroup,
        'allergies': allergies,
        'medicalNotes': medicalNotes,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          fullName == other.fullName &&
          username == other.username &&
          email == other.email &&
          phone == other.phone &&
          homeCity == other.homeCity &&
          dob == other.dob &&
          avatarPath == other.avatarPath &&
          ridingTier == other.ridingTier &&
          experienceIndex == other.experienceIndex &&
          setEquals(ridingStyles, other.ridingStyles) &&
          unitIndex == other.unitIndex &&
          listEquals(emergencyContacts, other.emergencyContacts) &&
          bloodGroup == other.bloodGroup &&
          allergies == other.allergies &&
          medicalNotes == other.medicalNotes;

  @override
  int get hashCode => Object.hash(
        id,
        fullName,
        username,
        email,
        phone,
        homeCity,
        dob,
        avatarPath,
        ridingTier,
        experienceIndex,
        Object.hashAll(ridingStyles),
        unitIndex,
        Object.hashAll(emergencyContacts),
        bloodGroup,
        allergies,
        medicalNotes,
      );
}
