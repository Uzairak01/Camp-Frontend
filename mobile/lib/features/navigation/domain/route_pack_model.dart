import 'package:flutter/material.dart';

/// Status of a route pack.
enum RoutePackStatus {
  comingSoon,
  saved,
  downloading,
  available,
}

/// Action button type on a pack card.
enum RoutePackActionType {
  none,
  syncUpdate,
  pause,
  download,
}

/// Data model representing a route pack.
/// Conforms to CAMP honesty rules: no unbacked offline coverage, Alps, or Cascades claims.
class RoutePack {
  const RoutePack({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    this.sizeMb = 0,
    this.status = RoutePackStatus.comingSoon,
    this.statusLabel,
    this.downloadProgress,
    this.downloadedMb,
    this.downloadSpeed,
    this.note,
    this.noteIcon,
    this.actionType = RoutePackActionType.none,
    this.actionLabel,
  });

  final String id;
  final String title;
  final int sizeMb;
  final String category;
  final String description;
  final RoutePackStatus status;
  final String? statusLabel;
  final double? downloadProgress;
  final int? downloadedMb;
  final String? downloadSpeed;
  final String? note;
  final IconData? noteIcon;
  final RoutePackActionType actionType;
  final String? actionLabel;

  /// Default 5 route packs per CAMP design specification (honest, no unbacked claims)
  static const List<RoutePack> defaultPacks = [
    // a. Karakoram Highway (KKH)
    RoutePack(
      id: 'kkh',
      title: 'Karakoram Highway (KKH)',
      category: 'Mountain Corridor',
      description:
          'High-altitude mountain highway corridor with terrain waypoints and pass crossings.',
      status: RoutePackStatus.comingSoon,
    ),

    // b. Babusar Pass & Kaghan
    RoutePack(
      id: 'babusar',
      title: 'Babusar Pass & Kaghan',
      category: 'Mountain Passes',
      description:
          'Glacial valley ascent, alpine ridge tracks, and valley waypoints.',
      status: RoutePackStatus.comingSoon,
    ),

    // c. Makran Coastal Highway
    RoutePack(
      id: 'makran',
      title: 'Makran Coastal Highway',
      category: 'Coastal Highway',
      description:
          'Coastal highway routes, rock formation markers, and fuel stop waypoints.',
      status: RoutePackStatus.comingSoon,
    ),

    // d. Cholistan Desert Rally Route
    RoutePack(
      id: 'cholistan',
      title: 'Cholistan Desert Rally Route',
      category: 'Desert Trail & Navigational Grid',
      description:
          'Dune navigational tracks, historic fort waypoints, and rally checkpoint grid.',
      status: RoutePackStatus.comingSoon,
    ),

    // e. Deosai Plains Plateau
    RoutePack(
      id: 'deosai',
      title: 'Deosai Plains Plateau',
      category: 'High Altitude Plateau',
      description:
          'High altitude plateau tracks, river crossings, and wilderness trails.',
      status: RoutePackStatus.comingSoon,
    ),
  ];
}
