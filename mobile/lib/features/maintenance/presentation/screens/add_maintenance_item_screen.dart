import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../domain/maintenance_item_model.dart';

/// Screen to log or edit a motorcycle maintenance inspection item
class AddMaintenanceItemScreen extends StatefulWidget {
  const AddMaintenanceItemScreen({super.key, this.initialItem});

  final MaintenanceItem? initialItem;

  @override
  State<AddMaintenanceItemScreen> createState() =>
      _AddMaintenanceItemScreenState();
}

class _AddMaintenanceItemScreenState extends State<AddMaintenanceItemScreen> {
  final _nameCtrl = TextEditingController();
  final _dueValueCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _mechanicCtrl = TextEditingController();

  String _selectedCategory = 'Suspension';
  static const List<String> _categoryOptions = [
    'Suspension',
    'Engine',
    'Brakes',
    'Drivetrain',
    'Tires',
    'Electrical',
    'Other',
  ];

  MaintenanceStatus _selectedStatus = MaintenanceStatus.dueSoon;
  int _dueTypeIndex = 0; // 0=By Mileage, 1=By Date
  int _trackingModeIndex = 1; // 0=Auto Telemetry, 1=Manual Entry (default: Manual)
  String? _selectedBikeId;

  @override
  void initState() {
    super.initState();
    if (widget.initialItem != null) {
      final item = widget.initialItem!;
      _selectedBikeId = item.bikeId;
      _nameCtrl.text = item.name;
      _selectedCategory = item.category;
      _selectedStatus = item.status;
      _trackingModeIndex =
          item.trackingMode == MaintenanceTrackingMode.auto ? 0 : 1;
      if (item.dueMileage != null && item.dueMileage!.isNotEmpty) {
        _dueTypeIndex = 0;
        _dueValueCtrl.text = item.dueMileage!;
      } else if (item.dueDate != null && item.dueDate!.isNotEmpty) {
        _dueTypeIndex = 1;
        _dueValueCtrl.text = item.dueDate!;
      }
      _notesCtrl.text = item.notes ?? '';
      if (item.cost != null) {
        _costCtrl.text = item.cost!.toStringAsFixed(0);
      }
      _mechanicCtrl.text = item.mechanicName ?? '';
    } else {
      _selectedBikeId = ActiveBikeController.instance.activeBike?.id;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dueValueCtrl.dispose();
    _notesCtrl.dispose();
    _costCtrl.dispose();
    _mechanicCtrl.dispose();
    super.dispose();
  }

  void _saveItem() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an item name'),
          backgroundColor: AppColors.alertRed,
        ),
      );
      return;
    }

    final double? parsedCost = parsePkr(_costCtrl.text);
    final String? mechanicName =
        _mechanicCtrl.text.trim().isNotEmpty ? _mechanicCtrl.text.trim() : null;

    final String? statusDisplay = _selectedStatus == MaintenanceStatus.ok
        ? 'OK'
        : (parsedCost != null && parsedCost > 0 ? formatPkr(parsedCost) : null);

    String conditionNote;
    if (_selectedStatus == MaintenanceStatus.ok) {
      conditionNote = 'Good • Ready for trail';
    } else {
      final rawVal = _dueValueCtrl.text.trim();
      if (rawVal.isNotEmpty) {
        final cleanNum = int.tryParse(rawVal.replaceAll(',', '').replaceAll(' ', ''));
        if (_dueTypeIndex == 0) {
          // By Mileage
          if (cleanNum != null) {
            conditionNote = 'Due soon • in ${_formatThousands(cleanNum)} km';
          } else {
            final kmMatch = RegExp(r'^(?:in\s+)?(\d[\d,]*)\s*km$', caseSensitive: false).firstMatch(rawVal);
            if (kmMatch != null) {
              final n = int.tryParse(kmMatch.group(1)!.replaceAll(',', ''));
              conditionNote = 'Due soon • in ${_formatThousands(n ?? 0)} km';
            } else {
              conditionNote = 'Due soon • $rawVal';
            }
          }
        } else {
          // By Date
          if (cleanNum != null) {
            conditionNote = 'Due soon • in ${_formatThousands(cleanNum)} days';
          } else {
            final daysMatch = RegExp(r'^(?:in\s+)?(\d[\d,]*)\s*days?$', caseSensitive: false).firstMatch(rawVal);
            if (daysMatch != null) {
              final n = int.tryParse(daysMatch.group(1)!.replaceAll(',', ''));
              conditionNote = 'Due soon • in ${_formatThousands(n ?? 0)} days';
            } else {
              conditionNote = 'Due soon • $rawVal';
            }
          }
        }
      } else {
        conditionNote = _selectedStatus == MaintenanceStatus.dueSoon
            ? 'Due soon'
            : 'Maintenance due';
      }
    }

    final item = widget.initialItem != null
        ? widget.initialItem!.copyWith(
            name: name,
            category: _selectedCategory,
            status: _selectedStatus,
            bikeId: _selectedBikeId,
            trackingMode: _trackingModeIndex == 0
                ? MaintenanceTrackingMode.auto
                : MaintenanceTrackingMode.manual,
            dueMileage: _dueTypeIndex == 0 ? _dueValueCtrl.text.trim() : null,
            dueDate: _dueTypeIndex == 1 ? _dueValueCtrl.text.trim() : null,
            notes: _notesCtrl.text.trim(),
            cost: parsedCost,
            mechanicName: mechanicName,
            actionLabel: null,
            statusValueDisplay: statusDisplay,
            subtitle: _notesCtrl.text.trim().isNotEmpty
                ? _notesCtrl.text.trim()
                : (mechanicName != null ? 'Serviced by $mechanicName' : null),
            conditionNote: conditionNote,
            icon: _getCategoryIcon(_selectedCategory),
            updatedAt: DateTime.now().toUtc(),
          )
        : MaintenanceItem(
            id: 'maint-${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            category: _selectedCategory,
            status: _selectedStatus,
            bikeId: _selectedBikeId,
            trackingMode: _trackingModeIndex == 0
                ? MaintenanceTrackingMode.auto
                : MaintenanceTrackingMode.manual,
            dueMileage: _dueTypeIndex == 0 ? _dueValueCtrl.text.trim() : null,
            dueDate: _dueTypeIndex == 1 ? _dueValueCtrl.text.trim() : null,
            notes: _notesCtrl.text.trim(),
            cost: parsedCost,
            mechanicName: mechanicName,
            actionLabel: null,
            statusValueDisplay: statusDisplay,
            subtitle: _notesCtrl.text.trim().isNotEmpty
                ? _notesCtrl.text.trim()
                : (mechanicName != null ? 'Serviced by $mechanicName' : null),
            conditionNote: conditionNote,
            icon: _getCategoryIcon(_selectedCategory),
          );

    Navigator.of(context).pop(item);
  }

  static String _formatThousands(int num) {
    final str = num.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'brakes':
        return Icons.disc_full_rounded;
      case 'engine':
        return Icons.opacity_rounded;
      case 'drivetrain':
        return Icons.link_rounded;
      case 'tires':
        return Icons.album_rounded;
      case 'suspension':
        return Icons.swap_vert_circle_rounded;
      case 'electrical':
        return Icons.bolt_rounded;
      default:
        return Icons.build_circle_rounded;
    }
  }

  Widget _buildStatusTile({
    required MaintenanceStatus status,
    required String label,
    Color? dotColor,
    IconData? icon,
  }) {
    final bool isSelected = _selectedStatus == status;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedStatus = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.tacticalOrange.withValues(alpha: 0.12)
              : AppColors.clayDark,
          borderRadius: BorderRadius.circular(AppColors.radiusTile),
          border: Border.all(
            color: isSelected
                ? AppColors.tacticalOrange
                : Colors.white.withValues(alpha: 0.45),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected ? null : AppColors.skeuRaisedSmall,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ] else if (icon != null) ...[
              Icon(icon, size: 13, color: AppColors.tacticalOrangeDark),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.tacticalOrangeDark
                      : AppColors.darkCharcoal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.clay,
        appBar: CampAppBar(
          leading: CampAppBarLeading.back,
          actionText: 'Save',
          onActionPressed: _saveItem,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppColors.screenPadding,
              12,
              AppColors.screenPadding,
              32,
            ),
            child: CampCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Item Name ─────────────────────────────────────────────
                  LabeledTextField(
                    label: 'ITEM NAME',
                    controller: _nameCtrl,
                  ),

                  const SizedBox(height: 18),

                  // ── Bike Picker Dropdown ──────────────────────────────────
                  LabeledDropdown<String?>(
                    label: 'BIKE',
                    value: _selectedBikeId,
                    items: [
                      null,
                      ...ActiveBikeController.instance.bikes.map((b) => b.id),
                      if (_selectedBikeId != null &&
                          !ActiveBikeController.instance.bikes
                              .any((b) => b.id == _selectedBikeId))
                        _selectedBikeId,
                    ],
                    itemLabelBuilder: (id) {
                      if (id == null) return 'No bike';
                      final bike =
                          ActiveBikeController.instance.getBikeById(id);
                      return bike != null ? bike.name : 'Deleted bike';
                    },
                    onChanged: (val) => setState(() => _selectedBikeId = val),
                  ),

                  const SizedBox(height: 18),

                  // ── Category Dropdown ─────────────────────────────────────
                  LabeledDropdown<String>(
                    label: 'CATEGORY',
                    value: _selectedCategory,
                    items: _categoryOptions,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategory = val);
                      }
                    },
                  ),

                  const SizedBox(height: 18),

                  // ── Status 2x2 Fixed Grid ─────────────────────────────────
                  Text('STATUS', style: AppTextStyles.overline),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusTile(
                          status: MaintenanceStatus.ok,
                          label: 'OK',
                          dotColor: AppColors.statusGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatusTile(
                          status: MaintenanceStatus.dueSoon,
                          label: 'Due Soon',
                          dotColor: AppColors.tacticalOrangeDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusTile(
                          status: MaintenanceStatus.overdue,
                          label: 'Overdue',
                          dotColor: AppColors.alertRed,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatusTile(
                          status: MaintenanceStatus.diyRec,
                          label: 'DIY-rec',
                          icon: Icons.build_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ── Due At (Optional) ─────────────────────────────────────
                  Text('DUE AT (OPTIONAL)', style: AppTextStyles.overline),
                  const SizedBox(height: 6),
                  SegmentedControl(
                    options: const ['By Mileage', 'By Date'],
                    selectedIndex: _dueTypeIndex,
                    onChanged: (idx) {
                      setState(() => _dueTypeIndex = idx);
                    },
                  ),
                  const SizedBox(height: 8),
                  LabeledTextField(
                    label: _dueTypeIndex == 0 ? 'ODOMETER DUE (OPTIONAL)' : 'DATE DUE (OPTIONAL)',
                    controller: _dueValueCtrl,
                    placeholder: _dueTypeIndex == 0 ? 'e.g. 5,000 km' : 'e.g. Nov 15, 2026',
                    trailingIcon: _dueTypeIndex == 0
                        ? Icons.speed_rounded
                        : Icons.calendar_today_rounded,
                  ),

                  const SizedBox(height: 18),

                  // ── Cost (Optional, PKR) ──────────────────────────────────
                  LabeledTextField(
                    label: 'SERVICE / PART COST (OPTIONAL)',
                    controller: _costCtrl,
                    prefixText: 'Rs ',
                    placeholder: '0',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),

                  const SizedBox(height: 18),

                  // ── Workshop / Mechanic (Optional) ────────────────────────
                  LabeledTextField(
                    label: 'WORKSHOP / MECHANIC (OPTIONAL)',
                    controller: _mechanicCtrl,
                    placeholder: 'e.g. Peak Moto, DIY, Local Mechanic',
                    trailingIcon: Icons.handyman_rounded,
                  ),

                  const SizedBox(height: 18),

                  // ── Notes (Multiline) ─────────────────────────────────────
                  LabeledTextField(
                    label: 'NOTES (OPTIONAL)',
                    controller: _notesCtrl,
                    placeholder: 'Additional service details, part numbers, or fluid specs',
                    maxLines: 3,
                  ),

                  const SizedBox(height: 18),

                  // ── Tracking Mode ─────────────────────────────────────────
                  Text('TRACKING MODE', style: AppTextStyles.overline),
                  const SizedBox(height: 6),
                  SegmentedControl(
                    options: const ['Auto Sync', 'Manual Entry'],
                    selectedIndex: _trackingModeIndex,
                    onChanged: (idx) {
                      setState(() => _trackingModeIndex = idx);
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: AppColors.mutedText,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Manual entries won\'t be affected by auto sync.',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Primary Button ────────────────────────────────────────
                  PrimaryButton(
                    label: 'Add Item',
                    icon: Icons.arrow_forward_rounded,
                    isFullWidth: true,
                    onTap: _saveItem,
                  ),

                  const SizedBox(height: 10),

                  // ── Cancel Button ─────────────────────────────────────────
                  Center(
                    child: GhostButton(
                      label: 'Cancel',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
