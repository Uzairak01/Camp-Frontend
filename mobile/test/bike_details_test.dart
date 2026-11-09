import 'package:camp/core/widgets/distance_or_date_input.dart';
import 'package:camp/features/bike_scan/controllers/bike_onboarding_controller.dart';
import 'package:camp/features/bike_scan/presentation/screens/bike_details_screen.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    BikeOnboardingController.instance.reset();
  });

  group('Phase 1: Bike model & ServiceRecord', () {
    test('Constructs Bike and ServiceRecord with all required and optional fields', () {
      const service = ServiceRecord(
        mode: TrackingMode.byDistance,
        km: 3200,
      );

      const bike = Bike(
        id: 'test-bike-1',
        make: 'Honda',
        modelName: 'Africa Twin',
        modelYear: 2024,
        displacement: 1100,
        bikeType: 'Adventure',
        fuelSystem: FuelSystem.carburetor,
        carburetorType: 'Keihin CVK34',
        fuelTankCapacityLiters: 18.8,
        odometerKm: 14820,
        currentFuelLiters: 12.5,
        lastOilChange: service,
        lastTuneUp: service,
        vin: 'JH2SD0408MK000000',
        nickname: 'Black Beast',
      );

      expect(bike.id, 'test-bike-1');
      expect(bike.make, 'Honda');
      expect(bike.modelName, 'Africa Twin');
      expect(bike.modelYear, 2024);
      expect(bike.displacement, 1100);
      expect(bike.bikeType, 'Adventure');
      expect(bike.fuelSystem, FuelSystem.carburetor);
      expect(bike.carburetorType, 'Keihin CVK34');
      expect(bike.fuelTankCapacityLiters, 18.8);
      expect(bike.odometerKm, 14820);
      expect(bike.currentFuelLiters, 12.5);
      expect(bike.lastOilChange?.km, 3200);
      expect(bike.vin, 'JH2SD0408MK000000');
      expect(bike.nickname, 'Black Beast');
    });
  });

  group('Phase 2: DistanceOrDateInput Widget', () {
    testWidgets('Toggles between By Distance and By Date modes', (tester) async {
      ServiceRecord? updated;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: DistanceOrDateInput(
                label: 'Last Oil Change',
                placeholderKm: 'e.g. 3,200',
                onChanged: (val) => updated = val,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Last Oil Change'), findsOneWidget);
      expect(find.text('By Distance'), findsOneWidget);
      expect(find.text('By Date'), findsOneWidget);
      expect(find.text('km ago'), findsOneWidget);

      // Switch to By Date
      await tester.tap(find.text('By Date'));
      await tester.pumpAndSettle();

      expect(find.text('km ago'), findsNothing);
      expect(find.text('Select service date'), findsOneWidget);
      expect(updated?.mode, TrackingMode.byDate);

      // Switch back to By Distance
      await tester.tap(find.text('By Distance'));
      await tester.pumpAndSettle();

      expect(find.text('km ago'), findsOneWidget);
      expect(updated?.mode, TrackingMode.byDistance);
    });
  });

  group('Phase 3 & 4: BikeDetailsScreen Integration', () {
    testWidgets('Renders all cards in order and handles Carburetor conditional logic',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: const BikeDetailsScreen(),
          routes: {
            '/garage': (context) => const Scaffold(body: Text('Garage Screen')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Header & Progress (Header brand mark removed per BATCH UI-1)
      expect(find.text('CAMP'), findsNothing);
      expect(find.text('ADD BIKE'), findsOneWidget);
      expect(find.text('STEP 2 OF 4'), findsOneWidget);
      expect(find.text('Bike Details'), findsOneWidget);

      // Card 1: Basic Information
      expect(find.text('BASIC INFORMATION'), findsOneWidget);
      expect(find.text('Make / Manufacturer'), findsOneWidget);
      expect(find.text('Model Name'), findsOneWidget);
      expect(find.text('Model Year'), findsOneWidget);
      expect(find.text('Displacement'), findsOneWidget);

      // Card 2: Bike Type
      expect(find.text('BIKE TYPE'), findsOneWidget);
      expect(find.text('Adventure'), findsOneWidget);
      expect(find.text('Sport'), findsOneWidget);
      expect(find.text('Commuter'), findsOneWidget);

      // Card 3: Engine & Fuel System
      expect(find.text('ENGINE & FUEL SYSTEM'), findsOneWidget);
      expect(find.text('Fuel System'), findsOneWidget);
      expect(find.text('Carburetor'), findsOneWidget);
      expect(find.text('Fuel Injection (EFI)'), findsOneWidget);

      // Initially Carburetor is selected, so Carburetor Type is in widget tree
      expect(find.text('Carburetor Type'), findsOneWidget);

      // Select Fuel Injection (EFI)
      await tester.tap(find.text('Fuel Injection (EFI)'));
      await tester.pumpAndSettle();

      // Carburetor Type must be completely removed from the widget tree
      expect(find.text('Carburetor Type'), findsNothing);

      // Select Carburetor again
      await tester.tap(find.text('Carburetor'));
      await tester.pumpAndSettle();
      expect(find.text('Carburetor Type'), findsOneWidget);

      // Card 4: Current Status
      expect(find.text('CURRENT STATUS'), findsOneWidget);
      expect(find.text('Current Odometer Reading'), findsOneWidget);
      expect(find.text('Leave blank to start from 0'), findsOneWidget);
      expect(find.text('Current Fuel Level (Optional)'), findsOneWidget);
      expect(find.text('Last Oil Change'), findsOneWidget);
      expect(find.text('Last Tune-Up'), findsOneWidget);

      // Scroll down to see the lower cards and footnote
      await tester.scrollUntilVisible(
        find.text('OPTIONAL INFO'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Card 5: Optional Info
      expect(find.text('OPTIONAL INFO'), findsOneWidget);
      expect(find.text('Serial / VIN'), findsOneWidget);
      expect(find.text('Vehicle Nickname'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Continue'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Footnote
      expect(
        find.textContaining('Required fields: Make, Model Name, Model Year'),
        findsOneWidget,
      );

      // Fuel Average field should be present in Engine & Fuel System card
      await tester.scrollUntilVisible(
        find.text('Fuel Average (km/L)'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Fuel Average (km/L)'), findsOneWidget);
      expect(find.text('Used to estimate range and fuel cost'), findsOneWidget);

      // Info banner & link
      expect(
        find.text('You can edit these details anytime from your Garage.'),
        findsOneWidget,
      );
      expect(find.text('Back to options'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

  testWidgets('Gating validation: Continue requires Make, Model Name, Model Year only (odometer is optional)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: const BikeDetailsScreen(),
          routes: {
            '/garage': (context) => const Scaffold(body: Text('Garage Screen')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Initially Model Name is empty -> form is not valid
      expect(BikeOnboardingController.instance.isFormValid, isFalse);

      // Fill in Model Name
      final modelField = find.widgetWithText(TextField, '');
      await tester.enterText(modelField.first, 'Africa Twin');
      await tester.pumpAndSettle();

      // Now Make='Honda', ModelName='Africa Twin', Year=2024 -> valid (odometer not required)
      expect(BikeOnboardingController.instance.isFormValid, isTrue);

      // Scroll to Continue button
      final continueButton = find.text('Continue');
      await tester.scrollUntilVisible(
        continueButton,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Tap Continue -> Navigates to /garage
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('Garage Screen'), findsOneWidget);
    });
  });
}
