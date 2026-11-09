import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../domain/emergency_contact_model.dart';
import '../../domain/emergency_phone_helper.dart';
import '../../domain/user_profile_model.dart';
import '../widgets/change_password_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CAMP Edit Profile Screen
//  Reached from the "Edit Profile" button on the Profile hero card.
//  No bottom nav bar — this is a sub-screen.
// ─────────────────────────────────────────────────────────────────────────────
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // ── Personal Info controllers ─────────────────────────────────────────────
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _homeCityCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  // ── Riding Profile state ──────────────────────────────────────────────────
  int _experienceIndex = 2; // 0=Beginner 1=Intermediate 2=Advanced
  final Set<String> _ridingStyles = {'Touring'};
  int _unitIndex = 0; // 0=Metric 1=Imperial

  // ── Emergency Contacts list (maximum 5, first is primary) ─────────────────
  List<EmergencyContact> _emergencyContacts = [];
  final _allergiesCtrl = TextEditingController();
  final _medicalNotesCtrl = TextEditingController();
  String _bloodGroup = '';
  String? _avatarPath;

  static const List<String> _bloodGroups = UserProfile.kNormalizedBloodTypes;

  @override
  void initState() {
    super.initState();
    final profile = ProfileController.instance;
    _fullNameCtrl.text = profile.fullName;
    _usernameCtrl.text = profile.username;
    _emailCtrl.text = profile.email;
    _phoneCtrl.text = profile.phone;
    _homeCityCtrl.text = profile.homeCity;
    _dobCtrl.text = profile.dob;
    _experienceIndex = profile.experienceIndex;
    _ridingStyles.clear();
    _ridingStyles.addAll(profile.ridingStyles);
    _unitIndex = profile.unitIndex;
    _emergencyContacts = List.from(profile.emergencyContacts);
    _allergiesCtrl.text = profile.allergies;
    _medicalNotesCtrl.text = profile.medicalNotes;
    _bloodGroup = UserProfile.normalizeBloodType(profile.bloodGroup);
    _avatarPath = profile.avatarPath;
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _homeCityCtrl.dispose();
    _dobCtrl.dispose();
    _allergiesCtrl.dispose();
    _medicalNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _avatarPath = picked.path;
        });
        ProfileController.instance.setAvatarPath(picked.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Camera or storage access was not available ($e)',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.darkCharcoal,
          ),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.clay,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppColors.dockShadow,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mutedLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Change Profile Photo', style: AppTextStyles.cardTitle),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.tacticalOrange),
                title: Text('Take Photo with Camera',
                    style: AppTextStyles.itemTitle),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.tacticalOrange),
                title: Text('Choose from Gallery',
                    style: AppTextStyles.itemTitle),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Date picker for Date of Birth ─────────────────────────────────────────
  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1991, 3, 14),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: AppColors.tacticalOrange),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      setState(() {
        _dobCtrl.text =
            '${months[picked.month - 1]} ${picked.day}, ${picked.year}';
      });
    }
  }

  Future<void> _onSave() async {
    await ProfileController.instance.updateProfile(
      fullName: _fullNameCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      homeCity: _homeCityCtrl.text.trim(),
      dob: _dobCtrl.text.trim(),
      avatarPath: _avatarPath,
      experienceIndex: _experienceIndex,
      ridingStyles: _ridingStyles,
      unitIndex: _unitIndex,
      emergencyContacts: _emergencyContacts,
      bloodGroup: _bloodGroup,
      allergies: _allergiesCtrl.text.trim(),
      medicalNotes: _medicalNotesCtrl.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Profile saved successfully',
          style: GoogleFonts.manrope(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.darkCharcoal,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(milliseconds: 2000),
      ),
    );
    Navigator.of(context).pop();
  }

  void _onDeleteAccount() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusCard)),
        backgroundColor: AppColors.clay,
        title: Text('Delete Account?', style: AppTextStyles.cardTitle),
        content: Text(
          'This action is permanent and cannot be undone. All your ride history, garage, and SOS data will be erased.',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: GoogleFonts.manrope(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Delete',
                style: GoogleFonts.manrope(
                    color: AppColors.alertRed,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.clay,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── 1. Header ────────────────────────────────────────────────
              _buildHeader(context),

              // ── Scrollable Body ──────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppColors.screenPadding,
                    20,
                    AppColors.screenPadding,
                    40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── 2. Avatar Section ──────────────────────────────
                      _buildAvatarSection(),

                      const SizedBox(height: AppColors.cardGap),

                      // ── 3. Personal Info Card ──────────────────────────
                      _buildPersonalInfoCard(),

                      const SizedBox(height: AppColors.cardGap),

                      // ── 4. Riding Profile Card ─────────────────────────
                      _buildRidingProfileCard(),

                      const SizedBox(height: AppColors.cardGap),

                      // ── 5. Emergency Contact Card ──────────────────────
                      _buildEmergencyContactCard(),

                      const SizedBox(height: AppColors.cardGap),

                      // ── 6. Security & Auth Card ────────────────────────
                      _buildSecurityCard(),

                      const SizedBox(height: 24),

                      // ── 7. Save Changes Button ─────────────────────────
                      PrimaryButton(
                        label: 'Save Changes',
                        icon: Icons.arrow_forward_rounded,
                        isFullWidth: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        onTap: _onSave,
                      ),

                      const SizedBox(height: 24),

                      // ── 8. Delete Account Link ─────────────────────────
                      _buildDeleteAccountLink(),

                      // Bottom safe-area clearance
                      SizedBox(
                          height:
                              MediaQuery.of(context).padding.bottom + 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  1. Header
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return CampAppBar(
      leading: CampAppBarLeading.back,
      titleText: 'Edit Profile',
      actionText: 'Save',
      onActionPressed: _onSave,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  2. Avatar Section
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAvatarSection() {
    Widget avatarChild;
    if (_avatarPath != null && _avatarPath!.isNotEmpty) {
      final file = File(_avatarPath!);
      if (file.existsSync()) {
        avatarChild = Image.file(
          file,
          width: 90,
          height: 90,
          fit: BoxFit.cover,
        );
      } else {
        avatarChild = Center(
          child: Text(
            _fullNameCtrl.text.isNotEmpty ? _fullNameCtrl.text[0] : 'R',
            style: GoogleFonts.manrope(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.tacticalOrange,
            ),
          ),
        );
      }
    } else {
      avatarChild = const Center(
        child: Icon(
          Icons.person_rounded,
          size: 50,
          color: AppColors.mutedLight,
        ),
      );
    }

    return Column(
      children: [
        // Avatar circle with orange camera badge overlapping bottom-right
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showPhotoOptions,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.clayDark,
                  boxShadow: AppColors.skeuRaised,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: ClipOval(child: avatarChild),
              ),
              // Camera badge
              Positioned(
                bottom: 0,
                right: -2,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.tacticalOrangeLight,
                        AppColors.tacticalOrangeDark
                      ],
                    ),
                    boxShadow: AppColors.orangeGlow,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // "Change Photo" orange link
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showPhotoOptions,
          child: Text('Change Photo', style: AppTextStyles.orangeLink),
        ),

        const SizedBox(height: 4),

        // Caption
        Text(
          'Recommended 400x400px JPEG or PNG',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  3. Personal Info Card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPersonalInfoCard() {
    return CampCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardSectionHeader(
            icon: Icons.person_outline_rounded,
            title: 'Personal Info',
            pill: const StatusChip(
              label: 'Public & SOS',
              variant: StatusChipVariant.neutral,
            ),
          ),

          const SizedBox(height: 16),

          LabeledTextField(label: 'FULL NAME', controller: _fullNameCtrl),
          const SizedBox(height: 12),
          LabeledTextField(label: 'USERNAME', controller: _usernameCtrl),
          const SizedBox(height: 12),
          LabeledTextField(
            label: 'EMAIL ADDRESS',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),

          // Phone — ERROR state
          LabeledTextField(
            label: 'PHONE NUMBER',
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            isError: true,
            errorText: 'Enter a valid phone number',
            errorLabel: 'Requires verification',
            trailingIcon: Icons.warning_rounded,
          ),
          const SizedBox(height: 12),

          LabeledTextField(label: 'HOME CITY', controller: _homeCityCtrl),
          const SizedBox(height: 12),

          // Date of Birth — calendar icon, opens date picker
          LabeledTextField(
            label: 'DATE OF BIRTH',
            controller: _dobCtrl,
            readOnly: true,
            trailingIcon: Icons.calendar_today_rounded,
            trailingIconColor: AppColors.mutedLight,
            onTap: _pickDob,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  4. Riding Profile Card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRidingProfileCard() {
    return CampCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardSectionHeader(
            icon: Icons.directions_bike_rounded,
            title: 'Riding Profile',
          ),

          const SizedBox(height: 16),

          // Riding Experience
          Text('RIDING EXPERIENCE', style: AppTextStyles.overline),
          const SizedBox(height: 8),
          SegmentedControl(
            options: const ['Beginner', 'Intermediate', 'Advanced'],
            selectedIndex: _experienceIndex,
            onChanged: (i) => setState(() => _experienceIndex = i),
          ),

          const SizedBox(height: 16),

          // Riding Style (Multi-Select)
          Text('RIDING STYLE (MULTI-SELECT)', style: AppTextStyles.overline),
          const SizedBox(height: 8),
          MultiSelectChipRow(
            options: const ['Commuter', 'Touring', 'Off-road', 'Sport'],
            selected: _ridingStyles,
            onToggle: (s) => setState(() {
              if (_ridingStyles.contains(s)) {
                _ridingStyles.remove(s);
              } else {
                _ridingStyles.add(s);
              }
            }),
          ),

          const SizedBox(height: 16),

          // Preferred Units
          Text('PREFERRED UNITS', style: AppTextStyles.overline),
          const SizedBox(height: 8),
          SegmentedControl(
            options: const ['Metric (km, \u00b0C)', 'Imperial (mi, \u00b0F)'],
            selectedIndex: _unitIndex,
            onChanged: (i) => setState(() => _unitIndex = i),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  5. Emergency Contacts Card (Multiple Contacts, Max 5, First is Primary)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEmergencyContactCard() {
    return CampCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardSectionHeader(
            icon: Icons.contact_phone_rounded,
            iconColor: AppColors.tacticalOrangeDark,
            title: 'Emergency contacts',
            pill: StatusChip(
              label: _emergencyContacts.isNotEmpty ? 'SOS ready' : 'Not set',
              variant: _emergencyContacts.isNotEmpty
                  ? StatusChipVariant.success
                  : StatusChipVariant.danger,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save up to 5 emergency contacts. The first contact in your list is your primary contact for direct emergency calls.',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AppColors.mutedText,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          // ── Contacts List / Empty State ───────────────────────────────────
          if (_emergencyContacts.isEmpty)
            Container(
              key: const Key('empty_emergency_contacts_box'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.contact_phone_outlined,
                        color: Color(0xFF64748B),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No emergency contacts yet',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add your trusted ICE contacts to alert them in a roadside crisis.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      color: AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    key: const Key('add_emergency_contact_btn'),
                    onPressed: () => _showAddEditContactDialog(),
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'Add Contact',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tacticalOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Column(
              children: List.generate(_emergencyContacts.length, (index) {
                final c = _emergencyContacts[index];
                final isPrimary = index == 0;

                return Container(
                  key: Key('emergency_contact_item_$index'),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isPrimary
                          ? AppColors.statusGreen.withValues(alpha: 0.5)
                          : const Color(0xFFE2E8F0),
                      width: isPrimary ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isPrimary) ...[
                                  Container(
                                    key: const Key('chip_primary_contact'),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'PRIMARY',
                                      style: GoogleFonts.manrope(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.statusGreen,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(
                                    c.name,
                                    style: GoogleFonts.manrope(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.darkCharcoal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (c.relation.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '(${c.relation})',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        color: AppColors.mutedText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              EmergencyPhoneHelper.formatPhoneReadable(c.phone),
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                            if (!EmergencyPhoneHelper.hasValidFormat(c.phone)) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Check number format',
                                style: GoogleFonts.manrope(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.alertRed,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isPrimary)
                            TextButton(
                              key: Key('make_primary_btn_$index'),
                              onPressed: () => _makePrimary(index),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              ),
                              child: Text(
                                'Make primary',
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.tacticalOrange,
                                ),
                              ),
                            ),
                          IconButton(
                            key: Key('edit_contact_btn_$index'),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: AppColors.darkCharcoal,
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Edit contact',
                            onPressed: () => _showAddEditContactDialog(contact: c, index: index),
                          ),
                          IconButton(
                            key: Key('delete_contact_btn_$index'),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            color: AppColors.alertRed,
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Delete contact',
                            onPressed: () => _deleteContact(index),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ),
            if (_emergencyContacts.length < 5) ...[
              const SizedBox(height: 4),
              OutlinedButton.icon(
                key: const Key('add_another_contact_btn'),
                onPressed: () => _showAddEditContactDialog(),
                icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.tacticalOrange),
                label: Text(
                  'Add another contact (${_emergencyContacts.length}/5)',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tacticalOrange,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFED7AA), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'Maximum 5 emergency contacts saved.',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedText,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],

          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // Blood Group dropdown
          LabeledDropdown<String>(
            label: 'RIDER BLOOD GROUP',
            value: _bloodGroups.contains(_bloodGroup) ? _bloodGroup : _bloodGroups.last,
            items: _bloodGroups,
            onChanged: (v) {
              if (v != null) {
                setState(() => _bloodGroup = v);
              }
            },
          ),
          const SizedBox(height: 12),

          LabeledTextField(
            label: 'KNOWN ALLERGIES',
            controller: _allergiesCtrl,
            maxLength: 100,
            placeholder: 'e.g. Penicillin, Peanuts (optional)',
          ),
          const SizedBox(height: 12),

          LabeledTextField(
            label: 'MEDICAL NOTES',
            controller: _medicalNotesCtrl,
            maxLength: 120,
            maxLines: 2,
            placeholder: 'e.g. Asthma, Diabetic, Past surgeries (optional)',
          ),

          const SizedBox(height: 16),

          // Info banner
          _buildInfoBanner(
            'Shown on your Emergency SOS Medical ID card and accessible by first responders.',
          ),
        ],
      ),
    );
  }

  void _makePrimary(int index) {
    if (index > 0 && index < _emergencyContacts.length) {
      setState(() {
        final contact = _emergencyContacts.removeAt(index);
        _emergencyContacts.insert(0, contact);
      });
    }
  }

  void _deleteContact(int index) {
    if (index >= 0 && index < _emergencyContacts.length) {
      setState(() {
        _emergencyContacts.removeAt(index);
      });
    }
  }

  Future<void> _showAddEditContactDialog({EmergencyContact? contact, int? index}) async {
    final String initialCode;
    final String initialNationalPhone;

    if (contact != null) {
      final split = EmergencyPhoneHelper.splitE164(contact.phone);
      initialCode = split.countryCode;
      initialNationalPhone = split.nationalNumber;
    } else {
      // First time: empty. Subsequent times: prefilled with rider's last used code.
      initialCode = ProfileController.instance.lastUsedCountryCode ?? '';
      initialNationalPhone = '';
    }

    final nameCtrl = TextEditingController(text: contact?.name ?? '');
    final relCtrl = TextEditingController(text: contact?.relation ?? '');
    final codeCtrl = TextEditingController(text: initialCode);
    final phoneCtrl = TextEditingController(text: initialNationalPhone);
    String? nameError;
    String? codeError;
    String? phoneError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void validateAndSubmit() {
            final name = nameCtrl.text.trim();
            final rel = relCtrl.text.trim();
            final code = codeCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
            var national = EmergencyPhoneHelper.stripFormatting(phoneCtrl.text.trim());
            // Strip leading zeros from national part (e.g. 03212699353 -> 3212699353)
            national = national.replaceFirst(RegExp(r'^0+'), '');

            String? nErr;
            String? cErr;
            String? pErr;

            // Validate name required
            if (name.isEmpty) {
              nErr = 'Name is required';
            }

            // Validate country code required (1 to 3 digits)
            if (code.isEmpty) {
              cErr = 'Country code is required';
            } else if (code.length > 3) {
              cErr = 'Code must be 1 to 3 digits';
            }

            // Validate national number (6 to 12 digits, digits only)
            if (national.isEmpty) {
              pErr = 'Phone number is required';
            } else if (!RegExp(r'^[0-9]+$').hasMatch(national)) {
              pErr = 'Phone must contain digits only';
            } else if (national.length < 6 || national.length > 12) {
              pErr = 'National number must be between 6 and 12 digits';
            } else if (code.isNotEmpty) {
              // Check duplicate full E.164 against other contacts
              final fullE164 = '+$code$national';
              final isDuplicate = _emergencyContacts.asMap().entries.any((entry) {
                if (index != null && entry.key == index) return false;
                return entry.value.phone == fullE164;
              });
              if (isDuplicate) {
                pErr = 'This phone number is already added';
              }
            }

            if (nErr != null || cErr != null || pErr != null) {
              setDialogState(() {
                nameError = nErr;
                codeError = cErr;
                phoneError = pErr;
              });
              return;
            }

            final savedPhone = '+$code$national';

            // Remember the last code used through the profile repository
            ProfileController.instance.saveLastUsedCountryCode(code);

            setState(() {
              if (contact == null) {
                if (_emergencyContacts.length < 5) {
                  _emergencyContacts.add(
                    EmergencyContact(
                      name: name,
                      relation: rel,
                      phone: savedPhone,
                    ),
                  );
                }
              } else {
                _emergencyContacts[index!] = contact.copyWith(
                  name: name,
                  relation: rel,
                  phone: savedPhone,
                );
              }
            });
            Navigator.of(ctx).pop();
          }

          return AlertDialog(
            backgroundColor: AppColors.clay,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusCard)),
            title: Text(
              contact == null ? 'Add Emergency Contact' : 'Edit Emergency Contact',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const Key('input_contact_name'),
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Contact Name *',
                      errorText: nameError,
                      labelStyle: GoogleFonts.manrope(fontSize: 13, color: AppColors.mutedText),
                      errorStyle: GoogleFonts.manrope(fontSize: 11, color: AppColors.alertRed),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('input_contact_relation'),
                    controller: relCtrl,
                    decoration: InputDecoration(
                      labelText: 'Relationship (optional)',
                      hintText: 'e.g. Father, Spouse, Friend',
                      labelStyle: GoogleFonts.manrope(fontSize: 13, color: AppColors.mutedText),
                      hintStyle: GoogleFonts.manrope(fontSize: 12, color: AppColors.mutedText),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Country code field: small text box with fixed "+" prefix, digits only, 1-3 digits
                      SizedBox(
                        width: 78,
                        child: TextField(
                          key: const Key('input_contact_country_code'),
                          controller: codeCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Code *',
                            hintText: 'Code',
                            prefixText: '+',
                            errorText: codeError != null ? '' : null,
                            labelStyle: GoogleFonts.manrope(fontSize: 13, color: AppColors.mutedText),
                            hintStyle: GoogleFonts.manrope(fontSize: 12, color: AppColors.mutedText),
                            errorStyle: const TextStyle(fontSize: 0, height: 0),
                          ),
                          onChanged: (_) {
                            if (codeError != null) {
                              setDialogState(() => codeError = null);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // National number field
                      Expanded(
                        child: TextField(
                          key: const Key('input_contact_phone'),
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone Number *',
                            hintText: 'Phone number',
                            errorText: phoneError,
                            labelStyle: GoogleFonts.manrope(fontSize: 13, color: AppColors.mutedText),
                            hintStyle: GoogleFonts.manrope(fontSize: 12, color: AppColors.mutedText),
                            errorStyle: GoogleFonts.manrope(fontSize: 11, color: AppColors.alertRed),
                          ),
                          onChanged: (val) {
                            if (phoneError != null) {
                              setDialogState(() => phoneError = null);
                            }
                            final trimmed = val.trim();
                            if (trimmed.startsWith('+') || trimmed.startsWith('00')) {
                              if (codeCtrl.text.trim().isEmpty) {
                                // Code box is empty: split into code box and national field
                                final split = EmergencyPhoneHelper.trySplitPastedNumber(trimmed);
                                if (split != null) {
                                  setDialogState(() {
                                    codeCtrl.text = split.countryCode;
                                    phoneCtrl.value = TextEditingValue(
                                      text: split.nationalNumber,
                                      selection: TextSelection.collapsed(
                                        offset: split.nationalNumber.length,
                                      ),
                                    );
                                  });
                                } else {
                                  setDialogState(() {
                                    phoneError = 'Check number format';
                                  });
                                }
                              } else {
                                // Code box is already typed: keep code box as typed
                                var clean = EmergencyPhoneHelper.stripFormatting(trimmed);
                                if (clean.startsWith('00')) clean = clean.substring(2);
                                if (clean.startsWith('+')) clean = clean.substring(1);
                                final currentCode = codeCtrl.text.trim();
                                if (clean.startsWith(currentCode)) {
                                  clean = clean.substring(currentCode.length);
                                }
                                clean = clean.replaceFirst(RegExp(r'^0+'), '');
                                phoneCtrl.value = TextEditingValue(
                                  text: clean,
                                  selection: TextSelection.collapsed(offset: clean.length),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (codeError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      codeError!,
                      key: const Key('error_contact_country_code'),
                      style: GoogleFonts.manrope(fontSize: 11, color: AppColors.alertRed),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                  ),
                ),
              ),
              ElevatedButton(
                key: const Key('btn_save_contact'),
                onPressed: validateAndSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tacticalOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'Save',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  6. Security & Authentication Card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSecurityCard() {
    final signedInEmail = AuthController.instance.currentUser?.email ??
        (ProfileController.instance.email.isNotEmpty
            ? ProfileController.instance.email
            : _emailCtrl.text.trim());

    return CampCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardSectionHeader(
            icon: Icons.lock_outline_rounded,
            title: 'Security & Authentication',
          ),
          const SizedBox(height: 8),

          // Change password row
          _SettingsRow(
            key: const Key('change_password_row'),
            icon: Icons.vpn_key_outlined,
            title: 'Change password',
            subtitle: 'Update your account password',
            onTap: () => _showChangePasswordSheet(context),
          ),

          const Divider(height: 1, color: Color(0x12000000)),

          // Linked account row (read-only, no buttons, no fake providers)
          // Note: When Firebase Auth is integrated, add Google linked account row here below the CAMP account.
          _buildLinkedAccountRow(signedInEmail),
        ],
      ),
    );
  }

  /// Opens the Change Password modal bottom sheet.
  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChangePasswordSheet(parentContext: context),
    );
  }

  /// Read-only Linked Account row displaying the authenticated account's email and badge.
  Widget _buildLinkedAccountRow(String email) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          const IconTile(
            icon: Icons.alternate_email_rounded,
            size: 36,
            iconSize: 18,
            iconColor: AppColors.darkCharcoal,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Linked account',
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email.isNotEmpty ? email : 'No account connected',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.clayDark,
              borderRadius: BorderRadius.circular(AppColors.radiusPill),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: AppColors.skeuRecessed,
            ),
            child: Text(
              'CAMP account',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.darkCharcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  8. Delete Account Link
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDeleteAccountLink() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onDeleteAccount,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.delete_outline_rounded,
              size: 16, color: AppColors.alertRed),
          const SizedBox(width: 6),
          Text(
            'Delete CAMP Account',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.alertRed,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Shared: Card section header
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCardSectionHeader({
    required IconData icon,
    required String title,
    Color? iconColor,
    Widget? pill,
  }) {
    return Row(
      children: [
        IconTile(
          icon: icon,
          size: 36,
          iconSize: 18,
          iconColor: iconColor ?? AppColors.darkCharcoal,
          isInset: true,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: AppTextStyles.cardTitle)),
        ?pill,
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Shared: Info banner
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildInfoBanner(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.clayDark,
        borderRadius: BorderRadius.circular(AppColors.radiusTile),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.45), width: 1),
        boxShadow: AppColors.skeuRecessed,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.tacticalOrangeDark),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.caption)),
        ],
      ),
    );
  }
}



// ─────────────────────────────────────────────────────────────────────────────
//  _SettingsRow
//  Mirrors _buildSettingsRow() from ProfileScreen exactly, extracted as a
//  standalone private widget for inline use inside a Card.
//  The pattern is REUSED (not new) — same icon, title, subtitle, chevron
//  layout as ProfileScreen._buildSettingsRow.
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.onTap,
    super.key,
    this.icon,
    this.subtitle,
  });

  final String title;
  final VoidCallback onTap;
  final IconData? icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            IconTile(
              icon: icon ?? Icons.settings_outlined,
              size: 36,
              iconSize: 18,
              iconColor: AppColors.darkCharcoal,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.mutedLight, size: 20),
          ],
        ),
      ),
    );
  }
}
