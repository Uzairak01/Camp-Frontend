import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../dashboard/controllers/profile_controller.dart';

/// Card displaying rider's Medical ID on the Emergency SOS screen.
/// Shows ONLY profile-saved values (blood type, allergies, medical notes).
/// Any empty field displays "Not set" in muted text.
/// If all fields are empty, renders an empty state with an "Add medical info" button.
class OfflineMedicalIdCard extends StatelessWidget {
  const OfflineMedicalIdCard({
    super.key,
    this.onEmergencyQrPressed,
    this.onAddMedicalInfoPressed,
  });

  final VoidCallback? onEmergencyQrPressed;
  final VoidCallback? onAddMedicalInfoPressed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProfileController.instance,
      builder: (context, _) {
        final profile = ProfileController.instance;
        final bloodType = profile.bloodGroup.trim();
        final allergies = profile.allergies.trim();
        final medicalNotes = profile.medicalNotes.trim();

        final bool isAllEmpty = bloodType.isEmpty && allergies.isEmpty && medicalNotes.isEmpty;

        if (isAllEmpty) {
          return _buildEmptyState(context);
        }

        return _buildMedicalCard(
          context: context,
          bloodType: bloodType,
          allergies: allergies,
          medicalNotes: medicalNotes,
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.medical_services_outlined,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Medical ID',
                        overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF1E293B),
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
              GestureDetector(
                onTap: onEmergencyQrPressed ??
                    () => Navigator.of(context).pushNamed(CampRoutes.emergencyQr),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.qr_code_2_rounded,
                        color: Color(0xFF1E293B),
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Emergency QR',
                        style: GoogleFonts.manrope(
                          color: const Color(0xFF1E293B),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
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
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.favorite_outline_rounded,
                      color: Color(0xFFDC2626),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No medical info saved',
                  style: GoogleFonts.manrope(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add your blood type, allergies, and medical notes to assist first responders in an emergency.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onAddMedicalInfoPressed ??
                      () => Navigator.of(context).pushNamed(CampRoutes.editProfile),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Add medical info',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalCard({
    required BuildContext context,
    required String bloodType,
    required String allergies,
    required String medicalNotes,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Red Stripe Accent
            Container(
              width: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
              ),
            ),

            // Card Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top First Responder Data Tag
                    Text(
                      'FIRST RESPONDER DATA',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFFDC2626),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Header: Medical ID + Emergency QR Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Medical ID',
                          style: GoogleFonts.manrope(
                            color: const Color(0xFF1E293B),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        GestureDetector(
                          onTap: onEmergencyQrPressed ??
                              () => Navigator.of(context).pushNamed(CampRoutes.emergencyQr),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.qr_code_2_rounded,
                                  color: Color(0xFF1E293B),
                                  size: 15,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Emergency QR',
                                  style: GoogleFonts.manrope(
                                    color: const Color(0xFF1E293B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Row with 2 tiles: Blood Type & Known Allergies
                    Row(
                      children: [
                        // Left: Blood Type
                        Container(
                          width: 105,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BLOOD TYPE',
                                style: GoogleFonts.manrope(
                                  color: const Color(0xFF64748B),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                bloodType.isNotEmpty ? bloodType : 'Not set',
                                style: GoogleFonts.manrope(
                                  color: bloodType.isNotEmpty
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF94A3B8),
                                  fontSize: 15.5,
                                  fontWeight: bloodType.isNotEmpty
                                      ? FontWeight.w900
                                      : FontWeight.w600,
                                  fontStyle: bloodType.isEmpty ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Right: Known Allergies
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'KNOWN ALLERGIES',
                                  style: GoogleFonts.manrope(
                                    color: const Color(0xFF64748B),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  allergies.isNotEmpty ? allergies : 'Not set',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    color: allergies.isNotEmpty
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFF94A3B8),
                                    fontSize: 13,
                                    fontWeight: allergies.isNotEmpty
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontStyle: allergies.isEmpty ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Bottom Tile: MEDICAL NOTES
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MEDICAL NOTES',
                            style: GoogleFonts.manrope(
                              color: const Color(0xFF64748B),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            medicalNotes.isNotEmpty ? medicalNotes : 'Not set',
                            style: GoogleFonts.manrope(
                              color: medicalNotes.isNotEmpty
                                  ? const Color(0xFF334155)
                                  : const Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: medicalNotes.isNotEmpty
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontStyle: medicalNotes.isEmpty ? FontStyle.italic : FontStyle.normal,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
