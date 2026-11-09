import 'dart:io';

import 'package:camp/core/data/bike_repository_local.dart';
import 'package:camp/core/data/finance_repository_local.dart';
import 'package:camp/core/data/maintenance_repository_local.dart';
import 'package:camp/core/data/place_repository_local.dart';
import 'package:camp/core/data/profile_repository_local.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/domain/user_profile_model.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/domain/expense_model.dart';
import 'package:camp/features/maintenance/domain/maintenance_item_model.dart';
import 'package:camp/features/maintenance/domain/trip_budget_model.dart';
import 'package:camp/features/navigation/domain/geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStore.instance.resetForTesting();
  });

  group('Batch G1: Repository Fresh Install (Zero Seed Data)', () {
    test('BikeRepositoryLocal loads empty on fresh install', () async {
      final repo = BikeRepositoryLocal(LocalStore.instance);
      final bikes = await repo.loadBikes();
      final activeId = await repo.loadActiveBikeId();

      expect(bikes, isEmpty);
      expect(activeId, isNull);
    });

    test('FinanceRepositoryLocal loads empty on fresh install', () async {
      final repo = FinanceRepositoryLocal(LocalStore.instance);
      final budget = await repo.loadBudget();
      final expenses = await repo.loadExpenses();

      expect(budget, isNull);
      expect(expenses, isEmpty);
    });

    test('MaintenanceRepositoryLocal loads empty on fresh install', () async {
      final repo = MaintenanceRepositoryLocal(LocalStore.instance);
      final items = await repo.loadMaintenanceItems();

      expect(items, isEmpty);
    });

    test('PlaceRepositoryLocal loads empty on fresh install', () async {
      final repo = PlaceRepositoryLocal(LocalStore.instance);
      final saved = await repo.loadSavedPlaces();
      final recent = await repo.loadRecentPlaces();

      expect(saved, isEmpty);
      expect(recent, isEmpty);
    });

    test('ProfileRepositoryLocal loads null on fresh install', () async {
      final repo = ProfileRepositoryLocal(LocalStore.instance);
      final profile = await repo.loadProfile();

      expect(profile, isNull);
    });
  });

  group('Batch G1: Legacy Seed Cleanup (Purges Seed, Keeps Real Rider Data)', () {
    test('BikeRepositoryLocal cleans legacy seed bikes but keeps rider bikes', () async {
      final store = LocalStore.instance;
      final repo = BikeRepositoryLocal(store);

      const legacySeedBike = Bike(
        id: 'bike-bmw-1250',
        make: 'BMW',
        modelName: 'R 1250 GS Adventure',
        modelYear: 2023,
        odometerKm: 14200,
        plateNumber: 'LEB-20-4567',
        vin: 'WB10J9309PZE84102',
        nickname: 'GS #441',
      );
      const realRiderBike = Bike(
        id: 'rider-bike-custom-01',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2024,
        odometerKm: 3200,
        plateNumber: 'KHI-24-9999',
        nickname: 'Desert Eagle',
      );

      // Persist raw mixed list and set active to seed
      await store.writeJson(LocalStore.keyGarageBikes, [
        legacySeedBike.toJson(),
        realRiderBike.toJson(),
      ]);
      await store.writeString(LocalStore.keyActiveBikeId, 'bike-bmw-1250');

      // Load through repository (triggers one-time cleanup)
      final cleanedBikes = await repo.loadBikes();
      final cleanedActiveId = await repo.loadActiveBikeId();

      // Verify seed was purged and real bike kept
      expect(cleanedBikes.length, 1);
      expect(cleanedBikes.first.id, 'rider-bike-custom-01');
      expect(cleanedBikes.first.make, 'Yamaha');
      expect(cleanedBikes.any((b) => b.id == 'bike-bmw-1250'), isFalse);
      expect(cleanedActiveId, isNull);

      // Verify repository re-saved the cleaned state
      final reloadedRawBikes = (await store.readJson(LocalStore.keyGarageBikes) as List);
      expect(reloadedRawBikes.length, 1);
      expect(reloadedRawBikes.first['id'], 'rider-bike-custom-01');
    });

    test('FinanceRepositoryLocal cleans legacy seed budget and expenses', () async {
      final store = LocalStore.instance;
      final repo = FinanceRepositoryLocal(store);

      // Legacy seed budget and real rider budget
      const legacySeedBudget = TripBudget(
        tripName: 'Alpine Ridge Tour',
        capAmount: 75000.0,
        allocatedSoFar: 46125.0,
      );

      await store.writeJson(LocalStore.keyTripBudget, legacySeedBudget.toJson());
      final cleanedBudget = await repo.loadBudget();
      expect(cleanedBudget, isNull);

      // Real user budget is preserved
      const realRiderBudget = TripBudget(
        tripName: 'Khunjerab Pass Odyssey',
        capAmount: 120000.0,
        allocatedSoFar: 35000.0,
      );
      await repo.saveBudget(realRiderBudget);
      final reloadedBudget = await repo.loadBudget();
      expect(reloadedBudget?.tripName, 'Khunjerab Pass Odyssey');

      // Legacy seed expenses mixed with real rider expense
      const legacyExp1 = Expense(
        id: 'exp-1',
        title: 'Fuel Cost',
        amount: 9800.0,
        category: ExpenseCategory.fuel,
        trackingMode: ExpenseTrackingMode.manualEntry,
        note: 'Demo data',
      );
      const legacyExp2 = Expense(
        id: 'exp-2',
        title: 'Park Permits & Passes',
        amount: 3500.0,
        category: ExpenseCategory.permits,
        trackingMode: ExpenseTrackingMode.manualEntry,
        subtitle: 'National Park Entry (Demo data)',
      );
      const realRiderExpense = Expense(
        id: 'rider-exp-01',
        title: 'High Octane Fuel',
        amount: 4500.0,
        category: ExpenseCategory.fuel,
        trackingMode: ExpenseTrackingMode.manualEntry,
        note: 'Attock Petroleum Besham',
      );

      await store.writeJson(LocalStore.keyTripExpenses, [
        legacyExp1.toJson(),
        legacyExp2.toJson(),
        realRiderExpense.toJson(),
      ]);

      final cleanedExpenses = await repo.loadExpenses();
      expect(cleanedExpenses.length, 1);
      expect(cleanedExpenses.first.id, 'rider-exp-01');
      expect(cleanedExpenses.first.title, 'High Octane Fuel');

      // Verify repository re-saved the cleaned expenses
      final reloadedRawExpenses = (await store.readJson(LocalStore.keyTripExpenses) as List);
      expect(reloadedRawExpenses.length, 1);
      expect(reloadedRawExpenses.first['id'], 'rider-exp-01');
    });

    test('MaintenanceRepositoryLocal cleans legacy items but keeps rider items', () async {
      final store = LocalStore.instance;
      final repo = MaintenanceRepositoryLocal(store);

      const legacyItem = MaintenanceItem(
        id: 'maint-1',
        name: 'Rear Brake Pad Replacement',
        category: 'Brakes',
        status: MaintenanceStatus.dueSoon,
        trackingMode: MaintenanceTrackingMode.manual,
      );
      const realRiderItem = MaintenanceItem(
        id: 'rider-maint-01',
        name: 'DID Chain Slack Adjustment',
        category: 'Drive',
        status: MaintenanceStatus.ok,
        trackingMode: MaintenanceTrackingMode.manual,
      );

      await store.writeJson(LocalStore.keyMaintenanceItems, [
        legacyItem.toJson(),
        realRiderItem.toJson(),
      ]);

      final cleanedItems = await repo.loadMaintenanceItems();
      expect(cleanedItems.length, 1);
      expect(cleanedItems.first.id, 'rider-maint-01');
      expect(cleanedItems.first.name, 'DID Chain Slack Adjustment');

      final reloadedRaw = (await store.readJson(LocalStore.keyMaintenanceItems) as List);
      expect(reloadedRaw.length, 1);
      expect(reloadedRaw.first['id'], 'rider-maint-01');
    });

    test('PlaceRepositoryLocal cleans legacy places but keeps rider places', () async {
      final store = LocalStore.instance;
      final repo = PlaceRepositoryLocal(store);

      const legacyPlace1 = PlaceSearchResult(
        name: 'Timber Ridge Moto Outpost',
        displayName: 'Mile 42, North Cascades Hwy',
        location: LatLng(48.5135, -120.6877),
        category: 'Campground',
      );
      const legacyPlace2 = PlaceSearchResult(
        name: 'Cascade Alpine Loop Summit',
        displayName: 'Washington Pass Overlook',
        location: LatLng(48.5262, -120.6542),
        category: 'Viewpoint',
      );
      const realRiderPlace = PlaceSearchResult(
        name: 'Shangrila Resort Kachura',
        displayName: 'Lower Kachura Lake, Skardu',
        location: LatLng(35.4225, 75.4497),
        category: 'Resort',
      );

      await store.writeJson(LocalStore.keySavedPlaces, [
        legacyPlace1.toJson(),
        realRiderPlace.toJson(),
      ]);
      await store.writeJson(LocalStore.keyRecentPlaces, [
        legacyPlace2.toJson(),
        realRiderPlace.toJson(),
      ]);

      final cleanedSaved = await repo.loadSavedPlaces();
      final cleanedRecent = await repo.loadRecentPlaces();

      expect(cleanedSaved.length, 1);
      expect(cleanedSaved.first.name, 'Shangrila Resort Kachura');

      expect(cleanedRecent.length, 1);
      expect(cleanedRecent.first.name, 'Shangrila Resort Kachura');
    });

    test('ProfileRepositoryLocal cleans legacy seed strings while keeping rider profile data', () async {
      final store = LocalStore.instance;
      final repo = ProfileRepositoryLocal(store);

      final seededProfile = UserProfile(
        fullName: 'Alex Henderson',
        email: 'moto.rider@example.com',
        username: 'rider',
        homeCity: 'Islamabad',
        bloodGroup: 'O+',
        emergencyContactRelation: 'Emergency Contact',
      );

      await store.writeJson(LocalStore.keyProfile, seededProfile.toJson());

      final cleanedProfile = await repo.loadProfile();
      expect(cleanedProfile, isNotNull);
      expect(cleanedProfile!.fullName, isEmpty);
      expect(cleanedProfile.email, isEmpty);
      expect(cleanedProfile.username, isEmpty);
      expect(cleanedProfile.emergencyContactRelation, isEmpty);
      expect(cleanedProfile.homeCity, 'Islamabad');
      expect(cleanedProfile.bloodGroup, 'O+');
    });
  });

  group('Batch G1: Real Records Sharing Seed Names or Patterns Survive', () {
    test('BikeRepositoryLocal preserves real bike with seed nickname or plate', () async {
      final store = LocalStore.instance;
      final repo = BikeRepositoryLocal(store);

      const realBike = Bike(
        id: 'rider-bike-my-adventure',
        make: 'BMW',
        modelName: 'R 1250 GS Adventure',
        modelYear: 2024,
        odometerKm: 500,
        plateNumber: 'LEB-20-4567',
        nickname: 'GS #441',
      );

      await store.writeJson(LocalStore.keyGarageBikes, [realBike.toJson()]);

      final bikes = await repo.loadBikes();
      expect(bikes.length, 1);
      expect(bikes.first.id, 'rider-bike-my-adventure');
      expect(bikes.first.nickname, 'GS #441');
      expect(bikes.first.plateNumber, 'LEB-20-4567');
    });

    test('FinanceRepositoryLocal preserves real trip named Karakoram Highway Expedition or Alpine Ridge Tour', () async {
      final store = LocalStore.instance;
      final repo = FinanceRepositoryLocal(store);

      const realTrip = TripBudget(
        id: 'budget-rider-custom-1',
        tripName: 'Karakoram Highway Expedition',
        capAmount: 100000.0,
        allocatedSoFar: 25000.0,
      );
      final realExpense = Expense(
        id: 'exp-rider-real-99',
        title: 'Alpine Ridge Tour permit',
        amount: 5500.0,
        category: ExpenseCategory.permits,
        trackingMode: ExpenseTrackingMode.manualEntry,
        dateRecorded: DateTime(2026, 6, 1),
        note: 'Demo data',
        subtitle: 'Special pass (Demo data)',
      );

      await store.writeJson(LocalStore.keyTripBudget, realTrip.toJson());
      await store.writeJson(LocalStore.keyTripExpenses, [realExpense.toJson()]);

      final budget = await repo.loadBudget();
      final expenses = await repo.loadExpenses();

      expect(budget, isNotNull);
      expect(budget!.id, 'budget-rider-custom-1');
      expect(budget.tripName, 'Karakoram Highway Expedition');
      expect(budget.capAmount, 100000.0);

      expect(expenses.length, 1);
      expect(expenses.first.id, 'exp-rider-real-99');
      expect(expenses.first.title, 'Alpine Ridge Tour permit');
      expect(expenses.first.note, 'Demo data');
    });

    test('MaintenanceRepositoryLocal preserves real item named Rear Brake Pad Replacement or Engine Oil & Filter', () async {
      final store = LocalStore.instance;
      final repo = MaintenanceRepositoryLocal(store);

      const realItem1 = MaintenanceItem(
        id: 'maint-rider-real-01',
        name: 'Rear Brake Pad Replacement',
        category: 'Brakes',
        status: MaintenanceStatus.ok,
        trackingMode: MaintenanceTrackingMode.manual,
      );
      const realItem2 = MaintenanceItem(
        id: 'maint-rider-real-02',
        name: 'Engine Oil & Filter',
        category: 'Fluids',
        status: MaintenanceStatus.dueSoon,
        trackingMode: MaintenanceTrackingMode.manual,
      );

      await store.writeJson(LocalStore.keyMaintenanceItems, [
        realItem1.toJson(),
        realItem2.toJson(),
      ]);

      final items = await repo.loadMaintenanceItems();
      expect(items.length, 2);
      expect(items.map((i) => i.id), containsAll(['maint-rider-real-01', 'maint-rider-real-02']));
      expect(items.map((i) => i.name), containsAll(['Rear Brake Pad Replacement', 'Engine Oil & Filter']));
    });

    test('PlaceRepositoryLocal preserves real place named Basecamp or Timber Ridge Moto Outpost', () async {
      final store = LocalStore.instance;
      final repo = PlaceRepositoryLocal(store);

      const realPlace1 = PlaceSearchResult(
        id: 'place_rider_custom_101',
        name: 'Basecamp',
        displayName: 'Basecamp Northern Staging Area',
        location: LatLng(35.2987, 75.6341),
        category: 'Campground',
      );
      const realPlace2 = PlaceSearchResult(
        id: 'place_rider_custom_102',
        name: 'Timber Ridge Moto Outpost',
        displayName: 'Custom Rider Pin',
        location: LatLng(34.1234, 73.5678),
        category: 'Waypoint',
      );

      await store.writeJson(LocalStore.keySavedPlaces, [
        realPlace1.toJson(),
        realPlace2.toJson(),
      ]);

      final saved = await repo.loadSavedPlaces();
      expect(saved.length, 2);
      expect(saved.map((p) => p.name), containsAll(['Basecamp', 'Timber Ridge Moto Outpost']));
      expect(saved.map((p) => p.id), containsAll(['place_rider_custom_101', 'place_rider_custom_102']));
    });

    test('ProfileRepositoryLocal preserves real email containing @rider and names sharing seed parts', () async {
      final store = LocalStore.instance;
      final repo = ProfileRepositoryLocal(store);

      final realProfile = UserProfile(
        id: 'profile-rider-real-01',
        fullName: 'Alexander Henderson-Smythe',
        username: 'rider_supreme',
        email: 'alexander@riderclub.org',
        homeCity: 'Lahore',
      );

      await store.writeJson(LocalStore.keyProfile, realProfile.toJson());

      final profile = await repo.loadProfile();
      expect(profile, isNotNull);
      expect(profile!.id, 'profile-rider-real-01');
      expect(profile.fullName, 'Alexander Henderson-Smythe');
      expect(profile.username, 'rider_supreme');
      expect(profile.email, 'alexander@riderclub.org');
      expect(profile.homeCity, 'Lahore');
    });
  });

  group('Batch G1: Zero Seed Guard Test across lib/', () {
    test('Ensures no forbidden seed identifiers or demo structures exist in lib/', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final forbiddenSeedPatterns = <String>[
        'defaultSampleBudget',
        'defaultSampleExpenses',
        'defaultSampleItems',
        '_initializeDefaultFleet',
        '_initDefaultPlaces',
        'kLocationPresets',
        'LocationPreset',
        'FakeLocationService',
        'FakeRoutingService',
        'FakeGeocodingService',
        'bike-bmw-1250',
        'bike-rebel-500',
        'WB10J9309PZE84102',
        'JH2PC5601NM000000',
        'LEB-20-4567',
        'KHI-22-8819',
        'Alpine Ridge Tour',
        'Timber Ridge Moto Outpost',
        'Cascade Alpine Loop Summit',
        'Bear Creek Pass Rd',
        'Silver Creek Rest Area',
        'Peak Ridge Fuel & Mart',
      ];

      final violations = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        // Skip Auth screens, auth controller, user model per Batch H scope exclusion
        final normalizedPath = entity.path.replaceAll('\\', '/');
        if (normalizedPath.contains('lib/features/auth/')) {
          continue;
        }

        // Repositories define seed sets specifically to PURGE them from disk;
        // we allow seed IDs only inside repository cleanup definition lists.
        final isRepositoryCleaner = normalizedPath.endsWith('_repository_local.dart');

        final content = entity.readAsStringSync();
        final lines = content.split('\n');

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          final lineNum = i + 1;

          for (final pattern in forbiddenSeedPatterns) {
            if (pattern.startsWith('defaultSample') ||
                pattern.startsWith('_init') ||
                pattern.startsWith('Fake') ||
                pattern.startsWith('kLocationPresets')) {
              // These must not exist in ANY file in lib/
              if (line.contains(pattern)) {
                violations.add('$normalizedPath:$lineNum contains forbidden pattern "$pattern": "$line"');
              }
            } else if (!isRepositoryCleaner) {
              // Seed values (names, IDs, VINs) must never appear in models, controllers, or screens
              if (line.contains(pattern)) {
                violations.add('$normalizedPath:$lineNum contains forbidden seed data "$pattern": "$line"');
              }
            }
          }
        }
      }

      expect(violations, isEmpty, reason: 'Found forbidden seeds or test fakes in lib/:\n${violations.join('\n')}');
    });
  });
}
