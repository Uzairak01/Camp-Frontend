import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/camp_app_bar.dart';
import '../../../../core/widgets/camp_card.dart';
import '../../../garage/controllers/active_bike_controller.dart';
import '../../../garage/domain/bike_model.dart';
import '../../controllers/maintenance_controller.dart';
import '../../domain/service_schedule_engine.dart';
import '../../domain/service_schedule_item.dart';
import '../../domain/service_schedule_status_formatter.dart';

/// Input mode for entering when a service was last performed.
enum LastDoneInputMode {
  /// Rider enters relative distance ("About __ km ago"), converted to odometer.
  kmAgo,

  /// Rider enters absolute odometer reading at last service.
  odometer,
}

/// In-memory form state for an individual service schedule item.
class _ScheduleItemFormData {
  _ScheduleItemFormData({
    required this.id,
    required this.type,
    required this.enabled,
    required this.kmController,
    required this.monthController,
    required this.lastDoneController,
    required this.mode,
    required this.focusNode,
    this.customTitle,
    this.lastDoneDate,
  });

  final String id;
  final ServiceItemType type;
  String? customTitle;
  bool enabled;
  final TextEditingController kmController;
  final TextEditingController monthController;
  final TextEditingController lastDoneController;
  LastDoneInputMode mode;
  DateTime? lastDoneDate;
  final FocusNode focusNode;

  /// User-facing display name.
  String get displayName => (type == ServiceItemType.custom && customTitle != null && customTitle!.isNotEmpty)
      ? customTitle!
      : type.displayName;

  /// Calculates the effective last done odometer based on current input mode.
  double? calculateLastDoneOdometer(double bikeOdometer) {
    final text = lastDoneController.text.trim();
    if (text.isEmpty) return null;
    final val = double.tryParse(text);
    if (val == null || val < 0) return null;

    if (mode == LastDoneInputMode.kmAgo) {
      if (bikeOdometer <= 0) return null;
      return (bikeOdometer - val).clamp(0, bikeOdometer);
    }
    return val;
  }

  /// Validates the last done input. Returns an error message or null.
  String? validateLastDone(double bikeOdometer) {
    final text = lastDoneController.text.trim();
    if (text.isEmpty) return null;
    final val = double.tryParse(text);
    if (val == null || val < 0) {
      return 'Numbers only (0 or more)';
    }

    if (mode == LastDoneInputMode.kmAgo) {
      if (bikeOdometer > 0 && val > bikeOdometer) {
        return 'Cannot be more than bike\'s odometer (${ServiceScheduleStatusFormatter.formatNumber(bikeOdometer)} km)';
      }
    } else {
      if (bikeOdometer > 0 && val > bikeOdometer) {
        return 'Cannot be higher than bike\'s odometer (${ServiceScheduleStatusFormatter.formatNumber(bikeOdometer)} km)';
      }
    }
    return null;
  }

  void dispose() {
    kmController.dispose();
    monthController.dispose();
    lastDoneController.dispose();
    focusNode.dispose();
  }
}

/// Screen allowing the rider to configure their own service schedule per bike.
///
/// Features:
///  - "About __ km ago" (default for new items) vs "At odometer __ km" segmented control.
///  - Automatic conversion to stored absolute odometer reading.
///  - Live friendly status messages matching the unified status formatter.
///  - Sanity check warning if typed odometer is >3x interval in the past.
///  - Multi-component support including rear brakes and custom items.
class ServiceScheduleScreen extends StatefulWidget {
  const ServiceScheduleScreen({super.key, this.bikeId, this.focusItemType});

  final String? bikeId;
  final ServiceItemType? focusItemType;

  @override
  State<ServiceScheduleScreen> createState() => _ServiceScheduleScreenState();
}

class _ServiceScheduleScreenState extends State<ServiceScheduleScreen> {
  late Bike? _bike;
  bool _isHarsh = false;
  bool _hasCarburetorOverride = false;

  final Map<String, GlobalKey> _itemKeys = {};
  final List<_ScheduleItemFormData> _items = [];

  @override
  void initState() {
    super.initState();
    _resolveBike();
    _loadState();
    if (widget.focusItemType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _items.firstWhere(
          (i) => i.type == widget.focusItemType,
          orElse: () => _items.first,
        );
        final key = _itemKeys[target.id];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(ServiceScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bikeId != widget.bikeId) {
      for (final item in _items) {
        item.dispose();
      }
      _items.clear();
      _itemKeys.clear();
      _resolveBike();
      _loadState();
    }
  }

  void _resolveBike() {
    if (widget.bikeId != null && widget.bikeId!.isNotEmpty) {
      _bike = ActiveBikeController.instance.getBikeById(widget.bikeId!);
    } else {
      _bike = ActiveBikeController.instance.activeBike;
    }
  }

  void _loadState() {
    if (_bike == null) return;
    final bikeId = _bike!.id;

    _isHarsh = MaintenanceController.instance.isHarshConditions(bikeId);
    _hasCarburetorOverride = MaintenanceController.instance.isCarbureted(_bike);

    final storedItems = MaintenanceController.instance.getScheduleItems(bikeId);
    final isCarb = _bike!.fuelSystem == FuelSystem.carburetor || _hasCarburetorOverride;

    for (final item in storedItems) {
      if (item.type == ServiceItemType.carburetor && !isCarb) {
        continue;
      }

      // Existing saved items that already store an odometer reopen in "At odometer" mode.
      // New / empty items open in "About __ km ago" mode by default.
      final bool hasSavedOdometer = item.lastDoneKm != null;
      final LastDoneInputMode initialMode = hasSavedOdometer
          ? LastDoneInputMode.odometer
          : LastDoneInputMode.kmAgo;

      final String initialLastDoneText;
      if (hasSavedOdometer) {
        initialLastDoneText = item.lastDoneKm! % 1 == 0
            ? item.lastDoneKm!.toInt().toString()
            : item.lastDoneKm!.toString();
      } else {
        initialLastDoneText = '';
      }

      final data = _ScheduleItemFormData(
        id: item.id,
        type: item.type,
        customTitle: item.customTitle,
        enabled: item.enabled,
        kmController: TextEditingController(
          text: item.intervalKm != null ? item.intervalKm.toString() : '',
        ),
        monthController: TextEditingController(
          text: item.intervalMonths != null ? item.intervalMonths.toString() : '',
        ),
        lastDoneController: TextEditingController(text: initialLastDoneText),
        mode: initialMode,
        lastDoneDate: item.lastDoneDate,
        focusNode: FocusNode(),
      );

      _itemKeys[item.id] = GlobalKey();
      _items.add(data);
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  /// Shows the sanity check warning dialog when last service is >3x interval in the past.
  Future<bool> _showSanityWarningDialog({
    required int kmAgo,
    required int interval,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
        ),
        title: Text(
          'Check Last Service',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
            fontSize: 16,
          ),
        ),
        content: Text(
          'That is ${ServiceScheduleStatusFormatter.formatNumber(kmAgo)} km ago, much longer than the usual ${ServiceScheduleStatusFormatter.formatNumber(interval)} km. Is that right?',
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: AppColors.darkCharcoal,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Let me fix it',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: AppColors.tacticalOrangeDark,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tacticalOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusTile - 4),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Yes, keep it',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    if (_bike == null) return;
    final bikeId = _bike!.id;
    final bikeOdo = _bike!.odometerKm.toDouble();

    // 1. Validation check across all enabled items
    for (final item in _items) {
      if (!item.enabled) continue;
      final error = item.validateLastDone(bikeOdo);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.displayName}: $error'),
            backgroundColor: AppColors.alertRed,
          ),
        );
        return;
      }
    }

    // 2. Sanity warning check: trigger confirmation if result is >3x interval in the past
    for (final item in _items) {
      if (!item.enabled) continue;
      final rawKm = int.tryParse(item.kmController.text.trim());
      if (rawKm == null || rawKm <= 0) continue;

      final effInterval = _isHarsh ? (rawKm * 0.80).round() : rawKm;
      final lastDoneOdo = item.calculateLastDoneOdometer(bikeOdo);
      if (lastDoneOdo == null) continue;

      final kmAgo = (bikeOdo - lastDoneOdo).round();
      if (kmAgo > 3 * effInterval) {
        final confirmed = await _showSanityWarningDialog(
          kmAgo: kmAgo,
          interval: effInterval,
        );
        if (!confirmed) {
          // Rider chose "Let me fix it" -> abort save and focus the field
          item.focusNode.requestFocus();
          return;
        }
      }
    }

    await MaintenanceController.instance.setHarshConditions(bikeId, _isHarsh);
    MaintenanceController.instance.setCarburetorOverride(bikeId, _hasCarburetorOverride);

    final updatedItems = <ServiceScheduleItem>[];
    for (final item in _items) {
      final kmText = item.kmController.text.trim();
      final monthText = item.monthController.text.trim();

      final intervalKm = int.tryParse(kmText);
      final intervalMonths = int.tryParse(monthText);
      // ALWAYS store the service ODOMETER, never "km ago"
      final lastDoneKm = item.calculateLastDoneOdometer(bikeOdo);
      final lastDoneDate = item.lastDoneDate;

      updatedItems.add(ServiceScheduleItem(
        id: item.id,
        bikeId: bikeId,
        type: item.type,
        customTitle: item.customTitle,
        intervalKm: intervalKm,
        intervalMonths: intervalMonths,
        lastDoneKm: lastDoneKm,
        lastDoneDate: lastDoneDate,
        enabled: item.enabled,
        updatedAt: DateTime.now().toUtc(),
      ));
    }

    try {
      await MaintenanceController.instance.saveSchedule(bikeId, updatedItems);
    } catch (_) {
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service schedule saved'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.statusGreen,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _showAddCustomItemDialog() {
    final nameCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.clay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
        ),
        title: Text(
          'Add Custom Service Item',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Service item name',
            hintText: 'e.g. Fork Oil, Coolant, Brake Fluid',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusTile - 4),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(color: AppColors.mutedText, fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tacticalOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              final newItem = _ScheduleItemFormData(
                id: 'sched_${_bike!.id}_custom_${DateTime.now().millisecondsSinceEpoch}',
                type: ServiceItemType.custom,
                customTitle: name,
                enabled: true,
                kmController: TextEditingController(),
                monthController: TextEditingController(),
                lastDoneController: TextEditingController(),
                mode: LastDoneInputMode.kmAgo,
                focusNode: FocusNode(),
              );
              setState(() {
                _itemKeys[newItem.id] = GlobalKey();
                _items.add(newItem);
              });
            },
            child: Text(
              'Add Item',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bike == null) {
      return Scaffold(
        backgroundColor: AppColors.clay,
        appBar: CampAppBar(
          leading: CampAppBarLeading.back,
          onLeadingPressed: () => Navigator.of(context).pop(),
          actionText: 'SERVICE SCHEDULE',
        ),
        body: const Center(child: Text('No active motorcycle selected')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.clay,
      body: SafeArea(
        child: Column(
          children: [
            CampAppBar(
              leading: CampAppBarLeading.back,
              onLeadingPressed: () => Navigator.of(context).pop(),
              actionText: 'SERVICE SCHEDULE',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Bike Context Banner
                    _buildBikeHeader(_bike!),
                    const SizedBox(height: 14),

                    // Harsh Conditions Switch
                    _buildHarshConditionsCard(),
                    const SizedBox(height: 14),

                    // Carburetor Toggle (only shown when bike is not natively carbureted)
                    if (_bike!.fuelSystem != FuelSystem.carburetor) ...[
                      _buildCarburetorSwitchCard(),
                      const SizedBox(height: 14),
                    ],

                    // Section Header
                    Text(
                      'SCHEDULE INTERVALS',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mutedText,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // One row / card per service item
                    ..._items.map((item) => Padding(
                          key: _itemKeys[item.id],
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildItemCard(item),
                        )),

                    // Add Custom Item Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.tacticalOrange, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusTile),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, color: AppColors.tacticalOrange),
                      label: Text(
                        'Add Custom Service Item',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tacticalOrangeDark,
                        ),
                      ),
                      onPressed: _showAddCustomItemDialog,
                    ),

                    const SizedBox(height: 20),

                    // Save Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tacticalOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusTile),
                        ),
                        elevation: 4,
                      ),
                      onPressed: _save,
                      child: Text(
                        'Save Schedule',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBikeHeader(Bike bike) {
    return CampCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.clayDark,
              borderRadius: BorderRadius.circular(AppColors.radiusTile),
              boxShadow: AppColors.skeuRecessed,
            ),
            child: const Icon(
              Icons.two_wheeler_rounded,
              color: AppColors.tacticalOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${bike.make} ${bike.modelName}',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                Text(
                  'Odometer: ${ServiceScheduleStatusFormatter.formatNumber(bike.odometerKm)} km • ${_isHarsh ? "Harsh Conditions ON (-20%)" : "Standard Conditions"}',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHarshConditionsCard() {
    return CampCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.tacticalOrange,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Harsh conditions',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                Text(
                  'Dust, heat, off-road, heavy traffic (shortens intervals by 20%)',
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isHarsh,
            activeThumbColor: AppColors.tacticalOrange,
            onChanged: (val) {
              setState(() {
                _isHarsh = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCarburetorSwitchCard() {
    return CampCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.speed_rounded,
            color: AppColors.terracotta,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My bike has a carburetor',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                Text(
                  'Enables carburetor service and jetting tracking',
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _hasCarburetorOverride,
            activeThumbColor: AppColors.tacticalOrange,
            onChanged: (val) {
              setState(() {
                _hasCarburetorOverride = val;
              });
            },
          ),
        ],
      ),
    );
  }

  String _formatKm(int km) => ServiceScheduleStatusFormatter.formatNumber(km);

  String _getKmLabel(ServiceItemType type) {
    switch (type) {
      case ServiceItemType.oilAndSmallService:
        return 'Change oil every (km)';
      case ServiceItemType.oilFilter:
        return 'Change oil filter every (km)';
      case ServiceItemType.airFilter:
        return 'Clean or replace every (km)';
      case ServiceItemType.chain:
        return 'Clean and lube every (km)';
      case ServiceItemType.sparkPlug:
        return 'Check or replace every (km)';
      case ServiceItemType.tuning:
        return 'Full tuning every (km)';
      case ServiceItemType.brakes:
        return 'Check brake pads every (km)';
      case ServiceItemType.rearBrakes:
        return 'Check rear brake shoes/pads every (km)';
      case ServiceItemType.tyres:
        return 'Check tyres every (km)';
      case ServiceItemType.carburetor:
        return 'Clean or adjust every (km)';
      case ServiceItemType.battery:
        return 'Check battery every (months)';
      case ServiceItemType.custom:
        return 'Service every (km)';
    }
  }

  String _getKmHelperText(ServiceItemType type) {
    switch (type) {
      case ServiceItemType.oilAndSmallService:
        return 'Distance between oil changes, e.g. 1,500 km';
      case ServiceItemType.oilFilter:
        return 'Distance between oil filter changes';
      case ServiceItemType.airFilter:
        return 'Distance between air filter services';
      case ServiceItemType.chain:
        return 'Distance between chain cleaning and lubing';
      case ServiceItemType.sparkPlug:
        return 'Distance between spark plug checks';
      case ServiceItemType.tuning:
        return 'Distance between full tune-ups, e.g. 10,000 km';
      case ServiceItemType.brakes:
        return 'Distance between brake checks';
      case ServiceItemType.rearBrakes:
        return 'Distance between rear brake checks';
      case ServiceItemType.tyres:
        return 'Distance between tyre checks';
      case ServiceItemType.carburetor:
        return 'Distance between carburetor services';
      case ServiceItemType.battery:
        return 'Time between battery checks';
      case ServiceItemType.custom:
        return 'Distance between services';
    }
  }

  String _getMonthsLabel(ServiceItemType type) {
    switch (type) {
      case ServiceItemType.oilAndSmallService:
      case ServiceItemType.oilFilter:
        return 'Or change every (months)';
      case ServiceItemType.airFilter:
        return 'Or clean or replace every (months)';
      case ServiceItemType.chain:
        return 'Or clean and lube every (months)';
      case ServiceItemType.sparkPlug:
        return 'Or check or replace every (months)';
      case ServiceItemType.tuning:
        return 'Or tune every (months)';
      case ServiceItemType.brakes:
      case ServiceItemType.rearBrakes:
      case ServiceItemType.tyres:
        return 'Or check every (months)';
      case ServiceItemType.carburetor:
        return 'Or clean or adjust every (months)';
      case ServiceItemType.battery:
        return 'Check battery every (months)';
      case ServiceItemType.custom:
        return 'Or service every (months)';
    }
  }

  Widget _buildItemCard(_ScheduleItemFormData item) {
    final type = item.type;
    final enabled = item.enabled;
    final kmController = item.kmController;
    final monthController = item.monthController;
    final lastDoneController = item.lastDoneController;
    final lastDate = item.lastDoneDate;
    final isCustom = type == ServiceItemType.custom;
    final bikeOdo = _bike?.odometerKm.toDouble() ?? 0.0;
    final bool hasBikeOdometer = bikeOdo > 0;

    // Compute effective interval text transparently for km field
    final rawKm = int.tryParse(kmController.text.trim());
    final bool isHarshActive = _isHarsh && rawKm != null && rawKm > 0;
    final String kmHelperText;
    if (isHarshActive) {
      final effectiveKm = (rawKm * 0.80).round();
      kmHelperText = '${_formatKm(rawKm)} km -> ${_formatKm(effectiveKm)} km (harsh conditions)';
    } else {
      kmHelperText = _getKmHelperText(type);
    }

    final match = _bike != null
        ? MaintenanceController.instance.findLastLoggedService(_bike!.id, type)
        : null;

    final isBattery = type == ServiceItemType.battery;

    // Evaluate live status for this card
    final effLastDoneOdo = item.calculateLastDoneOdometer(bikeOdo);
    final tempItem = ServiceScheduleItem(
      id: item.id,
      bikeId: _bike!.id,
      type: item.type,
      customTitle: item.customTitle,
      intervalKm: rawKm,
      intervalMonths: int.tryParse(monthController.text.trim()),
      lastDoneKm: effLastDoneOdo,
      lastDoneDate: lastDate,
      enabled: enabled,
    );
    final tempPrediction = ServiceScheduleEngine.evaluateItem(
      item: tempItem,
      currentOdometerKm: bikeOdo,
      isHarshConditions: _isHarsh,
      recentReports: const [],
    );
    final friendlyStatus = ServiceScheduleStatusFormatter.format(tempPrediction);

    // Dynamic conversion subtitle under the last done field
    String? conversionText;
    if (item.mode == LastDoneInputMode.kmAgo) {
      if (!hasBikeOdometer) {
        conversionText = 'Add your bike\'s odometer first';
      } else {
        final parsed = double.tryParse(lastDoneController.text.trim());
        if (parsed != null && parsed >= 0) {
          final doneOdo = (bikeOdo - parsed).round();
          conversionText = 'Done at ${_formatKm(doneOdo)} km';
        }
      }
    }

    final lastDoneError = item.validateLastDone(bikeOdo);

    return CampCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Icon, Name, and Enable Switch
          Row(
            children: [
              Icon(type.icon, color: AppColors.tacticalOrange, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.displayName,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkCharcoal,
                  ),
                ),
              ),
              if (isCustom)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.alertRed, size: 20),
                  onPressed: () {
                    setState(() {
                      _items.remove(item);
                      item.dispose();
                    });
                  },
                ),
              Switch.adaptive(
                value: enabled,
                activeThumbColor: AppColors.tacticalOrange,
                onChanged: (val) {
                  setState(() {
                    item.enabled = val;
                  });
                },
              ),
            ],
          ),

          if (enabled) ...[
            const Divider(height: 20, color: AppColors.clayDark),

            // Friendly Status Banner (Unified across all 4 surfaces)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: friendlyStatus.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppColors.radiusTile - 4),
                border: Border.all(
                  color: friendlyStatus.color.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: friendlyStatus.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friendlyStatus.headline,
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: friendlyStatus.color == AppColors.statusGreen
                                ? AppColors.darkCharcoal
                                : friendlyStatus.color,
                          ),
                        ),
                        if (friendlyStatus.detail != null &&
                            !friendlyStatus.headline.contains(friendlyStatus.detail!)) ...[
                          const SizedBox(height: 2),
                          Text(
                            friendlyStatus.detail!,
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (friendlyStatus.actionLabel != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        item.focusNode.requestFocus();
                      },
                      child: Text(
                        friendlyStatus.actionLabel!,
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.alertRed,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (isBattery) ...[
              // Battery: single time-based interval
              Text(
                _getMonthsLabel(type),
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: monthController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. 6 (optional)',
                  hintStyle: GoogleFonts.manrope(fontSize: 13, color: AppColors.mutedLight),
                  suffixText: 'months',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusTile - 4),
                    borderSide: const BorderSide(color: AppColors.clayDark),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              Text(
                'Time between battery checks',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedText,
                ),
              ),
              const SizedBox(height: 8),

              // Quick Pick Month Chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: type.quickMonthSuggestions.map((months) {
                  return ActionChip(
                    label: Text('$months mo'),
                    labelStyle: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkCharcoal,
                    ),
                    backgroundColor: AppColors.clayDark,
                    onPressed: () {
                      monthController.text = months.toString();
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
            ] else ...[
              // Distance Interval Section
              Text(
                _getKmLabel(type),
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: kmController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. 1500 (optional)',
                  hintStyle: GoogleFonts.manrope(fontSize: 13, color: AppColors.mutedLight),
                  suffixText: 'km',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusTile - 4),
                    borderSide: const BorderSide(color: AppColors.clayDark),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              Text(
                kmHelperText,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: isHarshActive ? FontWeight.w700 : FontWeight.w600,
                  color: isHarshActive ? AppColors.tacticalOrangeDark : AppColors.mutedText,
                ),
              ),
              const SizedBox(height: 8),

              // Quick Pick KM Chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: type.quickKmSuggestions.map((suggestedKm) {
                  return ActionChip(
                    label: Text('$suggestedKm km'),
                    labelStyle: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkCharcoal,
                    ),
                    backgroundColor: AppColors.clayDark,
                    onPressed: () {
                      kmController.text = suggestedKm.toString();
                      setState(() {});
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),

              // Time Interval Section
              Text(
                _getMonthsLabel(type),
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: monthController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. 6 (optional)',
                  hintStyle: GoogleFonts.manrope(fontSize: 13, color: AppColors.mutedLight),
                  suffixText: 'months',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusTile - 4),
                    borderSide: const BorderSide(color: AppColors.clayDark),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              Text(
                'Optional. Reminds you by time too. Whichever comes first counts. Leave empty to track by km only.',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedText,
                ),
              ),
              const SizedBox(height: 8),

              // Quick Pick Month Chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: type.quickMonthSuggestions.map((months) {
                  return ActionChip(
                    label: Text('$months mo'),
                    labelStyle: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkCharcoal,
                    ),
                    backgroundColor: AppColors.clayDark,
                    onPressed: () {
                      monthController.text = months.toString();
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),

            // ── Last Done Section with Segmented Control ──────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.clayDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppColors.radiusTile),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'When did you last do this?',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      if (match != null)
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            if (match.km != null) {
                              item.mode = LastDoneInputMode.odometer;
                              lastDoneController.text = match.km!.round().toString();
                            }
                            if (match.date != null) {
                              item.lastDoneDate = match.date;
                            }
                            setState(() {});
                          },
                          child: Text(
                            'Use last logged service',
                            style: GoogleFonts.manrope(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.tacticalOrangeDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Segmented control: "About __ km ago" / "At odometer __ km"
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.clay,
                      borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: hasBikeOdometer
                                ? () {
                                    if (item.mode != LastDoneInputMode.kmAgo) {
                                      // Convert currently typed odometer to km ago if valid
                                      final curVal = double.tryParse(lastDoneController.text.trim());
                                      if (curVal != null && curVal <= bikeOdo && curVal >= 0) {
                                        lastDoneController.text = (bikeOdo - curVal).round().toString();
                                      } else {
                                        lastDoneController.clear();
                                      }
                                      setState(() {
                                        item.mode = LastDoneInputMode.kmAgo;
                                      });
                                    }
                                  }
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Add your bike\'s odometer first'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                            borderRadius: BorderRadius.circular(AppColors.radiusPill),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: item.mode == LastDoneInputMode.kmAgo
                                    ? AppColors.tacticalOrange
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppColors.radiusPill),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'About __ km ago',
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: item.mode == LastDoneInputMode.kmAgo
                                      ? Colors.white
                                      : (hasBikeOdometer ? AppColors.darkCharcoal : AppColors.mutedLight),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (item.mode != LastDoneInputMode.odometer) {
                                // Convert currently typed km ago to odometer reading
                                final curVal = double.tryParse(lastDoneController.text.trim());
                                if (curVal != null && curVal >= 0 && hasBikeOdometer && curVal <= bikeOdo) {
                                  lastDoneController.text = (bikeOdo - curVal).round().toString();
                                } else {
                                  lastDoneController.clear();
                                }
                                setState(() {
                                  item.mode = LastDoneInputMode.odometer;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(AppColors.radiusPill),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: item.mode == LastDoneInputMode.odometer
                                    ? AppColors.tacticalOrange
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppColors.radiusPill),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'At odometer __ km',
                                style: GoogleFonts.manrope(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: item.mode == LastDoneInputMode.odometer
                                      ? Colors.white
                                      : AppColors.darkCharcoal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Input Row: Km / Odometer Field + Date Picker
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: lastDoneController,
                              focusNode: item.focusNode,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              enabled: !(item.mode == LastDoneInputMode.kmAgo && !hasBikeOdometer),
                              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                labelText: item.mode == LastDoneInputMode.kmAgo
                                    ? 'Km since you did it'
                                    : 'Odometer when last changed (km)',
                                labelStyle: GoogleFonts.manrope(fontSize: 12),
                                hintText: (item.mode == LastDoneInputMode.kmAgo && !hasBikeOdometer)
                                    ? 'Add your bike\'s odometer first'
                                    : 'e.g. 250',
                                errorText: lastDoneError,
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppColors.radiusTile - 4),
                                  borderSide: const BorderSide(color: AppColors.clayDark),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            if (conversionText != null) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Text(
                                  conversionText,
                                  style: GoogleFonts.manrope(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: (item.mode == LastDoneInputMode.kmAgo && !hasBikeOdometer)
                                        ? AppColors.alertRed
                                        : AppColors.tacticalOrangeDark,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: lastDate ?? now,
                              firstDate: DateTime(2000),
                              lastDate: now,
                            );
                            if (picked != null) {
                              setState(() {
                                item.lastDoneDate = picked;
                              });
                            }
                          },
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppColors.radiusTile - 4),
                              border: Border.all(color: AppColors.clayDark),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.mutedText),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    lastDate != null
                                        ? '${lastDate.day}/${lastDate.month}/${lastDate.year}'
                                        : 'Date',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: lastDate != null ? AppColors.darkCharcoal : AppColors.mutedLight,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
