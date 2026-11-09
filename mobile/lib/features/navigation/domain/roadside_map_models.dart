import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum BreakdownSeverity {
  critical,
  high,
  moderate,
}

enum BreakdownCategory {
  flatTire,
  deadBattery,
  engineFailure,
  brokenChain,
  outOfFuel,
  towingRecovery,
}

class StrandedIncident {

  const StrandedIncident({
    required this.id,
    required this.driverName,
    required this.vehicleModel,
    required this.category,
    required this.severity,
    required this.issueDescription,
    required this.location,
    required this.distance,
    required this.eta,
    required this.phone,
    required this.timeReported,
    this.isUserReported = false,
  });
  final String id;
  final String driverName;
  final String vehicleModel;
  final BreakdownCategory category;
  final BreakdownSeverity severity;
  final String issueDescription;
  final LatLng location;
  final String distance;
  final String eta;
  final String phone;
  final String timeReported;
  final bool isUserReported;

  String get categoryLabel {
    switch (category) {
      case BreakdownCategory.flatTire:
        return 'Flat Tire / Bead Loss';
      case BreakdownCategory.deadBattery:
        return 'Dead Battery / No Crank';
      case BreakdownCategory.engineFailure:
        return 'Engine / Overheating';
      case BreakdownCategory.brokenChain:
        return 'Snapped Chain / Drive';
      case BreakdownCategory.outOfFuel:
        return 'Fuel Starvation / Dry';
      case BreakdownCategory.towingRecovery:
        return 'Ravine / Tow Recovery';
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case BreakdownCategory.flatTire:
        return Icons.tire_repair_rounded;
      case BreakdownCategory.deadBattery:
        return Icons.battery_alert_rounded;
      case BreakdownCategory.engineFailure:
        return Icons.warning_rounded;
      case BreakdownCategory.brokenChain:
        return Icons.link_off_rounded;
      case BreakdownCategory.outOfFuel:
        return Icons.local_gas_station_rounded;
      case BreakdownCategory.towingRecovery:
        return Icons.car_crash_rounded;
    }
  }

  Color get severityColor {
    switch (severity) {
      case BreakdownSeverity.critical:
        return const Color(0xFFEF4444);
      case BreakdownSeverity.high:
        return const Color(0xFFF97316);
      case BreakdownSeverity.moderate:
        return const Color(0xFFFBBF24);
    }
  }
}

class RoadsideMechanic {

  const RoadsideMechanic({
    required this.id,
    required this.name,
    required this.vehicleType,
    required this.distance,
    required this.eta,
    required this.rating,
    required this.reviews,
    required this.phone,
    required this.location,
    required this.isMobileVan,
    required this.isEmergencyVerified,
    required this.capabilities,
    required this.supportedBikes,
    required this.openHours,
  });
  final String id;
  final String name;
  final String vehicleType;
  final String distance;
  final String eta;
  final double rating;
  final int reviews;
  final String phone;
  final LatLng location;
  final bool isMobileVan;
  final bool isEmergencyVerified;
  final List<String> capabilities;
  final List<String> supportedBikes;
  final String openHours;
}

class RoadsideSupplyCache {

  const RoadsideSupplyCache({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.location,
    required this.fuelTypes,
    required this.availableTools,
    this.hasCompressor = true,
  });
  final String id;
  final String name;
  final String subtitle;
  final LatLng location;
  final String fuelTypes;
  final List<String> availableTools;
  final bool hasCompressor;
}

class RoadsideSectorDataset {

  const RoadsideSectorDataset({
    required this.mechanics,
    required this.strandedIncidents,
    required this.supplyCaches,
    required this.primaryRescueRoute,
  });
  final List<RoadsideMechanic> mechanics;
  final List<StrandedIncident> strandedIncidents;
  final List<RoadsideSupplyCache> supplyCaches;
  final List<LatLng> primaryRescueRoute;

  /// Sector dataset initialization; returns empty lists when no live verified units are in sector.
  static RoadsideSectorDataset generate(LatLng center, String sectorName) {
    return const RoadsideSectorDataset(
      mechanics: [],
      strandedIncidents: [],
      supplyCaches: [],
      primaryRescueRoute: [],
    );
  }
}
