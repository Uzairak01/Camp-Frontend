import 'package:camp/app/routes.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('CampRoutes has unique paths for all canonical constants', () {
    const canonical = CampRoutes.canonicalRoutes;
    final uniqueSet = canonical.toSet();
    expect(
      canonical.length,
      equals(uniqueSet.length),
      reason: 'No two canonical constants should share the same path string',
    );
  });

  testWidgets('CAMP Explore Home smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CampApp());

    // Verify key elements from the initial screen exist
    expect(find.text('CAMP'), findsWidgets);
  });

  testWidgets('Save on exit: lifecycle state change to paused flushes queued writes',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.instance.resetForTesting();
    ActiveBikeController.instance.resetForTesting();
    await LocalStore.instance.markFirstRunCompleted();

    await tester.pumpWidget(const CampApp());
    await tester.pump();

    // Perform a mutation with fire-and-forget save
    const testBike = Bike(
      id: 'lifecycle-test-bike',
      make: 'Triumph',
      modelName: 'Tiger 900',
      modelYear: 2024,
      displacement: 888,
      bikeType: 'Adventure',
      fuelSystem: FuelSystem.efi,
      carburetorType: null,
      fuelTankCapacityLiters: 20.0,
      fuelAverageKmPerLiter: 21.0,
      ridingTerrain: ['Highway'],
      edition: 'Pro',
      imagePath: null,
      odometerKm: 3100,
      currentFuelLiters: 14.0,
      lastOilChange: null,
      lastTuneUp: null,
      vin: 'LIFECYCLEVIN1',
      nickname: 'Tiger Pro',
    );

    ActiveBikeController.instance.addBike(testBike, setActive: true);

    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    // Simulate app entering paused state through valid Flutter lifecycle transitions
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    // Reload from a fresh store to verify that flush() was completed
    final freshStore = LocalStore();
    freshStore.resetForTesting();
    final freshController = ActiveBikeController.instance;
    freshController.resetForTesting();

    await freshController.load(freshStore);

    expect(freshController.bikes.any((b) => b.id == 'lifecycle-test-bike'), isTrue);
    expect(freshController.activeBikeId, 'lifecycle-test-bike');
  });

  testWidgets('Save on exit: lifecycle state change to inactive flushes queued writes',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    LocalStore.instance.resetForTesting();
    ActiveBikeController.instance.resetForTesting();
    await LocalStore.instance.markFirstRunCompleted();

    await tester.pumpWidget(const CampApp());
    await tester.pump();

    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    const bikeInactive = Bike(
      id: 'inactive-bike',
      make: 'KTM',
      modelName: '390 Adventure',
      modelYear: 2023,
      displacement: 373,
      bikeType: 'Adventure',
      fuelSystem: FuelSystem.efi,
      carburetorType: null,
      fuelTankCapacityLiters: 14.5,
      fuelAverageKmPerLiter: 28.0,
      ridingTerrain: ['Trail'],
      edition: 'Standard',
      imagePath: null,
      odometerKm: 4200,
      currentFuelLiters: 10.0,
      lastOilChange: null,
      lastTuneUp: null,
      vin: 'INACTIVEVIN',
      nickname: 'Baby Adventure',
    );

    ActiveBikeController.instance.addBike(bikeInactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();

    final freshStore = LocalStore();
    freshStore.resetForTesting();
    ActiveBikeController.instance.resetForTesting();
    await ActiveBikeController.instance.load(freshStore);

    expect(ActiveBikeController.instance.bikes.any((b) => b.id == 'inactive-bike'), isTrue);
  });
}
