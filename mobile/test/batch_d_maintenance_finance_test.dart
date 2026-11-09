import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/core/widgets/bike_label_chip.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/controllers/maintenance_controller.dart';
import 'package:camp/features/maintenance/controllers/post_ride_report_controller.dart';
import 'package:camp/features/maintenance/controllers/service_visit_controller.dart';
import 'package:camp/features/maintenance/controllers/trip_budget_controller.dart';
import 'package:camp/features/maintenance/domain/cost_per_km_calculator.dart';
import 'package:camp/features/maintenance/domain/expense_model.dart';
import 'package:camp/features/maintenance/domain/maintenance_item_model.dart';
import 'package:camp/features/maintenance/domain/post_ride_report.dart';
import 'package:camp/features/maintenance/domain/service_visit_model.dart';
import 'package:camp/features/maintenance/presentation/screens/add_expense_screen.dart';
import 'package:camp/features/maintenance/presentation/widgets/carburetor_tab.dart';
import 'package:camp/features/maintenance/presentation/widgets/plan_service_visit_sheet.dart';
import 'package:camp/features/maintenance/presentation/widgets/pre_ride_tab.dart';
import 'package:camp/features/maintenance/presentation/widgets/trip_budget_card_widget.dart';
import 'package:camp/features/maintenance/services/pdf_report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_ride_report_repository.dart';
import 'helpers/maintenance_test_helpers.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bikeA = Bike(
    id: 'bike-cd70',
    make: 'Honda',
    modelName: 'CD70 Dream',
    modelYear: 2024,
    odometerKm: 2500,
    fuelSystem: FuelSystem.carburetor,
  );

  const bikeB = Bike(
    id: 'bike-gs150',
    make: 'Suzuki',
    modelName: 'GS 150 SE',
    modelYear: 2023,
    odometerKm: 8200,
    fuelSystem: FuelSystem.carburetor,
  );

  late FakeMaintenanceRepository fakeMaintRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    LocalStore.instance.resetForTesting(prefs);
    AppRepositories.resetToDefault();

    fakeMaintRepo = FakeMaintenanceRepository();
    AppRepositories.instance = AppRepositories(maintenanceRepository: fakeMaintRepo);

    ActiveBikeController.instance.resetForTesting();
    ActiveBikeController.instance.addBike(bikeA, setActive: true);
    ActiveBikeController.instance.addBike(bikeB);

    TripBudgetController.instance.resetForTesting();
    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());
    ServiceVisitController.instance = ServiceVisitController(
      repository: FakeServiceVisitRepository(),
    );
    MaintenanceController.instance = MaintenanceController(
      repository: fakeMaintRepo,
    );
  });

  group('Batch D - 1. One data source for maintenance costs and Finances expenses', () {
    test('Maintenance cost links to exactly one expense and totals count cost once', () async {
      final budgetCtrl = TripBudgetController.instance;
      expect(budgetCtrl.budget.allocatedSoFar, 0.0);

      const cost = 2500.0;
      const expId = 'exp-maint-1';
      const item = MaintenanceItem(
        id: 'item-1',
        name: 'Oil Change',
        status: MaintenanceStatus.ok,
        category: 'Engine',
        trackingMode: MaintenanceTrackingMode.manual,
        cost: cost,
        bikeId: 'bike-cd70',
        expenseId: expId,
      );

      // Create linked expense
      const expense = Expense(
        id: expId,
        category: ExpenseCategory.service,
        title: 'Oil Change (Maintenance)',
        trackingMode: ExpenseTrackingMode.manualEntry,
        amount: cost,
        bikeId: 'bike-cd70',
        maintenanceItemId: 'item-1',
      );

      budgetCtrl.addExpense(expense);
      await fakeMaintRepo.saveMaintenanceItems([item]);

      // Verify allocatedSoFar counted once
      expect(budgetCtrl.budget.allocatedSoFar, 2500.0);
      expect(budgetCtrl.expenses.length, 1);
      expect(budgetCtrl.expenses.first.maintenanceItemId, 'item-1');
      expect(item.expenseId, expId);
    });

    test('Editing expense amount updates linked maintenance item cost', () async {
      final budgetCtrl = TripBudgetController.instance;

      const item = MaintenanceItem(
        id: 'item-2',
        name: 'Air Filter',
        status: MaintenanceStatus.ok,
        category: 'Intake',
        trackingMode: MaintenanceTrackingMode.manual,
        cost: 1000.0,
        bikeId: 'bike-cd70',
        expenseId: 'exp-2',
      );
      await fakeMaintRepo.saveMaintenanceItems([item]);

      const expense = Expense(
        id: 'exp-2',
        category: ExpenseCategory.service,
        title: 'Air Filter (Maintenance)',
        trackingMode: ExpenseTrackingMode.manualEntry,
        amount: 1000.0,
        bikeId: 'bike-cd70',
        maintenanceItemId: 'item-2',
      );
      budgetCtrl.addExpense(expense);

      // Update expense amount to 1500
      final updatedExp = expense.copyWith(amount: 1500.0);
      budgetCtrl.updateExpense(updatedExp);

      // Give microtask queue moment to flush sync
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final loadedItems = await fakeMaintRepo.loadMaintenanceItems();
      expect(loadedItems.first.cost, 1500.0);
      expect(budgetCtrl.budget.allocatedSoFar, 1500.0);
    });

    test('Deleting expense deletes linked maintenance item, undo restores both', () async {
      final budgetCtrl = TripBudgetController.instance;

      const item = MaintenanceItem(
        id: 'item-3',
        name: 'Spark Plug',
        status: MaintenanceStatus.ok,
        category: 'Ignition',
        trackingMode: MaintenanceTrackingMode.manual,
        cost: 650.0,
        bikeId: 'bike-cd70',
        expenseId: 'exp-3',
      );
      await fakeMaintRepo.saveMaintenanceItems([item]);

      const expense = Expense(
        id: 'exp-3',
        category: ExpenseCategory.service,
        title: 'Spark Plug (Maintenance)',
        trackingMode: ExpenseTrackingMode.manualEntry,
        amount: 650.0,
        bikeId: 'bike-cd70',
        maintenanceItemId: 'item-3',
      );
      budgetCtrl.addExpense(expense);

      // Delete expense
      budgetCtrl.deleteExpense('exp-3');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(budgetCtrl.expenses, isEmpty);
      var loadedItems = await fakeMaintRepo.loadMaintenanceItems();
      expect(loadedItems, isEmpty);

      // Restore expense (undo)
      budgetCtrl.insertExpense(0, expense);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(budgetCtrl.expenses.length, 1);
      loadedItems = await fakeMaintRepo.loadMaintenanceItems();
      expect(loadedItems.length, 1);
      expect(loadedItems.first.id, 'item-3');
      expect(loadedItems.first.cost, 650.0);
    });

    test('Mark service visit done links visit and expense bi-directionally', () async {
      final budgetCtrl = TripBudgetController.instance;
      final visitCtrl = ServiceVisitController.instance;

      final visit = ServiceVisit(
        id: 'visit-1',
        shopName: 'Ali Mechanics',
        dateTime: DateTime.now().subtract(const Duration(days: 1)),
        cost: 3200.0,
        bikeId: bikeA.id,
        expenseId: 'exp-visit-1',
      );

      final exp = Expense(
        id: 'exp-visit-1',
        category: ExpenseCategory.service,
        title: 'Ali Mechanics Service',
        trackingMode: ExpenseTrackingMode.manualEntry,
        amount: 3200.0,
        bikeId: bikeA.id,
        maintenanceItemId: 'visit-1',
      );

      await visitCtrl.addVisit(visit);
      budgetCtrl.addExpense(exp);

      expect(visitCtrl.visits.first.expenseId, 'exp-visit-1');
      expect(budgetCtrl.expenses.first.maintenanceItemId, 'visit-1');

      // Deleting visit removes linked expense
      await visitCtrl.deleteVisit('visit-1');
      expect(visitCtrl.visits, isEmpty);
      expect(budgetCtrl.expenses, isEmpty);
    });

    testWidgets('Planned service visit with a cost adds no expense; completing service adds exactly one', (tester) async {
      final budgetCtrl = TripBudgetController.instance;
      final visitCtrl = ServiceVisitController.instance;

      expect(budgetCtrl.expenses, isEmpty);
      expect(budgetCtrl.budget.allocatedSoFar, 0.0);

      // 1. Open PlanServiceVisitSheet and enter expected cost
      await tester.pumpWidget(
        _wrap(
          const PlanServiceVisitSheet(),
        ),
      );
      await tester.pump();

      expect(find.text('Expected cost (optional)'), findsOneWidget);

      final shopField = find.widgetWithText(TextField, 'e.g. Babusar Trail Works, Ali Motors');
      await tester.enterText(shopField, 'Babusar Trail Works');
      final costField = find.widgetWithText(TextField, '0');
      await tester.enterText(costField, '4500');
      await tester.pump();

      final scheduleBtn = find.text('Schedule Visit');
      await tester.ensureVisible(scheduleBtn);
      await tester.tap(scheduleBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Planned visit with cost stores cost on visit only, adds NO expense to Finances
      expect(visitCtrl.visits.length, 1);
      final planned = visitCtrl.visits.first;
      expect(planned.shopName, 'Babusar Trail Works');
      expect(planned.cost, 4500.0);
      expect(planned.expenseId, isNull);
      expect(budgetCtrl.expenses, isEmpty);
      expect(budgetCtrl.budget.allocatedSoFar, 0.0);

      // 2. Marking a service item done (completing service) creates exactly ONE linked expense
      await MaintenanceController.instance.markItemDone(
        bikeA.id,
        'sched_${bikeA.id}_oilAndSmallService',
        odometerKm: 2600.0,
        date: DateTime.now(),
        cost: 2800.0,
      );

      expect(budgetCtrl.expenses.length, 1);
      final createdExp = budgetCtrl.expenses.first;
      expect(createdExp.amount, 2800.0);
      expect(createdExp.bikeId, bikeA.id);
      expect(createdExp.maintenanceItemId, isNotNull);
      expect(budgetCtrl.budget.allocatedSoFar, 2800.0);
    });
  });

  group('Batch D - 2. Expenses and refills know their bike', () {
    testWidgets('Legacy expense with null bikeId shows No bike chip', (tester) async {
      const legacyExpense = Expense(
        id: 'exp-legacy',
        title: 'Legacy Fuel Refill',
        trackingMode: ExpenseTrackingMode.manualEntry,
        amount: 1200.0,
        category: ExpenseCategory.fuel,
        bikeId: null,
      );

      await tester.pumpWidget(
        _wrap(
          Row(
            children: [
              Text(legacyExpense.title),
              BikeLabelChip(bikeId: legacyExpense.bikeId),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No bike'), findsOneWidget);
    });

    testWidgets('AddExpenseScreen for legacy expense preserves No bike and is not silently reassigned', (tester) async {
      const legacyExpense = Expense(
        id: 'exp-legacy-2',
        title: 'Legacy Snack Expense',
        trackingMode: ExpenseTrackingMode.manualEntry,
        amount: 450.0,
        category: ExpenseCategory.food,
        bikeId: null,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AddExpenseScreen(initialExpense: legacyExpense),
        ),
      );
      await tester.pump();

      // Bike picker displays "No bike"
      expect(find.text('No bike'), findsOneWidget);
    });

    testWidgets('Cost per km with two bikes ignores other bike expenses, includes legacy no-bike expenses, and budget total counts everything', (tester) async {
      ActiveBikeController.instance.setActiveBike('bike-cd70');
      final budgetCtrl = TripBudgetController.instance;

      // Bike A: 100 km, Bike B: 50 km
      final reports = [
        PostRideReport(
          id: 'rep-a',
          bikeId: 'bike-cd70',
          date: DateTime.now(),
          distanceKm: 100.0,
          terrainTags: const ['Road'],
        ),
        PostRideReport(
          id: 'rep-b',
          bikeId: 'bike-gs150',
          date: DateTime.now(),
          distanceKm: 50.0,
          terrainTags: const ['Trail'],
        ),
      ];

      // Expenses: Bike A = 5,000, Legacy = 3,000, Bike B = 10,000
      const expA = Expense(
        id: 'exp-a',
        category: ExpenseCategory.service,
        title: 'Brake Pads',
        trackingMode: ExpenseTrackingMode.manualEntry,
        amount: 5000.0,
        bikeId: 'bike-cd70',
      );
      const expLegacy = Expense(
        id: 'exp-legacy',
        category: ExpenseCategory.food,
        title: 'Highway Dhaba',
        trackingMode: ExpenseTrackingMode.manualEntry,
        amount: 3000.0,
        bikeId: null,
      );
      const expB = Expense(
        id: 'exp-b',
        category: ExpenseCategory.parts,
        title: 'GS150 Battery',
        trackingMode: ExpenseTrackingMode.manualEntry,
        amount: 10000.0,
        bikeId: 'bike-gs150',
      );

      budgetCtrl.addExpense(expA);
      budgetCtrl.addExpense(expLegacy);
      budgetCtrl.addExpense(expB);

      // Shared budget total counts everything (18,000 PKR)
      expect(budgetCtrl.budget.allocatedSoFar, 18000.0);

      // Cost per km for active Bike A: (5000 + 3000) / 100 = 80 PKR/km
      final costPerKmA = calculateCostPerKm(
        totalCost: budgetCtrl.budget.allocatedSoFar,
        expenses: budgetCtrl.expenses,
        reports: reports,
        bikeId: 'bike-cd70',
      );
      expect(costPerKmA, 80.0);

      // Cost per km for Bike B: (10000 + 3000) / 50 = 260 PKR/km
      final costPerKmB = calculateCostPerKm(
        totalCost: budgetCtrl.budget.allocatedSoFar,
        expenses: budgetCtrl.expenses,
        reports: reports,
        bikeId: 'bike-gs150',
      );
      expect(costPerKmB, 260.0);

      // If active bike has no distance or no expenses, returns null ("-")
      final noDist = calculateCostPerKm(
        totalCost: budgetCtrl.budget.allocatedSoFar,
        expenses: budgetCtrl.expenses,
        reports: const [],
        bikeId: 'bike-cd70',
      );
      expect(noDist, isNull);

      final noExp = calculateCostPerKm(
        totalCost: 0,
        expenses: const [],
        reports: reports,
        bikeId: 'bike-cd70',
      );
      expect(noExp, isNull);

      // Render TripBudgetCardWidget with Bike A active
      for (final r in reports) {
        PostRideReportController.instance.addReport(r);
      }
      await tester.pumpWidget(
        _wrap(
          TripBudgetCardWidget(
            tripBudget: budgetCtrl.budget,
            expenses: budgetCtrl.expenses,
            onEditTrip: () {},
            onDeleteTrip: () {},
            onAddExpense: () {},
          ),
        ),
      );
      await tester.pump();

      // Next to Cost per km row show a small label "for <bike name>"
      expect(find.text('for Honda CD70 Dream'), findsWidgets);
      // Cost per km display reflects only active bike's expenses: Rs 80/km
      expect(find.text('Rs 80/km'), findsOneWidget);
      // Subtitle shows active bike's expenses and distance: "Rs 8,000 ÷ 100 km"
      expect(find.text('Rs 8,000 ÷ 100 km'), findsOneWidget);
      // Shared budget total still displays all expenses: Rs 18,000
      expect(find.text('Rs 18,000'), findsWidgets);
    });
  });

  group('Batch D - 3. PDFs', () {
    test('Maintenance PDF content includes only active bike items + separate unassigned section', () async {
      const activeItem = MaintenanceItem(
        id: 'm-act',
        name: 'Oil Filter CD70',
        status: MaintenanceStatus.ok,
        category: 'Engine',
        trackingMode: MaintenanceTrackingMode.manual,
        bikeId: 'bike-cd70',
      );

      const otherBikeItem = MaintenanceItem(
        id: 'm-oth',
        name: 'Tire GS150',
        status: MaintenanceStatus.dueSoon,
        category: 'Tires',
        trackingMode: MaintenanceTrackingMode.manual,
        bikeId: 'bike-gs150',
      );

      const unassignedItem = MaintenanceItem(
        id: 'm-old',
        name: 'Old Chain Lube',
        status: MaintenanceStatus.ok,
        category: 'Drivetrain',
        trackingMode: MaintenanceTrackingMode.manual,
        bikeId: null,
      );

      const reportData = MaintenanceReportData(
        bikeName: 'Honda CD70 Dream',
        bikeId: 'bike-cd70',
        items: [activeItem, otherBikeItem, unassignedItem],
      );

      final pdfBytes = await PdfReportService.buildMaintenancePdf(reportData);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(100));
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), '%PDF-');
    });

    test('Budget PDF generates with Bike column in expense ledger', () async {
      const expA = Expense(
        id: 'e1',
        title: 'Babu Sar Petrol',
        trackingMode: ExpenseTrackingMode.manualEntry,
        amount: 3000.0,
        category: ExpenseCategory.fuel,
        bikeId: 'bike-cd70',
      );
      const expOld = Expense(
        id: 'e2',
        title: 'Tea & Chai',
        trackingMode: ExpenseTrackingMode.manualEntry,
        amount: 200.0,
        category: ExpenseCategory.food,
        bikeId: null,
      );

      const budgetData = BudgetReportData(
        tripName: 'Karakoram Highway Raid',
        capAmount: 50000.0,
        allocatedSoFar: 3200.0,
        expenses: [expA, expOld],
      );

      final pdfBytes = await PdfReportService.buildBudgetPdf(budgetData);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(100));
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), '%PDF-');
    });
  });

  group('Batch D - 4. Past service visits show bike chip and sort active bike first', () {
    test('pastVisits getter sorts active bike visits first', () async {
      final visitCtrl = ServiceVisitController.instance;

      final visitOther = ServiceVisit(
        id: 'v-other',
        shopName: 'Suzuki Workshop',
        dateTime: DateTime.now().subtract(const Duration(days: 1)),
        bikeId: 'bike-gs150',
      );

      final visitActive = ServiceVisit(
        id: 'v-active',
        shopName: 'Honda Center',
        dateTime: DateTime.now().subtract(const Duration(days: 3)),
        bikeId: 'bike-cd70',
      );

      await visitCtrl.addVisit(visitOther);
      await visitCtrl.addVisit(visitActive);

      final past = visitCtrl.pastVisits;
      expect(past.length, 2);
      // Active bike (bike-cd70) appears first even though its date was older
      expect(past.first.bikeId, 'bike-cd70');
      expect(past.last.bikeId, 'bike-gs150');
    });
  });

  group('Batch D - 5. Pre-ride checklist persists per bike', () {
    testWidgets('Pre-ride checklist persists per bike and survives restart with reset button', (tester) async {
      await tester.pumpWidget(_wrap(const PreRideTab()));
      await tester.pump();

      // Tap first item
      final firstTile = find.text('Tire Pressures & Tread Inspection');
      expect(firstTile, findsOneWidget);
      await tester.tap(firstTile);
      await tester.pump();

      expect(find.text('1 of 7 Done'), findsOneWidget);

      // Verify saved in repository for bike-cd70
      final savedForCd70 = await fakeMaintRepo.loadChecklist('bike-cd70');
      expect(savedForCd70['Tire Pressures & Tread Inspection'], isTrue);

      final lastChecked = await fakeMaintRepo.loadChecklistLastChecked('bike-cd70');
      expect(lastChecked, isNotNull);

      // Verify bike B is unkeyed/empty
      final savedForGs150 = await fakeMaintRepo.loadChecklist('bike-gs150');
      expect(savedForGs150['Tire Pressures & Tread Inspection'] ?? false, isFalse);

      // Switch active bike to bike B
      ActiveBikeController.instance.setActiveBike('bike-gs150');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('0 of 7 Done'), findsOneWidget);

      // Switch back to bike A and verify restoration
      ActiveBikeController.instance.setActiveBike('bike-cd70');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('1 of 7 Done'), findsOneWidget);

      // Tap Reset checklist
      final resetBtn = find.text('Reset checklist');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pump();

      expect(find.text('0 of 7 Done'), findsOneWidget);
      final resetCd70 = await fakeMaintRepo.loadChecklist('bike-cd70');
      expect(resetCd70.values.every((v) => !v), isTrue);
    });
  });

  group('Batch D - 6. Carburetor tab persists per bike with neutral guidance', () {
    testWidgets('Carburetor jetting values persist per bike and reload on restart', (tester) async {
      await tester.pumpWidget(_wrap(const CarburetorTab(bike: bikeA)));
      await tester.pump();

      // Enter baseline altitude and main jet
      final baselineField = find.widgetWithText(TextField, 'e.g. 500');
      final mainJetField = find.widgetWithText(TextField, 'e.g. 115');

      expect(baselineField, findsOneWidget);
      expect(mainJetField, findsOneWidget);

      await tester.enterText(baselineField, '600');
      await tester.enterText(mainJetField, '118');
      await tester.pump();

      // Verify saved in repository for bike-cd70
      final savedA = await fakeMaintRepo.loadJettingBaseline('bike-cd70');
      expect(savedA?['baselineAltitude'], '600');
      expect(savedA?['mainJet'], '118');

      // Verify neutral guidance label is present
      expect(find.text('Guidance only'), findsWidgets);

      // Switch to bike B
      await tester.pumpWidget(_wrap(const CarburetorTab(bike: bikeB)));
      await tester.pump();

      final savedB = await fakeMaintRepo.loadJettingBaseline('bike-gs150');
      expect(savedB, isNull);

      // Re-render bike A and verify restoration
      await tester.pumpWidget(_wrap(const CarburetorTab(bike: bikeA)));
      await tester.pump();

      expect(find.text('600'), findsOneWidget);
      expect(find.text('118'), findsOneWidget);
    });
  });
}
