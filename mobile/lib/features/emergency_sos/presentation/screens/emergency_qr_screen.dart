import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/camp_app_bar.dart';
import '../../../bike_scan/presentation/screens/bike_details_screen.dart';
import '../../../dashboard/controllers/profile_controller.dart';
import '../../../dashboard/domain/emergency_phone_helper.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../../garage/domain/bike_model.dart';
import '../../../settings/controllers/settings_controller.dart';
import '../../domain/emergency_qr_payload.dart';
import '../../services/emergency_qr_export_service.dart';

/// Screen displaying the rider's Emergency Medical & ICE QR Card.
/// Generates real scannable QR codes with Error Correction Level Q,
/// per-field inclusion toggles, scan density warnings, and standalone QR exports.
class EmergencyQrScreen extends StatefulWidget {
  const EmergencyQrScreen({super.key});

  static const Key qrKey = Key('emergency_qr_repaint_boundary');

  @override
  State<EmergencyQrScreen> createState() => _EmergencyQrScreenState();
}

class _EmergencyQrScreenState extends State<EmergencyQrScreen> {

  // Per-field inclusion toggles
  bool _includeBloodType = true;
  bool _includeAllergies = true;
  bool _includeMedicalNotes = true;
  bool _includeEmergencyContact = true;

  bool _isSavingPng = false;
  bool _isSavingPdf = false;
  bool _isSharing = false;

  Future<void> _saveQrAsPng(String payload) async {
    if (_isSavingPng) return;
    setState(() => _isSavingPng = true);

    try {
      final pngBytes =
          await EmergencyQrExportService.buildEmergencyQrPng(payload);
      await Gal.putImageBytes(pngBytes, name: 'camp_emergency_qr');

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.greenAccent,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'QR saved to photo gallery',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.darkCharcoal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save to gallery: $e'),
            backgroundColor: AppColors.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPng = false);
    }
  }

  Future<void> _saveQrAsPdf(String payload) async {
    if (_isSavingPdf) return;
    setState(() => _isSavingPdf = true);

    try {
      final pdfBytes =
          await EmergencyQrExportService.buildEmergencyQrPdf(payload);
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save Emergency QR PDF',
        fileName: 'camp_emergency_qr.pdf',
        bytes: pdfBytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (savedPath != null && mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.greenAccent,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PDF saved successfully',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.darkCharcoal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save PDF: $e'),
            backgroundColor: AppColors.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPdf = false);
    }
  }

  Future<void> _shareQrImage(String payload) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final pngBytes =
          await EmergencyQrExportService.buildEmergencyQrPng(payload);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/camp_emergency_qr.png');
      await tempFile.writeAsBytes(pngBytes);

      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(tempFile.path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share QR image: $e'),
            backgroundColor: AppColors.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ProfileController.instance,
        ActiveBikeController.instance,
        SettingsController.instance,
      ]),
      builder: (context, _) {
        final profile = ProfileController.instance;
        final bikeController = ActiveBikeController.instance;
        final settings = SettingsController.instance;

        final name = profile.fullName;
        final bloodType = profile.bloodGroup.trim();
        final allergies = profile.allergies.trim();
        final medicalNotes = profile.medicalNotes.trim();
        final contactName = profile.emergencyContactName.trim();
        final contactPhone = profile.emergencyContactPhone.trim();
        final contactRelation = profile.emergencyContactRelation.trim();

        final Bike? activeBike = bikeController.activeBike;
        final bool bikeDetailsToggle = settings.showBikeOnEmergencyQr;

        final payloadResult = EmergencyQrPayloadBuilder.build(
          fullName: name,
          bloodGroup: bloodType,
          allergies: allergies,
          medicalNotes: medicalNotes,
          emergencyContacts: profile.emergencyContacts,
          emergencyContactName: contactName,
          emergencyContactPhone: contactPhone,
          emergencyContactRelation: contactRelation,
          bike: activeBike,
          includeBloodType: _includeBloodType,
          includeAllergies: _includeAllergies,
          includeMedicalNotes: _includeMedicalNotes,
          includeEmergencyContact: _includeEmergencyContact,
          includeBike: bikeDetailsToggle,
        );

        // Density warning logic
        final List<String> fieldsToShorten = [];
        if (_includeMedicalNotes && medicalNotes.length > 35) {
          fieldsToShorten.add('Medical notes (${medicalNotes.length} chars)');
        }
        if (_includeAllergies && allergies.length > 25) {
          fieldsToShorten.add('Allergies (${allergies.length} chars)');
        }
        if (name.length > 25) {
          fieldsToShorten.add('Full name (${name.length} chars)');
        }
        if (_includeEmergencyContact && contactName.length > 25) {
          fieldsToShorten.add('Contact name');
        }

        final bool isPayloadDense =
            payloadResult.totalLength > 240 || payloadResult.isNotesTruncated;

        return Scaffold(
          backgroundColor: AppColors.clay,
          appBar: const CampAppBar(
            leading: CampAppBarLeading.back,
            titleText: 'Emergency QR',
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top guidance card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF475569),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Scan this QR code with any smartphone camera to access vital medical & contact information offline.',
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            color: const Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Truncation Notice Banner
                if (payloadResult.isNotesTruncated) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFD97706),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Medical notes shortened for QR',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Notes were trimmed to ensure first responders can read the code reliably offline in field conditions.',
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFB45309),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Density warning banner if payload is long
                if (isPayloadDense) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFD97706),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'High QR Density Warning',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'The QR code contains ${payloadResult.totalLength} characters and may take longer to scan. Consider shortening: ${fieldsToShorten.isNotEmpty ? fieldsToShorten.join(', ') : 'Medical notes / Allergies'}.',
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFB45309),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Per-field toggles section
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FIELDS INCLUDED IN QR',
                        style: AppTextStyles.overline,
                      ),
                      const SizedBox(height: 8),

                      // Bike details toggle
                      _buildToggleRow(
                        key: const Key('toggle_bike_details_row'),
                        switchKey: const Key('switch_bike_details'),
                        title: 'Bike details in QR',
                        subtitle: activeBike != null
                            ? '${activeBike.make} ${activeBike.modelName}'
                            : 'No active bike',
                        value: bikeDetailsToggle,
                        icon: Icons.two_wheeler_rounded,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          settings.setShowBikeOnEmergencyQr(val);
                        },
                      ),
                      const Divider(height: 12, color: Color(0xFFE2E8F0)),

                      // Blood type toggle
                      _buildToggleRow(
                        key: const Key('toggle_blood_type_row'),
                        switchKey: const Key('switch_blood_type'),
                        title: 'Blood group',
                        subtitle: bloodType.isNotEmpty ? bloodType : 'Not set',
                        value: _includeBloodType,
                        icon: Icons.bloodtype_rounded,
                        onChanged: (val) =>
                            setState(() => _includeBloodType = val),
                      ),
                      const Divider(height: 12, color: Color(0xFFE2E8F0)),

                      // Allergies toggle
                      _buildToggleRow(
                        key: const Key('toggle_allergies_row'),
                        switchKey: const Key('switch_allergies'),
                        title: 'Allergies',
                        subtitle: allergies.isNotEmpty ? allergies : 'None',
                        value: _includeAllergies,
                        icon: Icons.coronavirus_outlined,
                        onChanged: (val) =>
                            setState(() => _includeAllergies = val),
                      ),
                      const Divider(height: 12, color: Color(0xFFE2E8F0)),

                      // Medical notes toggle
                      _buildToggleRow(
                        key: const Key('toggle_medical_notes_row'),
                        switchKey: const Key('switch_medical_notes'),
                        title: 'Medical notes',
                        subtitle:
                            medicalNotes.isNotEmpty ? medicalNotes : 'None',
                        value: _includeMedicalNotes,
                        icon: Icons.notes_rounded,
                        onChanged: (val) =>
                            setState(() => _includeMedicalNotes = val),
                      ),
                      const Divider(height: 12, color: Color(0xFFE2E8F0)),

                      // Emergency contact toggle
                      _buildToggleRow(
                        key: const Key('toggle_emergency_contact_row'),
                        switchKey: const Key('switch_emergency_contact'),
                        title: 'Emergency contact',
                        subtitle: profile.emergencyContacts.isNotEmpty
                            ? (profile.emergencyContacts.length == 1
                                ? profile.emergencyContacts.first.name
                                : '${profile.emergencyContacts.first.name} (+${profile.emergencyContacts.length - 1} more)')
                            : 'Not set',
                        value: _includeEmergencyContact,
                        icon: Icons.contact_phone_outlined,
                        onChanged: (val) =>
                            setState(() => _includeEmergencyContact = val),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Physical Card Preview
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Red emergency header band
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        color: const Color(0xFFDC2626),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.medical_services_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'CAMP EMERGENCY MEDICAL ID',
                                  style: GoogleFonts.manrope(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'OFFLINE',
                              style: GoogleFonts.manrope(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Real Scannable QR Graphic Container
                            Center(
                              child: RepaintBoundary(
                                key: EmergencyQrScreen.qrKey,
                                child: Container(
                                  width: 220,
                                  height: 220,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF0F172A),
                                      width: 2.0,
                                    ),
                                  ),
                                  child: QrImageView(
                                    data: payloadResult.payload,
                                    version: QrVersions.auto,
                                    errorCorrectionLevel: QrErrorCorrectLevel.Q,
                                    size: 184,
                                    padding: EdgeInsets.zero,
                                    backgroundColor: Colors.white,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Color(0xFF0F172A),
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Rider Name
                            Center(
                              child: Text(
                                name.isNotEmpty ? name : 'Motorcycle Rider',
                                style: GoogleFonts.manrope(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 16),

                            // Medical Details Grid
                            if (_includeBloodType) ...[
                              _buildInfoRow(
                                label: 'BLOOD TYPE',
                                value: bloodType.isNotEmpty
                                    ? bloodType
                                    : 'Not set',
                                isHighlight: bloodType.isNotEmpty,
                              ),
                              const SizedBox(height: 10),
                            ],
                            if (_includeAllergies) ...[
                              _buildInfoRow(
                                label: 'ALLERGIES',
                                value:
                                    allergies.isNotEmpty ? allergies : 'None',
                              ),
                              const SizedBox(height: 10),
                            ],
                            if (_includeMedicalNotes) ...[
                              _buildInfoRow(
                                label: 'MEDICAL NOTES',
                                value: medicalNotes.isNotEmpty
                                    ? medicalNotes
                                    : 'None',
                              ),
                              const SizedBox(height: 10),
                            ],

                            // Emergency Contact (renamed from ICE CONTACT & ICE PHONE)
                            if (_includeEmergencyContact) ...[
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              const SizedBox(height: 14),
                              _buildInfoRow(
                                label: 'Emergency contact',
                                value: contactName.isNotEmpty
                                    ? '$contactName ${contactRelation.isNotEmpty ? "($contactRelation)" : ""}'
                                    : 'Not set',
                              ),
                              const SizedBox(height: 10),
                              _buildInfoRow(
                                label: 'Contact phone',
                                value: contactPhone.isNotEmpty
                                    ? EmergencyPhoneHelper.formatPhoneReadable(contactPhone)
                                    : 'Not set',
                              ),
                            ],

                            // Motorcycle Section (when toggle is ON)
                            if (bikeDetailsToggle) ...[
                              const SizedBox(height: 14),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              const SizedBox(height: 14),
                              _buildBikeDetailsSection(
                                context: context,
                                activeBike: activeBike,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Buttons Section ──────────────────────────────────────────
                // Row: Save QR as PNG + Small Secondary Share Icon
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isSavingPng
                              ? null
                              : () => _saveQrAsPng(payloadResult.payload),
                          icon: _isSavingPng
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.image_outlined, size: 20),
                          label: Text(
                            _isSavingPng ? 'Saving...' : 'Save QR as PNG',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.darkCharcoal,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: AppColors.clayDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        boxShadow: AppColors.skeuRaisedSmall,
                      ),
                      child: IconButton(
                        tooltip: 'Share QR image',
                        icon: _isSharing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(
                                Icons.share_outlined,
                                color: AppColors.darkCharcoal,
                                size: 20,
                              ),
                        onPressed: _isSharing
                            ? null
                            : () => _shareQrImage(payloadResult.payload),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Save QR as PDF button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isSavingPdf
                        ? null
                        : () => _saveQrAsPdf(payloadResult.payload),
                    icon: _isSavingPdf
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.darkCharcoal,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined, size: 20),
                    label: Text(
                      _isSavingPdf ? 'Preparing PDF...' : 'Save QR as PDF',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.darkCharcoal,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Edit Profile link
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(CampRoutes.editProfile),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: Color(0xFFFF6B00),
                  ),
                  label: Text(
                    'Edit Medical Info in Profile',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFFFF6B00),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
    Key? key,
    Key? switchKey,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF64748B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: switchKey,
            value: value,
            activeThumbColor: AppColors.tacticalOrange,
            activeTrackColor: AppColors.tacticalOrange.withValues(alpha: 0.5),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildBikeDetailsSection({
    required BuildContext context,
    required Bike? activeBike,
  }) {
    if (activeBike == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.two_wheeler_outlined,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'No bike added',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () =>
                  Navigator.of(context).pushNamed(CampRoutes.addMotorcycle),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.tacticalOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Add bike',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasPlate =
        activeBike.plateNumber != null && activeBike.plateNumber!.isNotEmpty;
    final bikeMakeModel = '${activeBike.make} ${activeBike.modelName}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Note: Duplicate "Bike: ..." pill has been removed per requirement 4.
        _buildInfoRow(
          label: 'BIKE',
          value: activeBike.modelYear > 1900
              ? '$bikeMakeModel (${activeBike.modelYear})'
              : bikeMakeModel,
        ),
        const SizedBox(height: 10),

        _buildInfoRow(
          label: 'PLATE',
          value: hasPlate ? activeBike.plateNumber! : 'Not set',
          isHighlight: hasPlate,
        ),

        if (activeBike.colour != null && activeBike.colour!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildInfoRow(
            label: 'COLOUR',
            value: activeBike.colour!,
          ),
        ],

        // Missing Plate Hint
        if (!hasPlate) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BikeDetailsScreen(initialBike: activeBike),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    size: 15,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Add your plate number to help identify the bike',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    final isNotSet = value == 'Not set';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF64748B),
              letterSpacing: 0.4,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w700,
              color: isNotSet
                  ? const Color(0xFF94A3B8)
                  : (isHighlight
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF0F172A)),
              fontStyle: isNotSet ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }
}
