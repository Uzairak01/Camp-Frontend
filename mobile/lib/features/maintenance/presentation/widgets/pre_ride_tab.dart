import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/data/app_repositories.dart';
import '../../../../core/widgets/camp_bottom_nav.dart';
import '../../../../core/widgets/camp_card.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../controllers/maintenance_controller.dart';

/// Tab 3 — Pre-Ride Safety Audit checklist.
/// Keyed by active bikeId and persisted through MaintenanceRepository.
class PreRideTab extends StatefulWidget {
  const PreRideTab({super.key});

  @override
  State<PreRideTab> createState() => _PreRideTabState();
}

class _PreRideTabState extends State<PreRideTab> {
  static const List<String> _builtInChecks = [
    'Tire Pressures & Tread Inspection',
    'Chain slack & lubrication',
    'Engine Oil Sight Glass Level Check',
    'Front & Rear Brake Lever Pressure',
    'Throttle Return & Clutch Cable Freeplay',
    'Headlight, Brake Lamp & Turn Signals',
    'Luggage Straps & Crash Bars Torqued',
  ];

  final Map<String, bool> _checklist = {};
  List<String> _customChecks = [];

  DateTime? _lastChecked;
  String? _currentBikeId;

  @override
  void initState() {
    super.initState();
    ActiveBikeController.instance.addListener(_onActiveBikeChanged);
    _loadForBike(ActiveBikeController.instance.activeBike?.id);
  }

  @override
  void dispose() {
    ActiveBikeController.instance.removeListener(_onActiveBikeChanged);
    super.dispose();
  }

  void _onActiveBikeChanged() {
    final newId = ActiveBikeController.instance.activeBike?.id;
    if (newId != _currentBikeId) {
      _loadForBike(newId);
    }
  }

  Future<void> _loadForBike(String? bikeId) async {
    _currentBikeId = bikeId;
    final repo = AppRepositories.instance.maintenanceRepository;
    final saved = await repo.loadChecklist(bikeId);
    final lastChecked = await repo.loadChecklistLastChecked(bikeId);
    final custom = bikeId != null ? await repo.loadCustomChecks(bikeId) : <String>[];
    if (bikeId != null) {
      await MaintenanceController.instance.loadCustomChecks(bikeId);
    }
    if (!mounted) return;
    setState(() {
      _lastChecked = lastChecked;
      _customChecks = List<String>.from(custom);
      _checklist.clear();
      final all = [..._builtInChecks, ..._customChecks];
      for (final k in all) {
        _checklist[k] = saved[k] ?? false;
      }
    });
  }

  Future<void> _toggleItem(String checkpoint) async {
    final newVal = !(_checklist[checkpoint] ?? false);
    final now = DateTime.now();
    setState(() {
      _checklist[checkpoint] = newVal;
      _lastChecked = now;
    });
    final repo = AppRepositories.instance.maintenanceRepository;
    await repo.saveChecklist(
      _checklist,
      bikeId: _currentBikeId,
      lastChecked: now,
    );
  }

  Future<void> _resetChecklist() async {
    final repo = AppRepositories.instance.maintenanceRepository;
    await repo.resetChecklist(_currentBikeId);
    if (!mounted) return;
    setState(() {
      for (final k in _checklist.keys.toList()) {
        _checklist[k] = false;
      }
      _lastChecked = null;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pre-ride checklist reset'),
        backgroundColor: AppColors.darkCharcoal,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showAddCustomCheckDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add Custom Check',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.manrope(fontSize: 14, color: AppColors.darkCharcoal),
          decoration: InputDecoration(
            hintText: 'e.g. Check coolant level',
            hintStyle: GoogleFonts.manrope(fontSize: 13, color: AppColors.mutedLight),
            filled: true,
            fillColor: AppColors.clayDark.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tacticalOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(ctx).pop();
                _addCustomCheck(text);
              }
            },
            child: Text(
              'Save',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCustomCheck(String text) async {
    if (_customChecks.contains(text) || _builtInChecks.contains(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkpoint already exists'),
          backgroundColor: AppColors.darkCharcoal,
        ),
      );
      return;
    }

    setState(() {
      _customChecks.add(text);
      _checklist[text] = false;
    });

    final repo = AppRepositories.instance.maintenanceRepository;
    await repo.saveCustomChecks(_customChecks, _currentBikeId);
    await repo.saveChecklist(_checklist, bikeId: _currentBikeId, lastChecked: _lastChecked);
    if (_currentBikeId != null) {
      MaintenanceController.instance.addCustomCheck(_currentBikeId!, text);
    }
  }

  void _confirmDeleteCustomCheck(String checkpoint) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Check?',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "$checkpoint" from this bike\'s checklist?',
          style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop(true);
              _deleteCustomCheck(checkpoint);
            },
            child: Text(
              'Delete',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCustomCheck(String checkpoint) async {
    final removedIndex = _customChecks.indexOf(checkpoint);
    final wasChecked = _checklist[checkpoint] ?? false;

    setState(() {
      _customChecks.remove(checkpoint);
      _checklist.remove(checkpoint);
    });

    final repo = AppRepositories.instance.maintenanceRepository;
    await repo.saveCustomChecks(_customChecks, _currentBikeId);
    await repo.saveChecklist(_checklist, bikeId: _currentBikeId, lastChecked: _lastChecked);
    if (_currentBikeId != null) {
      MaintenanceController.instance.deleteCustomCheck(_currentBikeId!, checkpoint);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "$checkpoint"'),
        backgroundColor: AppColors.darkCharcoal,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.tacticalOrange,
          onPressed: () async {
            if (!mounted) return;
            setState(() {
              final safeIndex = removedIndex.clamp(0, _customChecks.length);
              _customChecks.insert(safeIndex, checkpoint);
              _checklist[checkpoint] = wasChecked;
            });
            await repo.saveCustomChecks(_customChecks, _currentBikeId);
            await repo.saveChecklist(_checklist, bikeId: _currentBikeId, lastChecked: _lastChecked);
            if (_currentBikeId != null) {
              MaintenanceController.instance.insertCustomCheck(_currentBikeId!, removedIndex, checkpoint);
            }
          },
        ),
      ),
    );
  }

  String _formatLastChecked(DateTime? dt) {
    if (dt == null) return 'Never checked';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final allCheckpoints = [..._builtInChecks, ..._customChecks];
    final completedCount = allCheckpoints.where((k) => _checklist[k] == true).length;
    final totalCount = allCheckpoints.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress Card
        CampCard(
          padding: const EdgeInsets.all(16),
          borderRadius: AppColors.radiusCard,
          color: AppColors.clay,
          shadows: AppColors.skeuRaised,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PRE-RIDE SAFETY AUDIT',
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkCharcoal,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '$completedCount of $totalCount Done',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: completedCount == totalCount
                          ? AppColors.statusGreen
                          : AppColors.tacticalOrangeDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.clayDark,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completedCount == totalCount
                        ? AppColors.statusGreen
                        : AppColors.tacticalOrange,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Last checked: ${_formatLastChecked(_lastChecked)}',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _resetChecklist,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        'Reset checklist',
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.alertRed,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Checkpoint Items
        ...allCheckpoints.map((checkpoint) {
          final isChecked = _checklist[checkpoint] ?? false;
          final isCustom = _customChecks.contains(checkpoint);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleItem(checkpoint),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isChecked
                    ? AppColors.clay
                    : AppColors.clayDark.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppColors.radiusTile),
                boxShadow: isChecked ? AppColors.skeuRaisedSmall : null,
                border: Border.all(
                  color: isChecked
                      ? AppColors.statusGreen.withValues(alpha: 0.5)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isChecked
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: isChecked ? AppColors.statusGreen : AppColors.mutedLight,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      checkpoint,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: isChecked ? FontWeight.w700 : FontWeight.w600,
                        color: isChecked ? AppColors.darkCharcoal : AppColors.mutedText,
                        decoration: isChecked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if (isCustom)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _confirmDeleteCustomCheck(checkpoint),
                      child: const Tooltip(
                        message: 'Delete check',
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.alertRed,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 8),

        // "+ Add your own check" button
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showAddCustomCheckDialog,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.clay,
              borderRadius: BorderRadius.circular(AppColors.radiusTile),
              boxShadow: AppColors.skeuRaisedSmall,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: AppColors.tacticalOrangeDark,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add your own check',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tacticalOrangeDark,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Start Ride Button
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // When the Step 4 ride tracker exists, this should also start the tracker.
            CampBottomNav.navigateToTab(context, CampTab.navigation);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.tacticalOrangeLight,
                  AppColors.tacticalOrange,
                  AppColors.tacticalOrangeDark,
                ],
              ),
              borderRadius: BorderRadius.circular(AppColors.radiusTile),
              boxShadow: AppColors.orangeGlow,
            ),
            child: Center(
              child: Text(
                'Start Ride',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
