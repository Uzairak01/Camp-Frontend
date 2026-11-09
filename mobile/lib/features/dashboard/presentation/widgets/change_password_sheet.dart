import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/labeled_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/password_strength_indicator.dart';

/// Modal bottom sheet providing the "Change Password" form.
///
/// Features three password input fields (current, new, confirm) with individual
/// show/hide password visibility eye toggles, an inline password strength meter,
/// and sequential validation with inline error messaging:
/// 1. Current password matches active account ("Current password is incorrect.")
/// 2. New password minimum 8 characters ("Use at least 8 characters.")
/// 3. New password differs from current ("New password must be different.")
/// 4. Confirm matches new password ("Passwords do not match.")
///
/// On success:
/// Persists newly salted hash to [AccountRepository], keeps rider authenticated,
/// closes the modal sheet, and notifies with "Password changed."
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({
    super.key,
    this.parentContext,
  });

  /// Optional context of the parent screen for displaying SnackBars after sheet pop.
  final BuildContext? parentContext;

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String? _currentError;
  String? _newError;
  String? _confirmError;
  String? _generalError;

  int _passwordStrength = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _newCtrl.addListener(_onNewPasswordChanged);
  }

  void _onNewPasswordChanged() {
    final strength = AuthController.instance.calculateStrength(_newCtrl.text);
    if (strength != _passwordStrength) {
      setState(() => _passwordStrength = strength);
    }
  }

  @override
  void dispose() {
    _newCtrl.removeListener(_onNewPasswordChanged);
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    // Dismiss soft keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
      _currentError = null;
      _newError = null;
      _confirmError = null;
      _generalError = null;
    });

    final result = await AuthController.instance.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
      confirmPassword: _confirmCtrl.text,
    );

    if (!mounted) return;

    if (result.success) {
      final messenger = ScaffoldMessenger.of(widget.parentContext ?? context);
      Navigator.of(context).pop();

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Password changed.',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppColors.darkCharcoal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 2200),
        ),
      );
    } else {
      setState(() {
        _isSaving = false;
        switch (result.errorField) {
          case ChangePasswordField.current:
            _currentError = result.errorMessage;
            break;
          case ChangePasswordField.newPassword:
            _newError = result.errorMessage;
            break;
          case ChangePasswordField.confirm:
            _confirmError = result.errorMessage;
            break;
          case ChangePasswordField.general:
          case null:
            _generalError = result.errorMessage;
            break;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.clay,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppColors.dockShadow,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top drag handle pill ──────────────────────────────────────
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.mutedLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Sheet Header ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Change Password', style: AppTextStyles.cardTitle),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.clayDark,
                        shape: BoxShape.circle,
                        boxShadow: AppColors.skeuRaisedSmall,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Text(
                'Enter your current password and set a new secure password.',
                style: AppTextStyles.caption,
              ),

              const SizedBox(height: 18),

              // ── General Error Banner (if repository fails) ────────────────
              if (_generalError != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.alertRedBg,
                    borderRadius: BorderRadius.circular(AppColors.radiusTile),
                    border: Border.all(color: AppColors.alertRed, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.alertRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _generalError!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.alertRed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Field 1: Current Password ─────────────────────────────────
              LabeledTextField(
                label: 'CURRENT PASSWORD',
                controller: _currentCtrl,
                placeholder: 'Enter current password',
                obscureText: _obscureCurrent,
                isError: _currentError != null,
                errorText: _currentError,
                onChanged: (_) {
                  if (_currentError != null) setState(() => _currentError = null);
                },
                trailingWidget: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  child: Icon(
                    _obscureCurrent
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.mutedText,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Field 2: New Password + Strength Meter ────────────────────
              LabeledTextField(
                label: 'NEW PASSWORD',
                controller: _newCtrl,
                placeholder: 'At least 8 characters',
                obscureText: _obscureNew,
                rightLabelWidget: PasswordStrengthIndicator(
                  strength: _passwordStrength,
                ),
                isError: _newError != null,
                errorText: _newError,
                onChanged: (_) {
                  if (_newError != null) setState(() => _newError = null);
                },
                trailingWidget: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _obscureNew = !_obscureNew),
                  child: Icon(
                    _obscureNew
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.mutedText,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Field 3: Confirm New Password ─────────────────────────────
              LabeledTextField(
                label: 'CONFIRM NEW PASSWORD',
                controller: _confirmCtrl,
                placeholder: 'Re-enter new password',
                obscureText: _obscureConfirm,
                isError: _confirmError != null,
                errorText: _confirmError,
                onChanged: (_) {
                  if (_confirmError != null) setState(() => _confirmError = null);
                },
                trailingWidget: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  child: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.mutedText,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ── Submit Button (Disabled while saving) ──────────────────────
              PrimaryButton(
                key: const Key('change_password_submit_button'),
                label: 'Update Password',
                icon: Icons.check_circle_outline_rounded,
                isFullWidth: true,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                onTap: _isSaving ? null : _handleSubmit,
              ),

              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

