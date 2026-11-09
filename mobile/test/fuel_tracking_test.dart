import 'dart:convert';

import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/garage/domain/fuel_estimator.dart';
import 'package:camp/features/garage/services/fuel_notification_service.dart';
import 'package:camp/features/garage/services/fuel_tracker_service.dart';
import 'package:camp/features/navigation/domain/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/fake_location_service.dart';

class TestFuelNotificationService extends FuelNotificationService {
  int alertCount = 0;
  int? lastRangeKm;

  @override
  Future<void> showLowFuelAlert({required int rangeKm}) async {
    alertCount++;
    lastRangeKm = rangeKm;
  }

  @override
  Future<bool> requestPermission() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pure Logic: FuelEstimator', () {
    test('40 km at 40 km/l removes exactly 1.0 L', () {
      const startingLiters = 10.0;
      final remaining = FuelEstimator.applyDistance(startingLiters, 40.0, 40.0);
      expect(remaining, 9.0);
    });

    test('Fuel never goes below 0 or above tank capacity', () {
      // Below 0 check
      final remaining = FuelEstimator.applyDistance(2.0, 100.0, 20.0); // 5 L needed
      expect(remaining, 0.0);

      // Percent clamp 0..100
      expect(FuelEstimator.percent(-5.0, 20.0), 0.0);
      expect(FuelEstimator.percent(25.0, 20.0), 100.0);
      expect(FuelEstimator.percent(10.0, 20.0), 50.0);
    });

    test('Missing fuel average or tank -> no range, no percent', () {
      expect(FuelEstimator.rangeKm(10.0, null), isNull);
      expect(FuelEstimator.rangeKm(10.0, 0.0), isNull);
      expect(FuelEstimator.rangeKm(null, 25.0), isNull);

      expect(FuelEstimator.percent(10.0, null), isNull);
      expect(FuelEstimator.percent(10.0, 0.0), isNull);
      expect(FuelEstimator.percent(null, 20.0), isNull);

      expect(FuelEstimator.applyDistance(null, 40.0, 40.0), isNull);
      expect(FuelEstimator.applyDistance(10.0, 40.0, null), 10.0);
    });

    test('Full-to-full learning computes the right km/l', () {
      // 200 km traveled on 10 L refill -> 20.0 km/l
      final efficiency = FuelEstimator.computeFullToFullEfficiency(200.0, 10.0);
      expect(efficiency, 20.0);

      // 450 km on 15 L refill -> 30.0 km/l
      expect(FuelEstimator.computeFullToFullEfficiency(450.0, 15.0), 30.0);

      // Invalid arguments return null
      expect(FuelEstimator.computeFullToFullEfficiency(0.0, 10.0), isNull);
      expect(FuelEstimator.computeFullToFullEfficiency(100.0, 0.0), isNull);
      expect(FuelEstimator.computeFullToFullEfficiency(-50.0, 10.0), isNull);
    });
  });

  group('FuelTrackerService & GPS Filtering', () {
    late FakeLocationService fakeLocation;
    late TestFuelNotificationService fakeNotification;
    late ActiveBikeController bikeController;
    late FuelTrackerService fuelTracker;

    Future<void> emit(PositionData pos) async {
      fakeLocation.emitPosition(pos);
      await pumpEventQueue();
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalStore();
      store.resetForTesting();
      await store.markFirstRunCompleted();

      bikeController = ActiveBikeController.instance;
      bikeController.resetForTesting();

      const testBike = Bike(
        id: 'test-bike-fuel-1',
        make: 'Honda',
        modelName: 'Transalp',
        modelYear: 2024,
        odometerKm: 1000,
        preciseOdometerKm: 1000.0,
        fuelTankCapacityLiters: 16.0,
        fuelAverageKmPerLiter: 20.0,
        fuelRemainingLiters: 3.0, // 3 / 16 = 18.75% (> 15%)
      );
      bikeController.addBike(testBike, setActive: true);

      fakeLocation = FakeLocationService();
      fakeNotification = TestFuelNotificationService();

      fuelTracker = FuelTrackerService.instance;
      fuelTracker.resetForTesting();
      fuelTracker.setDependenciesForTesting(
        locationService: fakeLocation,
        bikeController: bikeController,
        notificationService: fakeNotification,
      );
    });

    tearDown(() {
      fuelTracker.resetForTesting();
    });

    test('Jitter fixes (accuracy 80 m, movement 3 m) add no distance', () async {
      final started = await fuelTracker.startRide();
      expect(started, isTrue);

      final initialOdo = bikeController.activeBike!.preciseOdometerKm!;
      final initialFuel = bikeController.activeBike!.fuelRemainingLiters!;

      // 1. Initial valid fix establishing anchor
      await emit(PositionData(
        latitude: 45.00000,
        longitude: 10.00000,
        accuracy: 10.0,
        speed: 15.0,
        timestamp: DateTime(2026, 1, 1, 10, 0, 0),
      ));

      // 2. Jitter fix: Accuracy > 30 m (80 m) -> must be rejected
      await emit(PositionData(
        latitude: 45.00100,
        longitude: 10.00100,
        accuracy: 80.0,
        speed: 15.0,
        timestamp: DateTime(2026, 1, 1, 10, 0, 5),
      ));

      expect(fuelTracker.rideDistanceKm, 0.0);
      expect(bikeController.activeBike!.preciseOdometerKm, initialOdo);
      expect(bikeController.activeBike!.fuelRemainingLiters, initialFuel);

      // 3. Jitter fix: Movement under 5 m (small latitude shift ~3 m)
      await emit(PositionData(
        latitude: 45.000027,
        longitude: 10.00000,
        accuracy: 5.0,
        speed: 2.0,
        timestamp: DateTime(2026, 1, 1, 10, 0, 10),
      ));

      expect(fuelTracker.rideDistanceKm, 0.0);
      expect(bikeController.activeBike!.preciseOdometerKm, initialOdo);
      expect(bikeController.activeBike!.fuelRemainingLiters, initialFuel);

      // 4. Jitter fix: Speed under 1 m/s (GPS jitter while parked)
      await emit(PositionData(
        latitude: 45.00010, // ~11 meters
        longitude: 10.00000,
        accuracy: 5.0,
        speed: 0.4, // < 1.0 m/s
        timestamp: DateTime(2026, 1, 1, 10, 0, 15),
      ));

      expect(fuelTracker.rideDistanceKm, 0.0);
      expect(bikeController.activeBike!.preciseOdometerKm, initialOdo);
      expect(bikeController.activeBike!.fuelRemainingLiters, initialFuel);

      // 5. Valid movement: ~1.11 km away (0.01 deg lat), plausible speed 20 m/s (~72 km/h)
      await emit(PositionData(
        latitude: 45.01000,
        longitude: 10.00000,
        accuracy: 5.0,
        speed: 20.0,
        timestamp: DateTime(2026, 1, 1, 10, 1, 0),
      ));

      expect(fuelTracker.rideDistanceKm, greaterThan(1.0));
      expect(bikeController.activeBike!.preciseOdometerKm, greaterThan(initialOdo));
      expect(FuelEstimator.currentLiters(bikeController.activeBike!), lessThan(initialFuel));
    });

    test('Crossing 15% fires exactly one notification trigger; refilling resets it', () async {
      // Tank: 16 L, 15% threshold is 2.4 L.
      // Starting fuel: 2.5 L (15.625% > 15%).
      final bike = bikeController.activeBike!.copyWith(
        fuelRemainingLiters: 2.5,
        fuelLevelOdometerKm: bikeController.activeBike!.preciseOdometerKm,
        fuelAverageKmPerLiter: 20.0,
      );
      bikeController.updateBike(bike);

      await fuelTracker.startRide();
      expect(fakeNotification.alertCount, 0);

      // Baseline fix
      await emit(PositionData(
        latitude: 45.00000,
        longitude: 10.00000,
        accuracy: 5.0,
        speed: 20.0,
        timestamp: DateTime(2026, 1, 1, 10, 0, 0),
      ));

      // Move ~4.4 km (0.04 deg lat) at 20 km/l -> uses ~0.22 L -> fuel drops to ~2.28 L (< 15%)
      await emit(PositionData(
        latitude: 45.04000,
        longitude: 10.00000,
        accuracy: 5.0,
        speed: 20.0,
        timestamp: DateTime(2026, 1, 1, 10, 4, 0),
      ));

      expect(FuelEstimator.currentLiters(bikeController.activeBike!), lessThan(2.4));
      expect(fakeNotification.alertCount, 1);
      expect(fakeNotification.lastRangeKm, isNotNull);

      // Continuing ride while still < 15%: must NOT fire second notification
      await emit(PositionData(
        latitude: 45.08000,
        longitude: 10.00000,
        accuracy: 5.0,
        speed: 20.0,
        timestamp: DateTime(2026, 1, 1, 10, 8, 0),
      ));

      expect(fakeNotification.alertCount, 1); // Still exactly 1 trigger

      // Refill to 10 L (well above 15%)
      fuelTracker.resetLowFuelFlag();
      final refilledBike = bikeController.activeBike!.copyWith(
        fuelRemainingLiters: 10.0,
        fuelLevelOdometerKm: bikeController.activeBike!.preciseOdometerKm,
      );
      bikeController.updateBike(refilledBike);
      expect(fuelTracker.hasShownLowFuelNotification, isFalse);

      // Drop again below 15% (set to 2.45 L)
      final lowBike = bikeController.activeBike!.copyWith(
        fuelRemainingLiters: 2.45,
        fuelLevelOdometerKm: bikeController.activeBike!.preciseOdometerKm,
      );
      bikeController.updateBike(lowBike);

      // Move another segment crossing below 2.4 L
      await emit(PositionData(
        latitude: 45.12000,
        longitude: 10.00000,
        accuracy: 5.0,
        speed: 20.0,
        timestamp: DateTime(2026, 1, 1, 10, 12, 0),
      ));

      expect(fakeNotification.alertCount, 2); // Fired again after reset!
    });

    test('Missing fuel average or tank -> no range, no percent, no notification', () async {
      final bikeWithoutFuelAvg = bikeController.activeBike!.copyWith(
        fuelRemainingLiters: 1.0, // Low fuel amount
        fuelAverageKmPerLiter: null, // Missing average
      );
      bikeController.updateBike(bikeWithoutFuelAvg);

      await fuelTracker.startRide();

      await emit(PositionData(
        latitude: 45.00000,
        longitude: 10.00000,
        accuracy: 5.0,
        speed: 20.0,
        timestamp: DateTime(2026, 1, 1, 10, 0, 0),
      ));

      await emit(PositionData(
        latitude: 45.04000,
        longitude: 10.00000,
        accuracy: 5.0,
        speed: 20.0,
        timestamp: DateTime(2026, 1, 1, 10, 4, 0),
      ));

      // With missing fuel average, rangeKm is null, so no notification can compute remaining km
      expect(FuelEstimator.rangeKm(bikeWithoutFuelAvg.fuelRemainingLiters, null), isNull);
      expect(fakeNotification.alertCount, 0);
    });
  });

  group('Persistence & Legacy Data Migration', () {
    test('Persistence round trip including migration from fuelLevelPercent', () async {
      // Legacy JSON with fuelLevelPercent = 75, tank = 20 L, and NO fuelRemainingLiters
      final legacyBikes = [
        {
          'id': 'legacy-bike-1',
          'make': 'Yamaha',
          'modelName': 'Tenere 700',
          'modelYear': 2023,
          'odometerKm': 12000,
          'fuelTankCapacityLiters': 20.0,
          'fuelAverageKmPerLiter': 22.0,
          'fuelLevelPercent': 75,
        }
      ];

      SharedPreferences.setMockInitialValues({
        LocalStore.schemaVersionKey: 1,
        LocalStore.keyFirstRunCompleted: true,
        LocalStore.keyBikes: jsonEncode(legacyBikes),
        LocalStore.keyActiveBikeId: 'legacy-bike-1',
      });

      final store = LocalStore();
      store.resetForTesting();
      LocalStore.instance.resetForTesting();

      ActiveBikeController.instance.resetForTesting();
      await ActiveBikeController.instance.load(store);

      final loaded = ActiveBikeController.instance.activeBike;
      expect(loaded, isNotNull);
      expect(loaded!.id, 'legacy-bike-1');

      // Migration: 75% of 20.0 L = 15.0 L
      expect(loaded.fuelRemainingLiters, 15.0);
      expect(loaded.fuelTankCapacityLiters, 20.0);
      expect(FuelEstimator.percent(loaded.fuelRemainingLiters, loaded.fuelTankCapacityLiters), 75.0);

      // Save back to store
      await ActiveBikeController.instance.save(store);

      // Reset and reload from store
      ActiveBikeController.instance.resetForTesting();
      await ActiveBikeController.instance.load(store);

      final reloaded = ActiveBikeController.instance.activeBike;
      expect(reloaded, isNotNull);
      expect(reloaded!.fuelRemainingLiters, 15.0);
      expect(reloaded.odometerKm, 12000);
      expect(reloaded.preciseOdometerKm ?? reloaded.odometerKm.toDouble(), 12000.0);
    });
  });
}
