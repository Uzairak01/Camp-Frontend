import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../dashboard/domain/emergency_contact_model.dart';
import '../../../dashboard/domain/emergency_phone_helper.dart';
import '../../domain/emergency_sos_helpers.dart';

/// Modal bottom sheet presented whenever at least one emergency contact is saved.
///
/// Provides per-contact dispatch to the native SMS app, WhatsApp, or any other app via the
/// system share sheet, plus sequential "SMS everyone in turn". Nothing is sent
/// automatically; the rider taps Send in the chosen app.
class AlertContactsBottomSheet extends StatefulWidget {
  const AlertContactsBottomSheet({
    required this.contacts,
    required this.messageBody,
    super.key,
  });

  /// The list of saved emergency contacts (primary contact first).
  final List<EmergencyContact> contacts;

  /// The pre-filled distress message text containing the GPS maps link.
  final String messageBody;

  /// Convenience helper to display this bottom sheet modally.
  static Future<void> show(
    BuildContext context, {
    required List<EmergencyContact> contacts,
    required String messageBody,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AlertContactsBottomSheet(
        contacts: contacts,
        messageBody: messageBody,
      ),
    );
  }

  @override
  State<AlertContactsBottomSheet> createState() => _AlertContactsBottomSheetState();
}

class _AlertContactsBottomSheetState extends State<AlertContactsBottomSheet>
    with WidgetsBindingObserver {
  /// Track contacts whose SMS or WhatsApp composer has been opened.
  final Set<String> _openedContactIds = {};

  /// Current contact index when executing "SMS everyone in turn".
  /// Null when no sequential dispatch is active.
  int? _inTurnIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the rider returns to CAMP from an external SMS composer, advance the in-turn queue.
    if (state == AppLifecycleState.resumed && _inTurnIndex != null) {
      _advanceInTurnQueue();
    }
  }

  Future<void> _advanceInTurnQueue() async {
    if (_inTurnIndex == null) return;
    final nextIndex = _inTurnIndex! + 1;

    if (nextIndex < widget.contacts.length) {
      _inTurnIndex = nextIndex;
      final contact = widget.contacts[nextIndex];
      _openedContactIds.add(contact.id);
      if (mounted) setState(() {});

      // Short delay before opening next composer to allow frame stabilization
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await launchSms(contact.phone, widget.messageBody);
    } else {
      _inTurnIndex = null;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Opened SMS composers for all contacts.',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.darkCharcoal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleSmsContact(EmergencyContact contact) async {
    _openedContactIds.add(contact.id);
    if (mounted) setState(() {});
    await launchSms(contact.phone, widget.messageBody);
  }

  Future<void> _handleWhatsAppContact(EmergencyContact contact) async {
    final launched = await launchWhatsApp(contact.phone, widget.messageBody);
    if (!mounted) return;

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'WhatsApp is not installed on this phone.',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _openedContactIds.add(contact.id);
      if (mounted) setState(() {});
    }
  }

  /// Opens the system share sheet with the alert text for [contact].
  ///
  /// The sheet cannot target a person, so the rider picks the contact inside the chosen
  /// app (hinted under the button). The row is marked Opened only if the sheet appeared.
  Future<void> _handleOtherApps(EmergencyContact contact) async {
    final shown = await shareAlert(widget.messageBody);
    if (!mounted) return;
    if (shown) {
      _openedContactIds.add(contact.id);
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open the share menu.',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSmsEveryoneInTurn() async {
    if (widget.contacts.isEmpty) return;
    _inTurnIndex = 0;
    final firstContact = widget.contacts.first;
    _openedContactIds.add(firstContact.id);
    if (mounted) setState(() {});

    await launchSms(firstContact.phone, widget.messageBody);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('alert_contacts_bottom_sheet'),
      decoration: const BoxDecoration(
        color: AppColors.clay,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Drag Handle ────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header Title & Subtitle ────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.emergency_share_outlined,
                    color: AppColors.alertRed,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alert Contacts',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    Text(
                      'Choose SMS or WhatsApp for each contact, or SMS all in turn.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // ── Contact Rows List ──────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.contacts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final contact = entry.value;
                  final isPrimary = index == 0;
                  final isOpened = _openedContactIds.contains(contact.id);
                  final readablePhone = EmergencyPhoneHelper.formatPhoneReadable(contact.phone);

                  return Container(
                    key: Key('alert_contact_row_${contact.id}'),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isOpened
                            ? const Color(0xFFBBF7D0)
                            : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name, primary tag, and opened status row
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      contact.name.isNotEmpty
                                          ? contact.name
                                          : 'Emergency Contact',
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.darkCharcoal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (contact.relation.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${contact.relation})',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.mutedText,
                                      ),
                                    ),
                                  ],
                                  if (isPrimary) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      key: Key('chip_primary_${contact.id}'),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'PRIMARY',
                                        style: GoogleFonts.manrope(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.tacticalOrange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isOpened) ...[
                              Container(
                                key: Key('chip_opened_${contact.id}'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 13,
                                      color: AppColors.statusGreen,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Opened',
                                      style: GoogleFonts.manrope(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.statusGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Formatted phone number
                        Text(
                          readablePhone,
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // SMS & WhatsApp button row
                        Row(
                          children: [
                            // SMS Button
                            Expanded(
                              child: OutlinedButton.icon(
                                key: Key('btn_sms_${contact.id}'),
                                onPressed: () => _handleSmsContact(contact),
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 15,
                                  color: Color(0xFF0284C7),
                                ),
                                label: Text(
                                  'SMS',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0284C7),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFBAE6FD),
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // WhatsApp Button
                            Expanded(
                              child: OutlinedButton.icon(
                                key: Key('btn_wa_${contact.id}'),
                                onPressed: () => _handleWhatsAppContact(contact),
                                icon: const Icon(
                                  Icons.forum_outlined,
                                  size: 15,
                                  color: Color(0xFF16A34A),
                                ),
                                label: Text(
                                  'WhatsApp',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFBBF7D0),
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // "Other apps" opens the system share sheet with the same message.
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: Key('btn_other_${contact.id}'),
                            onPressed: () => _handleOtherApps(contact),
                            icon: const Icon(
                              Icons.share_outlined,
                              size: 15,
                              color: Color(0xFF475569),
                            ),
                            label: Text(
                              'Other apps',
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFCBD5E1),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pick ${contact.name.isNotEmpty ? contact.name : 'this contact'} inside the app you choose.',
                          key: Key('hint_other_${contact.id}'),
                          style: GoogleFonts.manrope(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── SMS Everyone in Turn Button ────────────────────────────────────
          ElevatedButton.icon(
            key: const Key('btn_sms_everyone_in_turn'),
            onPressed: _handleSmsEveryoneInTurn,
            icon: const Icon(
              Icons.playlist_play_rounded,
              size: 20,
              color: Colors.white,
            ),
            label: Text(
              _inTurnIndex != null
                  ? 'Alerting in turn (${_inTurnIndex! + 1}/${widget.contacts.length})...'
                  : 'SMS everyone in turn',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tacticalOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
