import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/camp_app_bar.dart';
import '../../../../core/widgets/camp_bottom_nav.dart';
import '../../../../core/widgets/labeled_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../navigation/domain/location_service.dart';
import '../../controllers/mechanic_controller.dart';
import '../../domain/mechanic_model.dart';
import '../../domain/mechanic_open_status.dart';
import '../widgets/map_pin_picker_modal.dart';

/// Screen for adding or editing a community roadside mechanic / workshop.
/// Follows the tactile CAMP clay design language with recessed inputs,
/// camera/gallery photo picker, and persistent storage.
class AddMechanicScreen extends StatefulWidget {
  const AddMechanicScreen({
    super.key,
    this.mechanic,
    this.locationService,
    this.tileProvider,
  });

  final Mechanic? mechanic;
  final LocationService? locationService;
  final TileProvider? tileProvider;

  @override
  State<AddMechanicScreen> createState() => _AddMechanicScreenState();
}

class _AddMechanicScreenState extends State<AddMechanicScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _specialityController;
  late final TextEditingController _notesController;

  double? _latitude;
  double? _longitude;

  String? _photoPath;
  bool _nameError = false;
  String? _phoneError;

  List<int> _openDays = [];
  int? _openMinutes;
  int? _closeMinutes;
  bool _open24Hours = false;
  String? _hoursError;

  bool get _isEditing => widget.mechanic != null;

  @override
  void initState() {
    super.initState();
    final mech = widget.mechanic;
    _nameController = TextEditingController(text: mech?.name ?? '');
    _phoneController = TextEditingController(text: mech?.phone ?? '');
    _addressController = TextEditingController(
      text: mech?.address ?? (mech?.durationOrLocation ?? ''),
    );
    _latitude = mech?.latitude;
    _longitude = mech?.longitude;
    _specialityController = TextEditingController(
      text: mech != null && mech.tags1.isNotEmpty ? mech.tags1.join(', ') : '',
    );
    _notesController = TextEditingController(text: mech?.notes ?? '');
    _photoPath = mech?.photoPath;

    if (mech != null) {
      _openDays = List<int>.from(mech.openDays);
      _openMinutes = mech.openMinutes;
      _closeMinutes = mech.closeMinutes;
      _open24Hours = mech.open24Hours;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _specialityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Ensures picked photos outside app storage are copied to the app documents directory
  /// so they survive app restarts and temporary cache purges.
  Future<String> _persistImage(String pickedPath) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final mechanicsDir = Directory('${docsDir.path}/mechanics');
      if (!await mechanicsDir.exists()) {
        await mechanicsDir.create(recursive: true);
      }
      if (pickedPath.startsWith(docsDir.path)) {
        return pickedPath;
      }
      final extension = pickedPath.contains('.') ? pickedPath.split('.').last : 'jpg';
      final fileName = 'mech_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final targetFile = File('${mechanicsDir.path}/$fileName');
      final copied = await File(pickedPath).copy(targetFile.path);
      return copied.path;
    } catch (_) {
      // Gracefully fall back to original picked path if storage copy fails
      return pickedPath;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        final persisted = await _persistImage(picked.path);
        if (mounted) {
          setState(() {
            _photoPath = persisted;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Camera or storage access was not available. Please check device permissions.',
            ),
            backgroundColor: AppColors.darkCharcoal,
          ),
        );
      }
    }
  }

  void _showImageSourcePicker() {
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
              Text(
                'Shop or Signboard Photo',
                style: AppTextStyles.cardTitle,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppColors.tacticalOrange,
                ),
                title: Text(
                  'Take Photo with Camera',
                  style: AppTextStyles.itemTitle,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.tacticalOrange,
                ),
                title: Text(
                  'Choose from Gallery',
                  style: AppTextStyles.itemTitle,
                ),
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

  Future<void> _useCurrentLocation() async {
    try {
      final locService =
          widget.locationService ?? const GeolocatorLocationService();
      final hasPerm = await locService.checkPermission();
      if (!hasPerm) {
        final granted = await locService.requestPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission is required to save current position'),
                backgroundColor: AppColors.darkCharcoal,
              ),
            );
          }
          return;
        }
      }
      final pos = await locService.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Current location saved as shop location'),
            backgroundColor: AppColors.statusGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get position: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    }
  }

  Future<void> _chooseOnMap() async {
    LatLng center = const LatLng(31.5204, 74.3587);
    if (_latitude != null && _longitude != null) {
      center = LatLng(_latitude!, _longitude!);
    } else {
      try {
        final locService =
            widget.locationService ?? const GeolocatorLocationService();
        final pos = await locService.getCurrentPosition();
        if (pos != null) {
          center = pos.toLatLng();
        }
      } catch (_) {}
    }

    if (!mounted) return;

    final LatLng? picked = await showDialog<LatLng>(
      context: context,
      builder: (ctx) => MapPinPickerModal(
        initialCenter: center,
        initialPin: _latitude != null && _longitude != null
            ? LatLng(_latitude!, _longitude!)
            : null,
        tileProvider: widget.tileProvider,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _latitude = picked.latitude;
        _longitude = picked.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Map pin location saved as shop location'),
          backgroundColor: AppColors.statusGreen,
        ),
      );
    }
  }

  void _saveMechanic() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = true;
      });
      return;
    }

    // Opening hours validation:
    // If days are chosen, both times are required unless Open 24 hours is on.
    // Closing earlier than opening is allowed (overnight). Equal times are invalid.
    // Leaving the whole section empty is fine.
    if (_openDays.isNotEmpty) {
      if (!_open24Hours) {
        if (_openMinutes == null || _closeMinutes == null) {
          setState(() {
            _hoursError = 'Opening and closing times are required';
          });
          return;
        }
        if (_openMinutes == _closeMinutes) {
          setState(() {
            _hoursError = 'Opening and closing times cannot be identical';
          });
          return;
        }
      }
    } else {
      if (_open24Hours || _openMinutes != null || _closeMinutes != null) {
        setState(() {
          _hoursError = 'Please select at least one open day';
        });
        return;
      }
    }

    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length < 5 || !RegExp(r'^[+0-9\s\-()]{5,20}$').hasMatch(phone)) {
        setState(() {
          _phoneError = 'Please enter a valid phone number (at least 5 digits)';
        });
        return;
      }
    }

    final address = _addressController.text.trim();
    final speciality = _specialityController.text.trim();
    final notes = _notesController.text.trim();

    final existing = widget.mechanic;
    final id = existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final List<String> tags1;
    if (speciality.isNotEmpty) {
      tags1 = speciality
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      tags1 = existing?.tags1 ?? const ['General Repair'];
    }

    final List<String> tags2;
    if (address.isNotEmpty) {
      tags2 = [address];
    } else {
      tags2 = existing?.tags2 ?? const ['Local Area'];
    }

    final newMech = Mechanic(
      id: id,
      name: name,
      distance: null,
      latitude: _latitude,
      longitude: _longitude,
      durationOrLocation: address.isNotEmpty
          ? address
          : (existing?.durationOrLocation ?? ''),
      badgeType: BadgeType.verified,
      badgeLabel: 'Added by you',
      beaconStatus: '',
      beaconColor: AppColors.statusGreen,
      categoryTitle1: 'SPECIALTIES',
      tags1: tags1,
      categoryTitle2: 'LOCATION',
      tags2: tags2,
      rating: 0.0,
      reviewCount: 0,
      openStatus: '',
      phoneNumber: phone.isNotEmpty ? phone : null,
      address: address.isNotEmpty ? address : null,
      notes: notes.isNotEmpty ? notes : null,
      photoPath: _photoPath,
      openDays: _openDays,
      openMinutes: _open24Hours ? null : _openMinutes,
      closeMinutes: _open24Hours ? null : _closeMinutes,
      open24Hours: _open24Hours,
    );

    if (_isEditing) {
      MechanicController.instance.updateMechanic(newMech);
    } else {
      MechanicController.instance.addMechanic(newMech);
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(newMech);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.clay,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                CampAppBar(
                  leading: CampAppBarLeading.back,
                  onLeadingPressed: () => Navigator.of(context).pop(),
                  titleText: _isEditing ? 'Edit Mechanic' : 'Add Mechanic',
                ),
                Expanded(
                  child: SingleChildScrollView(
                    // Reserve space for the floating nav dock below
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header hint
                        Text(
                          'Know a mechanic or emergency pitstop? Add them so you and other riders can find reliable support offline.',
                          style: AppTextStyles.bodySecondary.copyWith(
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Shop name (required)
                        LabeledTextField(
                          label: 'Shop / Mechanic Name',
                          controller: _nameController,
                          placeholder: 'e.g. Peak Moto & Adventure Rig Prep',
                          isError: _nameError,
                          errorText: _nameError ? 'Shop name is required' : null,
                          rightLabelWidget: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0DB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'REQUIRED',
                              style: GoogleFonts.manrope(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.tacticalOrangeDark,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          onChanged: (_) {
                            if (_nameError) {
                              setState(() => _nameError = false);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Phone
                        LabeledTextField(
                          label: 'Phone Number (optional)',
                          controller: _phoneController,
                          placeholder: 'e.g. +92 300 1234567',
                          keyboardType: TextInputType.phone,
                          trailingIcon: Icons.phone_outlined,
                          isError: _phoneError != null,
                          errorText: _phoneError,
                          onChanged: (_) {
                            if (_phoneError != null) {
                              setState(() => _phoneError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Address
                        LabeledTextField(
                          label: 'Address / Location',
                          controller: _addressController,
                          placeholder: 'e.g. 42 Timberline Rd, Babusar Valley',
                          trailingIcon: Icons.location_on_outlined,
                        ),
                        const SizedBox(height: 16),

                        // Shop Location (GPS) Section
                        Text(
                          'SHOP LOCATION',
                          style: AppTextStyles.overline.copyWith(
                            color: AppColors.mutedText,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Location status card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.clayDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _latitude != null
                                  ? AppColors.statusGreen.withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _latitude != null
                                    ? Icons.check_circle_rounded
                                    : Icons.location_off_outlined,
                                color: _latitude != null
                                    ? AppColors.statusGreen
                                    : AppColors.mutedText,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _latitude != null
                                          ? 'Location saved'
                                          : 'No location yet',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _latitude != null
                                            ? Colors.white
                                            : AppColors.mutedText,
                                      ),
                                    ),
                                    if (_latitude != null && _longitude != null)
                                      Text(
                                        '${_latitude!.toStringAsFixed(4)}°, ${_longitude!.toStringAsFixed(4)}°',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.mutedText,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (_latitude != null)
                                TextButton(
                                  key: const ValueKey('change_location_button'),
                                  onPressed: _chooseOnMap,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Change',
                                    style: TextStyle(
                                      color: AppColors.tacticalOrange,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Location Action Buttons: "Use my current location" & "Choose on map"
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const ValueKey('use_current_location_button'),
                                onPressed: _useCurrentLocation,
                                icon: const Icon(Icons.my_location_rounded, size: 16),
                                label: const Text(
                                  'Use my current location',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.tacticalOrange,
                                  side: BorderSide(
                                    color: AppColors.tacticalOrange.withValues(alpha: 0.5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const ValueKey('choose_on_map_button'),
                                onPressed: _chooseOnMap,
                                icon: const Icon(Icons.map_rounded, size: 16),
                                label: const Text(
                                  'Choose on map',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Speciality (optional)
                        LabeledTextField(
                          label: 'Speciality (optional)',
                          controller: _specialityController,
                          placeholder: 'e.g. Engine rebuild, tire plugs, carb jetting',
                          trailingIcon: Icons.build_outlined,
                          helperText: 'Separate multiple skills with commas',
                        ),
                        const SizedBox(height: 16),

                        // Notes (optional)
                        LabeledTextField(
                          label: 'Rider Notes (optional)',
                          controller: _notesController,
                          placeholder: 'e.g. Has 220V arc welder, stocked tubes & spark plugs',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),

                        // Opening Hours Section (optional)
                        _buildOpeningHoursSection(),
                        const SizedBox(height: 20),

                        // Photo Section
                        _buildPhotoSection(),
                        const SizedBox(height: 28),

                        // Save Button
                        PrimaryButton(
                          label: _isEditing ? 'Save Changes' : 'Save Mechanic',
                          icon: Icons.check_rounded,
                          isFullWidth: true,
                          onTap: _saveMechanic,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Floating Bottom Nav Dock — CampBottomNav hides itself when keyboard is open
            const Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: CampBottomNav(
                  selected: CampTab.mechanics,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    final photo = _photoPath;
    final file = photo != null ? File(photo) : null;
    final hasPhoto = file != null && file.existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Shop or Signboard Photo',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.darkCharcoal,
              ),
            ),
            Text(
              'OPTIONAL',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedLight,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (hasPhoto)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.clay,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.clayDark, width: 1.2),
              boxShadow: AppColors.skeuRaisedSmall,
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    file,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      color: AppColors.clayDark,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: AppColors.mutedLight,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showImageSourcePicker,
                        icon: const Icon(
                          Icons.photo_camera_rounded,
                          size: 16,
                          color: AppColors.tacticalOrange,
                        ),
                        label: Text(
                          'Replace Photo',
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: AppColors.clayDark, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor: AppColors.clay,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _photoPath = null),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: AppColors.alertRed,
                      ),
                      label: Text(
                        'Remove',
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.alertRed,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        side: BorderSide(
                          color: AppColors.alertRed.withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: AppColors.alertRedBg,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: _showImageSourcePicker,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.clayDark,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.clayDark, width: 1.2),
                boxShadow: AppColors.skeuRecessed,
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.clay,
                      border: Border.all(color: AppColors.clayDark, width: 1),
                      boxShadow: AppColors.skeuRaisedSmall,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.photo_camera_rounded,
                        color: AppColors.tacticalOrange,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Take photo or choose from gallery',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Helps passing riders recognize the roadside workshop or signboard',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOpeningHoursSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Opening Hours',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.darkCharcoal,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.clayDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'OPTIONAL',
                style: GoogleFonts.manrope(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedLight,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.clay,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hoursError != null ? AppColors.alertRed : AppColors.clayDark,
              width: 1.2,
            ),
            boxShadow: AppColors.skeuRaisedSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Presets Row
              Text(
                'QUICK PRESETS',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mutedLight,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildPresetChip('Mon to Fri', const [1, 2, 3, 4, 5]),
                  _buildPresetChip('Mon to Sat', const [1, 2, 3, 4, 5, 6]),
                  _buildPresetChip('Every day', const [1, 2, 3, 4, 5, 6, 7]),
                ],
              ),
              const SizedBox(height: 16),

              // Seven Day Chips (Mon to Sun)
              Text(
                'SELECT OPEN DAYS',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mutedLight,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDayChip('M', 1),
                  _buildDayChip('T', 2),
                  _buildDayChip('W', 3),
                  _buildDayChip('T', 4),
                  _buildDayChip('F', 5),
                  _buildDayChip('S', 6),
                  _buildDayChip('S', 7),
                ],
              ),
              const SizedBox(height: 16),

              // Open 24 Hours Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.clayDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.all_inclusive_rounded,
                          size: 18,
                          color: AppColors.tacticalOrange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Open 24 hours',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: _open24Hours,
                      activeTrackColor: AppColors.tacticalOrange,
                      onChanged: (val) {
                        setState(() {
                          _open24Hours = val;
                          _hoursError = null;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Time Pickers (hidden when Open 24 hours is on)
              if (!_open24Hours) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimePickerField(
                        label: 'Opens at',
                        minutes: _openMinutes,
                        onTap: () => _pickTime(isOpening: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTimePickerField(
                        label: 'Closes at',
                        minutes: _closeMinutes,
                        onTap: () => _pickTime(isOpening: false),
                      ),
                    ),
                  ],
                ),
              ],

              // Validation Error Message
              if (_hoursError != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 14,
                      color: AppColors.alertRed,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _hoursError!,
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.alertRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Clear Button
              if (_openDays.isNotEmpty ||
                  _openMinutes != null ||
                  _closeMinutes != null ||
                  _open24Hours) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _openDays.clear();
                        _openMinutes = null;
                        _closeMinutes = null;
                        _open24Hours = false;
                        _hoursError = null;
                      });
                    },
                    icon: const Icon(
                      Icons.clear_rounded,
                      size: 14,
                      color: AppColors.mutedLight,
                    ),
                    label: Text(
                      'Clear hours',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedLight,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, List<int> days) {
    final isSelected = _daysMatch(_openDays, days);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _openDays.clear();
          } else {
            _openDays = List<int>.from(days);
          }
          _hoursError = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF0DB) : AppColors.clayDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.tacticalOrange : AppColors.clayDark,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.tacticalOrangeDark : AppColors.charcoalLight,
          ),
        ),
      ),
    );
  }

  Widget _buildDayChip(String label, int day) {
    final isSelected = _openDays.contains(day);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _openDays.remove(day);
          } else {
            _openDays.add(day);
            _openDays.sort();
          }
          _hoursError = null;
        });
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tacticalOrange : AppColors.clayDark,
          shape: BoxShape.circle,
          boxShadow: isSelected ? AppColors.orangeGlow : AppColors.skeuRaisedSmall,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : AppColors.darkCharcoal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimePickerField({
    required String label,
    required int? minutes,
    required VoidCallback onTap,
  }) {
    final hasValue = minutes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.charcoalLight,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.clay,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hoursError != null && !hasValue
                    ? AppColors.alertRed
                    : AppColors.clayDark,
                width: 1.2,
              ),
              boxShadow: AppColors.skeuRecessed,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: AppColors.tacticalOrange,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasValue ? formatMinutes(minutes) : 'Select time',
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                      color: hasValue ? AppColors.darkCharcoal : AppColors.mutedLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickTime({required bool isOpening}) async {
    final currentMinutes = isOpening ? _openMinutes : _closeMinutes;
    final initialTime = currentMinutes != null
        ? TimeOfDay(hour: currentMinutes ~/ 60, minute: currentMinutes % 60)
        : (isOpening
            ? const TimeOfDay(hour: 9, minute: 0)
            : const TimeOfDay(hour: 18, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.tacticalOrange,
              onPrimary: Colors.white,
              surface: AppColors.clay,
              onSurface: AppColors.darkCharcoal,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppColors.clay,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        final mins = picked.hour * 60 + picked.minute;
        if (isOpening) {
          _openMinutes = mins;
        } else {
          _closeMinutes = mins;
        }
        _hoursError = null;
      });
    }
  }

  bool _daysMatch(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    final sortedA = List<int>.from(a)..sort();
    final sortedB = List<int>.from(b)..sort();
    for (var i = 0; i < sortedA.length; i++) {
      if (sortedA[i] != sortedB[i]) return false;
    }
    return true;
  }
}
