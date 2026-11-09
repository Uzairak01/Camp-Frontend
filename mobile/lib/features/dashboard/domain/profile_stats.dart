import '../../maintenance/domain/post_ride_report.dart';
import 'profile_tier_constants.dart';

/// Pure domain class that computes rider statistics, tier advancement,
/// and earned badge states from real ride history ([PostRideReport]s).
class ProfileStats {
  ProfileStats(List<PostRideReport> reports)
      : reports = List.unmodifiable(reports);

  final List<PostRideReport> reports;

  /// Whether the rider has completed at least one ride.
  bool get hasRides => reports.isNotEmpty;

  /// Lifetime total distance in kilometers (sum of all ride distances).
  double get lifetimeDistanceKm {
    return reports.fold<double>(
      0.0,
      (sum, report) => sum + report.distanceKm,
    );
  }

  /// Total count of completed rides.
  int get ridesCount => reports.length;

  /// Total saddle time in hours computed from recorded ride durations.
  double get saddleTimeHours {
    return reports.fold<double>(
      0.0,
      (sum, report) => sum + (report.durationHours ?? 0.0),
    );
  }

  /// Longest single ride in kilometers. Returns 0.0 if no rides exist.
  double get longestSingleRideKm {
    if (reports.isEmpty) return 0.0;
    return reports
        .map((r) => r.distanceKm)
        .reduce((a, b) => a > b ? a : b);
  }

  // ── Tier Progress Calculation ─────────────────────────────────────────────

  /// Current active tier based on [lifetimeDistanceKm].
  ProfileTier get currentTier {
    final km = lifetimeDistanceKm;
    ProfileTier activeTier = ProfileTierConstants.tiers.first;
    for (final tier in ProfileTierConstants.tiers) {
      if (km >= tier.thresholdKm) {
        activeTier = tier;
      } else {
        break;
      }
    }
    return activeTier;
  }

  /// Next tier to achieve, or null if rider has reached top tier.
  ProfileTier? get nextTier {
    final current = currentTier;
    const tiers = ProfileTierConstants.tiers;
    final currentIndex = tiers.indexWhere((t) => t.level == current.level);
    if (currentIndex != -1 && currentIndex < tiers.length - 1) {
      return tiers[currentIndex + 1];
    }
    return null;
  }

  /// Whether top tier (Level 5 Legend at 10,000 km) has been achieved.
  bool get isTopTier => nextTier == null;

  /// Distance in kilometers required to reach the next tier, or 0.0 if top tier.
  double get kmToNextTier {
    final next = nextTier;
    if (next == null) return 0.0;
    final remaining = next.thresholdKm - lifetimeDistanceKm;
    return remaining > 0 ? remaining : 0.0;
  }

  /// Progress fraction (0.0 to 1.0) towards the next tier.
  double get tierProgressFraction {
    final current = currentTier;
    final next = nextTier;
    if (next == null) return 1.0;

    final span = next.thresholdKm - current.thresholdKm;
    if (span <= 0) return 1.0;

    final progressInSpan = lifetimeDistanceKm - current.thresholdKm;
    return (progressInSpan / span).clamp(0.0, 1.0);
  }

  /// Percentage (0 to 100) towards the next tier.
  int get tierProgressPercent => (tierProgressFraction * 100).round();

  // ── Badges Calculation ────────────────────────────────────────────────────

  /// Full list of badges with dynamically calculated unlocked states.
  List<ProfileBadge> get badges {
    return [
      ProfileBadge(
        definition: ProfileBadgeConstants.firstRide,
        isUnlocked: ridesCount >= 1,
      ),
      ProfileBadge(
        definition: ProfileBadgeConstants.club100,
        isUnlocked: lifetimeDistanceKm >= 100.0,
      ),
      ProfileBadge(
        definition: ProfileBadgeConstants.club500,
        isUnlocked: lifetimeDistanceKm >= 500.0,
      ),
      ProfileBadge(
        definition: ProfileBadgeConstants.club1000,
        isUnlocked: lifetimeDistanceKm >= 1000.0,
      ),
      ProfileBadge(
        definition: ProfileBadgeConstants.longHaul,
        isUnlocked: reports.any((r) => r.distanceKm >= 100.0),
      ),
      ProfileBadge(
        definition: ProfileBadgeConstants.tenRides,
        isUnlocked: ridesCount >= 10,
      ),
    ];
  }

  /// Number of unlocked badges.
  int get unlockedBadgeCount => badges.where((b) => b.isUnlocked).length;

  // ── Stat Card String Helpers ──────────────────────────────────────────────

  String get lifetimeDistanceDisplay {
    if (!hasRides) return '0';
    if (lifetimeDistanceKm == lifetimeDistanceKm.roundToDouble()) {
      return _formatNumber(lifetimeDistanceKm.round());
    }
    return lifetimeDistanceKm.toStringAsFixed(1);
  }

  String get ridesCountDisplay {
    return ridesCount.toString();
  }

  String get saddleTimeDisplay {
    if (!hasRides) return '-';
    final hours = saddleTimeHours;
    if (hours == 0) return '0h';
    if (hours == hours.roundToDouble()) {
      return '${hours.round()}h';
    }
    return '${hours.toStringAsFixed(1)}h';
  }

  String get longestRideDisplay {
    if (!hasRides) return '-';
    final longest = longestSingleRideKm;
    if (longest == longest.roundToDouble()) {
      return _formatNumber(longest.round());
    }
    return longest.toStringAsFixed(1);
  }

  static String _formatNumber(int number) {
    final s = number.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write(',');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }
}
