import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_info.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/camp_app_bar.dart';
import '../../../../core/widgets/camp_bottom_nav.dart';
import '../../../../core/widgets/camp_card.dart';
import '../../../../core/widgets/icon_tile.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../../../dashboard/controllers/profile_controller.dart';
import '../../../dashboard/domain/profile_stats.dart';
import '../../../dashboard/presentation/widgets/app_drawer_widget.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../../maintenance/controllers/post_ride_report_controller.dart';
import '../../controllers/settings_controller.dart';
import '../widgets/settings_controls.dart';
import '../widgets/settings_row_widget.dart';

/// CAMP Settings Screen
/// Serves as the application's single source of truth for Notifications,
/// Language, Storage metrics, and Emergency preferences.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.isDebugMode = kDebugMode,
  });

  /// Whether debug-only features (such as tracking diagnostics) should be presented.
  /// Defaults to [kDebugMode] and can be overridden in widget tests.
  final bool isDebugMode;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const double _kNavBottomMargin = 24.0;
  static const double _kScrollBottomPadding = 120.0;

  @override
  void initState() {
    super.initState();
    SettingsController.instance.refreshCacheSize();
  }

  void _showNotification(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.darkCharcoal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  // Note: Linked Accounts and Change Password return with AuthRepository and Firebase Auth (Batch H).

  void _showLanguageSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.clay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.radiusCard)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.mutedLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Display Language',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const SizedBox(height: 12),
              _buildLanguageOption(
                'English',
                isSelected: SettingsController.instance.language == 'English',
                isAvailable: true,
              ),
              // Note: Real Urdu localisation (translation files, RTL layout, Nastaliq font) is a separate batch.
              _buildLanguageOption(
                'اردو (Urdu)',
                isSelected: false,
                isAvailable: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    String lang, {
    required bool isSelected,
    required bool isAvailable,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        lang,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isAvailable
              ? (isSelected ? AppColors.tacticalOrangeDark : AppColors.darkCharcoal)
              : AppColors.mutedText,
        ),
      ),
      trailing: isAvailable
          ? (isSelected
              ? const Icon(Icons.check_circle_rounded, color: AppColors.tacticalOrange)
              : null)
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.clayDark,
                borderRadius: BorderRadius.circular(AppColors.radiusPill),
              ),
              child: Text(
                'Coming soon',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedText,
                ),
              ),
            ),
      onTap: () {
        if (!isAvailable) {
          _showNotification('Urdu localisation coming soon');
          return;
        }
        Navigator.of(context).pop();
        SettingsController.instance.setLanguage('English');
        _showNotification('Language set to English');
      },
    );
  }

  void _showEmergencyNumberSelector(SettingsController settings) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.clay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.radiusCard)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.mutedLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Emergency Number',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Default rescue dispatch number dialed from the SOS screen.',
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  color: AppColors.mutedText,
                ),
              ),
              const SizedBox(height: 12),
              _buildEmergencyOption('1122', '1122 Rescue (Pakistan Rescue)', settings),
              _buildEmergencyOption('15', '15 Police (Helpline)', settings),
              _buildEmergencyOption('115', '115 Ambulance (Emergency Dispatch)', settings),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined, color: AppColors.darkCharcoal),
                title: Text(
                  'Custom Number',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                subtitle: Text(
                  !['1122', '15', '115'].contains(settings.emergencyNumber)
                      ? 'Current: ${settings.emergencyNumber}'
                      : 'Enter a custom local emergency number',
                  style: GoogleFonts.manrope(fontSize: 11.5, color: AppColors.mutedText),
                ),
                trailing: !['1122', '15', '115'].contains(settings.emergencyNumber)
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.tacticalOrange)
                    : null,
                onTap: () {
              Navigator.of(ctx).pop();
                  _showCustomEmergencyDialog(settings);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyOption(String number, String label, SettingsController settings) {
    final isSelected = settings.emergencyNumber == number;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.emergency_rounded, color: AppColors.alertRed),
      title: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? AppColors.tacticalOrangeDark : AppColors.darkCharcoal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.tacticalOrange)
          : null,
      onTap: () {
        Navigator.of(context).pop();
        settings.setEmergencyNumber(number);
        _showNotification('Emergency number set to $number');
      },
    );
  }

  void _showCustomEmergencyDialog(SettingsController settings) {
    final controller = TextEditingController(text: settings.emergencyNumber);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusCard)),
        title: Text(
          'Custom Emergency Number',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.darkCharcoal,
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: 'Enter emergency number',
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
              backgroundColor: AppColors.tacticalOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                settings.setEmergencyNumber(text);
                _showNotification('Emergency number set to $text');
              }
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showFuelPriceDialog(SettingsController settings) {
    final controller = TextEditingController(
      text: settings.fuelPricePerLiter != null
          ? settings.fuelPricePerLiter!.toStringAsFixed(0)
          : '',
    );
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
        ),
        title: Text(
          'Fuel Price per Litre (PKR)',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.darkCharcoal,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set your local fuel price per litre in PKR. Used for trip fuel economics and refills.',
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixText: 'Rs ',
                hintText: 'e.g. 280',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          if (settings.fuelPricePerLiter != null)
            TextButton(
              onPressed: () async {
                settings.setFuelPricePerLiter(null);
                Navigator.of(dialogCtx).pop();
                _showNotification('Fuel price cleared');
              },
              child: Text(
                'Clear',
                style: GoogleFonts.manrope(color: AppColors.alertRed),
              ),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tacticalOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final text = controller.text.trim();
              final parsed = parsePkr(text);
              if (parsed != null && parsed > 0) {
                settings.setFuelPricePerLiter(parsed);
                _showNotification('Fuel price set to ${formatPkr(parsed)}/L');
              } else if (text.isEmpty) {
                settings.setFuelPricePerLiter(null);
                _showNotification('Fuel price cleared');
              }
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    final controller = SettingsController.instance;
    final currentDisplay = controller.localCacheDisplay;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
        ),
        title: Row(
          children: [
            const IconTile(
              icon: Icons.cleaning_services_outlined,
              size: 34,
              iconSize: 16,
              isInset: false,
              backgroundColor: AppColors.alertRedBg,
              iconColor: AppColors.alertRed,
            ),
            const SizedBox(width: 10),
            Text(
              'Clear Local Cache?',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
              ),
            ),
          ],
        ),
        content: Text(
          'This will purge temporary cache files ($currentDisplay). Your saved rides, garage fleet, and settings will not be deleted.',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final freedBytes = await controller.clearTemporaryCache();
              final freedText = SettingsController.formatBytes(freedBytes);
              _showNotification('Local cache cleared ($freedText freed)');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusPill),
              ),
              elevation: 0,
            ),
            child: Text(
              'Clear Cache',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleHelpSupport() async {
    const email = AppInfo.supportEmail;
    final uri = Uri.parse('mailto:$email?subject=CAMP%20Rider%20Support');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(const ClipboardData(text: email));
        _showNotification('Support email copied: $email');
      }
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: email));
      _showNotification('Support email copied: $email');
    }
  }

  void _showAboutDialog(SettingsController settings) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.clayDark,
                borderRadius: BorderRadius.circular(AppColors.radiusTile - 6),
                boxShadow: AppColors.skeuRecessed,
              ),
              child: Center(
                child: Text(
                  'CAMP',
                  style: GoogleFonts.manrope(
                    color: AppColors.tacticalOrange,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'About CAMP',
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CAMP Mobility Suite',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 4),
            FutureBuilder<String>(
              future: settings.getAppVersion(),
              builder: (context, snapshot) => Text(
                'Version ${snapshot.data ?? '1.0.0+1'}',
                style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'CAMP is an offline-first rider companion designed for adventure motorcycling, pass ascents, and backcountry touring in Pakistan.',
              style: AppTextStyles.bodySecondary.copyWith(height: 1.45),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tacticalOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusPill),
              ),
              elevation: 0,
            ),
            child: Text(
              'Close',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmationDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
        ),
        title: Row(
          children: [
            const IconTile(
              icon: Icons.logout_rounded,
              size: 34,
              iconSize: 17,
              isInset: false,
              backgroundColor: AppColors.alertRedBg,
              iconColor: AppColors.alertRed,
            ),
            const SizedBox(width: 10),
            Text(
              'Confirm Log Out',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to end your active rider session?',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              Navigator.of(ctx).pop();
              await AuthController.instance.signOut();
              navigator.pushNamedAndRemoveUntil(
                CampRoutes.signIn,
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusPill),
              ),
              elevation: 0,
            ),
            child: Text(
              'Log Out',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsController.instance;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AppDrawerWidget(),
        backgroundColor: AppColors.clay,
        body: Stack(
          children: [
            // ── Scrollable Body Content with Fixed Header ──────────────────
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppColors.screenPadding),
                    child: CampAppBar(
                      leading: CampAppBarLeading.back,
                      actionText: 'SETTINGS',
                      onLeadingPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacementNamed('/');
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppColors.screenPadding,
                        8.0,
                        AppColors.screenPadding,
                        _kScrollBottomPadding,
                      ),
                      child: ListenableBuilder(
                        listenable: settings,
                        builder: (context, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),

                              // 2. Hero Row (Compact rider summary card)
                              _buildHeroRow(),

                              const SizedBox(height: AppColors.cardGap),

                              // 3. Card "ACCOUNT"
                              _buildAccountCard(),

                              const SizedBox(height: AppColors.cardGap),

                              // 4. Card "PREFERENCES"
                              _buildPreferencesCard(settings),

                              const SizedBox(height: AppColors.cardGap),

                              // 5. Card "STORAGE & DATA"
                              _buildStorageCard(settings),

                              const SizedBox(height: AppColors.cardGap),

                              // 6. Card "SUPPORT"
                              _buildSupportCard(settings),

                              const SizedBox(height: AppColors.cardGap),

                              // 7. Full-width outlined red/danger "Log Out" button
                              _buildLogOutButton(),

                              const SizedBox(height: 16),

                              // 8. Small centered muted footer text
                              FutureBuilder<String>(
                                future: settings.getAppVersion(),
                                builder: (context, snapshot) => Text(
                                  'CAMP ${snapshot.data ?? 'v1.0.0+1'} • Built for adventure riders',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.mutedLight,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Floating Bottom Dock (No tab active) ─────────────────────────
            const Positioned(
              left: 0,
              right: 0,
              bottom: _kNavBottomMargin,
              child: Center(
                child: CampBottomNav(
                  selected: CampTab.profile,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Compact Hero Row ───────────────────────────────────────────────────
  Widget _buildHeroRow() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ProfileController.instance,
        ActiveBikeController.instance,
        PostRideReportController.instance,
      ]),
      builder: (context, _) {
        final profile = ProfileController.instance;
        final avatarPath = profile.avatarPath;
        final displayName = profile.fullName;
        final activeBike = ActiveBikeController.instance.activeBike;
        final bikeLabel = activeBike != null
            ? 'Active Rig: ${activeBike.make} ${activeBike.modelName}'
            : 'No bike added yet';

        // Show tier chip only if computed from the rider's real rides (Batch B)
        final reports = PostRideReportController.instance.reports;
        final tierName = reports.isNotEmpty
            ? ProfileStats(reports).currentTier.name
            : null;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pushNamed(CampRoutes.profile),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppColors.radiusCard),
              boxShadow: AppColors.skeuRaised,
            ),
            child: Row(
              children: [
                // Circular Avatar without fake green online dot
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.tacticalOrange,
                      width: 2.0,
                    ),
                    boxShadow: AppColors.skeuRaisedSmall,
                  ),
                  child: ClipOval(
                    child: avatarPath != null && File(avatarPath).existsSync()
                        ? Image.file(File(avatarPath), fit: BoxFit.cover)
                        : Container(
                            color: AppColors.clayDark,
                            child: Center(
                              child: Text(
                                profile.firstName.isNotEmpty
                                    ? profile.firstName[0].toUpperCase()
                                    : 'R',
                                style: GoogleFonts.manrope(
                                  color: AppColors.terracotta,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Rider Name + Real Tier Pill (if computed) + Active Rig
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                          ),
                          if (tierName != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: AppColors.tacticalOrange.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(AppColors.radiusPill),
                                border: Border.all(
                                  color: AppColors.tacticalOrange.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                tierName,
                                style: GoogleFonts.manrope(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: AppColors.tacticalOrangeDark,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        bikeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.mutedLight,
                  size: 22,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 3. Card "ACCOUNT" ─────────────────────────────────────────────────────
  Widget _buildAccountCard() {
    // Note: Both Linked Accounts and Change Password return with AuthRepository and Firebase Auth (Batch H).
    return CampCard(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: AppColors.radiusCard,
      shadows: AppColors.skeuRaised,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsCardHeader(
            icon: Icons.person_outline_rounded,
            title: 'ACCOUNT',
          ),
          SettingsRowWidget(
            icon: Icons.badge_outlined,
            title: 'Edit Personal Info',
            onTap: () => Navigator.of(context).pushNamed(CampRoutes.editProfile),
          ),
        ],
      ),
    );
  }

  // ── 4. Card "PREFERENCES" ─────────────────────────────────────────────────
  Widget _buildPreferencesCard(SettingsController settings) {
    return CampCard(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: AppColors.radiusCard,
      shadows: AppColors.skeuRaised,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsCardHeader(
            icon: Icons.tune_rounded,
            title: 'PREFERENCES',
          ),
          SettingsRowWidget(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: 'Low fuel alerts',
            trailing: TacticalSwitch(
              value: settings.notificationsEnabled,
              onChanged: settings.setNotificationsEnabled,
            ),
          ),
          const Divider(height: 1, color: Color(0x10000000)),
          SettingsRowWidget(
            icon: Icons.language_rounded,
            title: 'Language',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  settings.language,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.mutedLight,
                  size: 20,
                ),
              ],
            ),
            onTap: _showLanguageSelector,
          ),
          const Divider(height: 1, color: Color(0x10000000)),
          SettingsRowWidget(
            icon: Icons.emergency_outlined,
            title: 'Emergency Number',
            subtitle: 'Default dialed for Rescue & SOS',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  settings.emergencyNumber,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.mutedLight,
                  size: 20,
                ),
              ],
            ),
            onTap: () => _showEmergencyNumberSelector(settings),
          ),
          const Divider(height: 1, color: Color(0x10000000)),
          SettingsRowWidget(
            icon: Icons.local_gas_station_rounded,
            title: 'Fuel Price per Litre',
            subtitle: 'Used for fuel economics calculations',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  settings.fuelPricePerLiter != null
                      ? '${formatPkr(settings.fuelPricePerLiter!)}/L'
                      : 'Not set',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: settings.fuelPricePerLiter != null
                        ? AppColors.darkCharcoal
                        : AppColors.mutedText,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.mutedLight,
                  size: 20,
                ),
              ],
            ),
            onTap: () => _showFuelPriceDialog(settings),
          ),
        ],
      ),
    );
  }

  // ── 5. Card "STORAGE & DATA" ──────────────────────────────────────────────
  Widget _buildStorageCard(SettingsController settings) {
    return CampCard(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: AppColors.radiusCard,
      shadows: AppColors.skeuRaised,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsCardHeader(
            icon: Icons.folder_open_rounded,
            title: 'STORAGE & DATA',
          ),
          SettingsRowWidget(
            icon: Icons.map_outlined,
            title: 'Offline Maps',
            trailing: Text(
              'Coming soon',
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedText,
              ),
            ),
            onTap: () => _showNotification('Offline maps coming soon'),
          ),
          const Divider(height: 1, color: Color(0x10000000)),
          const SettingsRowWidget(
            icon: Icons.shield_outlined,
            title: 'Privacy & Data',
            subtitle: 'Your data stays on this phone.',
          ),
          const Divider(height: 1, color: Color(0x10000000)),
          SettingsRowWidget(
            customLeading: const IconTile(
              icon: Icons.cleaning_services_outlined,
              size: 38,
              iconSize: 18,
              isInset: false,
              backgroundColor: AppColors.alertRedBg,
              iconColor: AppColors.alertRed,
            ),
            title: 'Clear Local Cache',
            subtitle: 'Free up temporary storage (${settings.localCacheDisplay})',
            onTap: _showClearCacheDialog,
          ),
        ],
      ),
    );
  }

  // ── 6. Card "SUPPORT" ─────────────────────────────────────────────────────
  Widget _buildSupportCard(SettingsController settings) {
    return CampCard(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: AppColors.radiusCard,
      shadows: AppColors.skeuRaised,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsCardHeader(
            icon: Icons.help_outline_rounded,
            title: 'SUPPORT',
          ),
          SettingsRowWidget(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: AppInfo.supportEmail,
            onTap: _handleHelpSupport,
          ),
          const Divider(height: 1, color: Color(0x10000000)),
          SettingsRowWidget(
            icon: Icons.info_outline_rounded,
            title: 'About CAMP',
            trailing: FutureBuilder<String>(
              future: settings.getAppVersion(),
              builder: (context, snapshot) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.data ?? 'v1.0.0+1',
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.mutedLight,
                    size: 20,
                  ),
                ],
              ),
            ),
            onTap: () => _showAboutDialog(settings),
          ),
          if (widget.isDebugMode) ...[
            const Divider(height: 1, color: Color(0x10000000)),
            SettingsRowWidget(
              key: const ValueKey('settings_tracking_diagnostics_row'),
              icon: Icons.bug_report_rounded,
              title: 'Tracking diagnostics (debug)',
              subtitle: 'Inspect live location fixes & filters',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedLight,
                size: 20,
              ),
              onTap: () {
                Navigator.of(context).pushNamed(CampRoutes.trackingDiagnostics);
              },
            ),
          ],
        ],
      ),
    );
  }

  // ── 7. Full-width Log Out Button ──────────────────────────────────────────
  Widget _buildLogOutButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showLogoutConfirmationDialog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppColors.radiusTile),
          border: Border.all(
            color: AppColors.alertRed.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: AppColors.skeuRaisedSmall,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.logout_rounded,
              size: 19,
              color: AppColors.alertRed,
            ),
            const SizedBox(width: 8),
            Text(
              'Log Out',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.alertRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
