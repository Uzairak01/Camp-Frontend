import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/controllers/service_visit_controller.dart';
import 'package:camp/features/maintenance/controllers/trip_budget_controller.dart';
import 'package:camp/features/maintenance/domain/expense_model.dart';
import 'package:camp/features/maintenance/domain/service_visit_model.dart';
import 'package:camp/features/maintenance/presentation/widgets/mark_service_visit_done_sheet.dart';
import 'package:camp/features/maintenance/presentation/widgets/service_visit_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    LocalStore.instance.resetForTesting(prefs);
    AppRepositories.resetToDefault();

    final fakeVisitRepo = FakeServiceVisitRepository();
    AppRepositories.instance =
        AppRepositories(serviceVisitRepository: fakeVisitRepo);

    ActiveBikeController.instance.resetForTesting();
    ActiveBikeController.instance.addBike(bikeA, setActive: true);
    ActiveBikeController.instance.addBike(bikeB);

    TripBudgetController.instance.resetForTesting();
    ServiceVisitController.instance = ServiceVisitController(
      repository: fakeVisitRepo,
    );
  });

  group('Service Visit Mark Done - Unit & Controller Tests', () {
    test('Mark done with a cost adds one expense once and sets expenseId', () async {
      final visitCtrl = ServiceVisitController.instance;
      final budgetCtrl = TripBudgetController.instance;

      expect(budgetCtrl.expenses, isEmpty);
      expect(budgetCtrl.budget.allocatedSoFar, 0.0);

      final plannedVisit = ServiceVisit(
        id: 'visit-planned-1',
        dateTime: DateTime.now().add(const Duration(days: 3)),
        shopName: 'Babusar Mechanics',
        bikeId: 'bike-cd70',
        cost: 3500.0,
      );
      await visitCtrl.addVisit(plannedVisit);

      // Planned visit does not create expense
      expect(budgetCtrl.expenses, isEmpty);
      expect(budgetCtrl.budget.allocatedSoFar, 0.0);
      expect(visitCtrl.nextPlannedVisit?.id, 'visit-planned-1');

      // Mark done with cost
      await visitCtrl.markVisitDone(
        visit: plannedVisit,
        actualCost: 3500.0,
        bikeId: 'bike-cd70',
      );

      // Verify exactly one linked expense created
      expect(budgetCtrl.expenses.length, 1);
      final expense = budgetCtrl.expenses.first;
      expect(expense.amount, 3500.0);
      expect(expense.category, ExpenseCategory.service);
      expect(expense.bikeId, 'bike-cd70');
      expect(expense.maintenanceItemId, 'visit-planned-1');
      expect(budgetCtrl.budget.allocatedSoFar, 3500.0);

      // Verify visit is marked done and linked
      final updatedVisit = visitCtrl.visits.firstWhere((v) => v.id == 'visit-planned-1');
      expect(updatedVisit.isDone, isTrue);
      expect(updatedVisit.isPast, isTrue);
      expect(updatedVisit.expenseId, expense.id);
      expect(updatedVisit.cost, 3500.0);

      // No longer in nextPlannedVisit, now in pastVisits
      expect(visitCtrl.nextPlannedVisit, isNull);
      expect(visitCtrl.pastVisits.length, 1);
      expect(visitCtrl.pastVisits.first.id, 'visit-planned-1');

      // Marking done again does not duplicate the expense
      await visitCtrl.markVisitDone(
        visit: updatedVisit,
        actualCost: 3800.0,
        bikeId: 'bike-cd70',
      );
      expect(budgetCtrl.expenses.length, 1);
      expect(budgetCtrl.expenses.first.amount, 3800.0);
      expect(budgetCtrl.budget.allocatedSoFar, 3800.0);
    });

    test('Mark done without a cost adds none', () async {
      final visitCtrl = ServiceVisitController.instance;
      final budgetCtrl = TripBudgetController.instance;

      final plannedVisit = ServiceVisit(
        id: 'visit-planned-2',
        dateTime: DateTime.now().add(const Duration(days: 4)),
        shopName: 'Karakoram Spares',
        bikeId: 'bike-gs150',
        cost: 2000.0,
      );
      await visitCtrl.addVisit(plannedVisit);

      // Mark done without cost
      await visitCtrl.markVisitDone(
        visit: plannedVisit,
        actualCost: null,
        bikeId: 'bike-gs150',
      );

      // Zero expenses created
      expect(budgetCtrl.expenses, isEmpty);
      expect(budgetCtrl.budget.allocatedSoFar, 0.0);

      // Visit is marked done, shown in past visits
      final updatedVisit = visitCtrl.visits.firstWhere((v) => v.id == 'visit-planned-2');
      expect(updatedVisit.isDone, isTrue);
      expect(updatedVisit.expenseId, isNull);
      expect(visitCtrl.pastVisits.length, 1);
    });

    test('A visit that is done and has a cost: edit and delete stay in sync with undo', () async {
      final visitCtrl = ServiceVisitController.instance;
      final budgetCtrl = TripBudgetController.instance;

      final plannedVisit = ServiceVisit(
        id: 'visit-sync-1',
        dateTime: DateTime.now().add(const Duration(days: 2)),
        shopName: 'Ali Workshop',
        bikeId: 'bike-cd70',
        cost: 2500.0,
      );
      await visitCtrl.addVisit(plannedVisit);

      // Mark done with cost
      await visitCtrl.markVisitDone(
        visit: plannedVisit,
        actualCost: 2500.0,
      );
      expect(budgetCtrl.expenses.length, 1);
      expect(budgetCtrl.budget.allocatedSoFar, 2500.0);

      final doneVisit = visitCtrl.visits.firstWhere((v) => v.id == 'visit-sync-1');

      // Edit visit cost to 4000
      final editedVisit = doneVisit.copyWith(cost: 4000.0);
      await visitCtrl.updateVisit(editedVisit);

      expect(budgetCtrl.expenses.length, 1);
      expect(budgetCtrl.expenses.first.amount, 4000.0);
      expect(budgetCtrl.budget.allocatedSoFar, 4000.0);

      // Delete visit: deletes linked expense
      await visitCtrl.deleteVisit('visit-sync-1');
      expect(visitCtrl.visits, isEmpty);
      expect(budgetCtrl.expenses, isEmpty);
      expect(budgetCtrl.budget.allocatedSoFar, 0.0);

      // Undo delete via insertVisit restores visit and linked expense
      await visitCtrl.insertVisit(0, editedVisit);
      expect(visitCtrl.visits.length, 1);
      expect(budgetCtrl.expenses.length, 1);
      expect(budgetCtrl.expenses.first.amount, 4000.0);
      expect(budgetCtrl.budget.allocatedSoFar, 4000.0);
    });

    test('A past visit that was not marked done adds nothing to the total', () async {
      final visitCtrl = ServiceVisitController.instance;
      final budgetCtrl = TripBudgetController.instance;

      // Planned visit with date in the past, but not marked done
      final pastVisitNotDone = ServiceVisit(
        id: 'visit-past-not-done',
        dateTime: DateTime.now().subtract(const Duration(days: 2)),
        shopName: 'Gilgit Bike Care',
        bikeId: 'bike-cd70',
        cost: 6500.0, // Expected cost
        isDone: false,
      );
      await visitCtrl.addVisit(pastVisitNotDone);

      // It is a past visit because its date passed
      expect(pastVisitNotDone.isPast, isTrue);
      expect(visitCtrl.nextPlannedVisit, isNull);
      expect(visitCtrl.pastVisits.length, 1);
      expect(visitCtrl.pastVisits.first.isDone, isFalse);

      // But its expected cost is kept out of all totals!
      expect(budgetCtrl.expenses, isEmpty);
      expect(budgetCtrl.budget.allocatedSoFar, 0.0);
    });
  });

  group('Service Visit Mark Done - UI & Sheet Widget Tests', () {
    testWidgets('Planned visit card menu includes Mark done action', (tester) async {
      final visit = ServiceVisit(
        id: 'visit-menu-1',
        dateTime: DateTime.now().add(const Duration(days: 3)),
        shopName: 'Motorcycle Masters',
        cost: 3200.0,
      );
      await ServiceVisitController.instance.addVisit(visit);

      await tester.pumpWidget(_wrap(const ServiceVisitCardWidget()));
      await tester.pump();

      expect(find.text('Motorcycle Masters'), findsOneWidget);
      expect(find.text('Planned'), findsOneWidget);

      // Open popup menu
      final moreButton = find.byIcon(Icons.more_vert_rounded).first;
      await tester.tap(moreButton);
      await tester.pump();

      // Verify "Mark done", "Edit Visit", "Cancel Visit" are all present
      expect(find.text('Mark done'), findsOneWidget);
      expect(find.text('Edit Visit'), findsOneWidget);
      expect(find.text('Cancel Visit'), findsOneWidget);
    });

    testWidgets('Past visit whose date passed without Mark done shows Not marked done', (tester) async {
      final pastVisitNotDone = ServiceVisit(
        id: 'visit-past-1',
        dateTime: DateTime.now().subtract(const Duration(days: 5)),
        shopName: 'Hunza Tuning',
        cost: 5000.0,
        isDone: false,
      );
      await ServiceVisitController.instance.addVisit(pastVisitNotDone);

      await tester.pumpWidget(_wrap(const ServiceVisitCardWidget()));
      await tester.pump();

      // Card displays past visit
      expect(find.text('PAST SERVICE VISITS'), findsOneWidget);
      expect(find.text('Hunza Tuning'), findsOneWidget);
      expect(find.text('Not marked done'), findsOneWidget);
      // Expected cost is NOT shown as a paid cost
      expect(find.text('Rs 5,000'), findsNothing);
    });

    testWidgets('Mark done sheet opens prefilled with expected cost and bike', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final visit = ServiceVisit(
        id: 'visit-sheet-1',
        dateTime: DateTime.now().add(const Duration(days: 2)),
        shopName: 'Skardu Workshop',
        bikeId: 'bike-gs150',
        cost: 4500.0,
      );
      await ServiceVisitController.instance.addVisit(visit);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => MarkServiceVisitDoneSheet.show(context, visit: visit),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify sheet title and shop name
      expect(find.text('Mark Visit Done'), findsOneWidget);
      expect(find.text('Skardu Workshop'), findsOneWidget);

      // Verify actual cost field prefilled with 4500
      expect(find.text('4500'), findsOneWidget);

      // Verify bike prefilled
      expect(find.text('Suzuki GS 150 SE'), findsOneWidget);

      // Tap Mark Done button
      await tester.ensureVisible(find.text('Mark Done'));
      await tester.tap(find.text('Mark Done'));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify visit marked done and expense created
      final updated = ServiceVisitController.instance.visits
          .firstWhere((v) => v.id == 'visit-sheet-1');
      expect(updated.isDone, isTrue);
      expect(TripBudgetController.instance.expenses.length, 1);
      expect(TripBudgetController.instance.expenses.first.amount, 4500.0);
    });
  });
}
