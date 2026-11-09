import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';

/// Confirmation dialog for removing a trip and its budget ledger.
class DeleteTripDialogWidget extends StatelessWidget {
  const DeleteTripDialogWidget({
    required this.tripName,
    super.key,
    this.expenseCount = 0,
    this.onConfirmDelete,
  });

  final String tripName;
  final int expenseCount;
  final VoidCallback? onConfirmDelete;

  static Future<bool?> show(
    BuildContext context, {
    required String tripName,
    int expenseCount = 0,
    VoidCallback? onConfirmDelete,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => DeleteTripDialogWidget(
        tripName: tripName,
        expenseCount: expenseCount,
        onConfirmDelete: onConfirmDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.clay,
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
          boxShadow: AppColors.skeuRaised,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Red circular trash icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.alertRedBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.alertRed.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.alertRed,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Delete $tripName?',
              textAlign: TextAlign.center,
              style: AppTextStyles.cardTitle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),

            // Explanatory body text
            Text(
              expenseCount > 0
                  ? 'This will delete $expenseCount ${expenseCount == 1 ? 'expense' : 'expenses'} with it. Your maintenance records will stay.'
                  : 'This will remove the trip and its budget. Your maintenance records will stay.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary.copyWith(
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),

            // Action buttons row
            Row(
              children: [
                // Cancel neutral pill
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.clayDark,
                        borderRadius: BorderRadius.circular(AppColors.radiusPill),
                        boxShadow: AppColors.skeuRaisedSmall,
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.manrope(
                            color: AppColors.darkCharcoal,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Solid red delete pill
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.of(context).pop(true);
                      onConfirmDelete?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.alertRed,
                        borderRadius: BorderRadius.circular(AppColors.radiusPill),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.alertRed.withValues(alpha: 0.35),
                            offset: const Offset(0, 4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Delete',
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
