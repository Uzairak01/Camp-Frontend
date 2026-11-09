import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/controllers/maintenance_controller.dart';
import 'package:camp/features/maintenance/domain/service_schedule_item.dart';
import 'package:camp/features/maintenance/presentation/screens/service_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/maintenance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    LocalStore.instance.resetForTesting(prefs);
    AppRepositories.resetToDefault();
    ActiveBikeController.instance.resetForTesting();
    MaintenanceController.instance = MaintenanceController(
      repository: FakeMaintenanceRepository(),
    );
  });

  group('Service Schedule screen wording tests', () {
    testWidgets('Displays new questions and helpers per item, no standard interval text', (tester) async {
      const bike = Bike(
        id: 'test-bike-wording',
        make: 'Honda',
        modelName: 'CB500X',
        modelYear: 2021,
        odometerKm: 5000,
        fuelSystem: FuelSystem.carburetor, // Include carburetor
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: ServiceScheduleScreen(bikeId: 'test-bike-wording'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Field labels & helpers
      expect(find.text('Change oil every (km)'), findsOneWidget);
      expect(find.text('Distance between oil changes, e.g. 1,500 km'), findsOneWidget);

      expect(find.text('Clean or replace every (km)'), findsOneWidget);
      expect(find.text('Distance between air filter services'), findsOneWidget);

      expect(find.text('Clean and lube every (km)'), findsOneWidget);
      expect(find.text('Distance between chain cleaning and lubing'), findsOneWidget);

      expect(find.text('Check or replace every (km)'), findsOneWidget);
      expect(find.text('Distance between spark plug checks'), findsOneWidget);

      expect(find.text('Full tuning every (km)'), findsOneWidget);
      expect(find.text('Distance between full tune-ups, e.g. 10,000 km'), findsOneWidget);

      expect(find.text('Check brake pads every (km)'), findsOneWidget);
      expect(find.text('Distance between brake checks'), findsOneWidget);

      expect(find.text('Check tyres every (km)'), findsOneWidget);
      expect(find.text('Distance between tyre checks'), findsOneWidget);

      // Carburetor (only when shown)
      expect(find.text('Clean or adjust every (km)'), findsOneWidget);
      expect(find.text('Distance between carburetor services'), findsOneWidget);

      // Battery has time interval
      expect(find.text('Check battery every (months)'), findsOneWidget);
      expect(find.text('Time between battery checks'), findsOneWidget);

      // 2. Months field
      expect(find.text('Or change every (months)'), findsWidgets);
      expect(find.text('Or clean or replace every (months)'), findsOneWidget);
      expect(find.text('Or clean and lube every (months)'), findsOneWidget);
      expect(find.text('Or check or replace every (months)'), findsOneWidget);
      expect(find.text('Or tune every (months)'), findsOneWidget);
      expect(find.text('Or check every (months)'), findsWidgets);
      expect(find.text('Or clean or adjust every (months)'), findsOneWidget);

      // Months helper
      expect(
        find.text('Optional. Reminds you by time too. Whichever comes first counts. Leave empty to track by km only.'),
        findsWidgets,
      );

      // 3. Last done block
      expect(find.text('When did you last do this?'), findsWidgets);
      expect(find.text('LAST DONE'), findsNothing);
      expect(find.text('About __ km ago'), findsWidgets);
      expect(find.text('At odometer __ km'), findsWidgets);
      expect(find.text('Km since you did it'), findsWidgets);
      expect(find.text('Date'), findsWidgets);

      // 4. "standard interval" text must NOT appear anywhere
      expect(find.textContaining('standard interval'), findsNothing);
    });

    testWidgets('Harsh conditions shows effective interval under km field', (tester) async {
      const bike = Bike(
        id: 'test-bike-harsh',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2022,
        odometerKm: 8000,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      // Seed an item with 1500 km
      await setScheduleForTest(
        bike.id,
        [
          const ServiceScheduleItem(
            id: 'oil-item',
            bikeId: 'test-bike-harsh',
            type: ServiceItemType.oilAndSmallService,
            intervalKm: 1500,
            enabled: true,
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ServiceScheduleScreen(bikeId: 'test-bike-harsh'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // With harsh conditions OFF, shows normal helper
      expect(find.text('Distance between oil changes, e.g. 1,500 km'), findsOneWidget);
      expect(find.textContaining('(harsh conditions)'), findsNothing);

      // Toggle harsh conditions switch
      final harshSwitch = find.byType(Switch).first;
      await tester.tap(harshSwitch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Effective interval helper line is shown
      expect(find.text('1,500 km -> 1,200 km (harsh conditions)'), findsOneWidget);
      expect(find.textContaining('standard interval'), findsNothing);
    });
  });
}
