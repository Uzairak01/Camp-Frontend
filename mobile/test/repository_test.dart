import 'package:camp/app/theme/app_colors.dart';
import 'package:camp/core/data/bike_repository.dart';
import 'package:camp/core/data/bike_repository_local.dart';
import 'package:camp/core/data/finance_repository_local.dart';
import 'package:camp/core/data/maintenance_repository_local.dart';
import 'package:camp/core/data/mechanic_repository_local.dart';
import 'package:camp/core/data/place_repository_local.dart';
import 'package:camp/core/data/profile_repository_local.dart';
import 'package:camp/core/data/ride_report_repository_local.dart';
import 'package:camp/core/data/settings_repository_local.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/domain/user_profile_model.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/domain/expense_model.dart';
import 'package:camp/features/maintenance/domain/maintenance_item_model.dart';
import 'package:camp/features/maintenance/domain/post_ride_report.dart';
import 'package:camp/features/maintenance/domain/trip_budget_model.dart';
import 'package:camp/features/mechanics/domain/mechanic_model.dart';
import 'package:camp/features/navigation/domain/geocoding_service.dart';
import 'package:camp/features/settings/domain/app_settings.dart';
import 'package:camp/features/settings/domain/units_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory fake implementation of [BikeRepository] for testing.
class FakeBikeRepository implements BikeRepository {
  final List<Bike> _bikes = [];
  String? _activeBikeId;
  bool _firstRun = true;

  @override
  Future<bool> isFirstRun() async => _firstRun;

  @override
  Future<void> markFirstRunCompleted() async {
    _firstRun = false;
  }

  @override
  Future<List<Bike>> loadBikes() async => List.unmodifiable(_bikes);

  @override
  Future<void> saveBikes(List<Bike> bikes) async {
    _bikes.clear();
    _bikes.addAll(bikes);
  }

  @override
  Future<String?> loadActiveBikeId() async => _activeBikeId;

  @override
  Future<void> saveActiveBikeId(String? id) async {
    _activeBikeId = id;
  }

  @override
  Future<void> deleteBike(String id) async {
    _bikes.removeWhere((b) => b.effectiveId == id);
    if (_activeBikeId == id) {
      _activeBikeId = _bikes.isNotEmpty ? _bikes.first.effectiveId : null;
    }
  }

  @override
  Future<void> clear() async {
    _bikes.clear();
    _activeBikeId = null;
  }

  @override
  Future<void> flush() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = LocalStore(prefs);
    LocalStore.instance = store;
  });

  group('Repository Layer - Save, Load, Delete Round Trip', () {
    test('ProfileRepositoryLocal round trip', () async {
      final repo = ProfileRepositoryLocal(store);

      final profile = UserProfile(
        id: 'prof-test-1',
        fullName: 'Ahmad Khan',
        username: '@ahmad_adv',
        email: 'ahmad@example.com',
        phone: '+92 300 0000000',
        homeCity: 'Gilgit',
        dob: '1995-04-12',
        avatarPath: '/path/avatar.jpg',
        ridingTier: 'Explorer',
        experienceIndex: 2,
        ridingStyles: const {'Touring', 'Enduro'},
        unitIndex: 0,
        emergencyContactName: 'Fatima Khan',
        emergencyContactRelation: 'Sister',
        emergencyContactPhone: '+92 300 1111111',
        bloodGroup: 'B+',
      );

      await repo.saveProfile(profile);
      await repo.saveProfilePhotoPath('/path/profile_photo.jpg');

      final loaded = await repo.loadProfile();
      expect(loaded, isNotNull);
      expect(loaded!.id, 'prof-test-1');
      expect(loaded.fullName, 'Ahmad Khan');
      expect(loaded.email, 'ahmad@example.com');
      expect(loaded.updatedAt, isNotNull);

      final photoPath = await repo.loadProfilePhotoPath();
      expect(photoPath, '/path/profile_photo.jpg');

      await repo.deleteProfile();
      expect(await repo.loadProfile(), isNull);
      expect(await repo.loadProfilePhotoPath(), isNull);
    });

    test('BikeRepositoryLocal round trip', () async {
      final repo = BikeRepositoryLocal(store);
      await repo.markFirstRunCompleted();

      const bike = Bike(
        id: 'bike-test-t7',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2024,
        odometerKm: 3400,
        fuelRemainingLiters: 12.0,
      );

      await repo.saveBikes([bike]);
      await repo.saveActiveBikeId('bike-test-t7');

      final loadedBikes = await repo.loadBikes();
      expect(loadedBikes.length, 1);
      expect(loadedBikes.first.id, 'bike-test-t7');
      expect(loadedBikes.first.make, 'Yamaha');
      expect(await repo.loadActiveBikeId(), 'bike-test-t7');

      await repo.deleteBike('bike-test-t7');
      expect(await repo.loadBikes(), isEmpty);
      expect(await repo.loadActiveBikeId(), isNull);
    });

    test('MechanicRepositoryLocal round trip', () async {
      final repo = MechanicRepositoryLocal(store);
      await repo.markFirstRunCompleted();

      const mechanic = Mechanic(
        id: 'mech-hunza-01',
        name: 'Hunza Moto Care',
        distance: '2.5 km',
        durationOrLocation: 'Aliabad Main Bazaar',
        badgeType: BadgeType.verified,
        badgeLabel: 'Verified Shop',
        beaconStatus: 'Active',
        beaconColor: AppColors.statusGreen,
        categoryTitle1: 'SPECIALTIES',
        tags1: ['Carb Jetting'],
        categoryTitle2: 'LOCATION',
        tags2: ['Hunza'],
        rating: 4.8,
        reviewCount: 15,
        openStatus: 'OPEN NOW',
        phone: '+92 300 9999999',
      );

      await repo.saveMechanics([mechanic]);

      final loaded = await repo.loadMechanics();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'mech-hunza-01');
      expect(loaded.first.name, 'Hunza Moto Care');

      await repo.deleteMechanic('mech-hunza-01');
      expect(await repo.loadMechanics(), isEmpty);
    });

    test('RideReportRepositoryLocal round trip', () async {
      final repo = RideReportRepositoryLocal(store);
      await repo.markFirstRunCompleted();

      final report = PostRideReport(
        id: 'rep-pass-01',
        bikeId: 'bike-test-t7',
        date: DateTime.utc(2026, 9, 15),
        distanceKm: 180.5,
        terrainTags: const ['Mountain', 'Gravel'],
        notes: 'Khunjerab ascent',
      );

      await repo.saveReports([report]);

      final loaded = await repo.loadReports();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'rep-pass-01');
      expect(loaded.first.distanceKm, 180.5);

      await repo.deleteReport('rep-pass-01');
      expect(await repo.loadReports(), isEmpty);
    });

    test('SettingsRepositoryLocal round trip', () async {
      final repo = SettingsRepositoryLocal(store);
      await store.markFirstRunCompleted();

      final settings = AppSettings(
        units: UnitsSystem.imperial,
        notificationsEnabled: false,
        privacySharingEnabled: false,
      );

      await repo.saveSettings(settings);

      final loaded = await repo.loadSettings();
      expect(loaded.units, UnitsSystem.imperial);
      expect(loaded.notificationsEnabled, isFalse);
      expect(loaded.privacySharingEnabled, isFalse);

      await repo.deleteSettings();
      final afterDelete = await repo.loadSettings();
      expect(afterDelete.units, UnitsSystem.metric);
    });

    test('MaintenanceRepositoryLocal round trip', () async {
      final repo = MaintenanceRepositoryLocal(store);

      const item = MaintenanceItem(
        id: 'maint-chain-01',
        name: 'Drive Chain Tension',
        category: 'DRIVETRAIN',
        status: MaintenanceStatus.dueSoon,
        trackingMode: MaintenanceTrackingMode.manual,
        notes: 'Slack measured at 45mm, tighten to 30mm',
        dueMileage: '4000 km',
      );

      await repo.saveMaintenanceItems([item]);
      await repo.saveJettingBaseline({'mainJet': '142', 'pilotJet': '38'});
      await repo.saveChecklist({'tire_pressure': true, 'brakes': true});

      final loadedItems = await repo.loadMaintenanceItems();
      expect(loadedItems.length, 1);
      expect(loadedItems.first.id, 'maint-chain-01');

      final loadedJetting = await repo.loadJettingBaseline();
      expect(loadedJetting?['mainJet'], '142');

      final checklist = await repo.loadChecklist();
      expect(checklist['tire_pressure'], isTrue);
      expect(checklist['brakes'], isTrue);

      await repo.deleteMaintenanceItem('maint-chain-01');
      expect(await repo.loadMaintenanceItems(), isEmpty);

      await repo.clear();
      expect(await repo.loadJettingBaseline(), isNull);
      expect(await repo.loadChecklist(), isEmpty);
    });

    test('FinanceRepositoryLocal round trip', () async {
      final repo = FinanceRepositoryLocal(store);
      await repo.markFirstRunCompleted();

      const budget = TripBudget(
        id: 'budget-skardu-01',
        tripName: 'Skardu Expedition',
        capAmount: 1200.0,
        allocatedSoFar: 350.0,
      );

      const expense = Expense(
        id: 'exp-fuel-01',
        category: ExpenseCategory.fuel,
        title: 'Deosai Fuel Cache',
        amount: 60.0,
        trackingMode: ExpenseTrackingMode.manualEntry,
      );

      await repo.saveBudget(budget);
      await repo.saveExpenses([expense]);

      final loadedBudget = await repo.loadBudget();
      expect(loadedBudget, isNotNull);
      expect(loadedBudget!.tripName, 'Skardu Expedition');
      expect(loadedBudget.capAmount, 1200.0);

      final loadedExpenses = await repo.loadExpenses();
      expect(loadedExpenses.length, 1);
      expect(loadedExpenses.first.id, 'exp-fuel-01');
      expect(loadedExpenses.first.amount, 60.0);

      await repo.deleteExpense('exp-fuel-01');
      expect(await repo.loadExpenses(), isEmpty);

      await repo.deleteBudget();
      expect(await repo.loadBudget(), isNull);
    });

    test('PlaceRepositoryLocal round trip', () async {
      final repo = PlaceRepositoryLocal(store);

      const place = PlaceSearchResult(
        id: 'place-babusar-top',
        name: 'Babusar Top',
        displayName: 'Babusar Top 4173m',
        location: LatLng(35.148, 74.053),
        category: 'Mountain Pass',
      );

      await repo.saveSavedPlaces([place]);
      await repo.saveRecentPlaces([place]);

      final saved = await repo.loadSavedPlaces();
      expect(saved.length, 1);
      expect(saved.first.name, 'Babusar Top');

      final recent = await repo.loadRecentPlaces();
      expect(recent.length, 1);
      expect(recent.first.id, 'place-babusar-top');

      await repo.deleteSavedPlace('place-babusar-top');
      expect(await repo.loadSavedPlaces(), isEmpty);

      await repo.clear();
      expect(await repo.loadRecentPlaces(), isEmpty);
    });
  });

  group('Repository Layer - Legacy Migration Tests', () {
    test('Legacy Bike JSON without id/createdAt/updatedAt migrates seamlessly', () async {
      final legacyBikes = [
        {
          'make': 'Suzuki',
          'modelName': 'DR650',
          'modelYear': 2021,
          'odometerKm': 15000,
          'fuelTankCapacityLiters': 13.0,
          'currentFuelLiters': 9.0,
        }
      ];

      await store.markFirstRunCompleted();
      await store.writeJson(LocalStore.keyGarageBikes, legacyBikes);

      final repo = BikeRepositoryLocal(store);
      final bikes = await repo.loadBikes();

      expect(bikes.length, 1);
      expect(bikes.first.id.isNotEmpty, isTrue);
      expect(bikes.first.make, 'Suzuki');
      expect(bikes.first.modelName, 'DR650');
      expect(bikes.first.createdAt, isNotNull);
      expect(bikes.first.updatedAt, isNotNull);

      // Verify that migration was persisted back to storage
      final rawStored = await store.readJson(LocalStore.keyGarageBikes);
      expect(rawStored, isA<List<dynamic>>());
      final firstMap = (rawStored as List<dynamic>).first as Map;
      expect(firstMap['id'], isNotNull);
      expect(firstMap['createdAt'], isNotNull);
      expect(firstMap['updatedAt'], isNotNull);
    });

    test('Legacy UserProfile JSON without id/dates migrates and persists', () async {
      final legacyProfile = {
        'fullName': 'Legacy Rider',
        'email': 'legacy@rider.pk',
        'ridingTier': 'ADV NOVICE',
      };

      await store.writeJson(LocalStore.keyProfile, legacyProfile);

      final repo = ProfileRepositoryLocal(store);
      final profile = await repo.loadProfile();

      expect(profile, isNotNull);
      expect(profile!.fullName, 'Legacy Rider');
      expect(profile.id.isNotEmpty, isTrue);
      expect(profile.createdAt, isNotNull);
      expect(profile.updatedAt, isNotNull);

      final rawStored = await store.readJson(LocalStore.keyProfile) as Map;
      expect(rawStored['id'], isNotNull);
      expect(rawStored['createdAt'], isNotNull);
      expect(rawStored['updatedAt'], isNotNull);
    });

    test('Legacy AppSettings JSON migrates id and UTC timestamps', () async {
      final legacySettings = {
        'units': 'imperial',
        'notificationsEnabled': true,
      };

      await store.markFirstRunCompleted();
      await store.writeJson(LocalStore.keySettings, legacySettings);

      final repo = SettingsRepositoryLocal(store);
      final settings = await repo.loadSettings();

      expect(settings.units, UnitsSystem.imperial);
      expect(settings.id.isNotEmpty, isTrue);
      expect(settings.createdAt, isNotNull);
      expect(settings.updatedAt, isNotNull);
    });

    test('Legacy Mechanic JSON without id/dates migrates on load', () async {
      final legacyMechanics = [
        {
          'name': 'Karakoram Moto Prep',
          'distance': '5 km away',
        }
      ];

      await store.markFirstRunCompleted();
      await store.writeJson(LocalStore.keyMechanics, legacyMechanics);

      final repo = MechanicRepositoryLocal(store);
      final list = await repo.loadMechanics();

      expect(list.length, 1);
      expect(list.first.id.isNotEmpty, isTrue);
      expect(list.first.name, 'Karakoram Moto Prep');
      expect(list.first.createdAt, isNotNull);
      expect(list.first.updatedAt, isNotNull);
    });

    test('Legacy PostRideReport JSON without id/dates migrates on load', () async {
      final legacyReports = [
        {
          'bikeId': 'bike-1',
          'date': '2026-05-10T12:00:00.000Z',
          'distanceKm': 230.0,
          'terrainTags': ['Highway'],
        }
      ];

      await store.markFirstRunCompleted();
      await store.writeJson(LocalStore.keyRideReports, legacyReports);

      final repo = RideReportRepositoryLocal(store);
      final list = await repo.loadReports();

      expect(list.length, 1);
      expect(list.first.id.isNotEmpty, isTrue);
      expect(list.first.distanceKm, 230.0);
      expect(list.first.createdAt, isNotNull);
      expect(list.first.updatedAt, isNotNull);
    });

    test('Legacy TripBudget and Expense JSON migrate properly', () async {
      final legacyBudget = {
        'tripName': 'Old Karakoram Loop',
        'capAmount': 900.0,
      };
      final legacyExpenses = [
        {
          'category': 'fuel',
          'title': 'Local Gas',
          'amount': 30.0,
        }
      ];

      await store.markFirstRunCompleted();
      await store.writeJson(LocalStore.keyTripBudget, legacyBudget);
      await store.writeJson(LocalStore.keyTripExpenses, legacyExpenses);

      final repo = FinanceRepositoryLocal(store);
      final budget = await repo.loadBudget();
      final expenses = await repo.loadExpenses();

      expect(budget, isNotNull);
      expect(budget!.id.isNotEmpty, isTrue);
      expect(budget.createdAt, isNotNull);
      expect(budget.updatedAt, isNotNull);

      expect(expenses.length, 1);
      expect(expenses.first.id.isNotEmpty, isTrue);
      expect(expenses.first.createdAt, isNotNull);
      expect(expenses.first.updatedAt, isNotNull);
    });

    test('Legacy MaintenanceItem JSON migrates on load', () async {
      final legacyItems = [
        {
          'title': 'Brake Bleed',
          'category': 'BRAKES',
          'urgency': 'URGENT',
        }
      ];

      await store.writeJson(LocalStore.keyMaintenanceItems, legacyItems);

      final repo = MaintenanceRepositoryLocal(store);
      final items = await repo.loadMaintenanceItems();

      expect(items.length, 1);
      expect(items.first.id.isNotEmpty, isTrue);
      expect(items.first.createdAt, isNotNull);
      expect(items.first.updatedAt, isNotNull);
    });

    test('Legacy PlaceSearchResult JSON migrates on load', () async {
      final legacyPlaces = [
        {
          'name': 'Shandur Pass 3700m',
          'latitude': 36.08,
          'longitude': 72.55,
        }
      ];

      await store.writeJson(LocalStore.keySavedPlaces, legacyPlaces);

      final repo = PlaceRepositoryLocal(store);
      final places = await repo.loadSavedPlaces();

      expect(places.length, 1);
      expect(places.first.id.isNotEmpty, isTrue);
      expect(places.first.createdAt, isNotNull);
      expect(places.first.updatedAt, isNotNull);
    });
  });

  group('Controller Test with In-Memory Fake Repository', () {
    test('ActiveBikeController interacts strictly with FakeBikeRepository without touching LocalStore', () async {
      final fakeRepo = FakeBikeRepository();
      await fakeRepo.markFirstRunCompleted();

      const testBike = Bike(
        id: 'fake-bike-01',
        make: 'Husqvarna',
        modelName: 'Norden 901',
        modelYear: 2024,
        odometerKm: 5200,
      );
      await fakeRepo.saveBikes([testBike]);
      await fakeRepo.saveActiveBikeId('fake-bike-01');

      // Construct controller with in-memory fake repository
      final controller = ActiveBikeController(repository: fakeRepo);
      await controller.load();

      expect(controller.bikes.length, 1);
      expect(controller.bikes.first.id, 'fake-bike-01');
      expect(controller.activeBikeId, 'fake-bike-01');

      // Add a new bike via controller
      const secondBike = Bike(
        id: 'fake-bike-02',
        make: 'KTM',
        modelName: '690 Enduro R',
        modelYear: 2023,
        odometerKm: 2100,
      );
      controller.addBike(secondBike, setActive: true);
      await controller.save();

      // Verify the fake repository was updated directly
      final fakeBikes = await fakeRepo.loadBikes();
      expect(fakeBikes.length, 2);
      expect(fakeBikes.any((b) => b.id == 'fake-bike-02'), isTrue);
      expect(await fakeRepo.loadActiveBikeId(), 'fake-bike-02');

      // Verify LocalStore has no knowledge of these fake writes
      expect(await store.readJson(LocalStore.keyGarageBikes), isNull);
    });
  });
}
