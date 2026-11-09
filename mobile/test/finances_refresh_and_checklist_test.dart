import 'package:camp/app/routes.dart';
import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/controllers/maintenance_controller.dart';
import 'package:camp/features/maintenance/controllers/trip_budget_controller.dart';
import 'package:camp/features/maintenance/domain/expense_model.dart';
import 'package:camp/features/maintenance/domain/maintenance_item_model.dart';
import 'package:camp/features/maintenance/presentation/screens/finance_rig_health_screen.dart';
import 'package:camp/features/maintenance/presentation/screens/maintenance_screen.dart';
import 'package:camp/features/maintenance/presentation/widgets/maintenance_item_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_maintenance_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bike1 = Bike(
    id: 'bike-test-1',
    make: 'Honda',
    modelName: 'Transalp',
    modelYear: 2024,
    odometerKm: 4500,
  );

  const bike2 = Bike(
    id: 'bike-test-2',
    make: 'Yamaha',
    modelName: 'Tenere 700',
    modelYear: 2023,
    odometerKm: 8000,
  );

  late FakeMaintenanceRepository fakeRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    LocalStore.instance.resetForTesting(prefs);
    AppRepositories.resetToDefault();

    fakeRepo = FakeMaintenanceRepository();
    AppRepositories.instance = AppRepositories(maintenanceRepository: fakeRepo);

    ActiveBikeController.instance.resetForTesting();
    ActiveBikeController.instance.addBike(bike1, setActive: true);
    ActiveBikeController.instance.addBike(bike2);

    TripBudgetController.instance.resetForTesting();
    MaintenanceController.instance = MaintenanceController(repository: fakeRepo);
  });

  group('1. Finances List Refresh & Linked Item Synchronization', () {
    testWidgets('Adding an item shows in maintenance list and expense list at once; delete removes both; undo restores both',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: FinanceRigHealthScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no rider-added maintenance items or expenses
      expect(find.text('Brake Caliper Rebuild'), findsNothing);
      expect(find.text('Brake Caliper Rebuild Service'), findsNothing);

      // Add a maintenance item through MaintenanceController with cost
      const newItem = MaintenanceItem(
        id: 'caliper-1',
        name: 'Brake Caliper Rebuild',
        category: 'Brakes',
        status: MaintenanceStatus.dueSoon,
        trackingMode: MaintenanceTrackingMode.manual,
        cost: 3500.0,
        bikeId: 'bike-test-1',
      );

      await MaintenanceController.instance.addMaintenanceItem(newItem);
      await tester.pumpAndSettle();

      // Appears in both maintenance list AND expense list at once
      expect(find.text('Brake Caliper Rebuild'), findsOneWidget);
      expect(find.text('Brake Caliper Rebuild Service'), findsOneWidget);

      // Dismiss / delete item
      final itemInController = MaintenanceController.instance.maintenanceItems.first;
      await MaintenanceController.instance.deleteMaintenanceItem(itemInController.id);
      await tester.pumpAndSettle();

      // Removed from both at once
      expect(find.text('Brake Caliper Rebuild'), findsNothing);
      expect(find.text('Brake Caliper Rebuild Service'), findsNothing);

      // Undo deletion
      await MaintenanceController.instance.insertMaintenanceItem(0, itemInController);
      await tester.pumpAndSettle();

      // Restored in both at once
      expect(find.text('Brake Caliper Rebuild'), findsOneWidget);
      expect(find.text('Brake Caliper Rebuild Service'), findsOneWidget);
    });
  });

  group('2. Maintenance Item Card & Due Soon Unit Formatting', () {
    testWidgets('Maintenance item card does NOT have View Guide and formats Due soon with unit and thousands separator',
        (WidgetTester tester) async {
      const itemWithKm = MaintenanceItem(
        id: 'card-km-1',
        name: 'Fork Oil Flush',
        category: 'Suspension',
        status: MaintenanceStatus.dueSoon,
        trackingMode: MaintenanceTrackingMode.manual,
        conditionNote: 'Due soon • 1000',
        dueMileage: '1000',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MaintenanceItemCardWidget(item: itemWithKm),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No View Guide button or link
      expect(find.text('View Guide'), findsNothing);
      expect(find.textContaining('Guide'), findsNothing);

      // Formatted with thousands separator and unit
      expect(find.text('Due soon • in 1,000 km'), findsOneWidget);
    });

    testWidgets('Formats Due soon with days when dueDate is configured',
        (WidgetTester tester) async {
      const itemWithDays = MaintenanceItem(
        id: 'card-days-1',
        name: 'Coolant Flush',
        category: 'Engine',
        status: MaintenanceStatus.dueSoon,
        trackingMode: MaintenanceTrackingMode.manual,
        conditionNote: 'Due soon • 12',
        dueDate: '12',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MaintenanceItemCardWidget(item: itemWithDays),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Due soon • in 12 days'), findsOneWidget);
    });
  });

  group('3. Refill Rows 2-Decimal Formatting', () {
    test('Refill subtitle formats litres with 2 decimals so litres x price matches PKR', () {
      const expense = Expense(
        id: 'refill-exp-1',
        title: 'Fuel Refill',
        category: ExpenseCategory.fuel,
        trackingMode: ExpenseTrackingMode.manualEntry,
        amount: 2500.4,
        litres: 6.58,
        pricePerLitre: 380.0,
      );

      expect(expense.displaySubtitle, '6.58 L at Rs 380/L');

      const expenseIntegerLitres = Expense(
        id: 'refill-exp-2',
        title: 'Fuel Refill',
        category: ExpenseCategory.fuel,
        trackingMode: ExpenseTrackingMode.manualEntry,
        amount: 3800.0,
        litres: 10.0,
        pricePerLitre: 380.0,
      );

      expect(expenseIntegerLitres.displaySubtitle, '10.00 L at Rs 380/L');
    });
  });

  group('4. Pre-Ride Checklist', () {
    testWidgets('Start Ride opens Maps tab and does not claim ride started',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            CampRoutes.navigationMap: (context) => const Scaffold(
                  body: Text('MAPS TAB ACTIVE'),
                ),
          },
          home: const MaintenanceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Open Pre-Ride tab
      await tester.tap(find.text('Pre-Ride'));
      await tester.pumpAndSettle();

      // Verify spec number removed from "Chain slack & lubrication"
      expect(find.text('Chain slack & lubrication'), findsOneWidget);
      expect(find.textContaining('25-35mm'), findsNothing);

      // Tap Start Ride
      await tester.tap(find.text('Start Ride'));
      await tester.pumpAndSettle();

      // Navigated to Maps tab, no claim of ride started
      expect(find.text('MAPS TAB ACTIVE'), findsOneWidget);
      expect(find.textContaining('Ride started'), findsNothing);
    });

    testWidgets('Custom checks: Add check, count in x of N Done, persist per bike, survive controller restart',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            CampRoutes.navigationMap: (context) => const Scaffold(body: Text('MAPS')),
          },
          home: const MaintenanceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Open Pre-Ride tab
      await tester.tap(find.text('Pre-Ride'));
      await tester.pumpAndSettle();

      // Initially 0 of 7
      expect(find.text('0 of 7 Done'), findsOneWidget);

      // Tap "Add your own check"
      await tester.tap(find.text('Add your own check'));
      await tester.pumpAndSettle();

      // Enter custom check name in dialog
      expect(find.text('Add Custom Check'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Check pannier mounting bolts');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Newly added check appears and total count increases to 8
      expect(find.text('Check pannier mounting bolts'), findsOneWidget);
      expect(find.text('0 of 8 Done'), findsOneWidget);

      // Check the new item
      await tester.tap(find.text('Check pannier mounting bolts'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 8 Done'), findsOneWidget);

      // Verify it persists per bike only
      final bike1Checks = await fakeRepo.loadCustomChecks(bike1.id);
      expect(bike1Checks, contains('Check pannier mounting bolts'));

      final bike2Checks = await fakeRepo.loadCustomChecks(bike2.id);
      expect(bike2Checks, isEmpty);

      // Restart controller / reload custom checks for bike 1
      final newController = MaintenanceController(repository: fakeRepo);
      await newController.loadCustomChecks(bike1.id);
      expect(newController.getCustomChecks(bike1.id), contains('Check pannier mounting bolts'));
      expect(newController.getCustomChecks(bike2.id), isEmpty);
    });

    testWidgets('Custom checks: Deleting works with confirmation and undo',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await fakeRepo.saveCustomChecks(['Check toolkit strap'], bike1.id);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            CampRoutes.navigationMap: (context) => const Scaffold(body: Text('MAPS')),
          },
          home: const MaintenanceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pre-Ride'));
      await tester.pumpAndSettle();

      expect(find.text('Check toolkit strap'), findsOneWidget);

      // Tap delete button for the custom check
      final deleteBtn = find.byTooltip('Delete check');
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Delete Check?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Check is removed
      expect(find.text('Check toolkit strap'), findsNothing);
      expect(find.textContaining('Deleted "Check toolkit strap"'), findsOneWidget);

      // Tap Undo on SnackBar
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // Check restored
      expect(find.text('Check toolkit strap'), findsOneWidget);
    });

    testWidgets('Reset checklist unticks everything but keeps custom checks',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await fakeRepo.saveCustomChecks(['Check satellite communicator'], bike1.id);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            CampRoutes.navigationMap: (context) => const Scaffold(body: Text('MAPS')),
          },
          home: const MaintenanceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pre-Ride'));
      await tester.pumpAndSettle();

      // Tick first built-in check and the custom check
      await tester.tap(find.text('Tire Pressures & Tread Inspection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check satellite communicator'));
      await tester.pumpAndSettle();

      expect(find.text('2 of 8 Done'), findsOneWidget);

      // Tap Reset checklist
      await tester.tap(find.text('Reset checklist'));
      await tester.pumpAndSettle();

      // All unticked (0 of 8 Done), but custom check is preserved
      expect(find.text('0 of 8 Done'), findsOneWidget);
      expect(find.text('Check satellite communicator'), findsOneWidget);
    });
  });
}
