import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../dashboard/controllers/profile_controller.dart';
import '../../../dashboard/domain/emergency_phone_helper.dart';
import '../../../navigation/domain/location_service.dart';
import '../../domain/emergency_sos_helpers.dart';
import 'alert_contacts_bottom_sheet.dart';

/// Card 4: Emergency Contact Card showing rider's saved contact from Profile,
/// with "Call my contact" and "Alert my contacts" SMS composer with GPS link.
class EmergencyContactCard extends StatefulWidget {
  const EmergencyContactCard({
    super.key,
    this.onEditPressed,
    this.locationService = const GeolocatorLocationService(),
  });

  final VoidCallback? onEditPressed;
  final LocationService locationService;

  @override
  State<EmergencyContactCard> createState() => _EmergencyContactCardState();
}

class _EmergencyContactCardState extends State<EmergencyContactCard> {
  bool _isLocatingForSms = false;

  Future<void> _handleAlertContacts(BuildContext context) async {
    if (_isLocatingForSms) return;
    final contacts = ProfileController.instance.emergencyContacts;
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No emergency contact saved. Please add one in your profile.',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.tacticalOrange,
          action: SnackBarAction(
            label: 'Add',
            textColor: Colors.white,
            onPressed: () => _navigateToEditProfile(context),
          ),
        ),
      );
      return;
    }

    setState(() => _isLocatingForSms = true);

    PositionData? position;
    try {
      position = await widget.locationService.getCurrentPosition();
    } catch (_) {
      position = null;
    }

    if (mounted) {
      setState(() => _isLocatingForSms = false);
    }

    final body = buildEmergencySmsBody(position);

    // Always show the Alert Contacts sheet (also for a single contact) so the rider
    // chooses SMS, WhatsApp or another app explicitly.
    if (context.mounted) {
      await AlertContactsBottomSheet.show(
        context,
        contacts: contacts,
        messageBody: body,
      );
    }
  }

  void _handleCallContact(String phone) {
    launchTel(phone);
  }

  void _navigateToEditProfile(BuildContext context) {
    if (widget.onEditPressed != null) {
      widget.onEditPressed!();
    } else {
      Navigator.of(context).pushNamed(CampRoutes.editProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProfileController.instance,
      builder: (context, _) {
        final profile = ProfileController.instance;
        final contacts = profile.emergencyContacts;
        final primary = profile.primaryEmergencyContact;
        final hasContact = primary != null && primary.phone.trim().isNotEmpty;

        final name = primary?.name.trim() ?? '';
        final relation = primary?.relation.trim() ?? '';
        final phone = primary?.phone.trim() ?? '';

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
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row ─────────────────────────────────────────────────
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF1E293B),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Emergency Contact',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF1E293B),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasContact) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _navigateToEditProfile(context),
                      child: Text(
                        'Edit >',
                        style: GoogleFonts.manrope(
                          color: const Color(0xFFFF6B00),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              if (!hasContact) ...[
                // ── Empty State ─────────────────────────────────────────────
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
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.contact_phone_outlined,
                            color: Color(0xFF64748B),
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No emergency contact saved',
                        style: GoogleFonts.manrope(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Save a trusted emergency contact in your profile to alert them during a crisis.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => _navigateToEditProfile(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B00),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Add contact',
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // ── Contact Details Row ────────────────────────────────────────
                Row(
                  children: [
                    // Initials Circle Avatar
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(name),
                          style: GoogleFonts.manrope(
                            color: const Color(0xFF1E293B),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name, Relation, Phone Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isNotEmpty ? name : 'Emergency Contact',
                            style: GoogleFonts.manrope(
                              color: const Color(0xFF1E293B),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            relation.isNotEmpty ? relation : 'Contact',
                            style: GoogleFonts.manrope(
                              color: const Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            EmergencyPhoneHelper.formatPhoneReadable(phone),
                            style: GoogleFonts.manrope(
                              color: const Color(0xFF1E293B),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (contacts.length > 1) ...[
                            const SizedBox(height: 3),
                            Text(
                              '+${contacts.length - 1} more contact${contacts.length > 2 ? 's' : ''} will be alerted',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Action Buttons: Call my contact & Alert my contacts ───────
                Row(
                  children: [
                    // Call my contact Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _handleCallContact(phone),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.call_rounded,
                                color: Color(0xFF059669),
                                size: 16,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'Call my contact',
                                style: GoogleFonts.manrope(
                                  color: const Color(0xFF1E293B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Alert my contacts (SMS with GPS) Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _handleAlertContacts(context),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isLocatingForSms) ...[
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ] else ...[
                                const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                'Alert my contacts',
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Note: Must say "Opens your messages app, tap Send", never "Alert sent"
                Center(
                  child: Text(
                    'Opens your messages app, tap Send',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'EC';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}
