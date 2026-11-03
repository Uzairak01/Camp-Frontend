import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/camp_app_bar.dart';
import '../../../../core/widgets/camp_card.dart';
import '../../../../core/widgets/inset_tile.dart';
import '../../../../core/widgets/multi_select_chip_row.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../controllers/post_ride_report_controller.dart';
import '../../domain/post_ride_report.dart';

/// Dedicated post-ride debrief screen.
///
/// Collects rider-entered data: date, distance in km (required), duration,
/// optional riding terrain chips, and trail observations / flagged symptoms.
/// Never prefilled with estimates or default values. Saves directly to
/// [PostRideReportController] / repository.
class PostRideDebriefScreen extends StatefulWidget {
  const PostRideDebriefScreen({super.key, this.bikeId, this.initialReport});

  final String? bikeId;
  final PostRideReport? initialReport;

  @override
  State<PostRideDebriefScreen> createState() => _PostRideDebriefScreenState();
}

class _PostRideDebriefScreenState extends State<PostRideDebriefScreen> {
  late DateTime _selectedDate;
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();
  final Set<String> _selectedTerrainTags = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialReport != null) {
      final rep = widget.initialReport!;
      _selectedDate = rep.date;
      _distanceController.text = rep.distanceKm > 0
          ? (rep.distanceKm == rep.distanceKm.roundToDouble()
              ? rep.distanceKm.toStringAsFixed(0)
              : rep.distanceKm.toStringAsFixed(1))
          : '';
      if (rep.durationHours != null && rep.durationHours! > 0) {
        _durationController.text =
            rep.durationHours == rep.durationHours!.roundToDouble()
                ? rep.durationHours!.toStringAsFixed(0)
                : rep.durationHours!.toStringAsFixed(1);
      }
      _selectedTerrainTags.addAll(rep.terrainTags);
      if (rep.notes != null) {
        _notesController.text = rep.notes!;
      }
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.tacticalOrange,
              onPrimary: Colors.white,
              surface: AppColors.clay,
              onSurface: AppColors.darkCharcoal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _odometerImpactNote() {
    if (widget.initialReport?.source == 'tracked') {
      return 'Distance already added to odometer live';
    }
    final distanceText = _distanceController.text.trim();
    final entered = double.tryParse(distanceText) ?? 0.0;
    if (widget.initialReport != null) {
      final diff = entered - widget.initialReport!.distanceKm;
      if (diff == 0) {
        return 'Odometer already includes this ride';
      }
      final diffStr =
          diff > 0 ? '+${diff.toStringAsFixed(0)}' : diff.toStringAsFixed(0);
      return 'Will adjust odometer by $diffStr km';
    }
    final kmStr = entered > 0
        ? (entered == entered.roundToDouble()
            ? entered.toStringAsFixed(0)
            : entered.toStringAsFixed(1))
        : 'X';
    return 'Will add $kmStr km to odometer';
  }

  void _save() {
    final distanceText = _distanceController.text.trim();
    final distance = double.tryParse(distanceText);

    if (distance == null || distance <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid distance in km (> 0).';
      });
      return;
    }

    final durationText = _durationController.text.trim();
    double? duration;
    if (durationText.isNotEmpty) {
      duration = double.tryParse(durationText);
    }

    final notesText = _notesController.text.trim();

    final targetBikeId = widget.initialReport?.bikeId ??
        widget.bikeId ??
        ActiveBikeController.instance.activeBike?.id ??
        'unknown-bike';

    if (widget.initialReport != null) {
      // Update existing report in-place, preserving source and original creation timestamps
      final updated = widget.initialReport!.copyWith(
        date: _selectedDate,
        distanceKm: distance,
        durationHours: duration,
        terrainTags: _selectedTerrainTags.toList(),
        notes: notesText.isNotEmpty ? notesText : null,
        updatedAt: DateTime.now().toUtc(),
      );
      PostRideReportController.instance.updateReport(updated);

      // Only adjust odometer if this was a manual report! Tracked reports never touch odometer.
      if (widget.initialReport!.source != 'tracked') {
        final diff = distance - widget.initialReport!.distanceKm;
        if (diff != 0) {
          final bike = ActiveBikeController.instance.getBikeById(targetBikeId);
          if (bike != null) {
            final newOdo = bike.odometerKm + diff.round();
            final updatedBike = bike.copyWith(
              odometerKm: newOdo,
              preciseOdometerKm: newOdo.toDouble(),
              lastUpdated: DateTime.now(),
            );
            ActiveBikeController.instance.updateBike(updatedBike);
          }
        }
      }
    } else {
      // Create new manual report
      final report = PostRideReport(
        id: 'rep-${DateTime.now().millisecondsSinceEpoch}',
        bikeId: targetBikeId,
        date: _selectedDate,
        distanceKm: distance,
        durationHours: duration,
        terrainTags: _selectedTerrainTags.toList(),
        notes: notesText.isNotEmpty ? notesText : null,
        source: 'manual',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      PostRideReportController.instance.addReport(report);

      final bike = ActiveBikeController.instance.getBikeById(targetBikeId);
      if (bike != null) {
        final newOdo = bike.odometerKm + distance.round();
        final updatedBike = bike.copyWith(
          odometerKm: newOdo,
          preciseOdometerKm: newOdo.toDouble(),
          lastUpdated: DateTime.now(),
        );
        ActiveBikeController.instance.updateBike(updatedBike);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Post-ride report saved!',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.statusGreen,
      ),
    );

    Navigator.of(context).pop();
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.clay,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CampAppBar(
              leading: CampAppBarLeading.back,
              onLeadingPressed: () => Navigator.of(context).pop(),
              actionText: '• POST-RIDE DEBRIEF',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POST-RIDE DEBRIEF',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Record your real ride. Logged rides feed your riding history, Profile stats and predicted service dates.',
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CampCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Date Field (Default today)
                          Text(
                            'RIDE DATE',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mutedText,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _pickDate,
                            child: InsetTile(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDate(_selectedDate),
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.darkCharcoal,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 18,
                                    color: AppColors.tacticalOrange,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. Distance in km (Required, > 0)
                          Text(
                            'DISTANCE COVERED (KM) *',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mutedText,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InsetTile(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            child: TextField(
                              controller: _distanceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkCharcoal,
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. 185',
                                hintStyle: GoogleFonts.manrope(
                                  color: AppColors.mutedLight,
                                ),
                                border: InputBorder.none,
                                suffixText: 'km',
                                suffixStyle: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mutedText,
                                ),
                              ),
                              onChanged: (_) {
                                setState(() {
                                  _errorMessage = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _odometerImpactNote(),
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: widget.initialReport?.source == 'tracked'
                                  ? AppColors.statusGreen
                                  : AppColors.mutedText,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3. Duration in hours (Optional)
                          Text(
                            'DURATION IN HOURS (OPTIONAL)',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mutedText,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InsetTile(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            child: TextField(
                              controller: _durationController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkCharcoal,
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. 3.5',
                                hintStyle: GoogleFonts.manrope(
                                  color: AppColors.mutedLight,
                                ),
                                border: InputBorder.none,
                                suffixText: 'hours',
                                suffixStyle: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mutedText,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 4. Riding Terrain Chips (Optional)
                          Text(
                            'RIDING TERRAIN',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mutedText,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          MultiSelectChipRow(
                            options: const ['City', 'Highway', 'Off-road', 'Mountain'],
                            selected: _selectedTerrainTags,
                            onToggle: (tag) {
                              setState(() {
                                if (_selectedTerrainTags.contains(tag)) {
                                  _selectedTerrainTags.remove(tag);
                                } else {
                                  _selectedTerrainTags.add(tag);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // 5. Notes (Optional)
                          Text(
                            'Trail observations / flagged symptoms (optional)',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mutedText,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InsetTile(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: TextField(
                              controller: _notesController,
                              maxLines: 3,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkCharcoal,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'e.g. Loose scree ascent, heavy dust on chain',
                                hintStyle: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppColors.mutedLight,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.alertRed,
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Save Button
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _save,
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.tacticalOrange,
                                borderRadius: BorderRadius.circular(
                                  AppColors.radiusTile,
                                ),
                                boxShadow: AppColors.orangeGlow,
                              ),
                              child: Center(
                                child: Text(
                                  'Save Post-Ride Report',
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
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
