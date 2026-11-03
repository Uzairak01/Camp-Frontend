import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/presentation/widgets/active_bike_card_widget.dart';
import 'package:camp/features/dashboard/presentation/widgets/maintenance_alert_card_widget.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/controllers/maintenance_controller.dart';
import 'package:camp/features/maintenance/controllers/post_ride_report_controller.dart';
import 'package:camp/features/maintenance/controllers/service_visit_controller.dart';
import 'package:camp/features/maintenance/controllers/trip_budget_controller.dart';
import 'package:camp/features/maintenance/domain/service_schedule_item.dart';
import 'package:camp/features/maintenance/domain/service_visit_model.dart';
import 'package:camp/features/maintenance/presentation/screens/finance_rig_health_screen.dart';
import 'package:camp/features/maintenance/presentation/screens/service_schedule_screen.dart';
import 'package:camp/features/maintenance/presentation/widgets/service_visit_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_ride_report_repository.dart';
import 'helpers/maintenance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    LocalStore.instance.resetForTesting(prefs);
    AppRepositories.resetToDefault();
    ActiveBikeController.instance.resetForTesting();
    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());
    TripBudgetController.instance.resetForTesting();
    ServiceVisitController.instance = ServiceVisitController(
      repository: FakeServiceVisitRepository(),
    );
    MaintenanceController.instance = MaintenanceController(
      repository: FakeMaintenanceRepository(),
    );
  });

  group('Item 1: Home Maintenance Alert and Header Agreement', () {
    test('Header count and alert card due count come from the same controller method and agree', () async {
      const bike = Bike(
        id: 'bike-test',
        make: 'Honda',
        modelName: 'Transalp',
        modelYear: 2024,
        odometerKm: 6400,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      // 3 items: 2 overdue, 1 due soon, 1 ok
      await setScheduleForTest(
        bike.id,
        [
          const ServiceScheduleItem(
            id: 'oil',
            bikeId: 'bike-test',
            type: ServiceItemType.oilAndSmallService,
            intervalKm: 5000,
            lastDoneKm: 0,
            enabled: true,
          ), // 6400 km -> Overdue by 1,400 km
          const ServiceScheduleItem(
            id: 'air',
            bikeId: 'bike-test',
            type: ServiceItemType.airFilter,
            intervalKm: 6000,
            lastDoneKm: 0,
            enabled: true,
          ), // 6400 km -> Overdue by 400 km
          const ServiceScheduleItem(
            id: 'chain',
            bikeId: 'bike-test',
            type: ServiceItemType.chain,
            intervalKm: 7000,
            lastDoneKm: 0,
            enabled: true,
          ), // 6400 km -> Due in 600 km (due soon)
          const ServiceScheduleItem(
            id: 'tyres',
            bikeId: 'bike-test',
            type: ServiceItemType.tyres,
            intervalKm: 15000,
            lastDoneKm: 0,
            enabled: true,
          ), // OK
        ],
      );

      final dueItems = MaintenanceController.instance.dueItems(bike.id);
      final headerCount = MaintenanceController.instance.countDueItems(bike.id);
      final mostUrgent = MaintenanceController.instance.mostUrgentItem(bike.id);

      expect(headerCount, 3);
      expect(dueItems.length, 3);
      expect(mostUrgent, isNotNull);
      expect(mostUrgent!.id, 'oil'); // Highest wear overdue item
      expect(dueItems.first.id, mostUrgent.id);

      final otherDueCount = dueItems.length > 1 ? dueItems.length - 1 : 0;
      expect(otherDueCount, 2);
      // Header count equals 1 (card) + otherDueCount
      expect(headerCount, 1 + otherDueCount);
    });

    testWidgets('Maintenance alert displays real numbers and +X more due line', (tester) async {
      const bike = Bike(
        id: 'bike-test',
        make: 'Honda',
        modelName: 'Transalp',
        modelYear: 2024,
        odometerKm: 6400,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      // 3 due items: oil overdue by 1,400 km, air overdue by 400 km, chain due soon
      await setScheduleForTest(
        bike.id,
        [
          const ServiceScheduleItem(
            id: 'oil',
            bikeId: 'bike-test',
            type: ServiceItemType.oilAndSmallService,
            intervalKm: 5000,
            lastDoneKm: 0,
            enabled: true,
          ),
          const ServiceScheduleItem(
            id: 'air',
            bikeId: 'bike-test',
            type: ServiceItemType.airFilter,
            intervalKm: 6000,
            lastDoneKm: 0,
            enabled: true,
          ),
          const ServiceScheduleItem(
            id: 'chain',
            bikeId: 'bike-test',
            type: ServiceItemType.chain,
            intervalKm: 7000,
            lastDoneKm: 0,
            enabled: true,
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MaintenanceAlertCardWidget(),
          ),
        ),
      );
      await tester.pump();

      // Alert card shows most urgent item with real numbers: "1,400 km overdue"
      expect(find.text('Engine Oil & Filter'), findsOneWidget);
      expect(find.text('OVERDUE'), findsOneWidget);
      expect(find.textContaining('1,400 km overdue'), findsOneWidget);
      expect(find.text('Schedule Service'), findsOneWidget);

      // Tappable line "+2 more due"
      expect(find.text('+2 more due'), findsOneWidget);

      // Tap "+2 more due" to open Service Schedule screen
      await tester.tap(find.text('+2 more due'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ServiceScheduleScreen), findsOneWidget);
    });

    testWidgets('Tapping Schedule Service opens Service Schedule screen with item in view', (tester) async {
      const bike = Bike(
        id: 'bike-test',
        make: 'Honda',
        modelName: 'Transalp',
        modelYear: 2024,
        odometerKm: 6400,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      await setScheduleForTest(
        bike.id,
        [
          const ServiceScheduleItem(
            id: 'oil',
            bikeId: 'bike-test',
            type: ServiceItemType.oilAndSmallService,
            intervalKm: 5000,
            lastDoneKm: 0,
            enabled: true,
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MaintenanceAlertCardWidget(),
          ),
        ),
      );
      await tester.pump();

      // When only 1 item is due, "+X more due" line is hidden
      expect(find.textContaining('more due'), findsNothing);

      await tester.tap(find.text('Schedule Service'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ServiceScheduleScreen), findsOneWidget);
    });
  });

  group('Item 2: Reactive updates without navigation away and back', () {
    testWidgets('Saving service schedule item immediately updates Home alert and Service Status card', (tester) async {
      const bike = Bike(
        id: 'bike-react',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2024,
        odometerKm: 5000,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      // Initially no schedule setup
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  MaintenanceAlertCardWidget(),
                  ActiveBikeCardWidget(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("Add your bike's odometer to get reminders"), findsOneWidget);
      expect(find.text('Set up your service schedule'), findsOneWidget);

      // Save a schedule with overdue oil change
      await setScheduleForTest(
        bike.id,
        [
          const ServiceScheduleItem(
            id: 'oil',
            bikeId: 'bike-react',
            type: ServiceItemType.oilAndSmallService,
            intervalKm: 3000,
            lastDoneKm: 0,
            enabled: true,
          ),
        ],
      );
      await tester.pump();

      // Home alert and Service status card must update without any navigation!
      expect(find.text('Engine Oil & Filter'), findsOneWidget);
      expect(find.textContaining('2,000 km overdue'), findsOneWidget);
      expect(find.text('Engine Oil & Filter overdue'), findsOneWidget);
    });

    testWidgets('Marking item done immediately updates Home alert and Service Status card', (tester) async {
      const bike = Bike(
        id: 'bike-done',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2024,
        odometerKm: 5000,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      await setScheduleForTest(
        bike.id,
        [
          const ServiceScheduleItem(
            id: 'oil',
            bikeId: 'bike-done',
            type: ServiceItemType.oilAndSmallService,
            intervalKm: 3000,
            lastDoneKm: 0,
            enabled: true,
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  MaintenanceAlertCardWidget(),
                  ActiveBikeCardWidget(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('OVERDUE'), findsAtLeastNWidgets(1));

      // Mark item done at 5000 km (runAsync lets the LocalStore write queue drain)
      await tester.runAsync(() async {
        await MaintenanceController.instance.markItemDone(
          bike.id,
          'oil',
          odometerKm: 5000,
          date: DateTime.now(),
        );
      });
      await tester.pump();

      // Both cards immediately update to up to date without navigation!
      expect(find.text('No maintenance due'), findsOneWidget);
      expect(find.text('All maintenance up to date'), findsOneWidget);
      expect(find.text('UP TO DATE'), findsOneWidget);
      expect(find.text('ALL OK'), findsOneWidget);
    });

    testWidgets('Adding planned service visit immediately updates Next Service Visit card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ServiceVisitCardWidget(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No service visit planned'), findsOneWidget);

      // Add a planned visit (runAsync lets the LocalStore write queue drain)
      final visit = ServiceVisit(
        id: 'visit-1',
        dateTime: DateTime.now().add(const Duration(days: 3)),
        shopName: 'Apex Moto Workshop',
        phone: '+92 300 1234567',
      );
      await tester.runAsync(() async {
        await ServiceVisitController.instance.addVisit(visit);
      });
      await tester.pump();

      // Card immediately updates without navigation!
      expect(find.text('No service visit planned'), findsNothing);
      expect(find.text('Apex Moto Workshop'), findsOneWidget);
      expect(find.text('Planned'), findsOneWidget);
    });

    testWidgets('Maintenance list in Finances hub updates immediately when item is marked done', (tester) async {
      const bike = Bike(
        id: 'bike-fin',
        make: 'KTM',
        modelName: '390 Adv',
        modelYear: 2023,
        odometerKm: 4000,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      await setScheduleForTest(
        bike.id,
        [
          const ServiceScheduleItem(
            id: 'oil',
            bikeId: 'bike-fin',
            type: ServiceItemType.oilAndSmallService,
            intervalKm: 3000,
            lastDoneKm: 0,
            enabled: true,
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FinanceRigHealthScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Upcoming & Required\nMaintenance'), findsOneWidget);
      expect(find.text('Engine Oil & Filter'), findsOneWidget);
      expect(find.textContaining('1,000 km overdue'), findsOneWidget);

      // Mark done (runAsync lets the LocalStore write queue drain)
      await tester.runAsync(() async {
        await MaintenanceController.instance.markItemDone(
          bike.id,
          'oil',
          odometerKm: 4000,
          date: DateTime.now(),
        );
      });
      await tester.pump();

      // Maintenance list updates immediately to "Nothing due right now" without navigation!
      expect(find.text('Nothing due right now'), findsOneWidget);
      expect(find.textContaining('1,000 km overdue'), findsNothing);
    });
  });

  group('Item 3: Upcoming & Required Maintenance in Finances hub', () {
    testWidgets('Shows "Set up your service schedule" when no schedule configured', (tester) async {
      const bike = Bike(
        id: 'bike-empty',
        make: 'Kawasaki',
        modelName: 'KLR650',
        modelYear: 2022,
        odometerKm: 12000,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FinanceRigHealthScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Set up your service schedule'), findsAtLeastNWidgets(1));
      expect(find.text('Nothing due right now'), findsNothing);
    });

    testWidgets('Populated with overdue and due soon items, most urgent first, with chips and km/days', (tester) async {
      const bike = Bike(
        id: 'bike-items',
        make: 'BMW',
        modelName: 'F850GS',
        modelYear: 2023,
        odometerKm: 10500,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      await setScheduleForTest(
        bike.id,
        [
          const ServiceScheduleItem(
            id: 'oil',
            bikeId: 'bike-items',
            type: ServiceItemType.oilAndSmallService,
            intervalKm: 5000,
            lastDoneKm: 5000,
            enabled: true,
          ), // at 10500, overdue by 500 km
          const ServiceScheduleItem(
            id: 'air',
            bikeId: 'bike-items',
            type: ServiceItemType.airFilter,
            intervalKm: 11000,
            lastDoneKm: 0,
            enabled: true,
          ), // at 10500, due in 500 km (due soon)
          const ServiceScheduleItem(
            id: 'spark',
            bikeId: 'bike-items',
            type: ServiceItemType.sparkPlug,
            intervalKm: 20000,
            lastDoneKm: 0,
            enabled: true,
          ), // OK
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FinanceRigHealthScreen(),
          ),
        ),
      );
      await tester.pump();

      // Both overdue and due soon appear
      expect(find.text('Engine Oil & Filter'), findsOneWidget);
      expect(find.text('Air Filter Element'), findsOneWidget);
      expect(find.text('Spark Plug'), findsNothing);

      expect(find.text('OVERDUE'), findsOneWidget);
      expect(find.text('DUE SOON'), findsOneWidget);

      expect(find.textContaining('500 km overdue'), findsOneWidget);
      expect(find.textContaining('500 km left'), findsOneWidget);

      // Verify tapping opens ServiceScheduleScreen
      await tester.ensureVisible(find.text('Engine Oil & Filter'));
      await tester.tap(find.text('Engine Oil & Filter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ServiceScheduleScreen), findsOneWidget);
    });
  });
}
