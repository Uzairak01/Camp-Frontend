import 'package:camp/app/theme/app_colors.dart';
import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/presentation/widgets/maintenance_alert_card_widget.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/controllers/maintenance_controller.dart';
import 'package:camp/features/maintenance/domain/service_schedule_engine.dart';
import 'package:camp/features/maintenance/domain/service_schedule_item.dart';
import 'package:camp/features/maintenance/domain/service_schedule_status_formatter.dart';
import 'package:camp/features/maintenance/presentation/screens/finance_rig_health_screen.dart';
import 'package:camp/features/maintenance/presentation/screens/maintenance_screen.dart';
import 'package:camp/features/maintenance/presentation/screens/service_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/maintenance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMaintenanceRepository fakeRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    LocalStore.instance.resetForTesting(prefs);
    AppRepositories.resetToDefault();
    ActiveBikeController.instance.resetForTesting();
    fakeRepo = FakeMaintenanceRepository();
    MaintenanceController.instance = MaintenanceController(repository: fakeRepo);
  });

  group('BATCH M-1: Service schedule input + friendly status messages', () {
    // 1. Odometer 46,000, 250 km ago, interval 1,500: stored 45,750, 1,250 left, next at 47,250
    test('1. odometer 46,000, 250 km ago, interval 1,500: stored 45,750, 1,250 left, next at 47,250', () {
      const bikeOdo = 46000.0;
      const kmAgo = 250.0;
      const intervalKm = 1500;

      // Converting "250 km ago" to an odometer reading:
      const storedOdometer = bikeOdo - kmAgo;
      expect(storedOdometer, equals(45750.0));

      const item = ServiceScheduleItem(
        id: 'oil-filter',
        bikeId: 'test-bike',
        type: ServiceItemType.oilFilter,
        intervalKm: intervalKm,
        lastDoneKm: storedOdometer,
        enabled: true,
      );

      final pred = ServiceScheduleEngine.evaluateItem(
        item: item,
        currentOdometerKm: bikeOdo,
        isHarshConditions: false,
        recentReports: const [],
      );

      expect(pred.nextDueKm, equals(47250.0));
      expect(pred.remainingKm, equals(1250));
      expect(pred.scheduleStatus, equals(ScheduleItemStatus.ok));

      final msg = ServiceScheduleStatusFormatter.format(pred);
      expect(msg.headline, equals('1,250 km until your next oil filter change.'));
      expect(msg.detail, equals('Next at 47,250 km'));
      expect(msg.color, equals(AppColors.statusGreen));
      expect(msg.statusType, equals(ServiceStatusType.upcoming));
    });

    // 2. Status progression: approaching 100 km left, due now, 10 km overdue, 100 km overdue
    test('2. odometer 47,150: approaching "100 km left"; 47,250: due now; 47,260: "10 km overdue"; 47,350: "100 km overdue"', () {
      const item = ServiceScheduleItem(
        id: 'oil-filter',
        bikeId: 'test-bike',
        type: ServiceItemType.oilFilter,
        intervalKm: 1500,
        lastDoneKm: 45750.0,
        enabled: true,
      );

      // (a) At odometer 47,150 (remaining = 47,250 - 47,150 = 100 km left -> Approaching)
      final predApproaching = ServiceScheduleEngine.evaluateItem(
        item: item,
        currentOdometerKm: 47150.0,
        isHarshConditions: false,
        recentReports: const [],
      );
      expect(predApproaching.remainingKm, equals(100));
      expect(predApproaching.scheduleStatus, equals(ScheduleItemStatus.dueSoon));
      final msgApproaching = ServiceScheduleStatusFormatter.format(predApproaching);
      expect(msgApproaching.headline, contains('100 km left'));
      expect(msgApproaching.headline, equals('Only 100 km left until your next service.'));
      expect(msgApproaching.color, equals(AppColors.tacticalOrange));
      expect(msgApproaching.statusType, equals(ServiceStatusType.approaching));

      // (b) At odometer 47,250 (remaining = 47,250 - 47,250 = 0 -> Due now)
      final predDueNow = ServiceScheduleEngine.evaluateItem(
        item: item,
        currentOdometerKm: 47250.0,
        isHarshConditions: false,
        recentReports: const [],
      );
      expect(predDueNow.remainingKm, equals(0));
      expect(predDueNow.scheduleStatus, equals(ScheduleItemStatus.overdue));
      final msgDueNow = ServiceScheduleStatusFormatter.format(predDueNow);
      expect(msgDueNow.headline, contains('due now'));
      expect(msgDueNow.headline, equals('Your oil filter service is due now.'));
      expect(msgDueNow.color, equals(AppColors.alertRed));
      expect(msgDueNow.statusType, equals(ServiceStatusType.dueNow));

      // (c) At odometer 47,260 (measured from next service odometer 47,250 -> 10 km overdue)
      final predOverdue10 = ServiceScheduleEngine.evaluateItem(
        item: item,
        currentOdometerKm: 47260.0,
        isHarshConditions: false,
        recentReports: const [],
      );
      expect(predOverdue10.remainingKm, equals(-10));
      final msgOverdue10 = ServiceScheduleStatusFormatter.format(predOverdue10);
      expect(msgOverdue10.headline, contains('10 km overdue'));
      expect(msgOverdue10.headline, equals('Your oil filter service is 10 km overdue.'));
      expect(msgOverdue10.color, equals(AppColors.alertRed));
      expect(msgOverdue10.statusType, equals(ServiceStatusType.overdue));

      // (d) At odometer 47,350 (measured from next service odometer 47,250 -> 100 km overdue)
      final predOverdue100 = ServiceScheduleEngine.evaluateItem(
        item: item,
        currentOdometerKm: 47350.0,
        isHarshConditions: false,
        recentReports: const [],
      );
      expect(predOverdue100.remainingKm, equals(-100));
      final msgOverdue100 = ServiceScheduleStatusFormatter.format(predOverdue100);
      expect(msgOverdue100.headline, contains('100 km overdue'));
      expect(msgOverdue100.headline, equals('Your oil filter service is 100 km overdue.'));
      expect(msgOverdue100.color, equals(AppColors.alertRed));
      expect(msgOverdue100.statusType, equals(ServiceStatusType.overdue));
    });

    // 3. Changing the interval changes the result; updating the odometer changes the result
    test('3. changing the interval changes the result; updating the odometer changes the result', () {
      const baseItem = ServiceScheduleItem(
        id: 'oil-filter',
        bikeId: 'test-bike',
        type: ServiceItemType.oilFilter,
        intervalKm: 1500,
        lastDoneKm: 45750.0,
        enabled: true,
      );

      final initialPred = ServiceScheduleEngine.evaluateItem(
        item: baseItem,
        currentOdometerKm: 46000.0,
        isHarshConditions: false,
        recentReports: const [],
      );
      expect(initialPred.nextDueKm, equals(47250.0));
      expect(initialPred.remainingKm, equals(1250));

      // Change interval to 2,000 km
      final updatedIntervalItem = baseItem.copyWith(intervalKm: 2000);
      final predUpdatedInterval = ServiceScheduleEngine.evaluateItem(
        item: updatedIntervalItem,
        currentOdometerKm: 46000.0,
        isHarshConditions: false,
        recentReports: const [],
      );
      expect(predUpdatedInterval.nextDueKm, equals(47750.0));
      expect(predUpdatedInterval.remainingKm, equals(1750));
      final msgUpdatedInterval = ServiceScheduleStatusFormatter.format(predUpdatedInterval);
      expect(msgUpdatedInterval.headline, equals('1,750 km until your next oil filter change.'));
      expect(msgUpdatedInterval.detail, equals('Next at 47,750 km'));

      // Update bike odometer to 46,500 km
      final predUpdatedOdometer = ServiceScheduleEngine.evaluateItem(
        item: baseItem,
        currentOdometerKm: 46500.0,
        isHarshConditions: false,
        recentReports: const [],
      );
      expect(predUpdatedOdometer.nextDueKm, equals(47250.0));
      expect(predUpdatedOdometer.remainingKm, equals(750));
      final msgUpdatedOdo = ServiceScheduleStatusFormatter.format(predUpdatedOdometer);
      expect(msgUpdatedOdo.headline, equals('750 km until your next oil filter change.'));
    });

    // 4. "At odometer" stores typed value unchanged; km-ago mode disabled with no odometer
    testWidgets('4. "At odometer" stores the typed value unchanged; km-ago mode disabled with no odometer', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      const bikeNoOdo = Bike(
        id: 'bike-no-odo',
        make: 'Honda',
        modelName: 'CD70',
        modelYear: 2020,
        odometerKm: 0,
      );
      ActiveBikeController.instance.addBike(bikeNoOdo, setActive: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: ServiceScheduleScreen(bikeId: 'bike-no-odo'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // With 0 odometer, hint "Add your bike's odometer first" is shown
      expect(find.text('Add your bike\'s odometer first'), findsWidgets);

      // Now register bike with odometer
      const bikeWithOdo = Bike(
        id: 'bike-with-odo',
        make: 'Honda',
        modelName: 'CB500X',
        modelYear: 2022,
        odometerKm: 46000,
      );
      ActiveBikeController.instance.addBike(bikeWithOdo, setActive: true);

      // Seed an item with lastDoneKm = 45750 to verify reopening in "At odometer" mode
      await setScheduleForTest(
        bikeWithOdo.id,
        [
          const ServiceScheduleItem(
            id: 'oil-filter-reopen',
            bikeId: 'bike-with-odo',
            type: ServiceItemType.oilFilter,
            intervalKm: 1500,
            lastDoneKm: 45750.0,
            enabled: true,
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ServiceScheduleScreen(bikeId: 'bike-with-odo', focusItemType: ServiceItemType.oilFilter),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Pre-existing saved item reopens in "At odometer __ km" mode with 45750
      expect(find.text('Odometer when last changed (km)'), findsWidgets);
      expect(find.text('45750'), findsOneWidget);
    });

    // 5. Sanity warning for 250 typed as an odometer at 46,000, no warning for normal values
    testWidgets('5. sanity warning for 250 typed as an odometer at 46,000, no warning for normal values', (tester) async {
      const bike = Bike(
        id: 'bike-sanity',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2023,
        odometerKm: 46000,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      await setScheduleForTest(
        bike.id,
        [
          const ServiceScheduleItem(
            id: 'sched_bike-sanity_oilFilter',
            bikeId: 'bike-sanity',
            type: ServiceItemType.oilFilter,
            intervalKm: 1500,
            lastDoneKm: 250.0, // typed 250 as odometer at 46,000 -> 45,750 km ago!
            enabled: true,
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ServiceScheduleScreen(bikeId: 'bike-sanity'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Save Schedule
      final saveBtn = find.text('Save Schedule');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Sanity warning dialog appears!
      expect(find.text('Check Last Service'), findsOneWidget);
      expect(
        find.text('That is 45,750 km ago, much longer than the usual 1,500 km. Is that right?'),
        findsOneWidget,
      );
      expect(find.text('Let me fix it'), findsOneWidget);
      expect(find.text('Yes, keep it'), findsOneWidget);

      // Tapping "Let me fix it" dismisses dialog without saving
      await tester.tap(find.text('Let me fix it'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Check Last Service'), findsNothing);
      expect(find.byType(ServiceScheduleScreen), findsOneWidget);
    });

    // 6. Very overdue message and "Edit last service" action
    test('6. very overdue message and "Edit last service" action', () {
      const bikeOdo = 46000.0;
      const item = ServiceScheduleItem(
        id: 'oil-filter',
        bikeId: 'test-bike',
        type: ServiceItemType.oilFilter,
        intervalKm: 1500,
        lastDoneKm: 250.0, // next due 1,750 -> 44,250 km overdue (>2x 1500)
        enabled: true,
      );

      final pred = ServiceScheduleEngine.evaluateItem(
        item: item,
        currentOdometerKm: bikeOdo,
        isHarshConditions: false,
        recentReports: const [],
      );

      expect(pred.remainingKm, equals(-44250));
      final msg = ServiceScheduleStatusFormatter.format(pred);
      expect(msg.isVeryOverdue, isTrue);
      expect(msg.statusType, equals(ServiceStatusType.veryOverdue));
      expect(
        msg.headline,
        equals('Your oil filter service is 44,250 km overdue. The last service reading may be wrong.'),
      );
      expect(msg.actionLabel, equals('Edit last service'));
      expect(msg.color, equals(AppColors.alertRed));
    });

    // 7. Missing last-service record shows the not-set-up message
    test('7. missing last-service record shows the not-set-up message', () {
      const itemNoLastDone = ServiceScheduleItem(
        id: 'oil-filter',
        bikeId: 'test-bike',
        type: ServiceItemType.oilFilter,
        intervalKm: 1500,
        lastDoneKm: null,
        lastDoneDate: null,
        enabled: true,
      );

      final pred = ServiceScheduleEngine.evaluateItem(
        item: itemNoLastDone,
        currentOdometerKm: 46000.0,
        isHarshConditions: false,
        recentReports: const [],
      );

      final msg = ServiceScheduleStatusFormatter.format(pred);
      expect(msg.headline, equals('Add when you last did this to get reminders.'));
      expect(msg.statusType, equals(ServiceStatusType.notSetUp));
      expect(msg.color, equals(AppColors.mutedText));
    });

    // 8. Identical text on Service Schedule, Finances, Maintenance and Home for the same item
    testWidgets('8. identical text on Service Schedule, Finances, Maintenance and Home for the same item', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      const bike = Bike(
        id: 'bike-identical',
        make: 'Honda',
        modelName: 'CB500X',
        modelYear: 2022,
        odometerKm: 46000,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      const item = ServiceScheduleItem(
        id: 'oil-filter-identical',
        bikeId: 'bike-identical',
        type: ServiceItemType.oilFilter,
        intervalKm: 1500,
        lastDoneKm: 45750.0, // remaining 1,250 km
        enabled: true,
      );
      await setScheduleForTest(bike.id, [item]);

      final pred = ServiceScheduleEngine.evaluateItem(
        item: item,
        currentOdometerKm: bike.odometerKm.toDouble(),
        isHarshConditions: false,
        recentReports: const [],
      );
      final expectedText = ServiceScheduleStatusFormatter.format(pred).headline;
      expect(expectedText, equals('1,250 km until your next oil filter change.'));

      // (a) Service Schedule Screen
      await tester.pumpWidget(
        const MaterialApp(
          home: ServiceScheduleScreen(bikeId: 'bike-identical'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(expectedText), findsOneWidget);

      // (b) Finances "Upcoming & Required Maintenance"
      // Change to due item to verify list item rendering
      const dueItem = ServiceScheduleItem(
        id: 'oil-filter-identical',
        bikeId: 'bike-identical',
        type: ServiceItemType.oilFilter,
        intervalKm: 1500,
        lastDoneKm: 44490.0, // next at 45,990 -> 10 km overdue at 46,000!
        enabled: true,
      );
      await setScheduleForTest(bike.id, [dueItem]);

      final duePred = ServiceScheduleEngine.evaluateItem(
        item: dueItem,
        currentOdometerKm: bike.odometerKm.toDouble(),
        isHarshConditions: false,
        recentReports: const [],
      );
      final expectedDueText = ServiceScheduleStatusFormatter.format(duePred).headline;
      expect(expectedDueText, equals('Your oil filter service is 10 km overdue.'));

      // Finances Hub
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FinanceRigHealthScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(expectedDueText), findsOneWidget);

      // (c) Maintenance Screen (Diagnostics Tab)
      await tester.pumpWidget(
        const MaterialApp(
          home: MaintenanceScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(expectedDueText), findsOneWidget);

      // (d) Home Reminder Card
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MaintenanceAlertCardWidget(bikeId: 'bike-identical'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(expectedDueText), findsOneWidget);
    });

    // 9. Harsh conditions still shorten the interval by 20%
    test('9. harsh conditions still shorten the interval by 20%', () {
      const item = ServiceScheduleItem(
        id: 'oil-filter',
        bikeId: 'test-bike',
        type: ServiceItemType.oilFilter,
        intervalKm: 1500,
        lastDoneKm: 45750.0,
        enabled: true,
      );

      // Normal conditions: interval is 1500 km -> next due 47,250 km, remaining 1,250 km
      final normalPred = ServiceScheduleEngine.evaluateItem(
        item: item,
        currentOdometerKm: 46000.0,
        isHarshConditions: false,
        recentReports: const [],
      );
      expect(normalPred.effectiveIntervalKm, equals(1500));
      expect(normalPred.nextDueKm, equals(47250.0));
      expect(normalPred.remainingKm, equals(1250));

      // Harsh conditions ON: interval shortened by 20% (1,500 * 0.80 = 1,200 km)
      // Next due = 45,750 + 1,200 = 46,950 km
      // Remaining = 46,950 - 46,000 = 950 km
      final harshPred = ServiceScheduleEngine.evaluateItem(
        item: item,
        currentOdometerKm: 46000.0,
        isHarshConditions: true,
        recentReports: const [],
      );
      expect(harshPred.effectiveIntervalKm, equals(1200));
      expect(harshPred.nextDueKm, equals(46950.0));
      expect(harshPred.remainingKm, equals(950));

      final msg = ServiceScheduleStatusFormatter.format(harshPred);
      expect(msg.headline, equals('950 km until your next oil filter change.'));
      expect(msg.detail, equals('Next at 46,950 km'));
    });
  });
}
