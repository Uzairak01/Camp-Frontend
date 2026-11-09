import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/data/maintenance_repository.dart';
import 'package:camp/core/data/service_visit_repository.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/core/widgets/app_messenger.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/controllers/maintenance_controller.dart';
import 'package:camp/features/maintenance/controllers/service_visit_controller.dart';
import 'package:camp/features/maintenance/controllers/trip_budget_controller.dart';
import 'package:camp/features/maintenance/domain/maintenance_item_model.dart';
import 'package:camp/features/maintenance/domain/service_schedule_item.dart';
import 'package:camp/features/maintenance/domain/service_visit_model.dart';
import 'package:camp/features/maintenance/presentation/screens/finance_rig_health_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test repository that throws on saveServiceSchedule to verify write failure rollback.
class ThrowingMaintenanceRepository extends Fake implements MaintenanceRepository {
  ThrowingMaintenanceRepository({this.throwOnSave = true});

  final bool throwOnSave;
  final Map<String, List<ServiceScheduleItem>> _schedules = {};
  final Map<String, bool> _harsh = {};

  @override
  Future<List<ServiceScheduleItem>> loadServiceSchedule(String bikeId) async =>
      _schedules[bikeId] ?? [];

  @override
  Future<void> saveServiceSchedule(String bikeId, List<ServiceScheduleItem> items) async {
    if (throwOnSave) {
      throw Exception('Disk I/O failure while writing schedule');
    }
    _schedules[bikeId] = List.from(items);
  }

  @override
  Future<bool> loadHarshConditions(String bikeId) async => _harsh[bikeId] ?? false;

  @override
  Future<void> saveHarshConditions(String bikeId, bool isHarsh) async {
    _harsh[bikeId] = isHarsh;
  }

  @override
  Future<List<MaintenanceItem>> loadMaintenanceItems() async => [];

  @override
  Future<void> saveMaintenanceItems(List<MaintenanceItem> items) async {}

  @override
  Future<void> deleteMaintenanceItem(String id) async {}
}

/// Test repository that throws on saveServiceVisits to verify write failure rollback.
class ThrowingServiceVisitRepository extends Fake implements ServiceVisitRepository {
  ThrowingServiceVisitRepository({this.throwOnSave = true});

  final bool throwOnSave;
  List<ServiceVisit> _visits = [];

  @override
  Future<List<ServiceVisit>> loadServiceVisits() async => List.from(_visits);

  @override
  Future<void> saveServiceVisits(List<ServiceVisit> visits) async {
    if (throwOnSave) {
      throw Exception('Disk I/O failure while writing visits');
    }
    _visits = List.from(visits);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    LocalStore.instance.resetForTesting(prefs);
    AppRepositories.resetToDefault();
    ActiveBikeController.instance.resetForTesting();
    TripBudgetController.instance.resetForTesting();
    ServiceVisitController.instance = ServiceVisitController();
    MaintenanceController.instance = MaintenanceController();
  });

  group('Item 1: Background disk writes rollback and error snackbar surfacing', () {
    testWidgets('MaintenanceController.saveSchedule rolls back state and shows snackbar on throw', (tester) async {
      final throwingRepo = ThrowingMaintenanceRepository(throwOnSave: true);
      final controller = MaintenanceController(repository: throwingRepo);
      MaintenanceController.instance = controller;

      const bike = Bike(
        id: 'bike-throw-test',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2023,
        odometerKm: 5000,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      // Initial state has default unconfigured items
      final initialItems = controller.getScheduleItems(bike.id);
      expect(initialItems.first.intervalKm, isNull);

      final newItems = [
        initialItems.first.copyWith(intervalKm: 2500, enabled: true),
      ];

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          home: const Scaffold(body: Text('Test Root')),
        ),
      );
      await tester.pump();

      // Expect saveSchedule to rethrow on repository failure
      await expectLater(
        controller.saveSchedule(bike.id, newItems),
        throwsA(isA<Exception>()),
      );

      // Verify state was rolled back to previous schedule
      final rolledBackItems = controller.getScheduleItems(bike.id);
      expect(rolledBackItems.first.intervalKm, isNull);

      // Verify the snackbar error was surfaced
      await tester.pump();
      expect(find.text('Could not save, please try again'), findsOneWidget);
    });

    testWidgets('MaintenanceController.markItemDone rolls back state and shows snackbar on throw', (tester) async {
      final throwingRepo = ThrowingMaintenanceRepository(throwOnSave: true);
      final controller = MaintenanceController(repository: throwingRepo);
      MaintenanceController.instance = controller;

      const bike = Bike(
        id: 'bike-mark-throw',
        make: 'KTM',
        modelName: '390 Adv',
        modelYear: 2023,
        odometerKm: 4000,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      final items = controller.getScheduleItems(bike.id);
      final oilItem = items.firstWhere((i) => i.type == ServiceItemType.oilAndSmallService);
      expect(oilItem.lastDoneKm, isNull);

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          home: const Scaffold(body: Text('Test Root')),
        ),
      );
      await tester.pump();

      await expectLater(
        controller.markItemDone(
          bike.id,
          oilItem.id,
          odometerKm: 4500,
          date: DateTime.now(),
        ),
        throwsA(isA<Exception>()),
      );

      // Verify schedule rolled back (lastDoneKm remains null)
      final afterItems = controller.getScheduleItems(bike.id);
      final afterOil = afterItems.firstWhere((i) => i.type == ServiceItemType.oilAndSmallService);
      expect(afterOil.lastDoneKm, isNull);

      // Verify bike was not updated because write failed
      expect(ActiveBikeController.instance.activeBike?.odometerKm, 4000);

      // Verify error snackbar surfaced
      await tester.pump();
      expect(find.text('Could not save, please try again'), findsOneWidget);
    });

    testWidgets('ServiceVisitController addVisit rolls back state and shows snackbar on throw', (tester) async {
      final throwingRepo = ThrowingServiceVisitRepository(throwOnSave: true);
      final controller = ServiceVisitController(repository: throwingRepo);
      ServiceVisitController.instance = controller;

      final visit = ServiceVisit(
        id: 'visit-err-1',
        dateTime: DateTime.now().add(const Duration(days: 3)),
        shopName: 'Apex Moto Lab',
      );

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          home: const Scaffold(body: Text('Test Root')),
        ),
      );
      await tester.pump();

      await expectLater(
        controller.addVisit(visit),
        throwsA(isA<Exception>()),
      );

      // Verify in-memory state rolled back (visit not in list)
      expect(controller.visits.any((v) => v.id == 'visit-err-1'), isFalse);

      // Verify error snackbar surfaced
      await tester.pump();
      expect(find.text('Could not save, please try again'), findsOneWidget);
    });

    testWidgets('ServiceVisitController deleteVisit rolls back state and shows snackbar on throw', (tester) async {
      final throwingRepo = ThrowingServiceVisitRepository(throwOnSave: false);
      final controller = ServiceVisitController(repository: throwingRepo);
      ServiceVisitController.instance = controller;

      final initialVisit = ServiceVisit(
        id: 'visit-to-delete',
        dateTime: DateTime.now().add(const Duration(days: 5)),
        shopName: 'Mountain Garage',
      );
      await controller.addVisit(initialVisit);
      expect(controller.visits.length, 1);

      // Now enable throwing on save
      final failingRepo = ThrowingServiceVisitRepository(throwOnSave: true);
      controller.repository = failingRepo;

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          home: const Scaffold(body: Text('Test Root')),
        ),
      );
      await tester.pump();

      await expectLater(
        controller.deleteVisit('visit-to-delete'),
        throwsA(isA<Exception>()),
      );

      // Verify in-memory state rolled back (visit restored in list)
      expect(controller.visits.length, 1);
      expect(controller.visits.first.id, 'visit-to-delete');

      // Verify error snackbar surfaced
      await tester.pump();
      expect(find.text('Could not save, please try again'), findsOneWidget);
    });
  });

  group('Item 3: Finances screen rider-added maintenance items persistence after app restart', () {
    testWidgets('Saves item, recreates controllers, and confirms item loads upon app restart', (tester) async {
      const savedItem = MaintenanceItem(
        id: 'item-custom-persist-1',
        name: 'Fork Seal Replacement',
        category: 'Suspension',
        dueMileage: '10,000 km',
        status: MaintenanceStatus.ok,
        trackingMode: MaintenanceTrackingMode.manual,
      );

      // Save item through repository into the mock storage
      await tester.runAsync(() async {
        await AppRepositories.instance.maintenanceRepository.saveMaintenanceItems([savedItem]);
      });

      // Simulate app restart by completely resetting in-memory singleton controllers
      ActiveBikeController.instance = ActiveBikeController();
      TripBudgetController.instance = TripBudgetController();
      ServiceVisitController.instance = ServiceVisitController();
      MaintenanceController.instance = MaintenanceController();

      // Launch FinanceRigHealthScreen inside MaterialApp
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FinanceRigHealthScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll into view and verify the persisted item was loaded and appears on the screen
      await tester.ensureVisible(find.text('Fork Seal Replacement'));
      expect(find.text('Fork Seal Replacement'), findsOneWidget);
    });
  });
}
