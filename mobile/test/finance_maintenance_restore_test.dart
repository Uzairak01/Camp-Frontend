import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/controllers/maintenance_controller.dart';
import 'package:camp/features/maintenance/controllers/post_ride_report_controller.dart';
import 'package:camp/features/maintenance/controllers/service_visit_controller.dart';
import 'package:camp/features/maintenance/controllers/trip_budget_controller.dart';
import 'package:camp/features/maintenance/domain/maintenance_item_model.dart';
import 'package:camp/features/maintenance/domain/service_schedule_engine.dart';
import 'package:camp/features/maintenance/domain/service_schedule_item.dart';
import 'package:camp/features/maintenance/presentation/screens/add_maintenance_item_screen.dart';
import 'package:camp/features/maintenance/presentation/screens/finance_rig_health_screen.dart';
import 'package:camp/features/maintenance/presentation/screens/service_schedule_screen.dart';
import 'package:camp/features/maintenance/presentation/widgets/maintenance_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_ride_report_repository.dart';
import 'helpers/maintenance_test_helpers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal route-aware wrapper so Navigator.push works in tests.
Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

Widget _wrapScreen(Widget child) => MaterialApp(
      home: child,
    );

/// Shared setUp — clears all singleton state between tests.
Future<void> _setUp() async {
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Item 3: Restored Finances maintenance section ──────────────────────────

  group('Item 3 (restored): Dual overdue km+days display', () {
    test('_formatRemaining shows both km and days when overdue by both', () {
      // Construct a prediction that is overdue by km AND by days
      const item = ServiceScheduleItem(
        id: 'oil',
        bikeId: 'b1',
        type: ServiceItemType.oilAndSmallService,
        intervalKm: 5000,
        intervalMonths: 6,
        lastDoneKm: 0,
        lastDoneDate: null,
        enabled: true,
      );
      // Manually build a prediction to simulate both dimensions overdue
      const pred = ServiceSchedulePrediction(
        item: item,
        scheduleStatus: ScheduleItemStatus.overdue,
        remainingKm: -38855, // overdue by 38,855 km
        remainingDays: -236, // overdue by 236 days
        wearPercent: 100,
      );

      // Use the engine's displaySubtitle which now handles both
      expect(pred.displaySubtitle, contains('38855 km'));
      expect(pred.displaySubtitle, contains('236 days'));
      expect(pred.displaySubtitle, startsWith('Overdue by'));
    });

    test('displaySubtitle shows only km when only km overdue', () {
      const item = ServiceScheduleItem(
        id: 'chain',
        bikeId: 'b1',
        type: ServiceItemType.chain,
        intervalKm: 5000,
        lastDoneKm: 0,
        enabled: true,
      );
      const pred = ServiceSchedulePrediction(
        item: item,
        scheduleStatus: ScheduleItemStatus.overdue,
        remainingKm: -1400,
        remainingDays: null,
        wearPercent: 100,
      );
      expect(pred.displaySubtitle, equals('Overdue by 1400 km'));
    });

    test('displaySubtitle shows only days when only days overdue', () {
      const item = ServiceScheduleItem(
        id: 'air',
        bikeId: 'b1',
        type: ServiceItemType.airFilter,
        intervalMonths: 6,
        lastDoneDate: null,
        enabled: true,
      );
      const pred = ServiceSchedulePrediction(
        item: item,
        scheduleStatus: ScheduleItemStatus.overdue,
        remainingKm: null,
        remainingDays: -12,
        wearPercent: 100,
      );
      expect(pred.displaySubtitle, equals('Overdue by 12 days'));
    });
  });

  group('Item 3 (restored): MaintenanceListWidget — Add Item button visible', () {
    setUp(_setUp);

    testWidgets('Widget shows "+ Add Maintenance Item" button and rider-added items list', (tester) async {
      // No schedule configured (hasSchedule = false)
      final widget = MaintenanceListWidget(
        dueItems: const [],
        hasSchedule: false,
        onSetUpSchedule: () {},
        items: const [],
        onAddMaintenanceItem: () {},
      );

      await tester.pumpWidget(_wrap(widget));
      await tester.pump();

      expect(find.text('+ Add Maintenance Item'), findsOneWidget);
      expect(find.text('Configure Service Schedule'), findsOneWidget);
    });

    testWidgets('Widget shows rider-added item cards when items are provided', (tester) async {
      const items = [
        MaintenanceItem(
          id: 'item-1',
          name: 'Brake Fluid',
          category: 'Fluids',
          status: MaintenanceStatus.ok,
          trackingMode: MaintenanceTrackingMode.manual,
        ),
      ];

      final widget = MaintenanceListWidget(
        dueItems: const [],
        hasSchedule: false,
        onSetUpSchedule: () {},
        items: items,
        onAddMaintenanceItem: () {},
      );

      await tester.pumpWidget(_wrap(widget));
      await tester.pump();

      expect(find.text('Brake Fluid'), findsOneWidget);
      expect(find.text('+ Add Maintenance Item'), findsOneWidget);
    });

    testWidgets('Tapping "+ Add Maintenance Item" button calls onAddMaintenanceItem', (tester) async {
      var called = false;

      final widget = MaintenanceListWidget(
        dueItems: const [],
        hasSchedule: false,
        onSetUpSchedule: () {},
        items: const [],
        onAddMaintenanceItem: () => called = true,
      );

      await tester.pumpWidget(_wrap(widget));
      await tester.pump();

      await tester.tap(find.text('+ Add Maintenance Item'));
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('Wrench IconTile at top-right calls onAddMaintenanceItem', (tester) async {
      var addCalled = false;

      final widget = MaintenanceListWidget(
        dueItems: const [],
        hasSchedule: false,
        onSetUpSchedule: () {},
        items: const [],
        onAddMaintenanceItem: () => addCalled = true,
      );

      await tester.pumpWidget(_wrap(widget));
      await tester.pump();

      // The wrench IconTile is the build_rounded icon near the section header
      await tester.tap(find.byIcon(Icons.build_rounded).first);
      await tester.pump();

      expect(addCalled, isTrue);
    });
  });

  group('Item 3 (restored): Add Maintenance Item flow through FinanceRigHealthScreen', () {
    setUp(_setUp);

    testWidgets('Tapping "+ Add Maintenance Item" opens AddMaintenanceItemScreen', (tester) async {
      await tester.pumpWidget(_wrapScreen(const FinanceRigHealthScreen()));
      await tester.pump();

      // Scroll to find the button (it's below trip budget card)
      await tester.ensureVisible(find.text('+ Add Maintenance Item'));
      await tester.tap(find.text('+ Add Maintenance Item'));
      // Allow navigation to complete
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AddMaintenanceItemScreen), findsOneWidget);
    });

    testWidgets('Due items from schedule are visible alongside Add Item button', (tester) async {
      const bike = Bike(
        id: 'bike-restore',
        make: 'KTM',
        modelName: '390 Adv',
        modelYear: 2023,
        odometerKm: 6000,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      await setScheduleForTest(
        bike.id,
        [
          const ServiceScheduleItem(
            id: 'oil',
            bikeId: 'bike-restore',
            type: ServiceItemType.oilAndSmallService,
            intervalKm: 5000,
            lastDoneKm: 0,
            enabled: true,
          ), // overdue by 1,000 km
        ],
      );

      await tester.pumpWidget(_wrapScreen(const FinanceRigHealthScreen()));
      await tester.pump();

      // Schedule-driven due item visible
      expect(find.text('Engine Oil & Filter'), findsOneWidget);
      expect(find.text('OVERDUE'), findsAtLeastNWidgets(1));

      // Restored Add Item button also visible
      await tester.ensureVisible(find.text('+ Add Maintenance Item'));
      expect(find.text('+ Add Maintenance Item'), findsOneWidget);

      // Configure Service Schedule row also visible
      await tester.ensureVisible(find.text('Configure Service Schedule'));
      expect(find.text('Configure Service Schedule'), findsOneWidget);
    });

    testWidgets('Tapping "Configure Service Schedule" opens ServiceScheduleScreen', (tester) async {
      const bike = Bike(
        id: 'bike-cfg',
        make: 'Yamaha',
        modelName: 'Tenere',
        modelYear: 2024,
        odometerKm: 3000,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      await tester.pumpWidget(_wrapScreen(const FinanceRigHealthScreen()));
      await tester.pump();

      await tester.ensureVisible(find.text('Configure Service Schedule'));
      await tester.tap(find.text('Configure Service Schedule'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ServiceScheduleScreen), findsOneWidget);
    });
  });
}
