import 'dart:typed_data';

import 'package:camp/core/storage/local_store.dart';
import 'package:camp/core/utils/currency_formatter.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/controllers/post_ride_report_controller.dart';
import 'package:camp/features/maintenance/controllers/service_visit_controller.dart';
import 'package:camp/features/maintenance/controllers/trip_budget_controller.dart';
import 'package:camp/features/maintenance/domain/cost_per_km_calculator.dart';
import 'package:camp/features/maintenance/domain/expense_model.dart';
import 'package:camp/features/maintenance/domain/maintenance_item_model.dart';
import 'package:camp/features/maintenance/domain/post_ride_report.dart';
import 'package:camp/features/maintenance/domain/service_visit_model.dart';
import 'package:camp/features/maintenance/domain/trip_budget_model.dart';
import 'package:camp/features/maintenance/presentation/widgets/delete_trip_dialog_widget.dart';
import 'package:camp/features/maintenance/presentation/widgets/service_visit_card_widget.dart';
import 'package:camp/features/maintenance/presentation/widgets/trip_budget_card_widget.dart';
import 'package:camp/features/maintenance/services/pdf_report_service.dart';
import 'package:camp/features/settings/controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_ride_report_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStore.instance.resetForTesting();
  });

  group('Cost per KM Calculator Tests', () {
    final tripStart = DateTime(2026, 10, 10);
    final tripEnd = DateTime(2026, 10, 20);

    final trackedReports = <PostRideReport>[
      PostRideReport(
        id: 'r1',
        bikeId: 'bike-1',
        date: DateTime(2026, 10, 12), // Inside window
        distanceKm: 150.0,
        terrainTags: const ['Pass'],
      ),
      PostRideReport(
        id: 'r2',
        bikeId: 'bike-1',
        date: DateTime(2026, 10, 14), // Inside window
        distanceKm: 250.0,
        terrainTags: const ['Trail'],
      ),
      PostRideReport(
        id: 'r3',
        bikeId: 'bike-1',
        date: DateTime(2026, 10, 5), // Before window
        distanceKm: 500.0,
        terrainTags: const ['Highway'],
      ),
      PostRideReport(
        id: 'r4',
        bikeId: 'bike-1',
        date: DateTime(2026, 10, 25), // After window
        distanceKm: 300.0,
        terrainTags: const ['Mountain'],
      ),
    ];

    test('Computes cost per km from rides within trip window only', () {
      final budget = TripBudget(
        tripName: 'Alpine Tour',
        capAmount: 50000.0,
        allocatedSoFar: 20000.0, // 20,000 PKR / (150 + 250) km = 20,000 / 400 = 50 PKR/km
        startDate: tripStart.toIso8601String(),
        endDate: tripEnd.toIso8601String(),
      );

      final result = calculateCostPerKm(
        totalCost: budget.allocatedSoFar,
        tripStartDate: budget.parsedStartDate,
        tripEndDate: budget.parsedEndDate,
        reports: trackedReports,
      );

      expect(result, isNotNull);
      expect(result, 50.0);
      expect('${formatPkr(result!)}/km', '${formatPkr(50)}/km');
    });

    test('Returns null when no distance is recorded (never divides by odometer)', () {
      final budget = TripBudget(
        tripName: 'Alpine Tour',
        capAmount: 50000.0,
        allocatedSoFar: 20000.0,
        startDate: tripStart.toIso8601String(),
        endDate: tripEnd.toIso8601String(),
      );

      final result = calculateCostPerKm(
        totalCost: budget.allocatedSoFar,
        tripStartDate: budget.parsedStartDate,
        tripEndDate: budget.parsedEndDate,
        reports: const [], // Empty ride history
      );

      expect(result, isNull);
    });

    test('Returns null when distance is 0.0 to prevent division by zero', () {
      final budget = TripBudget(
        tripName: 'Alpine Tour',
        capAmount: 50000.0,
        allocatedSoFar: 20000.0,
        startDate: tripStart.toIso8601String(),
        endDate: tripEnd.toIso8601String(),
      );

      final zeroReports = <PostRideReport>[
        PostRideReport(
          id: 'rz',
          bikeId: 'b1',
          date: DateTime(2026, 10, 12),
          distanceKm: 0.0,
          terrainTags: const ['Trail'],
        ),
      ];

      final result = calculateCostPerKm(
        totalCost: budget.allocatedSoFar,
        tripStartDate: budget.parsedStartDate,
        tripEndDate: budget.parsedEndDate,
        reports: zeroReports,
      );

      expect(result, isNull);
    });

    test('Calculates correctly when under, at cap, and over budget', () {
      // 1. Under budget: 10,000 / 400 = 25 PKR/km
      final underCost = calculateCostPerKm(
        totalCost: 10000.0,
        tripStartDate: tripStart,
        tripEndDate: tripEnd,
        reports: trackedReports,
      );
      expect(underCost, 25.0);
      expect('${formatPkr(underCost!)}/km', '${formatPkr(25)}/km');

      // 2. Exactly at cap: 50,000 / 400 = 125 PKR/km
      final atCapCost = calculateCostPerKm(
        totalCost: 50000.0,
        tripStartDate: tripStart,
        tripEndDate: tripEnd,
        reports: trackedReports,
      );
      expect(atCapCost, 125.0);
      expect('${formatPkr(atCapCost!)}/km', '${formatPkr(125)}/km');

      // 3. Over budget: 60,000 / 400 = 150 PKR/km
      final overCost = calculateCostPerKm(
        totalCost: 60000.0,
        tripStartDate: tripStart,
        tripEndDate: tripEnd,
        reports: trackedReports,
      );
      expect(overCost, 150.0);
      expect('${formatPkr(overCost!)}/km', '${formatPkr(150)}/km');
    });
  });

  group('TripBudget Over-Budget Calculations & Strings', () {
    test('Under budget has isUnderBudget true and positive underBudgetAmount', () {
      const budget = TripBudget(
        tripName: 'Karakoram',
        capAmount: 60000.0,
        allocatedSoFar: 45000.0,
      );

      expect(budget.isUnderBudget, isTrue);
      expect(budget.underBudgetAmount, 15000.0);
      expect(budget.spentPercentInt, 75);
    });

    test('Exactly at budget cap has underBudgetAmount == 0.0 and spent 100%', () {
      const budget = TripBudget(
        tripName: 'Karakoram',
        capAmount: 50000.0,
        allocatedSoFar: 50000.0,
      );

      expect(budget.isUnderBudget, isTrue);
      expect(budget.underBudgetAmount, 0.0);
      expect(budget.spentPercentInt, 100);
    });

    test('Over budget has isUnderBudget false and negative underBudgetAmount', () {
      const budget = TripBudget(
        tripName: 'Karakoram',
        capAmount: 50000.0,
        allocatedSoFar: 65000.0,
      );

      expect(budget.isUnderBudget, isFalse);
      expect(budget.underBudgetAmount, -15000.0);
      expect(budget.spentPercentInt, 130);
    });

    test('TripBudget tolerant JSON parsing handles strings, doubles, and dates', () {
      final json = {
        'tripName': 'Skardu Express',
        'capAmount': '40000',
        'allocatedSoFar': '22500',
        'startDate': '2026-06-01',
        'endDate': '2026-06-10',
      };

      final parsed = TripBudget.fromJson(json);
      expect(parsed.tripName, 'Skardu Express');
      expect(parsed.capAmount, 40000.0);
      expect(parsed.allocatedSoFar, 22500.0);
      expect(parsed.startDate, '2026-06-01');
      expect(parsed.endDate, '2026-06-10');
      expect(parsed.dateRangeDisplay, '2026-06-01 – 2026-06-10');
    });
  });

  group('TripBudgetController CRUD & Total Recalculation', () {
    late TripBudgetController controller;

    setUp(() {
      controller = TripBudgetController();
      controller.resetForTesting();
    });

    test('Adding an expense increases allocatedSoFar immediately', () {
      expect(controller.expenses.length, 0);
      expect(controller.budget.allocatedSoFar, 0.0);

      controller.addExpense(const Expense(
        id: 'exp-1',
        title: 'Fuel Fillup',
        amount: 3500.0,
        category: ExpenseCategory.fuel,
        trackingMode: ExpenseTrackingMode.manualEntry,
      ));

      expect(controller.expenses.length, 1);
      expect(controller.budget.allocatedSoFar, 3500.0);
    });

    test('Updating an expense updates allocatedSoFar immediately', () {
      controller.addExpense(const Expense(
        id: 'exp-1',
        title: 'Fuel Fillup',
        amount: 3500.0,
        category: ExpenseCategory.fuel,
        trackingMode: ExpenseTrackingMode.manualEntry,
      ));

      expect(controller.budget.allocatedSoFar, 3500.0);

      controller.updateExpense(const Expense(
        id: 'exp-1',
        title: 'Fuel Fillup',
        amount: 4500.0, // increased by 1,000
        category: ExpenseCategory.fuel,
        trackingMode: ExpenseTrackingMode.manualEntry,
      ));

      expect(controller.budget.allocatedSoFar, 4500.0);
      expect(controller.expenses.first.amount, 4500.0);
    });

    test('Deleting an expense decreases allocatedSoFar immediately', () {
      controller.addExpense(const Expense(
        id: 'exp-1',
        title: 'Fuel',
        amount: 3000.0,
        category: ExpenseCategory.fuel,
        trackingMode: ExpenseTrackingMode.manualEntry,
      ));
      controller.addExpense(const Expense(
        id: 'exp-2',
        title: 'Camp Permit',
        amount: 2000.0,
        category: ExpenseCategory.permits,
        trackingMode: ExpenseTrackingMode.manualEntry,
      ));

      expect(controller.budget.allocatedSoFar, 5000.0);

      controller.deleteExpense('exp-1');

      expect(controller.expenses.length, 1);
      expect(controller.budget.allocatedSoFar, 2000.0);
    });

    test('Inserting expense at index (Undo) restores list and total', () {
      const exp1 = Expense(
        id: 'exp-1',
        title: 'Toll',
        amount: 800.0,
        category: ExpenseCategory.other,
        trackingMode: ExpenseTrackingMode.manualEntry,
      );
      const exp2 = Expense(
        id: 'exp-2',
        title: 'Lunch',
        amount: 1200.0,
        category: ExpenseCategory.food,
        trackingMode: ExpenseTrackingMode.manualEntry,
      );

      controller.addExpense(exp1);
      controller.addExpense(exp2);
      expect(controller.budget.allocatedSoFar, 2000.0);

      controller.deleteExpense('exp-1');
      expect(controller.budget.allocatedSoFar, 1200.0);

      controller.insertExpense(0, exp1);
      expect(controller.expenses.length, 2);
      expect(controller.budget.allocatedSoFar, 2000.0);
      expect(controller.expenses.first.id, 'exp-1');
    });
  });

  group('ServiceVisit Model & Controller Filtering', () {
    test('ServiceVisit serialization round-trip', () {
      final visit = ServiceVisit(
        id: 'sv-101',
        shopName: 'KTM Karakoram Outpost',
        dateTime: DateTime(2026, 11, 20, 14, 30),
        note: 'Replace clutch cables and oil filter',
        phone: '+92 300 1234567',
        latitude: 35.8812,
        longitude: 74.4641,
      );

      final json = visit.toJson();
      final revived = ServiceVisit.fromJson(json);

      expect(revived.id, visit.id);
      expect(revived.shopName, visit.shopName);
      expect(revived.dateTime, visit.dateTime);
      expect(revived.note, visit.note);
      expect(revived.phone, visit.phone);
      expect(revived.latitude, visit.latitude);
      expect(revived.longitude, visit.longitude);
    });

    test('Controller filters past visits and returns next planned future visit', () {
      final controller = ServiceVisitController();

      final now = DateTime.now();

      // Past visit (2 days ago)
      final pastVisit = ServiceVisit(
        id: 'v-past',
        shopName: 'Past Auto',
        dateTime: now.subtract(const Duration(days: 2)),
      );

      // Future visit 1 (tomorrow)
      final tomorrowVisit = ServiceVisit(
        id: 'v-tomorrow',
        shopName: 'Peak Moto Workshop',
        dateTime: now.add(const Duration(days: 1)),
      );

      // Future visit 2 (next week)
      final nextWeekVisit = ServiceVisit(
        id: 'v-nextweek',
        shopName: 'Hunza Garage',
        dateTime: now.add(const Duration(days: 7)),
      );

      controller.addVisit(nextWeekVisit);
      controller.addVisit(pastVisit);
      controller.addVisit(tomorrowVisit);

      // nextPlannedVisit must ignore past visit and pick the earliest upcoming one (tomorrow)
      final next = controller.nextPlannedVisit;
      expect(next, isNotNull);
      expect(next!.id, 'v-tomorrow');
      expect(next.shopName, 'Peak Moto Workshop');
    });
  });

  group('PDF Generator Pure Functions', () {
    test('PdfReportService.buildBudgetPdf generates valid PDF bytes', () async {
      const budgetData = BudgetReportData(
        tripName: 'Karakoram Highway Rally',
        dateRange: 'Oct 10 – Oct 20, 2026',
        capAmount: 85000.0,
        allocatedSoFar: 62000.0,
        costPerKmDisplay: 'Rs 42/km',
        expenses: [
          Expense(
            id: 'e1',
            title: 'High-octane fuel',
            amount: 14500.0,
            category: ExpenseCategory.fuel,
            trackingMode: ExpenseTrackingMode.manualEntry,
          ),
          Expense(
            id: 'e2',
            title: 'Basecamp permit',
            amount: 8000.0,
            category: ExpenseCategory.permits,
            trackingMode: ExpenseTrackingMode.manualEntry,
          ),
        ],
      );

      final Uint8List pdfBytes = await PdfReportService.buildBudgetPdf(budgetData);
      expect(pdfBytes, isNotEmpty);
      // PDF documents start with '%PDF-' (bytes: 0x25, 0x50, 0x44, 0x46, 0x2D)
      expect(pdfBytes.length, greaterThan(100));
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), '%PDF-');
    });

    test('PdfReportService.buildMaintenancePdf generates valid PDF bytes', () async {
      const maintenanceData = MaintenanceReportData(
        bikeName: 'KTM 890 Adventure R',
        odometerKm: 14200,
        items: [
          MaintenanceItem(
            id: 'm1',
            name: 'Engine Oil & Filter',
            status: MaintenanceStatus.dueSoon,
            category: 'Fluids',
            trackingMode: MaintenanceTrackingMode.manual,
          ),
          MaintenanceItem(
            id: 'm2',
            name: 'Brake Pads Front',
            status: MaintenanceStatus.ok,
            category: 'Brakes',
            trackingMode: MaintenanceTrackingMode.manual,
          ),
        ],
      );

      final Uint8List pdfBytes =
          await PdfReportService.buildMaintenancePdf(maintenanceData);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(100));
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), '%PDF-');
    });
  });

  group('Widget Tests: Dialogs & Service Visit Cards', () {
    testWidgets('DeleteTripDialogWidget displays expense count and calls onConfirmDelete',
        (tester) async {
      bool deleteTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeleteTripDialogWidget(
              tripName: 'Alpine Ridge Tour',
              expenseCount: 5,
              onConfirmDelete: () => deleteTriggered = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete Alpine Ridge Tour?'), findsOneWidget);
      expect(
        find.text(
          'This will delete 5 expenses with it. Your maintenance records will stay.',
        ),
        findsOneWidget,
      );

      // Verify Delete button
      final deleteBtn = find.text('Delete');
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(deleteTriggered, isTrue);
    });

    testWidgets('ServiceVisitCardWidget shows empty state with Plan a visit button',
        (tester) async {
      bool planTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceVisitCardWidget(
              visit: null,
              onPlanVisit: () => planTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NEXT SERVICE VISIT'), findsOneWidget);
      expect(find.text('No service visit planned'), findsOneWidget);

      final planBtn = find.text('Plan a visit');
      expect(planBtn, findsOneWidget);

      await tester.tap(planBtn);
      await tester.pumpAndSettle();
      expect(planTapped, isTrue);
    });

    testWidgets('ServiceVisitCardWidget shows Planned chip (never Confirmed) and conditional Call/Directions',
        (tester) async {
      // 1. Visit with phone and coords
      final fullVisit = ServiceVisit(
        id: 'sv-1',
        shopName: 'Peak Moto Specialists',
        dateTime: DateTime.now().add(const Duration(days: 3)),
        phone: '+92 312 9998877',
        latitude: 34.1234,
        longitude: 73.5678,
        note: 'Check chain slack & sprocket wear',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceVisitCardWidget(
              visit: fullVisit,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Planned'), findsOneWidget);
      expect(find.text('Confirmed'), findsNothing);
      expect(find.text('CONFIRMED'), findsNothing);
      expect(find.text('Peak Moto Specialists'), findsOneWidget);
      expect(find.text('Check chain slack & sprocket wear'), findsOneWidget);
      expect(find.text('📞 Call Shop'), findsOneWidget);
      expect(find.text('🗺 Directions'), findsOneWidget);

      // 2. Visit without phone or coords hides Call & Directions
      final simpleVisit = ServiceVisit(
        id: 'sv-2',
        shopName: 'Roadside Mechanic',
        dateTime: DateTime.now().add(const Duration(days: 2)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceVisitCardWidget(
              visit: simpleVisit,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Roadside Mechanic'), findsOneWidget);
      expect(find.text('📞 Call Shop'), findsNothing);
      expect(find.text('🗺 Directions'), findsNothing);
    });
  });

  group('TripBudgetCardWidget Hero Card & Fuel Economics Tests', () {
    final tripStartDate = DateTime(2026, 10, 10);
    final tripEndDate = DateTime(2026, 10, 20);

    const testExpenses = [
      Expense(
        id: 'e1',
        title: 'Dinner at Abbottabad',
        amount: 2500.0,
        category: ExpenseCategory.food,
        trackingMode: ExpenseTrackingMode.manualEntry,
      ),
      Expense(
        id: 'e2',
        title: 'Fuel refill',
        amount: 4500.0,
        category: ExpenseCategory.fuel,
        trackingMode: ExpenseTrackingMode.manualEntry,
      ),
      Expense(
        id: 'e3',
        title: 'Brake pad replacement',
        amount: 3000.0,
        category: ExpenseCategory.service,
        trackingMode: ExpenseTrackingMode.manualEntry,
      ),
      Expense(
        id: 'e4',
        title: 'Toll & misc',
        amount: 3000.0,
        category: ExpenseCategory.other,
        trackingMode: ExpenseTrackingMode.manualEntry,
      ),
    ];

    setUp(() {
      ActiveBikeController.instance.resetForTesting();
      PostRideReportController.instance =
          PostRideReportController(repository: FakeRideReportRepository());
      SettingsController.instance.resetForTesting();
    });

    testWidgets('Chips row not present; total, budget cap, progress bar and Cost per km kept',
        (tester) async {
      final budget = TripBudget(
        tripName: 'Karakoram Tour',
        capAmount: 50000.0,
        allocatedSoFar: 13000.0,
        startDate: tripStartDate.toIso8601String(),
        endDate: tripEndDate.toIso8601String(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TripBudgetCardWidget(
                tripBudget: budget,
                expenses: testExpenses,
                onEditTrip: () {},
                onDeleteTrip: () {},
                onAddExpense: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Category chips row must be completely removed:
      // The chips "Other: Rs 3,000", "Food: Rs 2,500", "Service: Rs 3,000", "Fuel: Rs 4,500" must not be present
      expect(find.text('Other: Rs 3,000'), findsNothing);
      expect(find.text('Food: Rs 2,500'), findsNothing);
      expect(find.text('Service: Rs 3,000'), findsNothing);
      expect(find.text('Fuel: Rs 4,500'), findsNothing);

      // Keep total, budget cap, over/under budget text, progress bar, Cost per km
      expect(find.text('Rs 13,000'), findsOneWidget);
      expect(find.text('/ Rs 50,000 Budget Cap'), findsOneWidget);
      expect(find.textContaining('under target budget'), findsOneWidget);
      expect(find.text('Allocation Spent'), findsOneWidget);
      expect(find.text('Cost per km'), findsOneWidget);
      expect(find.text('Fuel cost per km'), findsOneWidget);
    });

    testWidgets('Line shows total, distance and fuel price when all data is present',
        (tester) async {
      SettingsController.instance.setFuelPricePerLiter(390.0);
      ActiveBikeController.instance.addBike(
        const Bike(
          id: 'bike-1',
          make: 'Honda',
          modelName: 'CB500X',
          modelYear: 2023,
          odometerKm: 5000,
          fuelAverageKmPerLiter: 40.0,
        ),
        setActive: true,
      );
      PostRideReportController.instance.addReport(
        PostRideReport(
          id: 'r1',
          bikeId: 'bike-1',
          date: DateTime(2026, 10, 15),
          distanceKm: 200.0,
          terrainTags: const ['Highway'],
        ),
      );

      final budget = TripBudget(
        tripName: 'Karakoram Tour',
        capAmount: 50000.0,
        allocatedSoFar: 20000.0,
        startDate: tripStartDate.toIso8601String(),
        endDate: tripEndDate.toIso8601String(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TripBudgetCardWidget(
                tripBudget: budget,
                expenses: testExpenses,
                onEditTrip: () {},
                onDeleteTrip: () {},
                onAddExpense: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Total Cost per km = 20,000 PKR / 200 km = Rs 100/km
      expect(find.text('Rs 100/km'), findsOneWidget);
      // Muted line shows total and distance: "Rs 20,000 ÷ 200 km"
      expect(find.text('Rs 20,000 ÷ 200 km'), findsOneWidget);

      // Fuel cost per km = 390 / 40 = Rs 9.75/km
      expect(find.text('Rs 9.75/km'), findsOneWidget);
      // Muted line shows fuel price and bike average: "Rs 390/L ÷ 40 km/L"
      expect(find.text('Rs 390/L ÷ 40 km/L'), findsOneWidget);
    });

    testWidgets('Fuel price missing shows the "Set fuel price" link and keeps "-" for fuel cost',
        (tester) async {
      SettingsController.instance.setFuelPricePerLiter(null);
      ActiveBikeController.instance.addBike(
        const Bike(
          id: 'bike-1',
          make: 'Honda',
          modelName: 'CB500X',
          modelYear: 2023,
          odometerKm: 5000,
          fuelAverageKmPerLiter: 40.0,
        ),
        setActive: true,
      );

      final budget = TripBudget(
        tripName: 'Karakoram Tour',
        capAmount: 50000.0,
        allocatedSoFar: 20000.0,
        startDate: tripStartDate.toIso8601String(),
        endDate: tripEndDate.toIso8601String(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TripBudgetCardWidget(
                tripBudget: budget,
                expenses: const [],
                onEditTrip: () {},
                onDeleteTrip: () {},
                onAddExpense: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Fuel price missing shows "Set fuel price" link
      expect(find.text('Set fuel price'), findsOneWidget);
      // No guessing or fallback numbers
      expect(find.text('Rs 9.75/km'), findsNothing);
      expect(find.textContaining('÷ 40 km/L'), findsNothing);
    });

    testWidgets('Distance missing keeps "-" for total Cost per km',
        (tester) async {
      SettingsController.instance.setFuelPricePerLiter(390.0);
      ActiveBikeController.instance.addBike(
        const Bike(
          id: 'bike-1',
          make: 'Honda',
          modelName: 'CB500X',
          modelYear: 2023,
          odometerKm: 5000,
          fuelAverageKmPerLiter: 40.0,
        ),
        setActive: true,
      );
      // Ensure no reports exist for the trip period
      PostRideReportController.instance =
          PostRideReportController(repository: FakeRideReportRepository());

      final budget = TripBudget(
        tripName: 'Karakoram Tour',
        capAmount: 50000.0,
        allocatedSoFar: 20000.0,
        startDate: tripStartDate.toIso8601String(),
        endDate: tripEndDate.toIso8601String(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TripBudgetCardWidget(
                tripBudget: budget,
                expenses: const [],
                onEditTrip: () {},
                onDeleteTrip: () {},
                onAddExpense: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Total Cost per km displays "-" when distance is missing
      expect(find.text('-'), findsOneWidget);
      expect(find.text('Rs 20,000 ÷ 0 km'), findsOneWidget);

      // Fuel cost per km still works if fuel price and bike average exist
      expect(find.text('Rs 9.75/km'), findsOneWidget);
      expect(find.text('Rs 390/L ÷ 40 km/L'), findsOneWidget);
    });

    testWidgets('Bike average missing shows "Set your bike\'s average" link',
        (tester) async {
      SettingsController.instance.setFuelPricePerLiter(390.0);
      ActiveBikeController.instance.addBike(
        const Bike(
          id: 'bike-1',
          make: 'Honda',
          modelName: 'CB500X',
          modelYear: 2023,
          odometerKm: 5000,
          fuelAverageKmPerLiter: null,
        ),
        setActive: true,
      );

      final budget = TripBudget(
        tripName: 'Karakoram Tour',
        capAmount: 50000.0,
        allocatedSoFar: 20000.0,
        startDate: tripStartDate.toIso8601String(),
        endDate: tripEndDate.toIso8601String(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TripBudgetCardWidget(
                tripBudget: budget,
                expenses: const [],
                onEditTrip: () {},
                onDeleteTrip: () {},
                onAddExpense: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("Set your bike's average"), findsOneWidget);
      expect(find.text('Rs 9.75/km'), findsNothing);
    });
  });
}
