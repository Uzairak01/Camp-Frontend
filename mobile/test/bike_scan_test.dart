import 'package:camp/features/bike_scan/controllers/bike_onboarding_controller.dart';
import 'package:camp/features/bike_scan/domain/bike_recognition_service.dart';
import 'package:camp/features/bike_scan/presentation/screens/bike_details_screen.dart';
import 'package:camp/features/bike_scan/presentation/screens/bike_scan_screen.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    BikeOnboardingController.instance.reset();
    ActiveBikeController.instance.resetForTesting();
  });

  // ── 1. No-camera state ────────────────────────────────────────────────────
  testWidgets(
    'No-camera state shows "Enter details manually" and has no fake claims',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: BikeScanScreen(cameraAvailable: false),
        ),
      );
      await tester.pumpAndSettle();

      // Should show the manual entry button
      expect(find.text('Enter details manually'), findsOneWidget);

      // Must NOT show any fake detection or scan banners
      expect(find.textContaining('Analyzing', findRichText: true), findsNothing);
      expect(find.textContaining('identified', findRichText: true), findsNothing);
      expect(find.textContaining('BMW', findRichText: true), findsNothing);
    },
  );

  // ── 2. Scan banner and BMW prefill are completely removed ─────────────────
  testWidgets(
    'Scan banner and BMW prefill are gone when photo is provided',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const testImagePath = 'test_assets/dummy_bike.jpg';

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/bike-scan',
          routes: {
            '/bike-scan': (context) => const BikeScanScreen(
                  imagePath: testImagePath,
                  cameraAvailable: false,
                ),
            '/garage': (context) => const Scaffold(body: Text('Garage Mock')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Ensure NO detection banners exist
      expect(find.textContaining('Analyzing photo', findRichText: true), findsNothing);
      expect(find.textContaining('Looks like a', findRichText: true), findsNothing);
      expect(find.textContaining('BMW', findRichText: true), findsNothing);
      expect(find.textContaining('R 1250 GS', findRichText: true), findsNothing);

      // Tap 'Add Details'
      final addDetailsBtn = find.text('Add Details');
      expect(addDetailsBtn, findsOneWidget);
      await tester.tap(addDetailsBtn);
      await tester.pumpAndSettle();

      // Navigated to BikeDetailsScreen
      expect(find.byType(BikeDetailsScreen), findsOneWidget);

      // Controller should NOT have BMW prefilled!
      final ctrl = BikeOnboardingController.instance;
      expect(ctrl.make, isNot('BMW'));
      expect(ctrl.modelName, isNot('R 1250 GS'));
      expect(ctrl.modelName, isEmpty);

      // But photo path must be preserved!
      expect(ctrl.imagePath, testImagePath);

      // In BikeDetailsScreen, ensure NO "Auto-filled" / "Suggested" banners appear
      expect(find.textContaining('Auto-filled', findRichText: true), findsNothing);
      expect(find.textContaining('Sample suggestion', findRichText: true), findsNothing);
      expect(find.text('Suggested'), findsNothing);
    },
  );

  // ── 3. Manual entry saves bike with its photo ─────────────────────────────
  testWidgets(
    'Manual entry saves a bike with its photo and user-entered values',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const testImagePath = 'test_assets/rider_bike.jpg';
      BikeOnboardingController.instance.setImagePath(testImagePath);

      await tester.pumpWidget(
        MaterialApp(
          home: const BikeDetailsScreen(),
          routes: {
            '/garage': (context) => const Scaffold(body: Text('Garage Mock')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Enter Model Name
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Africa Twin, CB650R'),
        'Tenere 700',
      );
      await tester.pumpAndSettle();

      // Enter License Plate
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. ABC-1234'),
        'MOTO-99',
      );
      await tester.pumpAndSettle();

      // Enter Odometer
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 14,820'),
        '15200',
      );
      await tester.pumpAndSettle();

      // Enter Fuel Average
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 40'),
        '22.5',
      );
      await tester.pumpAndSettle();

      // Tap Continue
      final continueBtn = find.text('Continue');
      expect(continueBtn, findsOneWidget);
      await tester.ensureVisible(continueBtn);
      await tester.pumpAndSettle();
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Check ActiveBikeController
      final activeBike = ActiveBikeController.instance.activeBike;
      expect(activeBike, isNotNull);
      expect(activeBike!.modelName, 'Tenere 700');
      expect(activeBike.plateNumber, 'MOTO-99');
      expect(activeBike.odometerKm, 15200);
      expect(activeBike.fuelAverageKmPerLiter, 22.5);
      expect(activeBike.imagePath, testImagePath);
    },
  );

  // ── 4. populateFromRecognition fills only the provided fields ─────────────
  test('populateFromRecognition fills only the provided fields', () {
    final controller = BikeOnboardingController.instance;
    controller.reset();

    // Set initial values that should be wiped/left blank or preserved
    controller.setOdometerKm(12000);
    controller.setCurrentFuelLiters(14.5);
    controller.setVin('OLDVIN12345');
    controller.setNickname('Old Beast');
    controller.setFuelSystem(FuelSystem.carburetor);

    const result = BikeRecognitionResult(
      make: 'Yamaha',
      model: 'Tenere 700',
      year: 2023,
      displacementCc: 689,
      tankCapacityLiters: 16.0,
      category: 'Adventure',
      confidence: 0.94,
    );

    controller.populateFromRecognition(result);

    // Only provided fields are filled
    expect(controller.make, 'Yamaha');
    expect(controller.modelName, 'Tenere 700');
    expect(controller.modelYear, 2023);
    expect(controller.displacement, 689);
    expect(controller.fuelTankCapacityLiters, 16.0);
    expect(controller.bikeType, 'Adventure');

    // Left blank: odometer, fuel level, VIN, nickname
    expect(controller.odometerKm, isNull);
    expect(controller.currentFuelLiters, isNull);
    expect(controller.vin, isNull);
    expect(controller.nickname, isNull);

    // Never sets the fuel system (the rider chooses, remains untouched)
    expect(controller.fuelSystem, FuelSystem.carburetor);
  });

  test('populateFromRecognition with partial result leaves omitted fields unchanged and clears blanks', () {
    final controller = BikeOnboardingController.instance;
    controller.reset();
    controller.setOdometerKm(5000);
    controller.setCurrentFuelLiters(10.0);
    controller.setVin('VIN999');
    controller.setNickname('Ghost');
    controller.setFuelSystem(FuelSystem.efi);

    const partialResult = BikeRecognitionResult(
      make: 'Kawasaki',
      model: 'KLR 650',
    );

    controller.populateFromRecognition(partialResult);

    expect(controller.make, 'Kawasaki');
    expect(controller.modelName, 'KLR 650');
    // Left blank
    expect(controller.odometerKm, isNull);
    expect(controller.currentFuelLiters, isNull);
    expect(controller.vin, isNull);
    expect(controller.nickname, isNull);
    // Never sets the fuel system
    expect(controller.fuelSystem, FuelSystem.efi);
  });
}

