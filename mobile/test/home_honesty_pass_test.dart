import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/domain/weather_service.dart';
import 'package:camp/features/dashboard/presentation/screens/weather_detail_screen.dart';
import 'package:camp/features/dashboard/presentation/widgets/active_bike_card_widget.dart';
import 'package:camp/features/dashboard/presentation/widgets/app_drawer_widget.dart';
import 'package:camp/features/dashboard/presentation/widgets/cockpit_status_card_widget.dart';
import 'package:camp/features/dashboard/presentation/widgets/group_beacon_card_widget.dart';
import 'package:camp/features/dashboard/presentation/widgets/home_weather_card_widget.dart';
import 'package:camp/features/dashboard/presentation/widgets/maintenance_alert_card_widget.dart';
import 'package:camp/features/dashboard/presentation/widgets/recent_updates_feed_widget.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/controllers/maintenance_controller.dart';
import 'package:camp/features/maintenance/controllers/post_ride_report_controller.dart';
import 'package:camp/features/maintenance/controllers/service_visit_controller.dart';
import 'package:camp/features/maintenance/controllers/trip_budget_controller.dart';
import 'package:camp/features/maintenance/domain/expense_model.dart';
import 'package:camp/features/maintenance/domain/post_ride_report.dart';
import 'package:camp/features/maintenance/domain/service_schedule_item.dart';
import 'package:camp/features/mechanics/controllers/mechanic_controller.dart';
import 'package:camp/features/mechanics/domain/mechanic_model.dart';
import 'package:camp/features/settings/controllers/settings_controller.dart';
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
    ActiveBikeController.instance.resetForTesting();
    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());
    TripBudgetController.instance.resetForTesting();
    ServiceVisitController.instance = ServiceVisitController(
      repository: FakeServiceVisitRepository(),
    );
    MechanicController.instance.resetForTesting();
    SettingsController.instance.resetForTesting();
    MaintenanceController.instance = MaintenanceController(
      repository: FakeMaintenanceRepository(),
    );
    WeatherProvider.mockService = null;
  });

  group('Batch C: Maintenance Alert States', () {
    testWidgets('Neutral empty state when no odometer data exists', (tester) async {
      // 1. Bike with 0 km and no service records
      const zeroKmBike = Bike(
        id: 'bike-new',
        make: 'Honda',
        modelName: 'CB500X',
        modelYear: 2024,
        odometerKm: 0,
      );
      ActiveBikeController.instance.addBike(zeroKmBike, setActive: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MaintenanceAlertCardWidget(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("Add your bike's odometer to get reminders"), findsOneWidget);
      expect(find.text('DUE SOON'), findsNothing);
      expect(find.text('OVERDUE'), findsNothing);
    });

    testWidgets('Neutral empty state when no bike is registered', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MaintenanceAlertCardWidget(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("Add your bike's odometer to get reminders"), findsOneWidget);
    });

    testWidgets('Neutral empty state when all maintenance is up to date', (tester) async {
      // Bike at 500 km with recent oil change at 450 km (only 50 km since service)
      final okBike = Bike(
        id: 'bike-ok',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2024,
        odometerKm: 500,
        lastOilChange: ServiceRecord(
          mode: TrackingMode.byDistance,
          km: 50,
          date: DateTime.now().subtract(const Duration(days: 2)),
        ),
        lastTuneUp: const ServiceRecord(
          mode: TrackingMode.byDistance,
          km: 50,
        ),
      );
      ActiveBikeController.instance.addBike(okBike, setActive: true);
      await setScheduleForTest(
        okBike.id,
        [
          const ServiceScheduleItem(
            id: 'oil-ok',
            bikeId: 'bike-ok',
            type: ServiceItemType.oilAndSmallService,
            intervalKm: 5000,
            lastDoneKm: 450,
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

      expect(find.text('No maintenance due'), findsOneWidget);
      expect(find.text('UP TO DATE'), findsOneWidget);
      expect(find.text('OVERDUE'), findsNothing);
      expect(find.text('DUE SOON'), findsNothing);
    });

    testWidgets('Displays DUE SOON alert when an item is near service interval', (tester) async {
      // Bike at 3200 km on a 3500 km interval (91.4% wear -> DUE SOON, due in 300 km)
      const dueSoonBike = Bike(
        id: 'bike-due-soon',
        make: 'KTM',
        modelName: '390 Adventure',
        modelYear: 2023,
        odometerKm: 3200,
        lastOilChange: ServiceRecord(
          mode: TrackingMode.byDistance,
          km: 3200,
        ),
      );
      ActiveBikeController.instance.addBike(dueSoonBike, setActive: true);
      await setScheduleForTest(
        dueSoonBike.id,
        [
          const ServiceScheduleItem(
            id: 'oil-due-soon',
            bikeId: 'bike-due-soon',
            type: ServiceItemType.oilAndSmallService,
            intervalKm: 3500,
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

      expect(find.text('DUE SOON'), findsOneWidget);
      expect(find.text('OVERDUE'), findsNothing);
      expect(find.textContaining('left until your next service'), findsOneWidget);
    });

    testWidgets('Displays OVERDUE alert when an item exceeds service interval', (tester) async {
      // Bike at 5500 km since oil change (> 5000 km standard interval)
      const overdueBike = Bike(
        id: 'bike-overdue',
        make: 'BMW',
        modelName: 'R 1250 GS',
        modelYear: 2022,
        odometerKm: 5500,
        lastOilChange: ServiceRecord(
          mode: TrackingMode.byDistance,
          km: 5500,
        ),
      );
      ActiveBikeController.instance.addBike(overdueBike, setActive: true);
      await setScheduleForTest(
        overdueBike.id,
        [
          const ServiceScheduleItem(
            id: 'oil-overdue',
            bikeId: 'bike-overdue',
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

      expect(find.text('OVERDUE'), findsOneWidget);
      expect(find.textContaining('500 km overdue'), findsOneWidget);
      expect(find.text('Schedule Service'), findsOneWidget);
    });

    testWidgets('Tapping alert card triggers navigation callback', (tester) async {
      bool tapped = false;
      const overdueBike = Bike(
        id: 'bike-overdue',
        make: 'BMW',
        modelName: 'R 1250 GS',
        modelYear: 2022,
        odometerKm: 5500,
        lastOilChange: ServiceRecord(mode: TrackingMode.byDistance, km: 5500),
      );
      ActiveBikeController.instance.addBike(overdueBike, setActive: true);
      await setScheduleForTest(
        overdueBike.id,
        [
          const ServiceScheduleItem(
            id: 'oil-overdue',
            bikeId: 'bike-overdue',
            type: ServiceItemType.oilAndSmallService,
            intervalKm: 5000,
            lastDoneKm: 0,
            enabled: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaintenanceAlertCardWidget(
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(MaintenanceAlertCardWidget));
      expect(tapped, isTrue);
    });
  });

  group('Batch C: Service Status Card on Home', () {
    testWidgets('Displays "Set up your service schedule" when no data exists', (tester) async {
      const zeroKmBike = Bike(
        id: 'bike-zero',
        make: 'Honda',
        modelName: 'XR150L',
        modelYear: 2024,
        odometerKm: 0,
      );
      ActiveBikeController.instance.addBike(zeroKmBike, setActive: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActiveBikeCardWidget(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Set up your service schedule'), findsOneWidget);
      // Ensure odometer is not repeated as a service status
      expect(find.text('KM LOGGED'), findsNothing);
    });

    testWidgets('Displays next due item when maintenance is due soon', (tester) async {
      const dueSoonBike = Bike(
        id: 'bike-due-soon',
        make: 'KTM',
        modelName: '390 Adventure',
        modelYear: 2023,
        odometerKm: 3200,
        lastOilChange: ServiceRecord(
          mode: TrackingMode.byDistance,
          km: 3200,
        ),
      );
      ActiveBikeController.instance.addBike(dueSoonBike, setActive: true);
      await setScheduleForTest(
        dueSoonBike.id,
        [
          const ServiceScheduleItem(
            id: 'oil-due-soon',
            bikeId: 'bike-due-soon',
            type: ServiceItemType.oilAndSmallService,
            intervalKm: 3500,
            lastDoneKm: 0,
            enabled: true,
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActiveBikeCardWidget(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('DUE SOON'), findsOneWidget);
      expect(find.textContaining('in 300 km'), findsOneWidget);
    });
  });

  group('Batch C: Drawer Count Hiding at 0', () {
    testWidgets('Hides all count badges when repositories are empty', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 0 bikes, 0 reports, 0 mechanics
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            drawer: AppDrawerWidget(),
            body: Text('Home'),
          ),
        ),
      );
      await tester.pump();

      // Open drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pump();

      // Verify fake hardcoded badges are completely gone
      expect(find.text('5 Available'), findsNothing);
      expect(find.text('24 Logged'), findsNothing);
      expect(find.text('+ Contributor'), findsNothing);
      expect(find.text('GS #441'), findsNothing);

      // Verify labels match canonical screen names
      expect(find.text('Emergency SOS'), findsOneWidget);
      expect(find.text('Emergency SOS & Telematics'), findsNothing);
    });

    testWidgets('Displays real counts when items are added to repositories', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Add 2 bikes
      const b1 = Bike(id: 'b1', make: 'Honda', modelName: 'CB500X', modelYear: 2022, odometerKm: 1200);
      const b2 = Bike(id: 'b2', make: 'Yamaha', modelName: 'MT-07', modelYear: 2023, odometerKm: 3400);
      ActiveBikeController.instance.addBike(b1, setActive: true);
      ActiveBikeController.instance.addBike(b2);

      // Add 1 mechanic
      const m = Mechanic(
        id: 'm1',
        name: 'Tariq Autos',
        distance: '12 km',
        durationOrLocation: 'Gilgit',
        badgeType: BadgeType.verified,
        badgeLabel: 'Verified',
        beaconStatus: 'Available',
        beaconColor: Colors.green,
        categoryTitle1: 'Services',
        tags1: ['Repair'],
        categoryTitle2: 'Parts',
        tags2: ['Pads'],
        rating: 4.8,
        reviewCount: 12,
        openStatus: 'Open',
      );
      MechanicController.instance.addMechanic(m);

      // Add 1 report
      final r = PostRideReport(
        id: 'r1',
        bikeId: 'b1',
        date: DateTime.now(),
        distanceKm: 120.0,
        terrainTags: const ['Highway'],
      );
      PostRideReportController.instance.addReport(r);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            drawer: AppDrawerWidget(),
            body: Text('Home'),
          ),
        ),
      );
      await tester.pump();

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pump();

      // 2 bikes badge
      expect(find.text('2'), findsOneWidget);
      // 1 mechanic badge & 1 ride badge
      expect(find.text('1'), findsWidgets);
    });
  });

  group('Batch C: Recent Activity Feed Ordering & Empty State', () {
    testWidgets('Displays empty state when no activity records exist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecentUpdatesFeedWidget(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Recent activity'), findsOneWidget);
      expect(find.text('Live'), findsNothing);
      expect(find.text('Mark all read'), findsNothing);
      expect(find.text('No recent activity yet'), findsOneWidget);
    });

    testWidgets('Orders activities strictly newest first across repositories', (tester) async {
      final now = DateTime.now();

      // Older: Bike added 3 days ago
      final b = Bike(
        id: 'b-old',
        make: 'Honda',
        modelName: 'Transalp',
        modelYear: 2024,
        odometerKm: 2500,
        createdAt: now.subtract(const Duration(days: 3)),
      );
      ActiveBikeController.instance.addBike(b, setActive: true);

      // Middle: Expense added 2 days ago
      final exp = Expense(
        id: 'exp-mid',
        title: 'Brake Fluid',
        amount: 850.0,
        trackingMode: ExpenseTrackingMode.manualEntry,
        category: ExpenseCategory.parts,
        dateRecorded: now.subtract(const Duration(days: 2)),
      );
      TripBudgetController.instance.addExpense(exp);

      // Newest: Ride logged 1 hour ago
      final r = PostRideReport(
        id: 'ride-new',
        bikeId: 'b-old',
        date: now.subtract(const Duration(hours: 1)),
        distanceKm: 95.0,
        terrainTags: const ['Mountain'],
        notes: 'Pass summit test',
      );
      PostRideReportController.instance.addReport(r);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecentUpdatesFeedWidget(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Newest ride should appear first
      final rideFinder = find.textContaining('Ride Logged');
      final expenseFinder = find.text('Brake Fluid');
      final bikeFinder = find.textContaining('Motorcycle Added');

      expect(rideFinder, findsOneWidget);
      expect(expenseFinder, findsOneWidget);
      expect(bikeFinder, findsOneWidget);

      final rideTop = tester.getTopLeft(rideFinder).dy;
      final expenseTop = tester.getTopLeft(expenseFinder).dy;
      final bikeTop = tester.getTopLeft(bikeFinder).dy;

      // Newest first order
      expect(rideTop, lessThan(expenseTop));
      expect(expenseTop, lessThan(bikeTop));
    });
  });

  group('Batch C: Weather Unavailable State', () {
    testWidgets('Cockpit Status card shows "Weather unavailable" when no key', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CockpitStatusCardWidget(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Weather unavailable'), findsOneWidget);
      // Ensure fake "--" or "--° • Add weather API key" is absent
      expect(find.textContaining('--'), findsNothing);
    });

    testWidgets('WeatherDetailScreen displays "Weather unavailable" with Retry button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WeatherDetailScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Weather unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // Ensure fake placeholder forecast values are absent
      expect(find.text('Sunny & Ideal'), findsNothing);
      expect(find.text('22°'), findsNothing);
    });
  });

  group('Batch C: Restored Home Cards (Weather & Beacon)', () {
    testWidgets('HomeWeatherCardWidget displays "Weather unavailable" when no key', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomeWeatherCardWidget(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Weather'), findsOneWidget);
      expect(find.text('Weather unavailable'), findsOneWidget);
      expect(find.textContaining('22°'), findsNothing);
      expect(find.textContaining('Sunny & Ideal'), findsNothing);
    });

    testWidgets('Tapping HomeWeatherCardWidget invokes tap handler', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeWeatherCardWidget(
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(HomeWeatherCardWidget));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('GroupBeaconCardWidget displays "Group Beacon: coming soon"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroupBeaconCardWidget(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Group Beacon'), findsOneWidget);
      expect(find.text('Group Beacon: coming soon'), findsOneWidget);
      // Ensure no fake mesh or rider numbers
      expect(find.textContaining('Riders'), findsNothing);
      expect(find.textContaining('Signal'), findsNothing);
    });

    testWidgets('Tapping GroupBeaconCardWidget opens Coming soon bottom sheet', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroupBeaconCardWidget(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(GroupBeaconCardWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // bottom sheet animation

      expect(find.text('Group Beacon: coming soon'), findsWidgets);
      expect(find.textContaining('Live group coordination and rider beacons require a backend service'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('Batch C: Recent Activity Feed Clear Button', () {
    testWidgets('Clear button hides old entries but preserves real records, and new entries show', (tester) async {
      final now = DateTime.now();

      // 1. Add real records before clear
      final r1 = PostRideReport(
        id: 'r-prior-1',
        bikeId: 'b1',
        date: now.subtract(const Duration(hours: 2)),
        distanceKm: 45.0,
        terrainTags: const ['Pavement'],
        notes: 'Pre-clear ride',
      );
      PostRideReportController.instance.addReport(r1);

      final exp1 = Expense(
        id: 'exp-prior-1',
        title: 'Old Filter',
        amount: 450.0,
        trackingMode: ExpenseTrackingMode.manualEntry,
        category: ExpenseCategory.parts,
        dateRecorded: now.subtract(const Duration(hours: 3)),
      );
      TripBudgetController.instance.addExpense(exp1);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  HomeWeatherCardWidget(),
                  GroupBeaconCardWidget(),
                  RecentUpdatesFeedWidget(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Entries should be visible in feed
      expect(find.textContaining('Ride Logged • 45 km'), findsOneWidget);
      expect(find.text('Old Filter'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);

      // Weather and Beacon cards are visible
      expect(find.text('Weather unavailable'), findsOneWidget);
      expect(find.text('Group Beacon: coming soon'), findsOneWidget);

      // 2. Tap Clear -> confirmation dialog appears
      await tester.tap(find.text('Clear'));
      await tester.pump();

      expect(find.text('Clear recent activity?'), findsOneWidget);
      expect(find.textContaining('This hides previous activity from your Home feed'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // 3. Confirm Clear in dialog
      final confirmClearFinder = find.widgetWithText(ElevatedButton, 'Clear');
      expect(confirmClearFinder, findsOneWidget);
      await tester.tap(confirmClearFinder);
      await tester.pump();

      // Feed now shows empty state
      expect(find.text('No recent activity yet'), findsOneWidget);
      expect(find.textContaining('Ride Logged • 45 km'), findsNothing);
      expect(find.text('Old Filter'), findsNothing);

      // Crucial: Real records were NEVER deleted from repositories!
      expect(PostRideReportController.instance.reports.length, equals(1));
      expect(PostRideReportController.instance.reports.first.id, equals('r-prior-1'));
      expect(TripBudgetController.instance.expenses.length, equals(1));
      expect(TripBudgetController.instance.expenses.first.id, equals('exp-prior-1'));

      // Crucial: Clear does NOT affect Weather or Beacon cards
      expect(find.text('Weather unavailable'), findsOneWidget);
      expect(find.text('Group Beacon: coming soon'), findsOneWidget);

      // 4. Log a new activity after the clear
      final r2 = PostRideReport(
        id: 'r-after-1',
        bikeId: 'b1',
        date: DateTime.now().add(const Duration(seconds: 1)),
        distanceKm: 88.0,
        terrainTags: const ['Pass'],
        notes: 'Post-clear new ride',
      );
      PostRideReportController.instance.addReport(r2);
      await tester.pump();

      // New entry shows up normally!
      expect(find.textContaining('Ride Logged • 88 km'), findsOneWidget);
      expect(find.text('No recent activity yet'), findsNothing);
      // Old entry is still hidden
      expect(find.textContaining('Ride Logged • 45 km'), findsNothing);
    });
  });
}
