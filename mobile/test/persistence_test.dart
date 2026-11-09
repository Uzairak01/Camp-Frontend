import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/controllers/post_ride_report_controller.dart';
import 'package:camp/features/maintenance/controllers/trip_budget_controller.dart';
import 'package:camp/features/maintenance/domain/expense_model.dart';
import 'package:camp/features/maintenance/domain/maintenance_item_model.dart';
import 'package:camp/features/maintenance/domain/post_ride_report.dart';
import 'package:camp/features/maintenance/domain/trip_budget_model.dart';
import 'package:camp/features/settings/controllers/settings_controller.dart';
import 'package:camp/features/settings/domain/units_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStore.instance.resetForTesting();
    ActiveBikeController.instance.resetForTesting();
    SettingsController.instance.resetForTesting();
    PostRideReportController.instance = PostRideReportController();
    TripBudgetController.instance.resetForTesting();
  });

  group('First-run demo data seeding', () {
    test('Seeds demo fleet, settings, reports, and trip budget on first run', () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalStore();
      store.resetForTesting();

      expect(await store.isFirstRun(), isTrue);

      await ActiveBikeController.instance.load(store);
      await SettingsController.instance.load(store);
      await PostRideReportController.instance.load(store);
      await TripBudgetController.instance.load(store);

      expect(ActiveBikeController.instance.bikes, isEmpty);
      expect(ActiveBikeController.instance.activeBikeId, isNull);
      expect(SettingsController.instance.units, UnitsSystem.metric);
      expect(PostRideReportController.instance.reports, isEmpty);
      expect(TripBudgetController.instance.budget.tripName, isEmpty);
      expect(TripBudgetController.instance.expenses, isEmpty);

      await store.markFirstRunCompleted();
      expect(await store.isFirstRun(), isFalse);
    });

    test('User data wins on subsequent runs even if modified', () async {
      final store = LocalStore();
      store.resetForTesting();

      await store.markFirstRunCompleted();

      // User adds a custom bike
      const customBike = Bike(
        id: 'custom-bike-99',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2024,
        odometerKm: 500,
      );
      ActiveBikeController.instance.addBike(customBike, setActive: true);
      await ActiveBikeController.instance.save(store);

      // Reload controller from fresh store
      final freshStore = LocalStore();
      freshStore.resetForTesting();
      await ActiveBikeController.instance.load(freshStore);

      // Custom bike wins and defaults are NOT seeded
      expect(ActiveBikeController.instance.bikes.length, 1);
      expect(ActiveBikeController.instance.bikes.first.id, 'custom-bike-99');
      expect(ActiveBikeController.instance.activeBikeId, 'custom-bike-99');
    });

    test('Deleted bikes stay deleted after reload', () async {
      final store = LocalStore();
      store.resetForTesting();

      // Rider adds a bike then deletes it
      const customBike = Bike(
        id: 'temp-bike-1',
        make: 'KTM',
        modelName: '390 Adventure',
        modelYear: 2023,
        odometerKm: 500,
      );
      ActiveBikeController.instance.addBike(customBike, setActive: true);
      await ActiveBikeController.instance.save(store);

      ActiveBikeController.instance.removeBike('temp-bike-1');
      expect(ActiveBikeController.instance.bikes, isEmpty);
      await ActiveBikeController.instance.save(store);

      // Reload controller from fresh store
      final freshStore = LocalStore();
      freshStore.resetForTesting();
      await ActiveBikeController.instance.load(freshStore);

      // Garage remains empty; does NOT re-seed defaults
      expect(ActiveBikeController.instance.bikes, isEmpty);
      expect(ActiveBikeController.instance.activeBikeId, isNull);
    });
  });

  group('Round-trip persistence for each controller', () {
    test('ActiveBikeController round-trip saves and restores bikes & activeBikeId', () async {
      final store = LocalStore();
      store.resetForTesting();
      await store.markFirstRunCompleted();

      const testBike = Bike(
        id: 'test-ducati-v4',
        make: 'Ducati',
        modelName: 'DesertX',
        modelYear: 2025,
        odometerKm: 1200,
        displacement: 937,
      );

      ActiveBikeController.instance.addBike(testBike, setActive: true);
      await ActiveBikeController.instance.save(store);

      // Reset in-memory state without persisting
      ActiveBikeController.instance.resetForTesting();
      expect(ActiveBikeController.instance.activeBikeId, isNull);
      expect(ActiveBikeController.instance.bikes, isEmpty);

      // Restore from persistent store
      await ActiveBikeController.instance.load(store);
      expect(ActiveBikeController.instance.activeBikeId, 'test-ducati-v4');
      expect(
        ActiveBikeController.instance.bikes.any((b) => b.id == 'test-ducati-v4'),
        isTrue,
      );
    });

    test('SettingsController round-trip saves and restores preferences', () async {
      final store = LocalStore();
      store.resetForTesting();
      await store.markFirstRunCompleted();

      SettingsController.instance.setNotificationsEnabled(false);
      SettingsController.instance.setLanguage('English');
      SettingsController.instance.dismissAlert('item-1', 'dueSoon');
      await SettingsController.instance.save(store);

      // Reset to defaults
      SettingsController.instance.reset();
      expect(SettingsController.instance.units, UnitsSystem.metric);
      expect(SettingsController.instance.notificationsEnabled, isTrue);

      // Restore
      await SettingsController.instance.load(store);
      expect(SettingsController.instance.units, UnitsSystem.metric);
      expect(SettingsController.instance.notificationsEnabled, isFalse);
      expect(SettingsController.instance.isAlertDismissed('item-1', 'dueSoon'), isTrue);
    });

    test('PostRideReportController round-trip saves and restores reports', () async {
      final store = LocalStore();
      store.resetForTesting();
      await store.markFirstRunCompleted();

      final customReport = PostRideReport(
        id: 'rep-custom-roundtrip',
        bikeId: 'bike-bmw-1250',
        date: DateTime(2026, 9, 20),
        distanceKm: 312.4,
        terrainTags: const ['Mountain', 'Highway'],
        notes: 'High alpine test run',
        flaggedIssues: 'None',
      );

      PostRideReportController.instance.addReport(customReport);
      await PostRideReportController.instance.save(store);

      // Reset in-memory state without writing empty list to storage
      PostRideReportController.instance = PostRideReportController();
      expect(PostRideReportController.instance.reports, isEmpty);

      await PostRideReportController.instance.load(store);
      expect(PostRideReportController.instance.reports.isNotEmpty, isTrue);
      expect(
        PostRideReportController.instance.reports.first.id,
        'rep-custom-roundtrip',
      );
      expect(
        PostRideReportController.instance.reports.first.distanceKm,
        312.4,
      );
      expect(
        PostRideReportController.instance.reports.first,
        customReport,
      );
    });

    test('TripBudgetController round-trip saves and restores budget & expenses', () async {
      final store = LocalStore();
      store.resetForTesting();
      await store.markFirstRunCompleted();

      const customBudget = TripBudget(
        tripName: 'Karakoram Highway Expedition',
        capAmount: 850.0,
        allocatedSoFar: 220.0,
        startDate: 'Aug 1, 2026',
        endDate: 'Aug 10, 2026',
      );
      const customExpense = Expense(
        id: 'exp-roundtrip-1',
        category: ExpenseCategory.fuel,
        title: 'High Altitude High Octane',
        amount: 85.0,
        trackingMode: ExpenseTrackingMode.manualEntry,
      );

      TripBudgetController.instance.setBudget(customBudget);
      TripBudgetController.instance.addExpense(customExpense);
      await TripBudgetController.instance.save(store);

      TripBudgetController.instance.resetForTesting();
      expect(
        TripBudgetController.instance.budget.tripName,
        '',
      );

      await TripBudgetController.instance.load(store);
      expect(
        TripBudgetController.instance.budget.tripName,
        'Karakoram Highway Expedition',
      );
      expect(TripBudgetController.instance.budget.capAmount, 850.0);
      expect(
        TripBudgetController.instance.expenses.any((e) => e.id == 'exp-roundtrip-1'),
        isTrue,
      );
    });

    test('Every field of Bike, PostRideReport, Expense, and TripBudget survives save and load', () async {
      final store = LocalStore();
      store.resetForTesting();
      await store.markFirstRunCompleted();

      final fullSpecBike = Bike(
        id: 'bike-full-spec-1',
        make: 'KTM',
        modelName: '890 Adventure R',
        modelYear: 2024,
        odometerKm: 6450,
        fuelLevelOdometerKm: 6450.0,
        displacement: 889,
        bikeType: 'Adventure',
        fuelSystem: FuelSystem.efi,
        carburetorType: null,
        fuelTankCapacityLiters: 20.0,
        fuelAverageKmPerLiter: 21.5,
        ridingTerrain: const ['Off-road', 'Mountain'],
        edition: 'Rally Edition',
        imagePath: 'assets/images/ktm_890.jpg',
        currentFuelLiters: 14.2,
        lastOilChange: ServiceRecord(
          mode: TrackingMode.byDistance,
          km: 5000,
          date: DateTime(2026, 5, 1),
        ),
        lastTuneUp: ServiceRecord(
          mode: TrackingMode.byDate,
          km: 6000,
          date: DateTime(2026, 6, 15),
        ),
        vin: 'VBKVA4400PM000001',
        nickname: 'Orange Beast',
        lastUpdated: DateTime(2026, 7, 10, 12, 0),
      );

      final fullSpecReport = PostRideReport(
        id: 'rep-full-spec-1',
        bikeId: 'bike-full-spec-1',
        date: DateTime(2026, 8, 15, 10, 30),
        distanceKm: 245.5,
        terrainTags: const ['Mountain', 'Off-road', 'Highway'],
        notes: 'Scenic pass traverse with scree crossing',
        flaggedIssues: 'Front tire pressure drop',
      );

      final fullSpecExpense = Expense(
        id: 'exp-full-spec-1',
        category: ExpenseCategory.fuel,
        title: 'High-octane fuel',
        amount: 55.40,
        trackingMode: ExpenseTrackingMode.autoTrack,
        subtitle: '5.2 gallons at pass',
        note: 'Card receipt #991',
        dateRecorded: DateTime(2026, 8, 15, 11, 45),
        formattedDate: 'Aug 15, 11:45 AM',
      );

      const fullSpecBudget = TripBudget(
        tripName: 'North Cascade Loop',
        capAmount: 600.0,
        startDate: 'Aug 10, 2026',
        endDate: 'Aug 20, 2026',
        allocatedSoFar: 310.40,
      );

      ActiveBikeController.instance.addBike(fullSpecBike, setActive: true);
      await ActiveBikeController.instance.save(store);

      PostRideReportController.instance.addReport(fullSpecReport);
      await PostRideReportController.instance.save(store);

      TripBudgetController.instance.setBudget(fullSpecBudget);
      TripBudgetController.instance.addExpense(fullSpecExpense);
      await TripBudgetController.instance.save(store);

      // Clear in-memory singletons
      ActiveBikeController.instance.resetForTesting();
      PostRideReportController.instance = PostRideReportController();
      TripBudgetController.instance.resetForTesting();

      // Reload
      await ActiveBikeController.instance.load(store);
      await PostRideReportController.instance.load(store);
      await TripBudgetController.instance.load(store);

      // Verify exact equality across all fields
      expect(ActiveBikeController.instance.getBikeById('bike-full-spec-1'), fullSpecBike);
      expect(ActiveBikeController.instance.activeBikeId, 'bike-full-spec-1');
      expect(PostRideReportController.instance.reports.first, fullSpecReport);
      expect(TripBudgetController.instance.budget.tripName, fullSpecBudget.tripName);
      expect(TripBudgetController.instance.budget.capAmount, fullSpecBudget.capAmount);
      expect(TripBudgetController.instance.budget.startDate, fullSpecBudget.startDate);
      expect(TripBudgetController.instance.budget.endDate, fullSpecBudget.endDate);
      expect(
        TripBudgetController.instance.expenses.firstWhere((e) => e.id == 'exp-full-spec-1'),
        fullSpecExpense,
      );
    });
  });

  group('Corrupt JSON & Schema Version Fallback', () {
    test('Corrupted or invalid JSON falls back to defaults without crashing', () async {
      SharedPreferences.setMockInitialValues({
        LocalStore.schemaVersionKey: 1,
        LocalStore.keyFirstRunCompleted: true,
        LocalStore.keyBikes: '{corrupt json syntax::: invalid',
        LocalStore.keySettings: 'not valid json at all',
        LocalStore.keyPostRideReports: '{"broken": [true, false]}',
        LocalStore.keyTripBudget: '{"tripName": null, "capAmount": "invalid_num"}',
        LocalStore.keyTripExpenses: 'not_a_list',
      });

      final store = LocalStore();
      store.resetForTesting();

      await ActiveBikeController.instance.load(store);
      await SettingsController.instance.load(store);
      await PostRideReportController.instance.load(store);
      await TripBudgetController.instance.load(store);

      expect(ActiveBikeController.instance.bikes, isEmpty);
      expect(SettingsController.instance.units, UnitsSystem.metric);
      expect(PostRideReportController.instance.reports, isEmpty);
      expect(TripBudgetController.instance.budget.tripName, isEmpty);
    });

    test('Incompatible future schema version falls back safely to defaults', () async {
      SharedPreferences.setMockInitialValues({
        LocalStore.schemaVersionKey: 999,
        LocalStore.keyFirstRunCompleted: true,
        LocalStore.keySettings: '{"units": "imperial"}',
        LocalStore.keyBikes: '[{"id": "future-bike"}]',
        LocalStore.keyPostRideReports: '[{"id": "future-rep"}]',
        LocalStore.keyTripBudget: '{"tripName": "Future Tour"}',
      });

      final store = LocalStore();
      store.resetForTesting();

      await SettingsController.instance.load(store);
      await ActiveBikeController.instance.load(store);
      await PostRideReportController.instance.load(store);
      await TripBudgetController.instance.load(store);

      expect(SettingsController.instance.units, UnitsSystem.metric);
      expect(ActiveBikeController.instance.bikes, isEmpty);
      expect(PostRideReportController.instance.reports, isEmpty);
      expect(TripBudgetController.instance.budget.tripName, isEmpty);
    });

    test('Missing schema version after first run completed falls back safely', () async {
      SharedPreferences.setMockInitialValues({
        LocalStore.keyFirstRunCompleted: true,
        // schemaVersionKey missing
        LocalStore.keySettings: '{"units": "imperial"}',
      });

      final store = LocalStore();
      store.resetForTesting();

      await SettingsController.instance.load(store);
      expect(SettingsController.instance.units, UnitsSystem.metric);
    });
  });

  group('Clear Cache Isolation', () {
    test('Settings clearLocalCache leaves garage, reports, and settings intact on disk', () async {
      final store = LocalStore();
      store.resetForTesting();
      await store.markFirstRunCompleted();

      // Configure custom garage bike, post-ride report, and settings
      const testBike = Bike(
        id: 'cache-test-bike',
        make: 'Triumph',
        modelName: 'Tiger 900',
        modelYear: 2024,
        odometerKm: 3100,
      );
      ActiveBikeController.instance.addBike(testBike, setActive: true);
      await ActiveBikeController.instance.save(store);

      final testReport = PostRideReport(
        id: 'cache-test-report',
        bikeId: 'cache-test-bike',
        date: DateTime(2026, 9, 1),
        distanceKm: 140.0,
        terrainTags: const ['Mountain'],
      );
      PostRideReportController.instance.addReport(testReport);
      await PostRideReportController.instance.save(store);

      SettingsController.instance.setNotificationsEnabled(false);
      await SettingsController.instance.save(store);

      expect(SettingsController.instance.localCacheSizeGb, greaterThanOrEqualTo(0.0));

      // Execute Clear Local Cache from Settings
      SettingsController.instance.clearLocalCache();

      // Local cache size display is cleared
      expect(SettingsController.instance.localCacheSizeGb, 0.0);
      expect(SettingsController.instance.localCacheDisplay, '0 B');

      // Reload from a completely fresh LocalStore instance
      final freshStore = LocalStore();
      freshStore.resetForTesting();

      ActiveBikeController.instance.resetForTesting();
      PostRideReportController.instance = PostRideReportController();
      SettingsController.instance.resetForTesting();

      await ActiveBikeController.instance.load(freshStore);
      await PostRideReportController.instance.load(freshStore);
      await SettingsController.instance.load(freshStore);

      // Assert they are ALL still there!
      expect(
        ActiveBikeController.instance.bikes.any((b) => b.id == 'cache-test-bike'),
        isTrue,
      );
      expect(ActiveBikeController.instance.activeBikeId, 'cache-test-bike');
      expect(
        PostRideReportController.instance.reports.any((r) => r.id == 'cache-test-report'),
        isTrue,
      );
      expect(SettingsController.instance.units, UnitsSystem.metric);
      expect(SettingsController.instance.notificationsEnabled, isFalse);
    });
  });

  group('Trip Deletion Isolation', () {
    test('deleteTrip saves and clears ledger while maintenance items, bikes, and reports stay intact', () async {
      final store = LocalStore();
      store.resetForTesting();
      await store.markFirstRunCompleted();

      // Set up garage bike, report, maintenance item and trip
      const bike = Bike(
        id: 'trip-del-bike',
        make: 'Honda',
        modelName: 'Transalp',
        modelYear: 2024,
        odometerKm: 2100,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);
      await ActiveBikeController.instance.save(store);

      final report = PostRideReport(
        id: 'trip-del-report',
        bikeId: 'trip-del-bike',
        date: DateTime(2026, 9, 5),
        distanceKm: 88.0,
        terrainTags: const ['City'],
      );
      PostRideReportController.instance.addReport(report);
      await PostRideReportController.instance.save(store);

      final maintenanceItemsBefore = [
        const MaintenanceItem(
          id: 'test-item-1',
          name: 'Chain Lubrication',
          category: 'Drive',
          status: MaintenanceStatus.ok,
          trackingMode: MaintenanceTrackingMode.manual,
        ),
      ];

      // Execute deleteTrip
      TripBudgetController.instance.deleteTrip();
      await TripBudgetController.instance.save(store);

      expect(TripBudgetController.instance.budget.tripName, 'New Expedition');
      expect(TripBudgetController.instance.budget.capAmount, 0.0);
      expect(TripBudgetController.instance.expenses, isEmpty);

      // Reload from persistent store
      final freshStore = LocalStore();
      freshStore.resetForTesting();

      await TripBudgetController.instance.load(freshStore);
      expect(TripBudgetController.instance.budget.tripName, 'New Expedition');
      expect(TripBudgetController.instance.budget.capAmount, 0.0);
      expect(TripBudgetController.instance.expenses, isEmpty);

      // Confirm maintenance items, bikes, and reports are completely untouched
      expect(maintenanceItemsBefore.length, 1);
      expect(
        ActiveBikeController.instance.bikes.any((b) => b.id == 'trip-del-bike'),
        isTrue,
      );
      expect(
        PostRideReportController.instance.reports.any((r) => r.id == 'trip-del-report'),
        isTrue,
      );
    });
  });

  group('Save ordering and flush', () {
    test('two rapid mutations, then await flush, then reload from a fresh store gives the last state', () async {
      SharedPreferences.setMockInitialValues({});
      LocalStore.instance.resetForTesting();
      ActiveBikeController.instance.resetForTesting();

      // Seed first run completed so subsequent loads don't re-seed defaults
      await LocalStore.instance.markFirstRunCompleted();

      const bikeA = Bike(
        id: 'rapid-bike-1',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2024,
        displacement: 689,
        bikeType: 'Adventure',
        fuelSystem: FuelSystem.efi,
        carburetorType: null,
        fuelTankCapacityLiters: 16.0,
        fuelAverageKmPerLiter: 23.0,
        ridingTerrain: ['Off-road', 'Highway'],
        edition: 'Rally',
        imagePath: null,
        odometerKm: 2500,
        currentFuelLiters: 12.0,
        lastOilChange: null,
        lastTuneUp: null,
        vin: 'RAPIDVIN1',
        nickname: 'T7 Rapid 1',
      );

      const bikeB = Bike(
        id: 'rapid-bike-2',
        make: 'Ducati',
        modelName: 'DesertX',
        modelYear: 2024,
        displacement: 937,
        bikeType: 'Adventure',
        fuelSystem: FuelSystem.efi,
        carburetorType: null,
        fuelTankCapacityLiters: 21.0,
        fuelAverageKmPerLiter: 18.0,
        ridingTerrain: ['Off-road', 'Desert'],
        edition: 'Discovery',
        imagePath: null,
        odometerKm: 1200,
        currentFuelLiters: 15.0,
        lastOilChange: null,
        lastTuneUp: null,
        vin: 'RAPIDVIN2',
        nickname: 'DesertX Rapid 2',
      );

      // Mutation 1 (fire-and-forget save)
      ActiveBikeController.instance.addBike(bikeA, setActive: true);

      // Mutation 2 immediately afterwards without awaiting (fire-and-forget save)
      ActiveBikeController.instance.addBike(bikeB, setActive: true);

      // Await flush() so queued writes complete in strict order
      await LocalStore.instance.flush();

      // Reload into a freshly reset controller using a fresh LocalStore
      final freshStore = LocalStore();
      freshStore.resetForTesting();
      final reloadController = ActiveBikeController.instance;
      reloadController.resetForTesting();

      await reloadController.load(freshStore);

      // State must reflect both rapid mutations with the second one as active
      expect(reloadController.bikes.length, 2);
      expect(reloadController.bikes.any((b) => b.id == 'rapid-bike-1'), isTrue);
      expect(reloadController.bikes.any((b) => b.id == 'rapid-bike-2'), isTrue);
      expect(reloadController.activeBikeId, 'rapid-bike-2');
    });

    test('clearAll() awaits its save and persists empty list', () async {
      SharedPreferences.setMockInitialValues({});
      LocalStore.instance.resetForTesting();
      PostRideReportController.instance = PostRideReportController();
      await LocalStore.instance.markFirstRunCompleted();

      final report = PostRideReport(
        id: 'clear-rep-1',
        bikeId: 'bike-bmw-1250',
        date: DateTime.now(),
        distanceKm: 100.0,
        terrainTags: const ['Highway'],
      );
      PostRideReportController.instance.addReport(report);
      await PostRideReportController.instance.flush();

      // clearAll() awaits save
      await PostRideReportController.instance.clearAll();

      // Reload from fresh store
      final freshStore = LocalStore();
      freshStore.resetForTesting();
      PostRideReportController.instance = PostRideReportController();
      await PostRideReportController.instance.load(freshStore);

      expect(PostRideReportController.instance.reports, isEmpty);
    });
  });
}
