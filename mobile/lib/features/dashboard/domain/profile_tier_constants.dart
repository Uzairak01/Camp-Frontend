import 'package:flutter/material.dart';

/// Single tier level definition with threshold distance.
class ProfileTier {
  const ProfileTier({
    required this.level,
    required this.name,
    required this.thresholdKm,
  });

  final int level;
  final String name;
  final double thresholdKm;

  String get displayName => 'Level $level: $name';
}

/// Constants for Rider Tiers and Badges based on real riding totals.
class ProfileTierConstants {
  const ProfileTierConstants._();

  static const List<ProfileTier> tiers = [
    ProfileTier(level: 1, name: 'Rookie', thresholdKm: 0),
    ProfileTier(level: 2, name: 'Explorer', thresholdKm: 500),
    ProfileTier(level: 3, name: 'Road Warrior', thresholdKm: 2000),
    ProfileTier(level: 4, name: 'Master Explorer', thresholdKm: 5000),
    ProfileTier(level: 5, name: 'Legend', thresholdKm: 10000),
  ];

  static const double topTierThresholdKm = 10000.0;
}

/// Badge definition containing identifier, title, requirement, and icon.
class ProfileBadgeDefinition {
  const ProfileBadgeDefinition({
    required this.id,
    required this.title,
    required this.requirementText,
    required this.icon,
  });

  final String id;
  final String title;
  final String requirementText;
  final IconData icon;
}

/// Computed badge with its unlock state.
class ProfileBadge {
  const ProfileBadge({
    required this.definition,
    required this.isUnlocked,
  });

  final ProfileBadgeDefinition definition;
  final bool isUnlocked;

  String get id => definition.id;
  String get title => definition.title;
  String get requirementText => definition.requirementText;
  IconData get icon => definition.icon;
}

class ProfileBadgeConstants {
  const ProfileBadgeConstants._();

  static const ProfileBadgeDefinition firstRide = ProfileBadgeDefinition(
    id: 'first_ride',
    title: 'First Ride',
    requirementText: '1 ride completed',
    icon: Icons.two_wheeler_rounded,
  );

  static const ProfileBadgeDefinition club100 = ProfileBadgeDefinition(
    id: 'club_100',
    title: '100 km Club',
    requirementText: '100 km lifetime distance',
    icon: Icons.speed_rounded,
  );

  static const ProfileBadgeDefinition club500 = ProfileBadgeDefinition(
    id: 'club_500',
    title: '500 km Club',
    requirementText: '500 km lifetime distance',
    icon: Icons.explore_rounded,
  );

  static const ProfileBadgeDefinition club1000 = ProfileBadgeDefinition(
    id: 'club_1000',
    title: '1,000 km Club',
    requirementText: '1,000 km lifetime distance',
    icon: Icons.military_tech_rounded,
  );

  static const ProfileBadgeDefinition longHaul = ProfileBadgeDefinition(
    id: 'long_haul',
    title: 'Long Haul',
    requirementText: 'One ride of 100 km or more',
    icon: Icons.route_rounded,
  );

  static const ProfileBadgeDefinition tenRides = ProfileBadgeDefinition(
    id: 'ten_rides',
    title: 'Ten Rides',
    requirementText: '10 rides completed',
    icon: Icons.workspace_premium_rounded,
  );

  static const List<ProfileBadgeDefinition> allBadges = [
    firstRide,
    club100,
    club500,
    club1000,
    longHaul,
    tenRides,
  ];
}
