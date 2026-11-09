import 'package:flutter/foundation.dart';
import '../../../core/data/app_repositories.dart';
import '../../../core/data/profile_repository.dart';
import '../../../core/data/profile_repository_local.dart';
import '../../auth/controllers/auth_controller.dart';
import '../domain/emergency_contact_model.dart';
import '../domain/user_profile_model.dart';

/// Single source of truth for the rider's profile information.
/// Persisted through [ProfileRepository].
class ProfileController extends ChangeNotifier {
  ProfileController({ProfileRepository? repository})
      : _repository = repository ?? AppRepositories.instance.profileRepository;

  static ProfileController instance = ProfileController();

  ProfileRepository _repository;

  @visibleForTesting
  set repository(ProfileRepository repo) => _repository = repo;

  String? _fullName;
  String? _username;
  String? _email;
  String? _phone;
  String? _homeCity;
  String? _dob;
  String? _avatarPath;
  String _ridingTier = '';
  int _experienceIndex = 2; // 0=Beginner, 1=Intermediate, 2=Advanced
  Set<String> _ridingStyles = {'Touring'};
  int _unitIndex = 0; // 0=Metric, 1=Imperial

  // Emergency contacts (up to 5, first contact is primary)
  List<EmergencyContact> _emergencyContacts = [];
  String _bloodGroup = '';
  String? _allergies;
  String? _medicalNotes;

  // Last country code used by rider when adding/editing contacts
  String? _lastUsedCountryCode;

  // ── Getters ────────────────────────────────────────────────────────────────
  String get fullName {
    if (_fullName != null && _fullName!.trim().isNotEmpty) {
      return _fullName!.trim();
    }
    final authName = AuthController.instance.currentUser?.name.trim();
    if (authName != null && authName.isNotEmpty) {
      return authName;
    }
    return '';
  }

  String get firstName {
    final name = fullName;
    if (name.isEmpty) return '';
    if (name.contains(' ')) return name.split(' ').first;
    return name;
  }

  String get username => _username ?? '';

  String get email {
    if (_email != null && _email!.trim().isNotEmpty) {
      return _email!.trim();
    }
    final authEmail = AuthController.instance.currentUser?.email;
    if (authEmail != null && authEmail.isNotEmpty) {
      return authEmail;
    }
    return '';
  }

  String get phone => _phone ?? (AuthController.instance.currentUser?.phone ?? '');
  String get homeCity => _homeCity ?? '';
  String get dob => _dob ?? '';
  String? get avatarPath => _avatarPath;
  String get ridingTier => _ridingTier;
  int get experienceIndex => _experienceIndex;
  Set<String> get ridingStyles => Set.unmodifiable(_ridingStyles);
  int get unitIndex => _unitIndex;

  /// Unmodifiable view of all saved emergency contacts (up to 5).
  List<EmergencyContact> get emergencyContacts => List.unmodifiable(_emergencyContacts);

  /// Primary emergency contact (the first contact in the list, or null if none).
  EmergencyContact? get primaryEmergencyContact =>
      _emergencyContacts.isNotEmpty ? _emergencyContacts.first : null;

  /// Backwards-compatible getter for primary emergency contact name.
  String get emergencyContactName => primaryEmergencyContact?.name ?? '';

  /// Backwards-compatible getter for primary emergency contact relationship.
  String get emergencyContactRelation => primaryEmergencyContact?.relation ?? '';

  /// Backwards-compatible getter for primary emergency contact phone number.
  String get emergencyContactPhone => primaryEmergencyContact?.phone ?? '';

  String get bloodGroup => _bloodGroup;
  String get allergies => _allergies ?? '';
  String get medicalNotes => _medicalNotes ?? '';

  /// Country calling code last used by the rider (digits only, e.g. '92', '966').
  String? get lastUsedCountryCode => _lastUsedCountryCode;

  /// Update profile attributes and persist to [ProfileRepository].
  ///
  /// Awaits storage write before calling [notifyListeners] to ensure
  /// all observing screens receive fully committed data.
  Future<void> updateProfile({
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
  }) async {
    if (fullName != null) _fullName = fullName;
    if (username != null) _username = username;
    if (email != null) _email = email;
    if (phone != null) _phone = phone;
    if (homeCity != null) _homeCity = homeCity;
    if (dob != null) _dob = dob;
    if (avatarPath != null) _avatarPath = avatarPath;
    if (ridingTier != null) _ridingTier = ridingTier;
    if (experienceIndex != null) _experienceIndex = experienceIndex;
    if (ridingStyles != null) _ridingStyles = Set.from(ridingStyles);
    if (unitIndex != null) _unitIndex = unitIndex;
    if (emergencyContacts != null) {
      _emergencyContacts = List.from(emergencyContacts);
    } else if ((emergencyContactPhone != null && emergencyContactPhone.trim().isNotEmpty) ||
        (emergencyContactName != null && emergencyContactName.trim().isNotEmpty)) {
      _emergencyContacts = [
        EmergencyContact(
          id: 'ec_migrated_primary',
          name: (emergencyContactName ?? '').trim(),
          relation: (emergencyContactRelation ?? '').trim(),
          phone: (emergencyContactPhone ?? '').trim(),
        ),
      ];
    }
    if (bloodGroup != null) _bloodGroup = UserProfile.normalizeBloodType(bloodGroup);
    if (allergies != null) _allergies = allergies;
    if (medicalNotes != null) _medicalNotes = medicalNotes;

    await save();
    notifyListeners();
  }

  /// Adds a single emergency contact (up to 5 maximum).
  Future<void> addEmergencyContact(EmergencyContact contact) async {
    if (_emergencyContacts.length >= 5) return;
    _emergencyContacts.add(contact);
    await save();
    notifyListeners();
  }

  /// Updates an existing emergency contact matching id.
  Future<void> updateEmergencyContact(EmergencyContact contact) async {
    final idx = _emergencyContacts.indexWhere((c) => c.id == contact.id);
    if (idx != -1) {
      _emergencyContacts[idx] = contact;
      await save();
      notifyListeners();
    }
  }

  /// Removes an emergency contact matching id.
  Future<void> removeEmergencyContact(String id) async {
    _emergencyContacts.removeWhere((c) => c.id == id);
    await save();
    notifyListeners();
  }

  /// Reorders contact with [id] to index 0, designating it as the primary contact.
  Future<void> setPrimaryEmergencyContact(String id) async {
    final idx = _emergencyContacts.indexWhere((c) => c.id == id);
    if (idx > 0) {
      final contact = _emergencyContacts.removeAt(idx);
      _emergencyContacts.insert(0, contact);
      await save();
      notifyListeners();
    }
  }

  /// Replaces the list of emergency contacts (up to 5) and persists.
  Future<void> setEmergencyContacts(List<EmergencyContact> contacts) async {
    _emergencyContacts = contacts.take(5).toList();
    await save();
    notifyListeners();
  }

  /// Saves the last used country calling code through [ProfileRepository].
  Future<void> saveLastUsedCountryCode(String code) async {
    final clean = code.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (clean.isNotEmpty) {
      _lastUsedCountryCode = clean;
      await _repository.saveLastUsedCountryCode(clean);
    }
  }

  /// Update only the avatar file path and persist.
  void setAvatarPath(String path) {
    _avatarPath = path;
    save();
    notifyListeners();
  }

  /// Await completion of all pending storage writes.
  Future<void> flush() => _repository.flush();

  /// Reset in-memory state for testing.
  @visibleForTesting
  void resetForTesting() {
    _fullName = null;
    _username = null;
    _email = null;
    _phone = null;
    _homeCity = null;
    _dob = null;
    _avatarPath = null;
    _ridingTier = '';
    _experienceIndex = 2;
    _ridingStyles = {'Touring'};
    _unitIndex = 0;
    _emergencyContacts = [];
    _bloodGroup = '';
    _allergies = null;
    _medicalNotes = null;
    _lastUsedCountryCode = null;
    _repository = AppRepositories.instance.profileRepository;
    notifyListeners();
  }

  /// Load profile and last used country code from repository.
  Future<void> load([dynamic source]) async {
    final repo = resolveProfileRepository(source, _repository);
    if (source != null) {
      _repository = repo;
    }
    try {
      final profile = await repo.loadProfile();
      if (profile != null) {
        _fullName = profile.fullName;
        _username = profile.username;
        _email = profile.email;
        _phone = profile.phone;
        _homeCity = profile.homeCity;
        _dob = profile.dob;
        _avatarPath = profile.avatarPath;
        _ridingTier = profile.ridingTier;
        _experienceIndex = profile.experienceIndex;
        _ridingStyles = profile.ridingStyles;
        _unitIndex = profile.unitIndex;
        _emergencyContacts = List.from(profile.emergencyContacts);
        _bloodGroup = profile.bloodGroup;
        _allergies = profile.allergies;
        _medicalNotes = profile.medicalNotes;
        notifyListeners();
      }
      _lastUsedCountryCode = await repo.loadLastUsedCountryCode();
    } catch (_) {
      // Gracefully fall back to defaults
    }
  }

  /// Save profile to repository.
  Future<void> save([dynamic source]) async {
    final repo = resolveProfileRepository(source, _repository);
    final profile = UserProfile(
      fullName: _fullName,
      username: _username,
      email: _email,
      phone: _phone,
      homeCity: _homeCity,
      dob: _dob,
      avatarPath: _avatarPath,
      ridingTier: _ridingTier,
      experienceIndex: _experienceIndex,
      ridingStyles: _ridingStyles,
      unitIndex: _unitIndex,
      emergencyContacts: _emergencyContacts,
      bloodGroup: _bloodGroup,
      allergies: _allergies,
      medicalNotes: _medicalNotes,
    );
    await repo.saveProfile(profile);
  }
}
