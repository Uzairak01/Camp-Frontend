import 'package:camp/core/storage/local_store.dart';
import 'package:camp/core/utils/currency_formatter.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/garage/presentation/widgets/update_fuel_sheet.dart';
import 'package:camp/features/maintenance/controllers/post_ride_report_controller.dart';
import 'package:camp/features/maintenance/controllers/trip_budget_controller.dart';
import 'package:camp/features/maintenance/domain/cost_per_km_calculator.dart';
import 'package:camp/features/maintenance/domain/expense_model.dart';
import 'package:camp/features/maintenance/domain/post_ride_report.dart';
import 'package:camp/features/maintenance/domain/trip_budget_model.dart';
import 'package:camp/features/maintenance/presentation/widgets/trip_budget_card_widget.dart';
import 'package:camp/features/settings/controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_ride_report_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testBike = Bike(
    id: 'bike-test',
    make: 'Yamaha',
    modelName: 'YBR 125',
    modelYear: 2023,
    fuelTankCapacityLiters: 13.0,
    fuelRemainingLiters: 5.0,
    fuelAverageKmPerLiter: 40.0,
    odometerKm: 5000,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStore.instance.resetForTesting();
    ActiveBikeController.instance.resetForTesting();
    SettingsController.instance.resetForTesting();
    TripBudgetController.instance.resetForTesting();
    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());

    ActiveBikeController.instance.addBike(testBike);
    ActiveBikeController.instance.setActiveBike(testBike.id);
  });

  group('Fuel Refill Data Model & Tolerant JSON', () {
    test('Expense model handles litres, pricePerLitre, and tolerant JSON', () {
      final jsonWithLiters = {
        'id': 'exp-fuel-1',
        'category': 'fuel',
        'title': 'Fuel Refill (10 L)',
        'amount': 2750.0,
        'litres': 10.0,
        'pricePerLitre': 275.0,
        'trackingMode': 'manualEntry',
      };

      final expense = Expense.fromJson(jsonWithLiters);
      expect(expense.litres, 10.0);
      expect(expense.pricePerLitre, 275.0);
      expect(expense.amount, 2750.0);
      expect(expense.displaySubtitle, '10.00 L at Rs 275/L');

      // Tolerant variant keys: "liters" and "price_per_litre"
      final jsonVariant = {
        'id': 'exp-fuel-2',
        'category': 'fuel',
        'title': 'Fuel Refill (12.5 L)',
        'amount': 3500,
        'liters': '12.5',
        'price_per_litre': '280.00',
        'trackingMode': 'manualEntry',
      };

      final expenseVariant = Expense.fromJson(jsonVariant);
      expect(expenseVariant.litres, 12.5);
      expect(expenseVariant.pricePerLitre, 280.0);
      expect(expenseVariant.amount, 3500.0);
      expect(expenseVariant.displaySubtitle, '12.50 L at Rs 280/L');

      // Serializes back with litres and pricePerLitre
      final serialized = expense.toJson();
      expect(serialized['litres'], 10.0);
      expect(serialized['pricePerLitre'], 275.0);
      expect(serialized['amount'], 2750.0);
    });

    test('Old refill without litres renders amount only and displaySubtitle is null', () {
      final oldJson = {
        'id': 'exp-old-1',
        'category': 'fuel',
        'title': 'Old Refill',
        'amount': 2500.0,
        'trackingMode': 'manualEntry',
        'subtitle': 'Legacy subtitle',
      };

      final oldExpense = Expense.fromJson(oldJson);
      expect(oldExpense.litres, isNull);
      expect(oldExpense.pricePerLitre, isNull);
      expect(oldExpense.amount, 2500.0);
      // Must NOT invent litres by dividing by today's price!
      expect(oldExpense.displaySubtitle, isNull);
    });
  });

  group('Refill Sheet Live Recalculations', () {
    testWidgets('litres + price gives the total live', (tester) async {
      SettingsController.instance.setFuelPricePerLiter(275.0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateFuelSheet(bike: testBike),
          ),
        ),
      );
      await tester.pump();

      // Switch to "I Refilled" tab
      final refilledTab = find.text('I Refilled');
      expect(refilledTab, findsOneWidget);
      await tester.tap(refilledTab);
      await tester.pump();

      // Price per litre is prefilled with 275
      expect(find.text('275'), findsOneWidget);

      // Enter 10 in Litres
      final litresField = find.widgetWithText(TextField, '');
      expect(litresField, findsWidgets);

      // Enter litres = 10
      await tester.enterText(litresField.first, '10');
      await tester.pump();

      // Total paid should calculate live to 2750
      expect(find.text('2750'), findsOneWidget);
    });

    testWidgets('litres + total gives the price live', (tester) async {
      // No settings price set initially
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateFuelSheet(bike: testBike),
          ),
        ),
      );
      await tester.pump();

      // Switch to "I Refilled" tab
      await tester.tap(find.text('I Refilled'));
      await tester.pump();

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));

      // Enter litres = 10
      await tester.enterText(textFields.at(0), '10');
      await tester.pump();

      // Enter total = 2750 in total field
      await tester.enterText(textFields.at(2), '2750');
      await tester.pump();

      // Price should calculate live to 275
      expect(find.text('275'), findsOneWidget);
    });

    testWidgets('price per litre starts empty when Settings fuel price is not set', (tester) async {
      expect(SettingsController.instance.fuelPricePerLiter, isNull);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateFuelSheet(bike: testBike),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('I Refilled'));
      await tester.pump();

      final textFields = find.byType(TextField);
      // All three fields should start empty
      final priceField = tester.widget<TextField>(textFields.at(1));
      expect(priceField.controller!.text, isEmpty);
    });

    testWidgets('invalid input is rejected', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateFuelSheet(bike: testBike),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('I Refilled'));
      await tester.pump();

      // Tap Save Refill with empty/invalid inputs
      await tester.ensureVisible(find.text('Save Refill'));
      await tester.tap(find.text('Save Refill'));
      await tester.pump();

      // Should show validation error and reject save
      expect(find.text('Litres must be greater than 0'), findsWidgets);
      expect(TripBudgetController.instance.expenses, isEmpty);
    });

    testWidgets('saving refill updates fuel level and adds expense with all three fields', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateFuelSheet(bike: testBike),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('I Refilled'));
      await tester.pump();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '5');
      await tester.pump();
      await tester.enterText(textFields.at(1), '280');
      await tester.pump();

      // Total calculates to 1400
      expect(find.text('1400'), findsOneWidget);

      await tester.ensureVisible(find.text('Save Refill'));
      await tester.tap(find.text('Save Refill'));
      await tester.pump();

      // Expense was saved
      expect(TripBudgetController.instance.expenses.length, 1);
      final saved = TripBudgetController.instance.expenses.first;
      expect(saved.litres, 5.0);
      expect(saved.pricePerLitre, 280.0);
      expect(saved.amount, 1400.0);

      // Bike fuel remaining updated: 5.0 + 5.0 = 10.0 L
      final bike = ActiveBikeController.instance.activeBike!;
      expect(bike.fuelRemainingLiters, 10.0);
    });
  });

  group('Edit and Delete Refill', () {
    testWidgets('Editing a refill shows stored values, changing one recalculates only the third', (tester) async {
      const initialRefill = Expense(
        id: 'exp-stored-1',
        category: ExpenseCategory.fuel,
        title: 'Fuel Refill (10 L)',
        amount: 2750.0,
        litres: 10.0,
        pricePerLitre: 275.0,
        trackingMode: ExpenseTrackingMode.manualEntry,
      );
      TripBudgetController.instance.addExpense(initialRefill);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateFuelSheet(
              bike: testBike,
              initialExpense: initialRefill,
            ),
          ),
        ),
      );
      await tester.pump();

      // Directly opens in refill editing mode
      expect(find.text('Edit Fuel Refill'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('275'), findsOneWidget);
      expect(find.text('2750'), findsOneWidget);

      final textFields = find.byType(TextField);
      // Changing Litres from 10 to 12 recalculates only Total (using stored Price 275)
      await tester.enterText(textFields.at(0), '12');
      await tester.pump();

      expect(find.text('3300'), findsOneWidget);
      // Price per litre remains unchanged at 275
      final priceField = tester.widget<TextField>(textFields.at(1));
      expect(priceField.controller!.text, '275');

      // Save update
      await tester.tap(find.text('Update Refill'));
      await tester.pump();

      final updated = TripBudgetController.instance.expenses.first;
      expect(updated.litres, 12.0);
      expect(updated.pricePerLitre, 275.0);
      expect(updated.amount, 3300.0);
    });

    testWidgets('Delete keeps existing confirm and undo behaviour', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const refill = Expense(
        id: 'exp-to-del',
        category: ExpenseCategory.fuel,
        title: 'Fuel Refill (8 L)',
        amount: 2200.0,
        litres: 8.0,
        pricePerLitre: 275.0,
        trackingMode: ExpenseTrackingMode.manualEntry,
      );
      TripBudgetController.instance.addExpense(refill);

      const budget = TripBudget(
        tripName: 'Alpine Tour',
        capAmount: 50000.0,
        allocatedSoFar: 2200.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TripBudgetCardWidget(
                tripBudget: budget,
                expenses: TripBudgetController.instance.expenses,
                onEditTrip: () {},
                onDeleteTrip: () {},
                onAddExpense: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Expense row shows subtitle "8.00 L at Rs 275/L"
      expect(find.text('8.00 L at Rs 275/L'), findsOneWidget);

      // Tap expense to open action sheet
      await tester.tap(find.text('Fuel Refill (8 L)'));
      await tester.pumpAndSettle();

      // Tap Delete Expense
      await tester.tap(find.text('Delete Expense'));
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Delete Expense?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Confirm Delete
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(TripBudgetController.instance.expenses, isEmpty);

      // Undo SnackBar is visible
      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pump();

      // Expense is restored
      expect(TripBudgetController.instance.expenses.length, 1);
      expect(TripBudgetController.instance.expenses.first.id, 'exp-to-del');
    });
  });

  group('Totals & Settings Price Independence', () {
    test('Stored refill and totals are unchanged when Settings fuel price changes', () {
      SettingsController.instance.setFuelPricePerLiter(275.0);

      final refill = Expense(
        id: 'exp-refill-fixed',
        category: ExpenseCategory.fuel,
        title: 'Fuel Refill (10 L)',
        amount: 2750.0,
        litres: 10.0,
        pricePerLitre: 275.0,
        trackingMode: ExpenseTrackingMode.manualEntry,
        dateRecorded: DateTime(2026, 10, 15),
      );

      final otherExpense = Expense(
        id: 'exp-food-1',
        category: ExpenseCategory.food,
        title: 'Lunch',
        amount: 1500.0,
        trackingMode: ExpenseTrackingMode.manualEntry,
        dateRecorded: DateTime(2026, 10, 15),
      );

      TripBudgetController.instance.addExpense(refill);
      TripBudgetController.instance.addExpense(otherExpense);

      // Initial allocated so far
      expect(TripBudgetController.instance.budget.allocatedSoFar, 4250.0);

      final reports = [
        PostRideReport(
          id: 'r1',
          bikeId: testBike.id,
          date: DateTime(2026, 10, 15),
          distanceKm: 85.0,
          terrainTags: const ['Road'],
        ),
      ];

      final costPerKmBefore = calculateCostPerKm(
        totalCost: TripBudgetController.instance.budget.allocatedSoFar,
        reports: reports,
      );
      expect(costPerKmBefore, 4250.0 / 85.0); // 50 PKR / km

      // Now dramatically change today's Settings fuel price (e.g. up to 450 PKR/L)
      SettingsController.instance.setFuelPricePerLiter(450.0);

      // 1. Stored refill values are unchanged
      final storedRefill = TripBudgetController.instance.expenses.firstWhere((e) => e.id == 'exp-refill-fixed');
      expect(storedRefill.amount, 2750.0);
      expect(storedRefill.litres, 10.0);
      expect(storedRefill.pricePerLitre, 275.0);

      // 2. Budget total (allocatedSoFar) is unchanged
      expect(TripBudgetController.instance.budget.allocatedSoFar, 4250.0);

      // 3. Cost per km is unchanged
      final costPerKmAfter = calculateCostPerKm(
        totalCost: TripBudgetController.instance.budget.allocatedSoFar,
        reports: reports,
      );
      expect(costPerKmAfter, costPerKmBefore);

      // 4. Fuel expenses sum is unchanged
      final fuelExpensesSum = TripBudgetController.instance.expenses
          .where((e) => e.category == ExpenseCategory.fuel)
          .fold<double>(0.0, (s, e) => s + e.amount);
      expect(fuelExpensesSum, 2750.0);
    });

    testWidgets('Finances expense row renders "10 L at Rs 275/L" for new refill and amount only for old refill', (tester) async {
      const newRefill = Expense(
        id: 'new-refill',
        category: ExpenseCategory.fuel,
        title: 'Fuel Stop',
        amount: 2750.0,
        litres: 10.0,
        pricePerLitre: 275.0,
        trackingMode: ExpenseTrackingMode.manualEntry,
      );

      const oldRefill = Expense(
        id: 'old-refill',
        category: ExpenseCategory.fuel,
        title: 'Legacy Fuel Stop',
        amount: 3000.0,
        trackingMode: ExpenseTrackingMode.manualEntry,
      );

      const budget = TripBudget(
        tripName: 'Tour',
        capAmount: 20000.0,
        allocatedSoFar: 5750.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TripBudgetCardWidget(
                tripBudget: budget,
                expenses: const [newRefill, oldRefill],
                onEditTrip: () {},
                onDeleteTrip: () {},
                onAddExpense: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // New refill shows "10.00 L at Rs 275/L"
      expect(find.text('10.00 L at Rs 275/L'), findsOneWidget);

      // Old refill renders amount only (Rs 3,000) with title, and has NO subtitle
      expect(find.text('Legacy Fuel Stop'), findsOneWidget);
      expect(find.text(formatPkr(3000)), findsOneWidget);
      // Confirm no subtitle containing "/L" exists for the legacy stop
      expect(find.textContaining('Legacy Fuel Stop •'), findsNothing);
    });
  });

  group('Full Tank Refill & Edit Double-Counting Prevention', () {
    test('old expenses default to isFullTank=false and tolerant parsing works', () {
      // 1. Old expense without isFullTank
      final oldJson = {
        'id': 'exp-legacy',
        'category': 'fuel',
        'title': 'Legacy Fuel',
        'amount': 2000.0,
      };
      final oldExpense = Expense.fromJson(oldJson);
      expect(oldExpense.isFullTank, isFalse);

      // Default constructor parameter
      const defaultExp = Expense(
        id: 'exp-const',
        category: ExpenseCategory.fuel,
        title: 'Const Fuel',
        amount: 1000.0,
        trackingMode: ExpenseTrackingMode.manualEntry,
      );
      expect(defaultExp.isFullTank, isFalse);

      // Tolerant parsing variants
      final t1 = Expense.fromJson({
        'id': '1',
        'category': 'fuel',
        'title': 'F',
        'amount': 100.0,
        'is_full_tank': true,
      });
      expect(t1.isFullTank, isTrue);

      final t2 = Expense.fromJson({
        'id': '2',
        'category': 'fuel',
        'title': 'F',
        'amount': 100.0,
        'fullTank': 'true',
      });
      expect(t2.isFullTank, isTrue);

      final t3 = Expense.fromJson({
        'id': '3',
        'category': 'fuel',
        'title': 'F',
        'amount': 100.0,
        'isFullTank': 1,
      });
      expect(t3.isFullTank, isTrue);

      final t4 = Expense.fromJson({
        'id': '4',
        'category': 'fuel',
        'title': 'F',
        'amount': 100.0,
        'isFullTank': '1',
      });
      expect(t4.isFullTank, isTrue);

      final t5 = Expense.fromJson({
        'id': '5',
        'category': 'fuel',
        'title': 'F',
        'amount': 100.0,
        'isFullTank': 0,
      });
      expect(t5.isFullTank, isFalse);

      final t6 = Expense.fromJson({
        'id': '6',
        'category': 'fuel',
        'title': 'F',
        'amount': 100.0,
        'isFullTank': null,
      });
      expect(t6.isFullTank, isFalse);
    });

    testWidgets('full tank sets full while litres are still stored as entered', (tester) async {
      // testBike has fuelTankCapacityLiters = 13.0, fuelRemainingLiters = 5.0
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateFuelSheet(bike: testBike),
          ),
        ),
      );
      await tester.pump();

      // Switch to "I Refilled" tab
      await tester.tap(find.text('I Refilled'));
      await tester.pump();

      // Enter 4 in Litres and 250 in Price
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '4');
      await tester.enterText(textFields.at(1), '250');
      await tester.pump();

      // Turn ON the "Filled the tank" switch
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pump();

      // Tap Save Refill
      await tester.ensureVisible(find.text('Save Refill'));
      await tester.tap(find.text('Save Refill'));
      await tester.pump();

      // 1. Bike's fuel level becomes full capacity (13.0 L)
      final activeBike = ActiveBikeController.instance.activeBike!;
      expect(activeBike.fuelRemainingLiters, 13.0);

      // 2. Litres are still stored as entered (4.0 L) and isFullTank is true
      final savedExpense = TripBudgetController.instance.expenses.first;
      expect(savedExpense.litres, 4.0);
      expect(savedExpense.amount, 1000.0);
      expect(savedExpense.isFullTank, isTrue);
    });

    testWidgets('partial refill caps at capacity', (tester) async {
      // Bike has remaining 10.0 L and capacity 13.0 L
      final bike10L = testBike.copyWith(fuelRemainingLiters: 10.0);
      ActiveBikeController.instance.updateBike(bike10L);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateFuelSheet(bike: bike10L),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('I Refilled'));
      await tester.pump();

      // Enter 5 Litres and 250 Price (partial refill, switch is OFF by default)
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '5');
      await tester.enterText(textFields.at(1), '250');
      await tester.pump();

      // Verify switch is off
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);

      await tester.ensureVisible(find.text('Save Refill'));
      await tester.tap(find.text('Save Refill'));
      await tester.pump();

      // 10 + 5 = 15, but capped at capacity (13.0 L)
      final activeBike = ActiveBikeController.instance.activeBike!;
      expect(activeBike.fuelRemainingLiters, 13.0);

      final saved = TripBudgetController.instance.expenses.first;
      expect(saved.litres, 5.0);
      expect(saved.isFullTank, isFalse);
    });

    testWidgets('edit doesn\'t change the level when litres are unchanged', (tester) async {
      // 1. Initial refill was logged: 5 L, isFullTank = false
      const initialExpense = Expense(
        id: 'exp-edit-test',
        category: ExpenseCategory.fuel,
        title: 'Fuel Refill (5 L)',
        amount: 1250.0,
        litres: 5.0,
        pricePerLitre: 250.0,
        isFullTank: false,
        trackingMode: ExpenseTrackingMode.manualEntry,
      );
      TripBudgetController.instance.addExpense(initialExpense);

      // Bike currently has 7.0 L remaining
      final bike7L = testBike.copyWith(fuelRemainingLiters: 7.0);
      ActiveBikeController.instance.updateBike(bike7L);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateFuelSheet(
              bike: bike7L,
              initialExpense: initialExpense,
            ),
          ),
        ),
      );
      await tester.pump();

      // Litres is still 5, we only adjust price to 260 (total becomes 1300)
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), '260');
      await tester.pump();

      await tester.ensureVisible(find.text('Update Refill'));
      await tester.tap(find.text('Update Refill'));
      await tester.pump();

      // Fuel level is completely unchanged (7.0 L)
      final updatedBike = ActiveBikeController.instance.activeBike!;
      expect(updatedBike.fuelRemainingLiters, 7.0);

      // Expense amount updated to 1300
      final updatedExpense = TripBudgetController.instance.expenses.firstWhere((e) => e.id == 'exp-edit-test');
      expect(updatedExpense.amount, 1300.0);
      expect(updatedExpense.litres, 5.0);
    });

    testWidgets('editing a full-tank refill does not force level to full again unless flag was just turned on', (tester) async {
      // Refill had isFullTank = true
      const fullRefill = Expense(
        id: 'exp-full-edit',
        category: ExpenseCategory.fuel,
        title: 'Fuel Refill (8 L)',
        amount: 2000.0,
        litres: 8.0,
        pricePerLitre: 250.0,
        isFullTank: true,
        trackingMode: ExpenseTrackingMode.manualEntry,
      );
      TripBudgetController.instance.addExpense(fullRefill);

      // Bike later consumed fuel and currently has 4.0 L remaining
      final bike4L = testBike.copyWith(fuelRemainingLiters: 4.0);
      ActiveBikeController.instance.updateBike(bike4L);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateFuelSheet(
              bike: bike4L,
              initialExpense: fullRefill,
            ),
          ),
        ),
      );
      await tester.pump();

      // Switch should be initialized to ON
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);

      // Just update price to 255
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), '255');
      await tester.pump();

      await tester.ensureVisible(find.text('Update Refill'));
      await tester.tap(find.text('Update Refill'));
      await tester.pump();

      // MUST NOT force level to 13.0 again! Should remain 4.0
      final bikeAfter = ActiveBikeController.instance.activeBike!;
      expect(bikeAfter.fuelRemainingLiters, 4.0);
    });

    testWidgets('editing a refill and turning on full-tank flag forces level to full capacity', (tester) async {
      // Refill had isFullTank = false
      const partialRefill = Expense(
        id: 'exp-partial-to-full',
        category: ExpenseCategory.fuel,
        title: 'Fuel Refill (6 L)',
        amount: 1500.0,
        litres: 6.0,
        pricePerLitre: 250.0,
        isFullTank: false,
        trackingMode: ExpenseTrackingMode.manualEntry,
      );
      TripBudgetController.instance.addExpense(partialRefill);

      // Bike currently has 6.0 L remaining
      final bike6L = testBike.copyWith(fuelRemainingLiters: 6.0);
      ActiveBikeController.instance.updateBike(bike6L);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateFuelSheet(
              bike: bike6L,
              initialExpense: partialRefill,
            ),
          ),
        ),
      );
      await tester.pump();

      // Switch was off, user now flips it ON
      await tester.tap(find.byType(Switch));
      await tester.pump();

      await tester.ensureVisible(find.text('Update Refill'));
      await tester.tap(find.text('Update Refill'));
      await tester.pump();

      // Because flag was just turned on, level becomes full capacity (13.0 L)
      final bikeAfter = ActiveBikeController.instance.activeBike!;
      expect(bikeAfter.fuelRemainingLiters, 13.0);
      final updated = TripBudgetController.instance.expenses.firstWhere((e) => e.id == 'exp-partial-to-full');
      expect(updated.isFullTank, isTrue);
    });

    testWidgets('editing a refill adjusts fuel level only by difference in litres', (tester) async {
      const refill = Expense(
        id: 'exp-diff-test',
        category: ExpenseCategory.fuel,
        title: 'Fuel Refill (5 L)',
        amount: 1250.0,
        litres: 5.0,
        pricePerLitre: 250.0,
        isFullTank: false,
        trackingMode: ExpenseTrackingMode.manualEntry,
      );
      TripBudgetController.instance.addExpense(refill);

      // Bike currently has 7.0 L remaining
      final bike7L = testBike.copyWith(fuelRemainingLiters: 7.0);
      ActiveBikeController.instance.updateBike(bike7L);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateFuelSheet(
              bike: bike7L,
              initialExpense: refill,
            ),
          ),
        ),
      );
      await tester.pump();

      // Change litres from 5 to 7 (+2 L difference)
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '7');
      await tester.pump();

      await tester.ensureVisible(find.text('Update Refill'));
      await tester.tap(find.text('Update Refill'));
      await tester.pump();

      // 7.0 + (7 - 5) = 9.0 L (adjusts by diff, not 7 L again which would make 14 -> 13)
      final bikeAfter = ActiveBikeController.instance.activeBike!;
      expect(bikeAfter.fuelRemainingLiters, 9.0);
    });

    testWidgets('shows "Full tank" as a small label on the expense row when isFullTank is true', (tester) async {
      const fullExpense = Expense(
        id: 'exp-full-row',
        category: ExpenseCategory.fuel,
        title: 'Full Tank Stop',
        amount: 3200.0,
        litres: 12.0,
        pricePerLitre: 266.67,
        isFullTank: true,
        trackingMode: ExpenseTrackingMode.manualEntry,
      );

      const partialExpense = Expense(
        id: 'exp-partial-row',
        category: ExpenseCategory.fuel,
        title: 'Partial Stop',
        amount: 1000.0,
        litres: 4.0,
        pricePerLitre: 250.0,
        isFullTank: false,
        trackingMode: ExpenseTrackingMode.manualEntry,
      );

      const budget = TripBudget(
        tripName: 'Karakoram Highway Tour',
        capAmount: 50000.0,
        allocatedSoFar: 4200.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TripBudgetCardWidget(
                tripBudget: budget,
                expenses: const [fullExpense, partialExpense],
                onEditTrip: () {},
                onDeleteTrip: () {},
                onAddExpense: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // "Full tank" label appears exactly once for fullExpense
      expect(find.text('Full tank'), findsOneWidget);
    });
  });
}
