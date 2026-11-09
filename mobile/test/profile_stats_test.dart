import 'package:camp/core/data/session_repository_local.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/domain/profile_stats.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/domain/post_ride_report.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ProfileStats Unit Tests', () {
    test('Zero rides produces clean empty state with Rookie tier and all badges locked', () {
      final stats = ProfileStats(const []);

      expect(stats.ridesCount, 0);
      expect(stats.lifetimeDistanceKm, 0.0);
      expect(stats.saddleTimeHours, 0.0);
      expect(stats.longestSingleRideKm, 0.0);
      expect(stats.hasRides, isFalse);

      expect(stats.lifetimeDistanceDisplay, '0');
      expect(stats.ridesCountDisplay, '0');
      expect(stats.saddleTimeDisplay, '-');
      expect(stats.longestRideDisplay, '-');

      expect(stats.currentTier.name, 'Rookie');
      expect(stats.currentTier.level, 1);
      expect(stats.nextTier?.name, 'Explorer');
      expect(stats.kmToNextTier, 500.0);
      expect(stats.tierProgressFraction, 0.0);
      expect(stats.tierProgressPercent, 0);
      expect(stats.isTopTier, false);

      expect(stats.badges.length, 6);
      expect(stats.unlockedBadgeCount, 0);
      for (final b in stats.badges) {
        expect(b.isUnlocked, isFalse);
      }
    });

    test('Single ride of 120.5 km unlocks First Ride, 100 km Club, and Long Haul', () {
      final now = DateTime.now();
      final report = PostRideReport(
        id: 'r1',
        bikeId: 'b1',
        date: now,
        distanceKm: 120.5,
        durationHours: 2.5,
        terrainTags: const ['Highway'],
        notes: 'Coastal morning run',
      );

      final stats = ProfileStats([report]);

      expect(stats.ridesCount, 1);
      expect(stats.lifetimeDistanceKm, 120.5);
      expect(stats.saddleTimeHours, 2.5);
      expect(stats.longestSingleRideKm, 120.5);
      expect(stats.hasRides, isTrue);

      expect(stats.lifetimeDistanceDisplay, '120.5');
      expect(stats.ridesCountDisplay, '1');
      expect(stats.saddleTimeDisplay, '2.5h');
      expect(stats.longestRideDisplay, '120.5');

      // Tier check: 120.5 is still Rookie (< 500)
      expect(stats.currentTier.name, 'Rookie');
      expect(stats.kmToNextTier, closeTo(379.5, 0.01));
      expect(stats.tierProgressFraction, closeTo(120.5 / 500.0, 0.01));

      // Badges:
      // First Ride: true (1 >= 1)
      // 100 km Club: true (120.5 >= 100)
      // 500 km Club: false (120.5 < 500)
      // 1,000 km Club: false (120.5 < 1000)
      // Long Haul: true (120.5 >= 100)
      // Ten Rides: false (1 < 10)
      expect(stats.unlockedBadgeCount, 3);
      final badgeMap = {for (var b in stats.badges) b.id: b.isUnlocked};
      expect(badgeMap['first_ride'], isTrue);
      expect(badgeMap['club_100'], isTrue);
      expect(badgeMap['club_500'], isFalse);
      expect(badgeMap['club_1000'], isFalse);
      expect(badgeMap['long_haul'], isTrue);
      expect(badgeMap['ten_rides'], isFalse);
    });

    test('Tier boundaries calculation', () {
      ProfileStats statsForDistance(double dist) {
        return ProfileStats([
          PostRideReport(
            id: 'test',
            bikeId: 'b1',
            date: DateTime.now(),
            distanceKm: dist,
            terrainTags: const [],
          ),
        ]);
      }

      // Rookie (0 to < 500)
      expect(statsForDistance(0.0).currentTier.name, 'Rookie');
      expect(statsForDistance(499.9).currentTier.name, 'Rookie');

      // Explorer (500 to < 2000)
      expect(statsForDistance(500.0).currentTier.name, 'Explorer');
      expect(statsForDistance(1999.9).currentTier.name, 'Explorer');
      expect(statsForDistance(500.0).kmToNextTier, 1500.0);

      // Road Warrior (2000 to < 5000)
      expect(statsForDistance(2000.0).currentTier.name, 'Road Warrior');
      expect(statsForDistance(4999.9).currentTier.name, 'Road Warrior');

      // Master Explorer (5000 to < 10000)
      expect(statsForDistance(5000.0).currentTier.name, 'Master Explorer');
      expect(statsForDistance(9999.9).currentTier.name, 'Master Explorer');

      // Legend (>= 10000)
      final legendStats = statsForDistance(10000.0);
      expect(legendStats.currentTier.name, 'Legend');
      expect(legendStats.isTopTier, isTrue);
      expect(legendStats.nextTier, isNull);
      expect(legendStats.kmToNextTier, 0.0);
      expect(legendStats.tierProgressFraction, 1.0);
      expect(legendStats.tierProgressPercent, 100);

      final beyondLegendStats = statsForDistance(15000.0);
      expect(beyondLegendStats.currentTier.name, 'Legend');
      expect(beyondLegendStats.isTopTier, isTrue);
    });

    test('All badge unlock criteria combinations', () {
      // 10 small rides of 10 km each (total = 100 km)
      final tenRides = List.generate(
        10,
        (i) => PostRideReport(
          id: 'r-$i',
          bikeId: 'b1',
          date: DateTime.now(),
          distanceKm: 10.0,
          terrainTags: const [],
        ),
      );

      final stats1 = ProfileStats(tenRides);
      final badgeMap1 = {for (var b in stats1.badges) b.id: b.isUnlocked};
      expect(badgeMap1['first_ride'], isTrue);
      expect(badgeMap1['club_100'], isTrue); // total is 100
      expect(badgeMap1['club_500'], isFalse);
      expect(badgeMap1['club_1000'], isFalse);
      expect(badgeMap1['long_haul'], isFalse); // none >= 100 km
      expect(badgeMap1['ten_rides'], isTrue); // 10 rides completed

      // 1 massive ride of 1,200 km
      final oneMassiveRide = [
        PostRideReport(
          id: 'epic',
          bikeId: 'b1',
          date: DateTime.now(),
          distanceKm: 1200.0,
          terrainTags: const [],
        ),
      ];

      final stats2 = ProfileStats(oneMassiveRide);
      final badgeMap2 = {for (var b in stats2.badges) b.id: b.isUnlocked};
      expect(badgeMap2['first_ride'], isTrue);
      expect(badgeMap2['club_100'], isTrue);
      expect(badgeMap2['club_500'], isTrue);
      expect(badgeMap2['club_1000'], isTrue);
      expect(badgeMap2['long_haul'], isTrue);
      expect(badgeMap2['ten_rides'], isFalse); // only 1 ride
    });
  });

  group('Bike.formatSubtitle Unit Tests', () {
    test('Formats subtitle cleanly without raw id or empty separators', () {
      // Both year and make provided
      expect(Bike.formatSubtitle(year: 2023, make: 'BMW'), '2023 • BMW');
      expect(Bike.formatSubtitle(year: 2024, make: 'Yamaha'), '2024 • Yamaha');

      // Only make provided
      expect(Bike.formatSubtitle(make: 'Honda'), 'Honda');
      expect(Bike.formatSubtitle(year: 0, make: 'Honda'), 'Honda');
      expect(Bike.formatSubtitle(year: null, make: 'Honda'), 'Honda');

      // Only year provided
      expect(Bike.formatSubtitle(year: 2021), '2021');
      expect(Bike.formatSubtitle(year: 2021, make: ''), '2021');
      expect(Bike.formatSubtitle(year: 2021, make: null), '2021');

      // Neither provided
      expect(Bike.formatSubtitle(year: null, make: null), '');
      expect(Bike.formatSubtitle(year: 0, make: ''), '');

      // Bike instance getter
      const bike1 = Bike(
        id: 'test-1',
        make: 'KTM',
        modelName: '890 Adventure R',
        modelYear: 2022,
        odometerKm: 12000,
      );
      expect(bike1.formattedSubtitle, '2022 • KTM');

      const bike2 = Bike(
        id: 'test-2',
        make: '',
        modelName: 'Custom Cruiser',
        modelYear: 0,
        odometerKm: 500,
      );
      expect(bike2.formattedSubtitle, '');
    });
  });

  group('SessionRepository Unit Tests', () {
    test('Default session state, setting active, and clearing session preserves local data', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LocalStore(prefs);
      final sessionRepo = SessionRepositoryLocal(store);

      // Initially logged in (default for dev unless cleared)
      expect(await sessionRepo.isLoggedIn(), isTrue);

      // Sign out
      await sessionRepo.clearSession();
      expect(await sessionRepo.isLoggedIn(), isFalse);

      // Sign in again
      await sessionRepo.setLoggedIn(true);
      expect(await sessionRepo.isLoggedIn(), isTrue);

      // Setting other data into store to verify clearSession doesn't touch local rides/bikes
      await store.writeJson('bike_records', {'model': 'GS'});
      await store.writeJson('ride_reports', [{'id': 'r1'}]);

      await sessionRepo.clearSession();
      expect(await sessionRepo.isLoggedIn(), isFalse);

      // Rides and bikes are still intact!
      expect(await store.readJson('bike_records'), {'model': 'GS'});
      expect(await store.readJson('ride_reports'), [{'id': 'r1'}]);
    });
  });
}
