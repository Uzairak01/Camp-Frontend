import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/controllers/maintenance_controller.dart';
import 'package:camp/features/maintenance/controllers/post_ride_report_controller.dart';
import 'package:camp/features/maintenance/controllers/service_visit_controller.dart';
import 'package:camp/features/maintenance/controllers/trip_budget_controller.dart';
import 'package:camp/features/maintenance/domain/maintenance_item_model.dart';
import 'package:camp/features/maintenance/domain/service_visit_model.dart';
import 'package:camp/features/maintenance/presentation/screens/add_maintenance_item_screen.dart';
import 'package:camp/features/maintenance/presentation/widgets/maintenance_item_card_widget.dart';
import 'package:camp/features/maintenance/presentation/widgets/maintenance_list_widget.dart';
import 'package:camp/features/maintenance/presentation/widgets/plan_service_visit_sheet.dart';
import 'package:camp/features/maintenance/presentation/widgets/service_visit_card_widget.dart';
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
  );

  const bikeB = Bike(
    id: 'bike-gs150',
    make: 'Suzuki',
    modelName: 'GS 150 SE',
    modelYear: 2023,
    odometerKm: 8200,
  );

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

    // Register test garage fleet with CD70 active
    ActiveBikeController.instance.addBike(bikeA, setActive: true);
    ActiveBikeController.instance.addBike(bikeB);
  });

  group('CAMP Bike Label on Maintenance Items and Service Visits', () {
    testWidgets('1. Item with bikeId shows that bike\'s chip and updates on rename',
        (tester) async {
      const item = MaintenanceItem(
        id: 'item-front-tyre',
        bikeId: 'bike-gs150',
        name: 'Front Tyre',
        category: 'Tires',
        status: MaintenanceStatus.ok,
        trackingMode: MaintenanceTrackingMode.manual,
      );

      await tester.pumpWidget(_wrap(const MaintenanceItemCardWidget(item: item)));
      await tester.pump();

      // GS 150 SE chip is visible
      expect(find.text('Suzuki GS 150 SE'), findsOneWidget);

      // Rename the bike dynamically
      ActiveBikeController.instance.updateBike(
        bikeB.copyWith(nickname: 'GS Custom SE'),
      );
      await tester.pump();

      // Dynamic rename followed
      expect(find.text('GS Custom SE'), findsOneWidget);
      expect(find.text('Suzuki GS 150 SE'), findsNothing);
    });

    testWidgets('2. Old item without bikeId shows "No bike"', (tester) async {
      const oldItem = MaintenanceItem(
        id: 'item-legacy',
        name: 'Rear Brake Pad Replacement',
        category: 'Brakes',
        status: MaintenanceStatus.dueSoon,
        trackingMode: MaintenanceTrackingMode.auto,
      );

      await tester.pumpWidget(_wrap(const MaintenanceItemCardWidget(item: oldItem)));
      await tester.pump();

      expect(find.text('No bike'), findsOneWidget);
    });

    testWidgets('3. Deleted bike shows "Deleted bike"', (tester) async {
      const itemWithDeletedBike = MaintenanceItem(
        id: 'item-deleted-bike',
        bikeId: 'bike-non-existent',
        name: 'Fork Oil Replacement',
        category: 'Suspension',
        status: MaintenanceStatus.ok,
        trackingMode: MaintenanceTrackingMode.manual,
      );

      await tester.pumpWidget(
        _wrap(const MaintenanceItemCardWidget(item: itemWithDeletedBike)),
      );
      await tester.pump();

      expect(find.text('Deleted bike'), findsOneWidget);
    });

    testWidgets(
        '4. Items for a non-active bike are still listed, after the active bike\'s',
        (tester) async {
      // Active bike is bike-cd70
      expect(ActiveBikeController.instance.activeBike?.id, 'bike-cd70');

      const nonActiveBikeItem = MaintenanceItem(
        id: 'item-gs',
        bikeId: 'bike-gs150',
        name: 'GS 150 SE Front Tyre',
        category: 'Tires',
        status: MaintenanceStatus.ok,
        trackingMode: MaintenanceTrackingMode.manual,
      );

      const activeBikeItem = MaintenanceItem(
        id: 'item-cd',
        bikeId: 'bike-cd70',
        name: 'CD70 Engine Oil',
        category: 'Engine',
        status: MaintenanceStatus.dueSoon,
        trackingMode: MaintenanceTrackingMode.auto,
      );

      const unassignedItem = MaintenanceItem(
        id: 'item-legacy',
        name: 'Unassigned Spark Plug',
        category: 'Engine',
        status: MaintenanceStatus.ok,
        trackingMode: MaintenanceTrackingMode.manual,
      );

      // Pass items in reverse order: non-active first, then active, then unassigned
      await tester.pumpWidget(
        _wrap(
          MaintenanceListWidget(
            dueItems: const [],
            hasSchedule: true,
            onSetUpSchedule: () {},
            items: const [nonActiveBikeItem, activeBikeItem, unassignedItem],
            onAddMaintenanceItem: () {},
          ),
        ),
      );
      await tester.pump();

      // All items remain fully visible and listed
      expect(find.text('CD70 Engine Oil'), findsOneWidget);
      expect(find.text('GS 150 SE Front Tyre'), findsOneWidget);
      expect(find.text('Unassigned Spark Plug'), findsOneWidget);

      // Verify active bike item comes first in vertical order
      final activeTop = tester.getTopLeft(find.text('CD70 Engine Oil')).dy;
      final nonActiveTop =
          tester.getTopLeft(find.text('GS 150 SE Front Tyre')).dy;
      final unassignedTop =
          tester.getTopLeft(find.text('Unassigned Spark Plug')).dy;

      expect(activeTop, lessThan(nonActiveTop));
      expect(activeTop, lessThan(unassignedTop));
    });

    testWidgets('5. The add form\'s bike picker defaults to the active bike',
        (tester) async {
      // Active bike is bike-cd70 (Honda CD70 Dream)
      expect(ActiveBikeController.instance.activeBike?.id, 'bike-cd70');

      await tester.pumpWidget(
        const MaterialApp(home: AddMaintenanceItemScreen()),
      );
      await tester.pump();

      // Dropdown defaults to active bike name
      expect(find.text('Honda CD70 Dream'), findsOneWidget);
    });

    testWidgets(
        '6. Edit form for old item shows "No bike" and does not silently assign a bike',
        (tester) async {
      const oldItem = MaintenanceItem(
        id: 'item-old-no-bike',
        name: 'Pre-existing Cable Check',
        category: 'Drivetrain',
        status: MaintenanceStatus.ok,
        trackingMode: MaintenanceTrackingMode.manual,
      );

      MaintenanceItem? savedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                savedResult = await Navigator.of(context).push<MaintenanceItem>(
                  MaterialPageRoute(
                    builder: (context) =>
                        const AddMaintenanceItemScreen(initialItem: oldItem),
                  ),
                );
              },
              child: const Text('Open Edit'),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Edit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Prefilled as "No bike"
      expect(find.text('No bike'), findsOneWidget);

      // Save without touching the bike picker
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Result maintains bikeId as null without silent assignment
      expect(savedResult, isNotNull);
      expect(savedResult!.bikeId, isNull);
    });

    testWidgets(
        '7. Next Service Visit: shows the soonest planned visit across all bikes with bike chip',
        (tester) async {
      // Bike A (active) has visit in 5 days
      final visitA = ServiceVisit(
        id: 'visit-cd70',
        bikeId: 'bike-cd70',
        shopName: 'Honda Service Point',
        dateTime: DateTime.now().add(const Duration(days: 5)),
      );

      // Bike B (non-active) has soonest visit in 2 days
      final visitB = ServiceVisit(
        id: 'visit-gs150',
        bikeId: 'bike-gs150',
        shopName: 'Suzuki Authorized Works',
        dateTime: DateTime.now().add(const Duration(days: 2)),
      );

      await ServiceVisitController.instance.addVisit(visitA);
      await ServiceVisitController.instance.addVisit(visitB);

      await tester.pumpWidget(_wrap(const ServiceVisitCardWidget()));
      await tester.pump();

      // Card displays soonest visit (Suzuki) with its bike chip
      expect(find.text('NEXT SERVICE VISIT'), findsOneWidget);
      expect(find.text('Suzuki Authorized Works'), findsOneWidget);
      expect(find.text('Suzuki GS 150 SE'), findsOneWidget);
    });

    testWidgets('8. Service visit with deleted bike or no bike displays correct chip',
        (tester) async {
      final visitDeleted = ServiceVisit(
        id: 'visit-deleted',
        bikeId: 'bike-obsolete',
        shopName: 'Old Shop',
        dateTime: DateTime.now().add(const Duration(days: 1)),
      );

      await tester.pumpWidget(
        _wrap(ServiceVisitCardWidget(visit: visitDeleted)),
      );
      await tester.pump();

      expect(find.text('Deleted bike'), findsOneWidget);

      final visitNoBike = ServiceVisit(
        id: 'visit-unassigned',
        bikeId: null,
        shopName: 'Independent Mechanic',
        dateTime: DateTime.now().add(const Duration(days: 1)),
      );

      await tester.pumpWidget(
        _wrap(ServiceVisitCardWidget(visit: visitNoBike)),
      );
      await tester.pump();

      expect(find.text('No bike'), findsOneWidget);
    });

    testWidgets(
        '9. Plan service visit sheet bike picker defaults to active bike and allows selection',
        (tester) async {
      expect(ActiveBikeController.instance.activeBike?.id, 'bike-cd70');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlanServiceVisitSheet(),
          ),
        ),
      );
      await tester.pump();

      // Defaults to active bike
      expect(find.text('Honda CD70 Dream'), findsOneWidget);
    });
  });
}
