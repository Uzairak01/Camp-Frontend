import 'package:camp/features/bike_scan/presentation/screens/bike_details_screen.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/garage/presentation/screens/bike_profile_screen.dart';
import 'package:camp/features/garage/presentation/screens/garage_screen.dart';
import 'package:camp/features/maintenance/controllers/post_ride_report_controller.dart';
import 'package:camp/features/maintenance/domain/post_ride_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_ride_report_repository.dart';

const testBike1 = Bike(
  id: 'test-bike-1',
  make: 'BMW',
  modelName: 'R 1250 GS Adventure',
  modelYear: 2023,
  odometerKm: 14200,
  displacement: 1254,
  bikeType: 'Adventure',
  fuelSystem: FuelSystem.efi,
  ridingTerrain: ['City', 'Highway', 'Off-road', 'Mountain'],
);

const testBike2 = Bike(
  id: 'test-bike-2',
  make: 'Honda',
  modelName: 'Rebel 500',
  modelYear: 2021,
  odometerKm: 8500,
  displacement: 471,
  bikeType: 'Cruiser',
  fuelSystem: FuelSystem.carburetor,
  carburetorType: 'Keihin CVK',
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    ActiveBikeController.instance.reset();
    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());
  });

  tearDown(() {
    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());
  });

  group('ActiveBikeController Unit Tests', () {
    test('Initializes with empty fleet on reset', () {
      final controller = ActiveBikeController.instance;
      expect(controller.bikes, isEmpty);
      expect(controller.activeBikeId, isNull);
    });

    test('setActiveBike changes the active rig', () {
      final controller = ActiveBikeController.instance;
      controller.addBike(testBike1, setActive: true);
      controller.addBike(testBike2);
      expect(controller.activeBikeId, 'test-bike-1');

      controller.setActiveBike('test-bike-2');
      expect(controller.activeBikeId, 'test-bike-2');
      expect(controller.activeBike?.modelName, 'Rebel 500');
      expect(controller.isActive('test-bike-2'), isTrue);
      expect(controller.isActive('test-bike-1'), isFalse);
    });

    test('removeBike removes the bike and reassigns active rig if needed', () {
      final controller = ActiveBikeController.instance;
      controller.addBike(testBike1, setActive: true);
      controller.addBike(testBike2);
      expect(controller.bikes.any((b) => b.id == 'test-bike-1'), isTrue);

      controller.removeBike('test-bike-1');
      expect(controller.bikes.any((b) => b.id == 'test-bike-1'), isFalse);
      expect(controller.activeBikeId, 'test-bike-2');
      expect(controller.activeBike?.id, 'test-bike-2');
    });
  });

  group('BikeProfileScreen Widget Tests', () {
    testWidgets('Renders all sections, single tracking badge, and real enum values',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ActiveBikeController.instance.addBike(testBike1, setActive: true);
      final testBike = ActiveBikeController.instance.activeBike!;
      PostRideReportController.instance.addReport(
        PostRideReport(
          id: 'test-debrief-1',
          bikeId: testBike.id,
          distanceKm: 120,
          date: DateTime(2026, 5, 1),
          terrainTags: const ['Mountain'],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BikeProfileScreen(bike: testBike),
          routes: {
            '/finances-rig-health': (context) =>
                const Scaffold(body: Text('Finances & Rig Health Page')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // 1. Header: Back button, and ACTIVE RIG pill (Brand mark removed per BATCH UI-1)
      expect(find.text('CAMP'), findsNothing);
      expect(find.text('ACTIVE RIG'), findsNWidgets(2));

      // 2. Hero Card: Overline, Bike Name, single MANUALLY TRACKED badge
      expect(find.text('BMW R 1250 GS Adventure'), findsOneWidget);
      expect(find.text('MANUALLY TRACKED'), findsOneWidget);

      // Verify CONTRADICTION REMOVED: NO BLE / OBD-II pill overlay
      expect(find.textContaining('BLE Paired'), findsNothing);
      expect(find.textContaining('OBD-II Live'), findsNothing);

      // 3. Specifications Card: "As Entered" header and real Fuel System enum value
      expect(find.text('SPECIFICATIONS'), findsOneWidget);
      expect(find.text('As Entered'), findsOneWidget);
      expect(find.text('Fuel Injection (EFI)'), findsOneWidget);
      expect(find.text('Electronic'), findsOneWidget);
      expect(find.text('ENGINE'), findsOneWidget);
      expect(find.text('1,254 cc'), findsOneWidget);
      expect(find.text('RIG CATEGORY'), findsOneWidget);
      expect(find.text('Adventure'), findsOneWidget);

      // 4. Maintenance Health Card
      expect(find.text('MAINTENANCE HEALTH'), findsOneWidget);
      expect(find.textContaining('Systems'), findsOneWidget);
      expect(find.textContaining('Next service due in'), findsOneWidget);
      expect(find.text('COMPONENT DIAGNOSTICS'), findsOneWidget);
      expect(find.text('View Full Rig Diagnostics Report'), findsOneWidget);

      // 5. Riding Profile Card
      expect(find.text('RIDING PROFILE'), findsOneWidget);
      expect(find.text('Primary Riding Terrain (Configured):'), findsOneWidget);
      expect(find.text('City'), findsOneWidget);
      expect(find.text('Highway'), findsOneWidget);
      expect(find.text('Off-road'), findsOneWidget);
      expect(find.text('Mountain'), findsOneWidget);

      // 6. Recent Trips Card
      expect(find.text('RECENT TRIPS (ON THIS BIKE)'), findsOneWidget);
      expect(find.textContaining('See all'), findsOneWidget);

      // 7. Bottom Actions: Currently Active Rig state and Remove Bike link
      expect(find.text('Edit Specifications & Tires'), findsOneWidget);
      expect(find.text('Currently Active Rig'), findsOneWidget);
      expect(find.text('Remove Bike from Garage'), findsOneWidget);
    });

    testWidgets('Shows Carburetor fuel system when bike is carbureted',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ActiveBikeController.instance.addBike(testBike1, setActive: true);
      ActiveBikeController.instance.addBike(testBike2);
      const standbyBike = testBike2;

      await tester.pumpWidget(
        const MaterialApp(
          home: BikeProfileScreen(bike: standbyBike),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('STANDBY'), findsOneWidget);
      expect(find.text('STANDBY FLEET'), findsOneWidget);
      expect(find.text('Carburetor'), findsOneWidget);
      expect(find.text('Keihin CVK'), findsOneWidget);
      expect(find.text('Set as Active Rig'), findsOneWidget);
    });

    testWidgets('Set as Active Rig button updates controller',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ActiveBikeController.instance.addBike(testBike1, setActive: true);
      ActiveBikeController.instance.addBike(testBike2);
      const standbyBike = testBike2;

      await tester.pumpWidget(
        const MaterialApp(
          home: BikeProfileScreen(bike: standbyBike),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set as Active Rig'), findsOneWidget);
      await tester.tap(find.text('Set as Active Rig'));
      await tester.pumpAndSettle();

      // Controller should now have test-bike-2 as active
      expect(ActiveBikeController.instance.activeBikeId, 'test-bike-2');
      expect(find.text('Currently Active Rig'), findsOneWidget);
      expect(find.text('ACTIVE RIG'), findsWidgets);
    });

    testWidgets('Remove Bike shows confirmation dialog before deletion',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ActiveBikeController.instance.addBike(testBike1, setActive: true);
      const bike = testBike1;

      await tester.pumpWidget(
        const MaterialApp(
          home: BikeProfileScreen(bike: bike),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove Bike from Garage'));
      await tester.pumpAndSettle();

      expect(find.text('Remove Motorcycle?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Remove Bike'), findsOneWidget);

      await tester.tap(find.text('Remove Bike'));
      await tester.pumpAndSettle();

      expect(ActiveBikeController.instance.bikes.any((b) => b.id == bike.id),
          isFalse);
    });
  });

  group('GarageScreen Navigation Wiring Tests', () {
    testWidgets('Tapping bike card navigates to BikeProfileScreen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      ActiveBikeController.instance.addBike(testBike1, setActive: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: GarageScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BMW R 1250 GS Adventure'), findsOneWidget);

      // Tap on the bike title / card area
      await tester.tap(find.text('BMW R 1250 GS Adventure'));
      await tester.pumpAndSettle();

      // Should now be on BikeProfileScreen
      expect(find.byType(BikeProfileScreen), findsOneWidget);
      expect(find.text('As Entered'), findsOneWidget);
    });

    testWidgets('Tapping Edit directly opens BikeDetailsScreen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      ActiveBikeController.instance.addBike(testBike1, setActive: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: GarageScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the "Edit" button on the first card
      final editFinder = find.text('Edit');
      expect(editFinder, findsWidgets);

      await tester.tap(editFinder.first);
      await tester.pumpAndSettle();

      // Should have navigated straight to BikeDetailsScreen, bypassing BikeProfileScreen
      expect(find.byType(BikeDetailsScreen), findsOneWidget);
      expect(find.byType(BikeProfileScreen), findsNothing);
    });
  });
}
