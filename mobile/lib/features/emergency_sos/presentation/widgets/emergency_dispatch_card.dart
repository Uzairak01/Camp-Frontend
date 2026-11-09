import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../settings/controllers/settings_controller.dart';
import '../../domain/emergency_sos_helpers.dart';

/// Card for selecting the emergency response number and initiating a call
class EmergencyDispatchCard extends StatelessWidget {
  const EmergencyDispatchCard({super.key});

  void _showNumberPicker(BuildContext context) {
    final current = SettingsController.instance.emergencyNumber;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Emergency Service',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose the dispatch authority for your region or set a custom number.',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                for (final opt in kEmergencyServiceOptions)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.emergency_rounded,
                          color: Color(0xFFE53935),
                          size: 20,
                        ),
                      ),
                    ),
                    title: Text(
                      opt.label,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    subtitle: Text(
                      opt.description,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    trailing: current == opt.number
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFFE53935))
                        : null,
                    onTap: () {
                      SettingsController.instance.setEmergencyNumber(opt.number);
                      Navigator.of(ctx).pop();
                    },
                  ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.edit_outlined,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                    ),
                  ),
                  title: Text(
                    'Custom Emergency Number',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: Text(
                    !kEmergencyServiceOptions.any((o) => o.number == current)
                        ? 'Current: $current'
                        : 'Enter local police or rescue line',
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  trailing: !kEmergencyServiceOptions.any((o) => o.number == current)
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFFE53935))
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showCustomNumberDialog(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCustomNumberDialog(BuildContext context) {
    final controller = TextEditingController(
      text: SettingsController.instance.emergencyNumber,
    );

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Custom Emergency Number',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: const Color(0xFF1E293B),
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: 'e.g. 1122 or local helpline',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                SettingsController.instance.setEmergencyNumber(text);
              }
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsController.instance,
      builder: (context, _) {
        final emergencyNum = SettingsController.instance.emergencyNumber;
        final matchedOption = kEmergencyServiceOptions.cast<EmergencyServiceOption?>().firstWhere(
              (o) => o?.number == emergencyNum,
              orElse: () => null,
            );
        final displayLabel = matchedOption?.label ?? 'Custom ($emergencyNum)';

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
              // Header
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECEF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.emergency_rounded,
                        color: Color(0xFFE53935),
                        size: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Emergency Services',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF1E293B),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showNumberPicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayLabel,
                            style: GoogleFonts.manrope(
                              color: const Color(0xFF1E293B),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Prominent Call Emergency button
              GestureDetector(
                onTap: () => launchTel(emergencyNum),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.phone_in_talk_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Call Emergency ($emergencyNum)',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Opens phone dialer with tel:$emergencyNum (tap Call to connect)',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
