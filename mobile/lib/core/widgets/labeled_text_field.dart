import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';

/// Labeled recessed input field. Handles normal, error, and read-only states,
/// with optional placeholders, suffixes, and helpers.
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    required this.label,
    required this.controller,
    super.key,
    this.placeholder,
    this.prefixText,
    this.suffixText,
    this.helperText,
    this.keyboardType,
    this.isError = false,
    this.errorText,
    this.errorLabel,
    this.trailingIcon,
    this.trailingIconColor,
    this.trailingWidget,
    this.rightLabelWidget,
    this.readOnly = false,
    this.obscureText = false,
    this.onTap,
    this.onChanged,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final String? prefixText;
  final String? suffixText;
  final String? helperText;
  final TextInputType? keyboardType;
  final bool isError;
  final String? errorText;
  final String? errorLabel;
  final IconData? trailingIcon;
  final Color? trailingIconColor;
  final Widget? trailingWidget;
  final Widget? rightLabelWidget;
  final bool readOnly;
  final bool obscureText;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final borderColor = isError
        ? AppColors.alertRed
        : Colors.white.withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row: overline + optional right widget/badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                  ),
                  if (isError && errorLabel != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.alertRedBg,
                        borderRadius:
                            BorderRadius.circular(AppColors.radiusPill),
                      ),
                      child: Text(
                        errorLabel!,
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.alertRed,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (rightLabelWidget != null) ...[
              const SizedBox(width: 8),
              rightLabelWidget!,
            ],
          ],
        ),
        const SizedBox(height: 5),

        // Recessed input container
        Container(
          decoration: BoxDecoration(
            color: isError ? AppColors.alertRedBg : AppColors.clayDark,
            borderRadius: BorderRadius.circular(AppColors.radiusTile),
            border: Border.all(
              color: borderColor,
              width: isError ? 1.5 : 1,
            ),
            boxShadow: AppColors.skeuRecessed,
          ),
          child: Row(
            crossAxisAlignment: maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (prefixText != null)
                Padding(
                  padding: const EdgeInsets.only(left: 14, right: 2),
                  child: Text(
                    prefixText!,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  readOnly: readOnly,
                  obscureText: obscureText,
                  onTap: onTap,
                  onChanged: onChanged,
                  maxLines: maxLines,
                  maxLength: maxLength,
                  inputFormatters: inputFormatters,
                  textCapitalization: textCapitalization,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: AppColors.tacticalOrange,
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintStyle: GoogleFonts.manrope(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedLight,
                    ),
                    contentPadding: EdgeInsets.only(
                      left: prefixText != null ? 4 : 14,
                      right: 14,
                      top: 13,
                      bottom: 13,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (suffixText != null)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    suffixText!,
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
              if (trailingWidget != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: trailingWidget!,
                )
              else if (trailingIcon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    trailingIcon,
                    size: 18,
                    color: isError
                        ? AppColors.alertRed
                        : (trailingIconColor ?? AppColors.mutedLight),
                  ),
                ),
            ],
          ),
        ),

        // Helper text
        if (helperText != null && (!isError || errorText == null)) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              helperText!,
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppColors.mutedText,
              ),
            ),
          ),
        ],

        // Error helper text
        if (isError && errorText != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 13,
                color: AppColors.alertRed,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.alertRed,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
