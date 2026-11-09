import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/garage/presentation/widgets/update_fuel_sheet.dart';
import 'package:camp/features/garage/services/fuel_refill_service.dart';
import 'package:camp/features/maintenance/controllers/trip_budget_controller.dart';
import 'package:camp/features/maintenance/domain/trip_budget_model.dart';
import 'package:camp/features/maintenance/presentation/screens/add_expense_screen.dart';
import 'package:camp/features/maintenance/presentation/widgets/trip_budget_card_widget.dart';
import 'package:camp/features/settings/controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testBike1 = Bike(
    id: 'bike-primary',
    make: 'Yamaha',
    modelName: 'Tenere 700',
    modelYear: 2023,
    odometerKm: 12000,
    fuelTankCapacityLiters: 16.0,
    fuelRemainingLiters: 6.0,
  );

  const testBike2 = Bike(
    id: 'bike-secondary',
    make: 'Honda',
    modelName: 'CRF300L',
    modelYear: 2022,
    odometerKm: 5000,
    fuelTankCapacityLiters: 10.0,
    fuelRemainingLiters: 3.0,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStore.instance.resetForTesting();
    ActiveBikeController.instance.reset();
    TripBudgetController.instance.resetForTesting();
    SettingsController.instance.setFuelPricePerLiter(300.0);

    ActiveBikeController.instance.addBike(testBike1, setActive: true);
    ActiveBikeController.instance.addBike(testBike2);
  });

  group('CAMP: Fuel Refill Unified Path Tests', () {
    testWidgets(
        'Add Expense with litres raises that bike\'s level by the litres, capped at capacity',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AddExpenseScreen(),
          ),
        ),
      );
      await tester.pump();

      // Enter Amount = 1500
      await tester.enterText(
        find.byKey(const ValueKey('add_expense_amount_field')),
        '1500',
      );
      await tester.pump();

      // Enter Litres = 5 (Target: Yamaha Tenere 700, remaining 6.0, cap 16.0)
      await tester.enterText(
        find.byKey(const ValueKey('add_expense_litres_field')),
        '5',
      );
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Bike level should have risen from 6.0 by 5.0 to 11.0
      final updatedPrimary =
          ActiveBikeController.instance.getBikeById('bike-primary')!;
      expect(updatedPrimary.fuelRemainingLiters, 11.0);

      // Exactly 1 expense created with title "Fuel Refill (5 L)"
      expect(TripBudgetController.instance.expenses.length, 1);
      final expense = TripBudgetController.instance.expenses.first;
      expect(expense.title, 'Fuel Refill (5 L)');
      expect(expense.litres, 5.0);

      // Now add another refill with 10L (11.0 + 10.0 = 21.0, but capped at 16.0)
      await FuelRefillService.recordRefill(
        bikeId: 'bike-primary',
        litres: 10.0,
        pricePerLitre: 300.0,
        total: 3000.0,
        isFullTank: false,
      );

      final cappedPrimary =
          ActiveBikeController.instance.getBikeById('bike-primary')!;
      expect(cappedPrimary.fuelRemainingLiters, 16.0); // Capped at capacity
    });

    testWidgets(
        'Add Expense updates the chosen bike in the form, not necessarily active bike',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AddExpenseScreen(),
          ),
        ),
      );
      await tester.pump();

      // Select bike-secondary (CRF300L) from the dropdown
      final dropdown = find.descendant(
        of: find.byKey(const ValueKey('add_expense_bike_dropdown')),
        matching: find.byType(DropdownButton<String?>),
      );
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Honda CRF300L').last);
      await tester.pumpAndSettle();

      // Enter amount 1200 and litres 4
      await tester.enterText(
        find.byKey(const ValueKey('add_expense_amount_field')),
        '1200',
      );
      await tester.enterText(
        find.byKey(const ValueKey('add_expense_litres_field')),
        '4',
      );
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pump();

      // bike-secondary started with 3.0L, rises by 4.0L to 7.0L
      final updatedSecondary =
          ActiveBikeController.instance.getBikeById('bike-secondary')!;
      expect(updatedSecondary.fuelRemainingLiters, 7.0);

      // Active bike (bike-primary) remains untouched at 6.0L
      final primary =
          ActiveBikeController.instance.getBikeById('bike-primary')!;
      expect(primary.fuelRemainingLiters, 6.0);
    });

    testWidgets('with the full tank switch sets capacity', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AddExpenseScreen(),
          ),
        ),
      );
      await tester.pump();

      // Enter amount 900 and litres 3
      await tester.enterText(
        find.byKey(const ValueKey('add_expense_amount_field')),
        '900',
      );
      await tester.enterText(
        find.byKey(const ValueKey('add_expense_litres_field')),
        '3',
      );
      await tester.pump();

      // Toggle full tank switch ON
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pump();

      // Bike level is set to full tank capacity (16.0L)
      final primary =
          ActiveBikeController.instance.getBikeById('bike-primary')!;
      expect(primary.fuelRemainingLiters, 16.0);

      // Litres are stored as entered (3.0L) and isFullTank is true
      final expense = TripBudgetController.instance.expenses.first;
      expect(expense.litres, 3.0);
      expect(expense.isFullTank, isTrue);
      expect(expense.title, 'Fuel Refill (3 L)');
    });

    testWidgets('amount only leaves the level and shows the hint',
        (tester) async {
      // Clear settings price so litres is not auto-calculated
      SettingsController.instance.setFuelPricePerLiter(null);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AddExpenseScreen(),
          ),
        ),
      );
      await tester.pump();

      // Hint is visible in the UI
      expect(find.text('Add litres to update the fuel level'), findsOneWidget);

      // Enter only amount (no litres)
      await tester.enterText(
        find.byKey(const ValueKey('add_expense_amount_field')),
        '2500',
      );
      await tester.enterText(
        find.byKey(const ValueKey('add_expense_litres_field')),
        '',
      );
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Bike level is left alone (6.0L)
      final primary =
          ActiveBikeController.instance.getBikeById('bike-primary')!;
      expect(primary.fuelRemainingLiters, 6.0);

      // Expense saved as "Fuel Expense" without litres
      expect(TripBudgetController.instance.expenses.length, 1);
      final expense = TripBudgetController.instance.expenses.first;
      expect(expense.title, 'Fuel Expense');
      expect(expense.litres, isNull);
      expect(expense.amount, 2500.0);

      // SnackBar with hint shown
      expect(find.text('Add litres to update the fuel level'), findsWidgets);
    });

    testWidgets('a refill from the Home sheet creates exactly one expense',
        (tester) async {
      expect(TripBudgetController.instance.expenses.length, 0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateFuelSheet(bike: testBike1),
          ),
        ),
      );
      await tester.pump();

      // Switch to "I Refilled" tab
      await tester.tap(find.text('I Refilled'));
      await tester.pump();

      // Enter 4 in litres, price is prefilled with 300
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '4');
      await tester.pump();

      await tester.ensureVisible(find.text('Save Refill'));
      await tester.tap(find.text('Save Refill'));
      await tester.pump();

      // Exactly ONE expense was saved
      expect(TripBudgetController.instance.expenses.length, 1);
      final expense = TripBudgetController.instance.expenses.first;
      expect(expense.title, 'Fuel Refill (4 L)');
      expect(expense.litres, 4.0);
      expect(expense.amount, 1200.0);

      // Bike level was updated: 6.0 + 4.0 = 10.0L
      final primary =
          ActiveBikeController.instance.getBikeById('bike-primary')!;
      expect(primary.fuelRemainingLiters, 10.0);
    });

    testWidgets('edit adjusts by the difference in litres', (tester) async {
      // Create initial refill of 4.0 litres (bike moves 6.0 -> 10.0L)
      final initialExpense = await FuelRefillService.recordRefill(
        bikeId: 'bike-primary',
        litres: 4.0,
        pricePerLitre: 300.0,
        total: 1200.0,
        isFullTank: false,
      );

      final bikeAfterFirst =
          ActiveBikeController.instance.getBikeById('bike-primary')!;
      expect(bikeAfterFirst.fuelRemainingLiters, 10.0);

      // Now edit the refill to 7.0 litres (diff = +3.0L)
      final updatedExpense = await FuelRefillService.recordRefill(
        bikeId: 'bike-primary',
        litres: 7.0,
        pricePerLitre: 300.0,
        total: 2100.0,
        isFullTank: false,
        existingExpense: initialExpense,
      );

      // Bike level adjusted only by diff: 10.0 + 3.0 = 13.0L (not 10.0 + 7.0 = 17.0L)
      final bikeAfterEdit =
          ActiveBikeController.instance.getBikeById('bike-primary')!;
      expect(bikeAfterEdit.fuelRemainingLiters, 13.0);

      // Exactly 1 expense in ledger, updated in place
      expect(TripBudgetController.instance.expenses.length, 1);
      expect(updatedExpense.title, 'Fuel Refill (7 L)');
      expect(updatedExpense.amount, 2100.0);
    });

    testWidgets(
        'delete leaves the fuel level unchanged (the fuel is already in the tank)',
        (tester) async {
      final expense = await FuelRefillService.recordRefill(
        bikeId: 'bike-primary',
        litres: 4.0,
        pricePerLitre: 300.0,
        total: 1200.0,
        isFullTank: false,
      );

      final primary =
          ActiveBikeController.instance.getBikeById('bike-primary')!;
      expect(primary.fuelRemainingLiters, 10.0);

      // Delete the expense
      TripBudgetController.instance.deleteExpense(expense.id);

      // Expense removed
      expect(TripBudgetController.instance.expenses.isEmpty, isTrue);

      // Fuel level remains unchanged at 10.0L
      final primaryAfterDelete =
          ActiveBikeController.instance.getBikeById('bike-primary')!;
      expect(primaryAfterDelete.fuelRemainingLiters, 10.0);
    });
  });

  group('CAMP: Budget Cap Empty State Tests', () {
    testWidgets(
        'cap 0 shows "Add a budget" and "No budget cap set", and no "over target budget" text',
        (tester) async {
      bool editTapped = false;

      const budgetCap0 = TripBudget(
        id: 'budget-zero',
        tripName: 'Karakoram Ride',
        capAmount: 0.0,
        allocatedSoFar: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TripBudgetCardWidget(
                tripBudget: budgetCap0,
                expenses: const [],
                onEditTrip: () => editTapped = true,
                onDeleteTrip: () {},
                onAddExpense: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Shows "Add a budget" and "No budget cap set"
      expect(find.text('Add a budget'), findsOneWidget);
      expect(find.text('No budget cap set'), findsOneWidget);

      // Does NOT show "over target budget" or "under target budget"
      expect(find.textContaining('over target budget'), findsNothing);
      expect(find.textContaining('under target budget'), findsNothing);

      // Keeps big amount (Rs 0), "/ Rs 0 Budget Cap", "0% used", progress bar, etc.
      expect(find.text('Rs 0'), findsOneWidget);
      expect(find.text('/ Rs 0 Budget Cap'), findsOneWidget);
      expect(find.text('0% used'), findsOneWidget);

      // Tapping "Add a budget" opens budget editor via onEditTrip callback
      await tester.tap(find.text('Add a budget'));
      await tester.pump();
      expect(editTapped, isTrue);
    });

    testWidgets('a cap above 0 shows the usual over/under text',
        (tester) async {
      const budgetWithCap = TripBudget(
        id: 'budget-active',
        tripName: 'Karakoram Ride',
        capAmount: 50000.0,
        allocatedSoFar: 15000.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TripBudgetCardWidget(
                tripBudget: budgetWithCap,
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

      // Normal under target budget text appears
      expect(find.textContaining('under target budget'), findsOneWidget);

      // "Add a budget" and "No budget cap set" do NOT appear
      expect(find.text('Add a budget'), findsNothing);
      expect(find.text('No budget cap set'), findsNothing);
    });
  });
}
