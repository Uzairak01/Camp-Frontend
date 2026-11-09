import 'dart:math';
import 'package:flutter/foundation.dart';

import '../../garage/domain/bike_model.dart';
import '../controllers/maintenance_controller.dart';
import 'post_ride_report.dart';
import 'service_schedule_engine.dart';
import 'service_schedule_item.dart';

/// Health status classification for individual motorcycle components.
enum ComponentStatus {
  ok,
  dueSoon,
  overdue,
}

/// Computed wear and health prediction for a specific motorcycle component.
/// Fully derived from user-entered odometer readings, service records, and terrain profiles.
@immutable
class ComponentPrediction {
  const ComponentPrediction({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.wearPercent,
    required this.status,
    required this.reason,
    required this.remainingKm,
    required this.diyGuideTitle,
    required this.diySteps,
    this.remainingDays,
    this.scheduleStatus = ScheduleItemStatus.ok,
  });

  final String id;
  final String name;
  final String subtitle;
  final int wearPercent;
  final ComponentStatus status;
  final String reason;
  final int remainingKm;
  final int? remainingDays;
  final String diyGuideTitle;
  final List<String> diySteps;
  final ScheduleItemStatus scheduleStatus;

  /// Component health score (0-100, where 100 is brand new).
  int get healthScore => (100 - wearPercent).clamp(0, 100);

  /// Status badge label for the component.
  /// Replaces arbitrary "0% Wear" chips with honest "Up to date" status.
  String get statusBadgeText {
    if (scheduleStatus == ScheduleItemStatus.notSetUp) {
      return 'Not set up';
    }
    if (scheduleStatus == ScheduleItemStatus.addLastDone) {
      return 'Interval configured';
    }
    if (wearPercent <= 0) {
      return 'Up to date';
    }
    return '$wearPercent% Wear';
  }
}

/// Explainable pattern insight derived from user-logged post-ride debriefs.
@immutable
class RidePatternInsight {
  const RidePatternInsight({
    required this.title,
    required this.percentageBadge,
    required this.description,
    required this.recommendation,
  });

  final String title;
  final String percentageBadge;
  final String description;
  final String recommendation;
}

/// Complete predictive maintenance assessment result.
@immutable
class MaintenanceAssessment {
  const MaintenanceAssessment({
    required this.healthIndex,
    required this.healthStatusLabel,
    required this.nextServiceKm,
    required this.nextServiceDays,
    required this.components,
    required this.patternInsights,
    required this.hasSufficientRideLogs,
    required this.totalRideLogsCount,
  });

  /// Single aggregate Maintenance Health Index (0-100).
  final int healthIndex;

  /// Health descriptor: 'OPTIMAL', 'ATTENTION', or 'SERVICE DUE'.
  final String healthStatusLabel;

  /// Estimated distance remaining until the soonest component hits service threshold.
  final int nextServiceKm;

  /// Estimated days remaining until the soonest component hits service threshold.
  final int nextServiceDays;

  /// 4 analyzed components sorted by highest wear first.
  final List<ComponentPrediction> components;

  /// Computed pattern insights based on logged PostRideReports.
  final List<RidePatternInsight> patternInsights;

  /// True if at least 3 post-ride reports exist for the active bike.
  final bool hasSufficientRideLogs;

  /// Total number of post-ride reports evaluated.
  final int totalRideLogsCount;
}

/// Deterministic, software-based prediction engine.
/// Computes wear percentages, service timelines, and ride pattern insights
/// strictly from user inputs (odometer, service records, riding terrain, and post-ride logs).
/// Free of sensor, OBD-II, or ECU dependencies.
class MaintenancePredictionEngine {
  const MaintenancePredictionEngine._();

  /// Calculate the complete maintenance assessment for a given motorcycle and its ride logs.
  /// Fully derived from the rider's configured service schedule, with NO modulo wear and NO fixed interval table.
  static MaintenanceAssessment analyze({
    required Bike bike,
    required List<PostRideReport> rideReports,
  }) {
    final schedulePredictions = MaintenanceController.instance.itemsForBike(bike);

    // Map each schedule prediction to a ComponentPrediction
    final components = <ComponentPrediction>[];
    for (final sp in schedulePredictions) {
      final comp = _predictionToComponent(sp, bike);
      components.add(comp);
    }

    // Sort by highest wear first (most urgent at the top)
    components.sort((a, b) => b.wearPercent.compareTo(a.wearPercent));

    // Weighted Maintenance Health Index (0-100) based on configured components
    final configured = components.where((c) => c.wearPercent > 0 || c.remainingKm > 0).toList();
    final int healthIndex;
    if (configured.isEmpty) {
      healthIndex = 100;
    } else {
      final totalScore = configured.fold<int>(0, (sum, c) => sum + c.healthScore);
      healthIndex = (totalScore / configured.length).round().clamp(0, 100);
    }

    final String healthStatusLabel;
    if (healthIndex >= 80) {
      healthStatusLabel = 'OPTIMAL';
    } else if (healthIndex >= 60) {
      healthStatusLabel = 'ATTENTION';
    } else {
      healthStatusLabel = 'SERVICE DUE';
    }

    // Soonest service due estimation
    var soonestKm = 0;
    var soonestDays = 0;
    final dueOrConfigured = components.where((c) => c.remainingKm > 0).toList();
    if (dueOrConfigured.isNotEmpty) {
      soonestKm = dueOrConfigured.first.remainingKm;
      soonestDays = dueOrConfigured.first.remainingDays ?? max(1, (soonestKm / 35).round());
      for (final c in dueOrConfigured) {
        if (c.remainingKm < soonestKm) {
          soonestKm = c.remainingKm;
          soonestDays = c.remainingDays ?? max(1, (c.remainingKm / 35).round());
        }
      }
    }

    // ── Phase 3: Real Pattern Insights from Logged PostRideReports ──────────
    final patternInsights = _computePatternInsights(rideReports);
    final hasSufficientLogs = rideReports.length >= 3;

    return MaintenanceAssessment(
      healthIndex: healthIndex,
      healthStatusLabel: healthStatusLabel,
      nextServiceKm: soonestKm,
      nextServiceDays: soonestDays,
      components: components,
      patternInsights: patternInsights,
      hasSufficientRideLogs: hasSufficientLogs,
      totalRideLogsCount: rideReports.length,
    );
  }

  static ComponentPrediction _predictionToComponent(
    ServiceSchedulePrediction sp,
    Bike bike,
  ) {
    final name = sp.name;
    final status = sp.status;
    final wear = sp.wearPercent;
    final remainingKm = sp.remainingKm ?? 0;
    final remainingDays = sp.remainingDays;

    final String reason;
    if (sp.scheduleStatus == ScheduleItemStatus.notSetUp) {
      reason = 'Service schedule not set up. Add when you last did this to get reminders.';
    } else if (sp.scheduleStatus == ScheduleItemStatus.addLastDone) {
      reason = 'Interval configured. Add last done reading to start tracking wear. Add when you last did this to get reminders.';
    } else {
      reason = sp.friendlyStatus.headline;
    }

    final guideData = _guideForType(sp.type);

    return ComponentPrediction(
      id: sp.item.type.canonicalId,
      name: name,
      subtitle: bike.displacement != null ? '${bike.displacement}cc Spec' : 'Rider Spec',
      wearPercent: wear,
      status: status,
      reason: reason,
      remainingKm: max(0, remainingKm),
      remainingDays: remainingDays,
      diyGuideTitle: guideData.$1,
      diySteps: guideData.$2,
      scheduleStatus: sp.scheduleStatus,
    );
  }

  static (String, List<String>) _guideForType(ServiceItemType type) {
    switch (type) {
      case ServiceItemType.oilAndSmallService:
        return (
          'Engine Oil & Small Service',
          const [
            'Warm engine for 3-5 minutes to circulate suspended particles.',
            'Place catch-pan under crankcase drain bolt; remove bolt with calibrated hex socket.',
            'Remove old oil filter; lubricate rubber O-ring of new filter before installation.',
            'Torque drain bolt with new crush washer to factory specification.',
            'Refill with manufacturer-recommended viscosity oil and verify sight glass.',
          ],
        );
      case ServiceItemType.oilFilter:
        return (
          'Oil Filter Replacement',
          const [
            'Place drip tray under oil filter housing.',
            'Unscrew old oil filter cartridge or cap.',
            'Inspect rubber seals and replace O-rings.',
            'Lubricate gasket with fresh oil and spin on until hand-tight plus half turn.',
          ],
        );
      case ServiceItemType.airFilter:
        return (
          'Air Filter Element Service',
          const [
            'Remove seat and side covers to access airbox housing.',
            'Clean exterior dust and loose sand before opening airbox lid.',
            'Extract filter element and inspect clean-air intake duct for dust bypass.',
            'Clean or replace element according to manufacturer recommendations.',
            'Reinstall airbox lid ensuring an airtight seal.',
          ],
        );
      case ServiceItemType.chain:
        return (
          'Drive Chain Tension & Lubrication',
          const [
            'Place motorcycle on center-stand or rear stand on level ground.',
            'Measure bottom chain run vertical deflection halfway between sprockets.',
            'Adjust swingarm tension bolts evenly if slack exceeds specification.',
            'Inspect sprocket teeth for shark-fin wear or chipping.',
            'Clean chain thoroughly and apply high-quality chain lubricant.',
          ],
        );
      case ServiceItemType.sparkPlug:
        return (
          'Spark Plug Inspection & Gap Check',
          const [
            'Disconnect spark plug cap and blow compressed air around cylinder head recess.',
            'Remove spark plug using magnetic thin-wall plug socket.',
            'Inspect electrode color: light tan indicates correct stoichiometric combustion.',
            'Verify gap with wire feeler gauge; replace if electrode is eroded.',
            'Thread plug by hand to prevent cross-threading before final torque.',
          ],
        );
      case ServiceItemType.tuning:
        return (
          'Engine Tuning & Valve Clearance Check',
          const [
            'Ensure engine is stone cold before checking valve lash clearances.',
            'Remove valve inspection caps and align crankshaft to Top Dead Center (TDC).',
            'Slide feeler gauge between rocker arm and valve stem.',
            'Adjust tappet screw to factory clearance and snug locknut.',
            'Reassemble inspection caps with fresh O-rings.',
          ],
        );
      case ServiceItemType.brakes:
        return (
          'Brake Pad Thickness & Fluid Inspection',
          const [
            'Inspect pad friction material thickness through caliper inspection window.',
            'Check brake fluid reservoir level and color through inspection glass.',
            'If pads are near minimum thickness, unbolt caliper retaining pins and replace.',
            'Clean caliper pistons before retracting to avoid seal damage.',
            'Pump brake lever until firm hydraulic pressure is restored.',
          ],
        );
      case ServiceItemType.rearBrakes:
        return (
          'Rear Brake Inspection & Adjustment',
          const [
            'Inspect rear brake shoe wear indicator or pad thickness.',
            'Check rear brake pedal height and free play.',
            'Inspect brake rod, return spring, and stop switch linkage.',
            'Clean brake drum/disc and verify smooth stopping action.',
          ],
        );
      case ServiceItemType.custom:
        return (
          'Custom Maintenance Inspection',
          const [
            'Inspect component for wear, damage, or loose mounting hardware.',
            'Follow manufacturer recommendations for inspection or replacement.',
            'Record notes and odometer reading.',
          ],
        );
      case ServiceItemType.tyres:
        return (
          'Tyre Pressure & Tread Depth Inspection',
          const [
            'Check cold tyre inflation pressures with an accurate gauge.',
            'Inspect tread depth against wear indicators (TWI).',
            'Examine sidewalls for cracks, embedded sharp debris, or bulges.',
            'Verify valve stems are capped and undamaged.',
          ],
        );
      case ServiceItemType.battery:
        return (
          'Battery Terminals & Voltage Check',
          const [
            'Inspect positive and negative terminal posts for corrosion or white sulfates.',
            'Clean posts with a wire brush and apply dielectric grease.',
            'Verify resting voltage: 12.6V+ indicates a healthy charge.',
            'Start engine and verify charging system output: 13.8V - 14.5V.',
          ],
        );
      case ServiceItemType.carburetor:
        return (
          'Carburetor Jetting & Slide Service',
          const [
            'Turn fuel petcock off and drain float bowl into catch container.',
            'Inspect fuel strainer and clear any sediment or debris.',
            'Remove throttle slide and inspect diaphragm for tears or pinholes.',
            'Verify jet sizing and clean pilot and main jets with carb cleaner.',
            'Check idle speed and pilot mixture screw baseline turns.',
          ],
        );
    }
  }

  // ── Phase 3: Real Pattern Insights Computation ───────────────────────────
  static List<RidePatternInsight> _computePatternInsights(
    List<PostRideReport> reports,
  ) {
    if (reports.length < 3) return const [];

    final recentReports = reports.take(5).toList();
    final total = recentReports.length;

    final offRoadRides = recentReports.where((r) => r.terrainTags.contains('Off-road')).length;
    final offRoadPercent = ((offRoadRides / total) * 100).round();

    final mountainRides = recentReports.where((r) => r.terrainTags.contains('Mountain')).length;
    final mountainPercent = ((mountainRides / total) * 100).round();

    final insights = <RidePatternInsight>[];

    if (offRoadRides > 0) {
      insights.add(
        RidePatternInsight(
          title: 'Chain Wear Accelerating',
          percentageBadge: '$offRoadPercent% Off-Road',
          description: '$offRoadRides of your last $total logged rides included off-road terrain. High silt and gravel exposure accelerates chain and sprocket wear.',
          recommendation: 'Recommend tension adjustment & synthetic lube before cresting the next long trail.',
        ),
      );
    }

    if (mountainRides > 0) {
      insights.add(
        RidePatternInsight(
          title: 'Alpine Descent & Dust Factor',
          percentageBadge: '$mountainPercent% Mountain',
          description: '$mountainRides of your last $total logged rides traversed high-altitude mountain passes with extended descents.',
          recommendation: 'Steep grades increase thermal cycling on brake pads and collect airbox silt. Check pad thickness and wipe down stanchions.',
        ),
      );
    } else if (insights.isEmpty) {
      final cityRides = recentReports.where((r) => r.terrainTags.contains('City')).length;
      final cityPercent = ((cityRides / total) * 100).round();
      insights.add(
        RidePatternInsight(
          title: 'Urban Stop-and-Go Pattern',
          percentageBadge: '$cityPercent% City',
          description: '$cityRides of your last $total logged rides were urban commutes with frequent friction stops.',
          recommendation: 'Monitor front brake pad wear and engine idle temperature.',
        ),
      );
    }

    return insights;
  }
}
