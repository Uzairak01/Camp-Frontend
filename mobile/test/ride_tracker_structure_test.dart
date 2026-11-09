import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/data/bike_repository.dart';
import 'package:camp/core/data/in_progress_ride_model.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/presentation/screens/home_screen.dart';
import 'package:camp/features/dashboard/presentation/widgets/ride_summary_sheet.dart';
import 'package:camp/features/dashboard/presentation/widgets/unfinished_ride_recovery_sheet.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/garage/domain/fuel_estimator.dart';
import 'package:camp/features/garage/services/fuel_notification_service.dart';
import 'package:camp/features/garage/services/fuel_tracker_service.dart';
import 'package:camp/features/garage/services/tracking_diagnostics.dart';
import 'package:camp/features/maintenance/controllers/post_ride_report_controller.dart';
import 'package:camp/features/maintenance/domain/post_ride_report.dart';
import 'package:camp/features/maintenance/presentation/screens/post_ride_debrief_screen.dart';
import 'package:camp/features/navigation/controllers/navigation_controller.dart';
import 'package:camp/features/navigation/domain/geocoding_service.dart';
import 'package:camp/features/navigation/domain/location_service.dart';
import 'package:camp/features/navigation/domain/motion_math.dart';
import 'package:camp/features/navigation/domain/route_progress.dart';
import 'package:camp/features/navigation/domain/routing_service.dart';
import 'package:camp/features/navigation/presentation/screens/navigation_map_screen.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_arrived_sheet.dart';
import 'package:camp/features/settings/controllers/settings_controller.dart';
import 'package:camp/features/settings/presentation/screens/tracking_diagnostics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_in_progress_ride_repository.dart';
import 'helpers/fake_location_service.dart';
import 'helpers/fake_ride_report_repository.dart';
import 'helpers/fake_routing_service.dart';

class _TransparentTileProvider extends TileProvider {
  _TransparentTileProvider();

  static const String _whiteTile =
      'iVBORw0KGgoAAAANSUhEUgAAAQAAAAEAAQMAAABmvDolAAAAAXNSR0IB2cksfwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAANQTFRF////p8QbyAAAAB9JREFUeJztwQENAAAAwqD3T20ON6AAAAAAAAAAAL4NIQAAAfFnIe4AAAAASUVORK5CYII=';
  static final _whiteTileBytes = base64Decode(_whiteTile);

  @override
  ImageProvider<Object> getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    return MemoryImage(_whiteTileBytes);
  }
}

class _FakeBikeRepository implements BikeRepository {
  List<Bike> _bikes = [];
  String? _activeBikeId;
  bool _firstRun = false;

  @override
  Future<bool> isFirstRun() async => _firstRun;

  @override
  Future<void> markFirstRunCompleted() async => _firstRun = false;

  @override
  Future<List<Bike>> loadBikes() async => List<Bike>.from(_bikes);

  @override
  Future<void> saveBikes(List<Bike> bikes) async => _bikes = List<Bike>.from(bikes);

  @override
  Future<String?> loadActiveBikeId() async => _activeBikeId;

  @override
  Future<void> saveActiveBikeId(String? id) async => _activeBikeId = id;

  @override
  Future<void> deleteBike(String id) async =>
      _bikes.removeWhere((b) => b.id == id);

  @override
  Future<void> clear() async {
    _bikes = [];
    _activeBikeId = null;
  }

  @override
  Future<void> flush() async {}
}

class _FakeFuelNotificationService extends FuelNotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showLowFuelAlert({required int rangeKm}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BATCH S4-3a: Ride Tracker Structure & Fuel Model', () {
    late FakeLocationService fakeLocation;
    late FakeInProgressRideRepository fakeInProgressRepo;
    late ActiveBikeController bikeController;
    late PostRideReportController reportController;
    late FuelTrackerService fuelTracker;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LocalStore.instance.resetForTesting();

      fakeInProgressRepo = FakeInProgressRideRepository();
      AppRepositories.resetWith(
        bikeRepository: _FakeBikeRepository(),
        rideReportRepository: FakeRideReportRepository(),
        inProgressRideRepository: fakeInProgressRepo,
      );

      bikeController = ActiveBikeController.instance;
      bikeController.resetForTesting();

      reportController = PostRideReportController.instance;
      reportController.repository = AppRepositories.instance.rideReportRepository;
      reportController.reset();

      const testBike = Bike(
        id: 'test-bike-s4-3a',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2024,
        odometerKm: 5000,
        preciseOdometerKm: 5000.0,
        fuelLevelOdometerKm: 5000.0,
        fuelTankCapacityLiters: 16.0,
        fuelAverageKmPerLiter: 20.0,
        fuelRemainingLiters: 10.0,
      );
      bikeController.addBike(testBike, setActive: true);
      await bikeController.flush();

      fakeLocation = FakeLocationService();
      fuelTracker = FuelTrackerService.instance;
      fuelTracker.resetForTesting();
      fuelTracker.setDependenciesForTesting(
        locationService: fakeLocation,
        bikeController: bikeController,
        notificationService: _FakeFuelNotificationService(),
        inProgressRideRepository: fakeInProgressRepo,
      );
    });

    tearDown(() {
      fuelTracker.resetForTesting();
    });

    test('1. Navigation starts tracking, ending asks finish vs keep tracking', () async {
      final fakeRouting = FakeRoutingService();
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );

      // Open route preview for Margalla Ridge
      await nav.openRoutePreview(const PlaceSearchResult(
        name: 'Margalla Ridge',
        displayName: 'Margalla Ridge, Islamabad',
        location: LatLng(33.74, 73.06),
      ));

      expect(fuelTracker.isRiding, isFalse);

      // Start navigation couples to tracker
      await nav.startNavigation();
      expect(nav.state, NavigationState.navigating);
      expect(fuelTracker.isRiding, isTrue);
      expect(fuelTracker.routeTitle, 'Margalla Ridge');

      // Keep tracking preserves tracker state while navigation exits
      nav.stopNavigation();
      expect(nav.state, NavigationState.idle);
      expect(fuelTracker.isRiding, isTrue);

      await fuelTracker.stopRide();
    });

    test('2. Stop ride with distance >= 0.1 km creates PostRideReport with source = "tracked"', () async {
      await fuelTracker.startRide(routeTitle: 'Babusar Leg');
      expect(fuelTracker.isRiding, isTrue);

      // 1. Initial anchor fix
      fakeLocation.emitPosition(PositionData(
        latitude: 35.00000,
        longitude: 74.00000,
        accuracy: 5.0,
        speed: 15.0,
        timestamp: DateTime(2026, 6, 1, 10, 0, 0),
      ));
      await pumpEventQueue();

      // 2. Movement ~1.1 km
      fakeLocation.emitPosition(PositionData(
        latitude: 35.01000,
        longitude: 74.00000,
        accuracy: 5.0,
        speed: 15.0,
        timestamp: DateTime(2026, 6, 1, 10, 5, 0),
      ));
      await pumpEventQueue();

      expect(fuelTracker.rideDistanceKm, greaterThanOrEqualTo(0.1));

      final report = await fuelTracker.finishRide();
      expect(report, isNotNull);
      expect(report!.source, 'tracked');
      expect(report.isTracked, isTrue);
      expect(report.routeTitle, 'Babusar Leg');
      expect(report.distanceKm, greaterThanOrEqualTo(0.1));
      expect(report.startedAt, isNotNull);
      expect(report.endedAt, isNotNull);

      // Verify report was added to controller
      expect(reportController.reports.contains(report), isTrue);
    });

    test('3. Stop ride with distance < 0.1 km does not create report', () async {
      await fuelTracker.startRide(routeTitle: 'Quick Move');
      expect(fuelTracker.isRiding, isTrue);

      // Distance stays 0.0 km
      final report = await fuelTracker.finishRide();
      expect(report, isNull);
      expect(reportController.reports.isEmpty, isTrue);
    });

    testWidgets('4. Saving a debrief for a tracked ride does NOT increase the bike odometer', (tester) async {
      final initialOdo = bikeController.activeBike!.odometerKm;

      final trackedReport = PostRideReport(
        id: 'rep-tracked-1',
        bikeId: 'test-bike-s4-3a',
        date: DateTime(2026, 6, 1),
        distanceKm: 25.0,
        durationHours: 1.0,
        terrainTags: const ['Mountain'],
        source: 'tracked',
      );
      reportController.addReport(trackedReport);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PostRideDebriefScreen(
                      initialReport: trackedReport,
                      bikeId: 'test-bike-s4-3a',
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify tracked note is shown
      expect(find.text('Distance already added to odometer live'), findsOneWidget);

      // Tap Save button
      final saveBtn = find.text('Save Post-Ride Report');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Bike odometer must NOT have changed!
      expect(bikeController.activeBike!.odometerKm, initialOdo);
    });

    testWidgets('5. Saving a manual debrief DOES increase the odometer, and editing adjusts by difference', (tester) async {
      final initialOdo = bikeController.activeBike!.odometerKm; // 5000

      // A) Save a new manual debrief for 50 km
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PostRideDebriefScreen(bikeId: 'test-bike-s4-3a'),
                  ),
                ),
                child: const Text('Open New'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open New'));
      await tester.pumpAndSettle();

      final distanceField = find.byType(TextField).first;
      await tester.enterText(distanceField, '50');
      await tester.pumpAndSettle();

      expect(find.text('Will add 50 km to odometer'), findsOneWidget);

      final saveBtnA = find.text('Save Post-Ride Report');
      await tester.ensureVisible(saveBtnA);
      await tester.tap(saveBtnA);
      await tester.pumpAndSettle();

      // Odometer increased by 50 km: 5000 -> 5050
      expect(bikeController.activeBike!.odometerKm, initialOdo + 50);
      final savedManual = reportController.reports.first;
      expect(savedManual.isManual, isTrue);
      expect(savedManual.distanceKm, 50.0);

      // B) Edit the existing manual report: change from 50 to 65 km (+15 km diff)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PostRideDebriefScreen(
                      initialReport: savedManual,
                      bikeId: 'test-bike-s4-3a',
                    ),
                  ),
                ),
                child: const Text('Open Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '65');
      await tester.pumpAndSettle();

      expect(find.text('Will adjust odometer by +15 km'), findsOneWidget);

      final saveBtnB = find.text('Save Post-Ride Report');
      await tester.ensureVisible(saveBtnB);
      await tester.tap(saveBtnB);
      await tester.pumpAndSettle();

      // Odometer adjusted by diff (+15 km): 5050 -> 5065
      expect(bikeController.activeBike!.odometerKm, initialOdo + 65);
    });

    testWidgets('6. In-progress ride persistence survives simulated kill and restores via recovery sheet', (tester) async {
      // Simulate an unfinished ride left in storage before app kill
      final unfinished = InProgressRide(
        id: 'active-ride',
        startedAt: DateTime(2026, 6, 1, 14, 30),
        distanceKm: 18.5,
        bikeId: 'test-bike-s4-3a',
        routeTitle: 'Mountain Pass',
      );
      await fakeInProgressRepo.saveInProgressRide(unfinished);

      expect(await fakeInProgressRepo.loadInProgressRide(), isNotNull);

      // Render recovery sheet
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => UnfinishedRideRecoverySheet.show(ctx, unfinished),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Assert sheet shows the expected time and distance
      expect(find.textContaining('18.5 km'), findsOneWidget);
      expect(find.text('Finish ride or discard?'), findsOneWidget);

      // Tap "Finish ride"
      await tester.tap(find.text('Finish ride'));
      await tester.pumpAndSettle();

      // Verify finished report created with 18.5 km and source = tracked
      expect(reportController.reports.isNotEmpty, isTrue);
      final report = reportController.reports.first;
      expect(report.distanceKm, 18.5);
      expect(report.isTracked, isTrue);
      expect(report.routeTitle, 'Mountain Pass');

      // Verify persistent in-progress state is cleared
      expect(fakeInProgressRepo.savedRide, isNull);
    });

    test('7. Dynamic fuel calculation ties to odometer and does not decrement per fix', () {
      final bike = bikeController.activeBike!; // 10 L set at 5000 km, 20 km/l
      expect(FuelEstimator.currentLiters(bike), 10.0);

      // When bike odometer advances by 40 km (to 5040 km)
      final advancedBike = bike.copyWith(
        odometerKm: 5040,
        preciseOdometerKm: 5040.0,
      );
      // Consumed: 40 km / 20 km/l = 2.0 L -> Remaining: 8.0 L
      expect(FuelEstimator.currentLiters(advancedBike), 8.0);

      // Decreasing odometer below fuelLevelOdometerKm resets baseline so fuel never exceeds set amount
      final correctedDownBike = advancedBike.copyWith(
        odometerKm: 4950,
        preciseOdometerKm: 4950.0,
      );
      bikeController.updateBike(correctedDownBike);
      expect(bikeController.activeBike!.fuelLevelOdometerKm, 4950.0);
      expect(FuelEstimator.currentLiters(bikeController.activeBike!), 10.0);
    });
  });

  group('BATCH S4-3b-1: Filtering & Unfinished Ride Loop Fixes', () {
    late FakeLocationService fakeLocation;
    late FakeInProgressRideRepository fakeInProgressRepo;
    late ActiveBikeController bikeController;
    late PostRideReportController reportController;
    late FuelTrackerService fuelTracker;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LocalStore.instance.resetForTesting();

      fakeInProgressRepo = FakeInProgressRideRepository();
      AppRepositories.resetWith(
        bikeRepository: _FakeBikeRepository(),
        rideReportRepository: FakeRideReportRepository(),
        inProgressRideRepository: fakeInProgressRepo,
      );

      bikeController = ActiveBikeController.instance;
      bikeController.resetForTesting();

      reportController = PostRideReportController.instance;
      reportController.repository = AppRepositories.instance.rideReportRepository;
      reportController.reset();

      const testBike = Bike(
        id: 'test-bike-s4-3b1',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2024,
        odometerKm: 5000,
        preciseOdometerKm: 5000.0,
        fuelLevelOdometerKm: 5000.0,
        fuelTankCapacityLiters: 16.0,
        fuelAverageKmPerLiter: 20.0,
        fuelRemainingLiters: 10.0,
      );
      bikeController.addBike(testBike, setActive: true);
      await bikeController.flush();

      fakeLocation = FakeLocationService();
      fuelTracker = FuelTrackerService.instance;
      fuelTracker.resetForTesting();
      fuelTracker.setDependenciesForTesting(
        locationService: fakeLocation,
        bikeController: bikeController,
        notificationService: _FakeFuelNotificationService(),
        inProgressRideRepository: fakeInProgressRepo,
      );
      TrackingDiagnostics.instance.clear();
    });

    void bindToCurrentZone() {
      fakeLocation = FakeLocationService();
      fuelTracker.setDependenciesForTesting(
        locationService: fakeLocation,
        bikeController: bikeController,
        notificationService: _FakeFuelNotificationService(),
        inProgressRideRepository: fakeInProgressRepo,
      );
    }

    tearDown(() {
      fuelTracker.resetForTesting();
      TrackingDiagnostics.instance.clear();
    });

    test('(a) fix with reported speed 0.0 that moved ~26 m in 6 s with accuracy 20 m is accepted', () async {
      await fuelTracker.startRide();
      final t0 = DateTime(2026, 6, 1, 10, 0, 0);

      // Baseline fix
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 10.0,
        speed: 0.0,
        timestamp: t0,
      ));
      await pumpEventQueue();

      // Fix 6 s later, ~26.7 m north, accuracy 20 m, reported speed 0.0 m/s
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68464,
        longitude: 73.04790,
        accuracy: 20.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 6)),
      ));
      await pumpEventQueue();

      expect(fuelTracker.rideDistanceKm, closeTo(0.0267, 0.002));
      expect(TrackingDiagnostics.instance.acceptedCount, 2);
      expect(TrackingDiagnostics.instance.events.first.isAccepted, isTrue);
      expect(TrackingDiagnostics.instance.events.first.calculatedSpeed, closeTo(4.45, 0.3));
    });

    test('(b) three fixes within 8 m of each other with accuracy 12 m and speed 0 are rejected', () async {
      await fuelTracker.startRide();
      final t0 = DateTime(2026, 6, 1, 10, 0, 0);

      // Baseline fix
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 10.0,
        speed: 0.0,
        timestamp: t0,
      ));
      await pumpEventQueue();

      // Fix 1: ~6.7 m from baseline, accuracy 12 m, speed 0
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68446,
        longitude: 73.04790,
        accuracy: 12.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 5)),
      ));
      await pumpEventQueue();

      // Fix 2: ~7.8 m from baseline, accuracy 12 m, speed 0
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68447,
        longitude: 73.04790,
        accuracy: 12.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 10)),
      ));
      await pumpEventQueue();

      // Fix 3: ~5.6 m from baseline, accuracy 12 m, speed 0
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68445,
        longitude: 73.04790,
        accuracy: 12.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 15)),
      ));
      await pumpEventQueue();

      expect(fuelTracker.rideDistanceKm, 0.0);
      expect(TrackingDiagnostics.instance.acceptedCount, 1);
      expect(TrackingDiagnostics.instance.rejectedCount, 3);
      expect(
        TrackingDiagnostics.instance.events.first.reason,
        contains('Stationary: moved'),
      );
    });

    test('(c) fix with real speed 5 m/s is accepted', () async {
      await fuelTracker.startRide();
      final t0 = DateTime(2026, 6, 1, 10, 0, 0);

      // Baseline fix
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 15.0,
        speed: 5.0,
        timestamp: t0,
      ));
      await pumpEventQueue();

      // Fix 2 s later, ~10 m north, accuracy 18 m, reported speed 5.0 m/s (>= 1.0 m/s)
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68449,
        longitude: 73.04790,
        accuracy: 18.0,
        speed: 5.0,
        timestamp: t0.add(const Duration(seconds: 2)),
      ));
      await pumpEventQueue();

      expect(fuelTracker.rideDistanceKm, closeTo(0.010, 0.002));
      expect(TrackingDiagnostics.instance.acceptedCount, 2);
      expect(TrackingDiagnostics.instance.events.first.isAccepted, isTrue);
    });

    test('(d) rejected fixes do not move baseline so two 3 m steps followed by another 3 m step count once threshold is exceeded', () async {
      await fuelTracker.startRide();
      final t0 = DateTime(2026, 6, 1, 10, 0, 0);

      // Baseline fix at 33.684400
      fakeLocation.emitPosition(PositionData(
        latitude: 33.684400,
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 0.0,
        timestamp: t0,
      ));
      await pumpEventQueue();

      // Step 1: +3.3 m north (< 5 m minDistance) -> rejected, baseline unchanged
      fakeLocation.emitPosition(PositionData(
        latitude: 33.684430,
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 2)),
      ));
      await pumpEventQueue();
      expect(fuelTracker.rideDistanceKm, 0.0);

      // Step 2: another +3.3 m (+6.7 m from baseline), accuracy 8.0 m -> dist < accuracy, rejected, baseline unchanged
      fakeLocation.emitPosition(PositionData(
        latitude: 33.684460,
        longitude: 73.04790,
        accuracy: 8.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 4)),
      ));
      await pumpEventQueue();
      expect(fuelTracker.rideDistanceKm, 0.0);

      // Step 3: third +3.3 m step (+10.0 m from original baseline), accuracy 8.0 m, dt = 6 s (calcSpeed ~1.67 m/s)
      // Exceeds max(5.0, 8.0) = 8.0 m and calcSpeed >= 1.0 m/s -> accepted with full ~10 m distance!
      fakeLocation.emitPosition(PositionData(
        latitude: 33.684490,
        longitude: 73.04790,
        accuracy: 8.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 6)),
      ));
      await pumpEventQueue();

      expect(fuelTracker.rideDistanceKm, closeTo(0.010, 0.0015));
      expect(TrackingDiagnostics.instance.acceptedCount, 2);
      expect(TrackingDiagnostics.instance.rejectedCount, 2);
    });

    testWidgets('(e) finishSavedRide and discardSavedRide stop the tracker and repository stays empty after 35 s of fake time', (tester) async {
      bindToCurrentZone();
      final t0 = DateTime(2026, 6, 1, 10, 0, 0);

      // 1. Test finishSavedRide while tracker is actively running
      await fuelTracker.startRide(routeTitle: 'Active Loop');
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 5.0,
        speed: 12.0,
        timestamp: t0,
      ));
      await tester.pump();

      fakeLocation.emitPosition(PositionData(
        latitude: 33.69440, // ~1.11 km
        longitude: 73.04790,
        accuracy: 5.0,
        speed: 12.0,
        timestamp: t0.add(const Duration(seconds: 60)),
      ));
      await tester.pump();

      expect(fuelTracker.isRiding, isTrue);
      expect(fakeInProgressRepo.savedRide, isNotNull);

      final savedToFinish = fakeInProgressRepo.savedRide!;
      final report = await fuelTracker.finishSavedRide(savedToFinish);
      expect(report, isNotNull);
      expect(fuelTracker.isRiding, isFalse);
      expect(fuelTracker.rideDistanceKm, 0.0);
      expect(fuelTracker.routeTitle, isNull);
      expect(fakeInProgressRepo.savedRide, isNull);

      // Advance 35 seconds of fake time (past the 30s periodic save interval)
      await tester.pump(const Duration(seconds: 35));
      expect(fakeInProgressRepo.savedRide, isNull);
      expect(fuelTracker.isRiding, isFalse);

      // 2. Test discardSavedRide while tracker is actively running
      await fuelTracker.startRide(routeTitle: 'Discard Loop');
      fakeLocation.emitPosition(PositionData(
        latitude: 33.70000,
        longitude: 73.04790,
        accuracy: 5.0,
        speed: 12.0,
        timestamp: t0.add(const Duration(seconds: 120)),
      ));
      await tester.pump();
      fakeLocation.emitPosition(PositionData(
        latitude: 33.70500,
        longitude: 73.04790,
        accuracy: 5.0,
        speed: 12.0,
        timestamp: t0.add(const Duration(seconds: 150)),
      ));
      await tester.pump();

      expect(fuelTracker.isRiding, isTrue);
      expect(fakeInProgressRepo.savedRide, isNotNull);

      await fuelTracker.discardSavedRide();
      expect(fuelTracker.isRiding, isFalse);
      expect(fuelTracker.rideDistanceKm, 0.0);
      expect(fuelTracker.routeTitle, isNull);
      expect(fakeInProgressRepo.savedRide, isNull);

      // Advance 35 seconds of fake time
      await tester.pump(const Duration(seconds: 35));
      expect(fakeInProgressRepo.savedRide, isNull);
      expect(fuelTracker.isRiding, isFalse);

      // Also safe when tracker is already not running
      await fuelTracker.discardSavedRide();
      expect(fakeInProgressRepo.savedRide, isNull);
    });

    testWidgets('(f) Home does not show UnfinishedRideRecoverySheet while isRiding', (tester) async {
      bindToCurrentZone();
      // Save an in-progress ride in repository AND start an active ride in memory
      await fuelTracker.startRide(routeTitle: 'Commute');
      expect(fuelTracker.isRiding, isTrue);
      expect(fakeInProgressRepo.savedRide, isNotNull);

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      // Pump frames without pumpAndSettle (avoid repeating animation hang)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(UnfinishedRideRecoverySheet), findsNothing);
      expect(find.text('UNFINISHED RIDE RECOVERY'), findsNothing);

      await fuelTracker.stopRide();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('(g) resumeRide keeps the saved distance and continues accumulating', (tester) async {
      bindToCurrentZone();
      final startedAt = DateTime(2026, 6, 1, 9, 15);
      final savedRide = InProgressRide(
        id: 'saved-resume-1',
        startedAt: startedAt,
        distanceKm: 12.4,
        bikeId: 'test-bike-s4-3b1',
        routeTitle: 'Coastal Run',
      );
      await fakeInProgressRepo.saveInProgressRide(savedRide);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => UnfinishedRideRecoverySheet.show(ctx, savedRide),
                child: const Text('Open Recovery'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Recovery'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Continue ride'), findsOneWidget);

      await tester.tap(find.text('Continue ride'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fuelTracker.isRiding, isTrue);
      expect(fuelTracker.rideDistanceKm, 12.4);
      expect(fuelTracker.rideStartedAt, startedAt);
      expect(fuelTracker.routeTitle, 'Coastal Run');

      // Emit baseline + movement (+~555 m) and verify it adds onto 12.4 km
      final t0 = DateTime(2026, 6, 1, 10, 0, 0);
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 10.0,
        timestamp: t0,
      ));
      await tester.pump();

      fakeLocation.emitPosition(PositionData(
        latitude: 33.68940, // ~0.556 km north
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 10.0,
        timestamp: t0.add(const Duration(seconds: 40)),
      ));
      await tester.pump();

      expect(fuelTracker.rideDistanceKm, closeTo(12.956, 0.05));
      await fuelTracker.stopRide();
    });
  });

  group('BATCH S4-3b-2: Speedometer Fallback, Failed Reroute & Arrival Finish', () {
    late FakeLocationService fakeLocation;
    late FakeRoutingService fakeRouting;
    late FakeInProgressRideRepository fakeInProgressRepo;
    late ActiveBikeController bikeController;
    late PostRideReportController reportController;
    late FuelTrackerService fuelTracker;
    late TrackingDiagnostics diagnostics;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LocalStore.instance.resetForTesting();

      fakeInProgressRepo = FakeInProgressRideRepository();
      AppRepositories.resetWith(
        bikeRepository: _FakeBikeRepository(),
        rideReportRepository: FakeRideReportRepository(),
        inProgressRideRepository: fakeInProgressRepo,
      );

      bikeController = ActiveBikeController.instance;
      bikeController.resetForTesting();

      reportController = PostRideReportController.instance;
      reportController.repository = AppRepositories.instance.rideReportRepository;
      reportController.reset();

      const testBike = Bike(
        id: 'test-bike-s4-3b2',
        make: 'Honda',
        modelName: 'CRF300L',
        modelYear: 2024,
        odometerKm: 2000,
        preciseOdometerKm: 2000.0,
        fuelLevelOdometerKm: 2000.0,
        fuelTankCapacityLiters: 12.8,
        fuelAverageKmPerLiter: 25.0,
        fuelRemainingLiters: 8.0,
      );
      bikeController.addBike(testBike, setActive: true);
      await bikeController.flush();

      fakeLocation = FakeLocationService();
      fakeRouting = FakeRoutingService();

      diagnostics = TrackingDiagnostics.instance;
      diagnostics.clear();

      fuelTracker = FuelTrackerService.instance;
      fuelTracker.resetForTesting();
      fuelTracker.setDependenciesForTesting(
        locationService: fakeLocation,
        bikeController: bikeController,
        notificationService: _FakeFuelNotificationService(),
        inProgressRideRepository: fakeInProgressRepo,
      );
    });

    tearDown(() {
      fuelTracker.resetForTesting();
      diagnostics.clear();
    });

    test('1. Speed fallback with reported 0.0 and 40 m moved in 4 s gives ~36 km/h and holds for 3 s', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();

      final t0 = DateTime(2026, 6, 1, 12, 0, 0);
      // Baseline fix at t0 with reported speed 0.0
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 10.0,
        speed: 0.0,
        timestamp: t0,
      ));
      await pumpEventQueue();

      // Move ~40.0 m north (0.00036 deg lat ≈ 40.01 m) in 4 seconds with reported speed 0.0
      // 40.01 m / 4 s = 10.00 m/s = 36.0 km/h
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68476,
        longitude: 73.04790,
        accuracy: 12.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 4)),
      ));
      await pumpEventQueue();

      expect(nav.currentSpeed, closeTo(36, 1));
      expect(nav.latestGoodPosition?.latitude, 33.68476);

      // Stationary fix 2 s later (within 3 s hold window) keeps the last good speed
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68476,
        longitude: 73.04790,
        accuracy: 12.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 6)),
      ));
      await pumpEventQueue();
      expect(nav.currentSpeed, closeTo(36, 1));

      // Stationary fix 4 s after the good speed (> 3 s hold window, before 5 s stationary proof) drops to null ("--")
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68476,
        longitude: 73.04790,
        accuracy: 12.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 8)),
      ));
      await pumpEventQueue();
      expect(nav.currentSpeed, isNull);
      expect(nav.formattedSpeed, '--');

      // Stationary fix 5 s after stopping proves stationary -> 0 km/h
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68476,
        longitude: 73.04790,
        accuracy: 12.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 9)),
      ));
      await pumpEventQueue();
      expect(nav.currentSpeed, 0);

      nav.dispose();
    });

    test('2. Speed fallback ignores jitter smaller than current fix accuracy', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();

      final t0 = DateTime(2026, 6, 1, 12, 0, 0);
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 15.0,
        speed: 0.0,
        timestamp: t0,
      ));
      await pumpEventQueue();

      // Move ~8.9 m north in 3 s (dist < 15.0 m) with reported speed 0.0 -> no estimate yet (null / "--")
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68448,
        longitude: 73.04790,
        accuracy: 15.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 3)),
      ));
      await pumpEventQueue();
      expect(nav.currentSpeed, isNull);

      // Still within 15.0 m accuracy at 5 s -> proven stationary (0 km/h)
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68448,
        longitude: 73.04790,
        accuracy: 15.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 5)),
      ));
      await pumpEventQueue();
      expect(nav.currentSpeed, 0);
      nav.dispose();
    });

    test('3. Failed reroute keeps step index, route, and polyline unchanged', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();

      await nav.openRoutePreview(
        const PlaceSearchResult(
          name: 'Margalla Viewpoint',
          displayName: 'Margalla Viewpoint, Islamabad',
          location: LatLng(33.7294, 73.0931),
        ),
      );
      await nav.startNavigation();

      expect(nav.state, NavigationState.navigating);
      expect(nav.currentStepIndex, 0);
      expect(nav.currentStep?.instruction, 'Head out on Test Way');

      final originalRoute = nav.route!;
      final originalPolyline = List<LatLng>.from(originalRoute.polyline);
      final step1Point = originalRoute.steps[1].location;

      // Advance to step 1 by reaching within 30 m of step 1 maneuver location
      fakeLocation.emitPosition(PositionData(
        latitude: step1Point.latitude,
        longitude: step1Point.longitude,
        accuracy: 6.0,
        speed: 12.0,
        timestamp: DateTime(2026, 6, 1, 12, 1, 0),
      ));
      await pumpEventQueue();

      expect(nav.currentStepIndex, 1);
      expect(nav.currentStep?.instruction, 'Turn right onto Test Pass Rd');

      // Simulate offline / failed reroute
      fakeRouting.shouldThrow = true;

      // Emit 3 consecutive off-route fixes (> 50 m from polyline) to trigger reroute
      for (int i = 1; i <= 3; i++) {
        fakeLocation.emitPosition(PositionData(
          latitude: 33.8000 + (i * 0.001),
          longitude: 73.2000,
          accuracy: 8.0,
          speed: 10.0,
          timestamp: DateTime(2026, 6, 1, 12, 1, i * 5),
        ));
        await pumpEventQueue();
      }

      // Route, polyline, and step index must remain at step 1 (not reset to 0 / "Head out")
      expect(nav.currentStepIndex, 1);
      expect(nav.currentStep?.instruction, 'Turn right onto Test Pass Rd');
      expect(nav.route?.polyline, originalPolyline);
      expect(nav.state, NavigationState.navigating);

      await fuelTracker.stopRide();
      nav.dispose();
    });

    testWidgets('4. Arrival shows "Finish ride" and finishing stops the tracker and creates report', (tester) async {
      fakeLocation = FakeLocationService();
      fuelTracker.resetForTesting();
      fuelTracker.setDependenciesForTesting(
        locationService: fakeLocation,
        bikeController: bikeController,
        notificationService: _FakeFuelNotificationService(),
        inProgressRideRepository: fakeInProgressRepo,
      );

      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();

      const destPoint = LatLng(33.68940, 73.04790);
      await nav.openRoutePreview(
        const PlaceSearchResult(
          name: 'Trailhead Arrival',
          displayName: 'Trailhead Arrival, Sector F-6',
          location: destPoint,
        ),
      );
      await nav.startNavigation();
      expect(fuelTracker.isRiding, isTrue);

      final t0 = DateTime(2026, 6, 1, 12, 0, 0);
      // Baseline fix at start
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 0.0,
        timestamp: t0,
      ));
      await tester.pump();

      // Move ~556 m to destination (within 30 m of destPoint) -> triggers arrival & accumulates > 0.1 km
      fakeLocation.emitPosition(PositionData(
        latitude: destPoint.latitude,
        longitude: destPoint.longitude,
        accuracy: 6.0,
        speed: 12.0,
        timestamp: t0.add(const Duration(seconds: 45)),
      ));
      await tester.pump();

      expect(nav.state, NavigationState.arrived);
      expect(fuelTracker.rideDistanceKm, closeTo(0.556, 0.05));

      // Verify diagnostics logged reportedSpeedValid flags on fixes (events list is newest-first)
      final fixEvents = diagnostics.events
          .where((e) => e.type == TrackingEventType.fix)
          .toList();
      expect(fixEvents, isNotEmpty);
      expect(fixEvents.first.isReportedSpeedValid, isTrue);
      expect(fixEvents.last.isReportedSpeedValid, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NavArrivedSheet(
              controller: nav,
              onDone: nav.dismissArrived,
            ),
          ),
        ),
      );

      expect(find.text('Finish ride'), findsOneWidget);
      expect(find.text('Keep tracking'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('arrived_finish_ride_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fuelTracker.isRiding, isFalse);
      expect(nav.state, NavigationState.idle);
      expect(reportController.reports.length, 1);
      expect(reportController.reports.first.isTracked, isTrue);

      nav.dispose();
      // Flush any 1-second rate-limit timer scheduled by reverse geocoding on position updates
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('BATCH S4-3c-1: Clean Location Pipeline, Speedometer, Weak GPS & Diagnostics', () {
    late FakeInProgressRideRepository fakeInProgressRepo;
    late ActiveBikeController bikeController;
    late PostRideReportController reportController;
    late FakeLocationService fakeLocation;
    late FakeRoutingService fakeRouting;
    late FuelTrackerService fuelTracker;
    late TrackingDiagnostics diagnostics;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LocalStore.instance.resetForTesting();

      fakeInProgressRepo = FakeInProgressRideRepository();
      AppRepositories.resetWith(
        bikeRepository: _FakeBikeRepository(),
        rideReportRepository: FakeRideReportRepository(),
        inProgressRideRepository: fakeInProgressRepo,
      );

      SettingsController.instance.resetForTesting();

      bikeController = ActiveBikeController.instance;
      bikeController.resetForTesting();

      reportController = PostRideReportController.instance;
      reportController.repository = AppRepositories.instance.rideReportRepository;
      reportController.reset();

      const testBike = Bike(
        id: 'bike-s4-3c-1',
        make: 'Yamaha',
        modelName: 'YBR 125G',
        modelYear: 2024,
        odometerKm: 2000,
        preciseOdometerKm: 2000.0,
        fuelLevelOdometerKm: 2000.0,
        fuelTankCapacityLiters: 13.0,
        fuelAverageKmPerLiter: 40.0,
        fuelRemainingLiters: 8.0,
      );
      bikeController.addBike(testBike, setActive: true);
      await bikeController.flush();

      fakeLocation = FakeLocationService();
      fakeRouting = FakeRoutingService();

      diagnostics = TrackingDiagnostics.instance;
      diagnostics.clear();

      fuelTracker = FuelTrackerService.instance;
      fuelTracker.resetForTesting();
      fuelTracker.setDependenciesForTesting(
        locationService: fakeLocation,
        bikeController: bikeController,
        notificationService: _FakeFuelNotificationService(),
        inProgressRideRepository: fakeInProgressRepo,
      );
    });

    tearDown(() {
      fuelTracker.resetForTesting();
      diagnostics.clear();
      SettingsController.instance.resetForTesting();
    });

    test('1. Fix gate & 90m-accuracy fix 100m away causes no map dot jump, step change, or speed spike', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();
      await nav.openRoutePreview(
        const PlaceSearchResult(
          name: 'Checkpoint',
          displayName: 'Checkpoint, Islamabad',
          location: LatLng(33.7294, 73.0931),
        ),
      );
      await nav.startNavigation();

      final t0 = DateTime(2026, 6, 1, 12, 0, 0);
      // Good baseline fix at t0
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 12.0,
        speed: 0.0,
        timestamp: t0,
      ));
      await pumpEventQueue();

      // Good fix 4 s later, ~40 m north -> ~36 km/h
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68476,
        longitude: 73.04790,
        accuracy: 14.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 4)),
      ));
      await pumpEventQueue();

      expect(nav.latestGoodPosition?.latitude, 33.68476);
      expect(nav.currentPosition?.latitude, 33.68476);
      expect(nav.currentSpeed, closeTo(36, 1));
      final stepBeforeBadFix = nav.currentStepIndex;

      // Bad fix (accuracy 90 m > 30 m) 100 m away 2 s later (would be 180 km/h if not gated!)
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68566,
        longitude: 73.04790,
        accuracy: 90.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 6)),
      ));
      await pumpEventQueue();

      // Good position, map dot, step, and speed are untouched
      expect(nav.latestGoodPosition?.latitude, 33.68476);
      expect(nav.currentPosition?.latitude, 33.68476);
      expect(nav.currentStepIndex, stepBeforeBadFix);
      expect(nav.currentSpeed, closeTo(36, 1));

      await fuelTracker.stopRide();
      nav.dispose();
    });

    test('2. Reported speed is preferred over calculated speed, smoothed with EMA (alpha=0.4), and plausibility filters spikes', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();

      final t0 = DateTime(2026, 6, 1, 12, 0, 0);

      // Fix 1 at t0: reported speed = 10.0 m/s (36 km/h) on a good fix -> initial EMA = 10.0 m/s (36 km/h)
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 10.0,
        speed: 10.0,
        timestamp: t0,
      ));
      await pumpEventQueue();
      expect(nav.currentSpeed, 36);

      // Fix 2 at t0+4s: coordinates moved 80 m (20 m/s calc), but reported speed is 15.0 m/s (54 km/h).
      // Reported speed (15.0 m/s) must be preferred over calculated speed (20.0 m/s)!
      // Accel = |15 - 10| / 4 = 1.25 m/s² <= 5 m/s² (plausible).
      // EMA = 0.4 * 15.0 + 0.6 * 10.0 = 12.0 m/s -> 43.2 km/h -> rounds to 43 km/h.
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68512,
        longitude: 73.04790,
        accuracy: 10.0,
        speed: 15.0,
        timestamp: t0.add(const Duration(seconds: 4)),
      ));
      await pumpEventQueue();
      expect(nav.currentSpeed, 43);

      // Fix 3 at t0+6s (2 s later): implausible spike > 130 km/h (42 m/s = 151.2 km/h)
      // Must be ignored, holding the last smoothed value (43 km/h) within the 3 s hold window
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68588,
        longitude: 73.04790,
        accuracy: 10.0,
        speed: 42.0,
        timestamp: t0.add(const Duration(seconds: 6)),
      ));
      await pumpEventQueue();
      expect(nav.currentSpeed, 43);

      // Fix 4 at t0+6.5s (2.5 s after Fix 2): implausible acceleration jump (from 15 m/s to 30 m/s in 2.5 s = 6.0 m/s² > 5.0 m/s²)
      // Must also be ignored, still within 3 s hold window of Fix 2 -> 43 km/h
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68600,
        longitude: 73.04790,
        accuracy: 10.0,
        speed: 30.0,
        timestamp: t0.add(const Duration(milliseconds: 6500)),
      ));
      await pumpEventQueue();
      expect(nav.currentSpeed, 43);

      nav.dispose();
    });

    test('3. Speedometer exposes null ("--") after 8s without good fixes, and 0 when stationary over >= 5s', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();

      final t0 = DateTime(2026, 6, 1, 12, 0, 0);

      // Stationary good fixes at t0, t0+2s, t0+5s (moved ~3 m < 12 m accuracy, speed 0.0)
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 12.0,
        speed: 0.0,
        timestamp: t0,
      ));
      await pumpEventQueue();
      expect(nav.currentSpeed, isNull);
      expect(nav.formattedSpeed, '--');

      fakeLocation.emitPosition(PositionData(
        latitude: 33.68442,
        longitude: 73.04790,
        accuracy: 12.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 2)),
      ));
      await pumpEventQueue();

      fakeLocation.emitPosition(PositionData(
        latitude: 33.68443,
        longitude: 73.04790,
        accuracy: 12.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 5)),
      ));
      await pumpEventQueue();

      // Proven stationary over 5 s -> shows 0
      expect(nav.currentSpeed, 0);
      expect(nav.formattedSpeed, '0');

      // Now only bad fixes (> 30 m accuracy) arrive for 8+ seconds (at t0+13s, 8 s after last good fix at t0+5s)
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68500,
        longitude: 73.04790,
        accuracy: 65.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 13)),
      ));
      await pumpEventQueue();

      // 8 s without a good fix / valid speed estimate -> exposes null ("--")
      expect(nav.currentSpeed, isNull);
      expect(nav.formattedSpeed, '--');

      nav.dispose();
    });

    test('4. gpsWeak turns ON after > 10s without a good fix and OFF when a good fix arrives', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();

      final t0 = DateTime(2026, 6, 1, 12, 0, 0);

      // Good fix at t0
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 15.0,
        speed: 5.0,
        timestamp: t0,
      ));
      await pumpEventQueue();
      expect(nav.gpsWeak, isFalse);

      // Bad fix at t0 + 9 s (<= 10 s threshold) -> gpsWeak still false
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68460,
        longitude: 73.04790,
        accuracy: 55.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 9)),
      ));
      await pumpEventQueue();
      expect(nav.gpsWeak, isFalse);

      // Bad fix at t0 + 11 s (> 10 s without a good fix) -> gpsWeak becomes true, dot stays at last good position
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68500,
        longitude: 73.04790,
        accuracy: 75.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 11)),
      ));
      await pumpEventQueue();
      expect(nav.gpsWeak, isTrue);
      expect(nav.currentPosition?.latitude, 33.68440);

      // Good fix arrives at t0 + 14 s -> gpsWeak clears to false and dot updates
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68480,
        longitude: 73.04790,
        accuracy: 18.0,
        speed: 8.0,
        timestamp: t0.add(const Duration(seconds: 14)),
      ));
      await pumpEventQueue();
      expect(nav.gpsWeak, isFalse);
      expect(nav.currentPosition?.latitude, 33.68480);

      nav.dispose();
    });

    test('5. Tracker scenarios: stationary jitter, slow movement (~2 m/s), normal movement, long dropout chord (~1293 m / 79 s), jump rejection, and missing/zero speed', () async {
      fakeLocation.clearPosition();
      await fuelTracker.startRide();
      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);

      // Fix 1: Baseline accepted fix at t0
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 12.0,
        speed: 0.0,
        timestamp: t0,
      ));
      await pumpEventQueue();
      expect(fuelTracker.rideDistanceKm, 0.0);

      // (a) Stationary jitter: three fixes within 8 m, accuracy 12 m, speed 0 -> adds no distance
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68443, // ~3.3 m
        longitude: 73.04790,
        accuracy: 12.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 3)),
      ));
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68446, // ~6.7 m from baseline
        longitude: 73.04790,
        accuracy: 12.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 6)),
      ));
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68447, // ~7.8 m from baseline (< 12 m accuracy)
        longitude: 73.04790,
        accuracy: 12.0,
        speed: null,
        timestamp: t0.add(const Duration(seconds: 9)),
      ));
      await pumpEventQueue();
      expect(fuelTracker.rideDistanceKm, 0.0);

      // (b) Slow genuine movement (~2 m/s) with missing/zero reported speed:
      // Move ~20 m north from baseline over 10 s (calcSpeed = 2.0 m/s >= 1.0 m/s, dist 20 m >= accuracy 10 m)
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68458, // ~20.0 m from 33.68440
        longitude: 73.04790,
        accuracy: 10.0,
        speed: null,
        timestamp: t0.add(const Duration(seconds: 10)),
      ));
      await pumpEventQueue();
      expect(fuelTracker.rideDistanceKm, closeTo(0.020, 0.002));

      // (c) Normal movement (~11.1 m/s = 40 km/h) with zero reported speed:
      // Move ~100 m north over 9 s (33.68458 -> 33.68548)
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68548,
        longitude: 73.04790,
        accuracy: 14.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 19)),
      ));
      await pumpEventQueue();
      expect(fuelTracker.rideDistanceKm, closeTo(0.120, 0.005));

      // (d) Accuracy degrades above 30 m (rejected), then recovers after a 79 s dropout ~1,293 m away:
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68800,
        longitude: 73.04790,
        accuracy: 48.0, // rejected (> 30 m)
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 40)),
      ));
      fakeLocation.emitPosition(PositionData(
        latitude: 33.69200,
        longitude: 73.04790,
        accuracy: 85.0, // rejected (> 30 m)
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 70)),
      ));
      // Recovery fix 79 s after last accepted fix (t0+19s -> t0+98s), ~1,293 m north (0.011625 deg lat ≈ 1293 m)
      fakeLocation.emitPosition(PositionData(
        latitude: 33.697105,
        longitude: 73.04790,
        accuracy: 18.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 98)),
      ));
      await pumpEventQueue();
      // Total distance should now include the ~1.293 km chord (0.120 + 1.293 ≈ 1.413 km)
      expect(fuelTracker.rideDistanceKm, closeTo(1.413, 0.02));

      // (e) Large coordinate jump rejected by existing speed-jump rule (> 200 km/h = 55.56 m/s):
      // Jump ~1,112 m in 2 s (~556 m/s = 2000 km/h)
      fakeLocation.emitPosition(PositionData(
        latitude: 33.707105,
        longitude: 73.04790,
        accuracy: 10.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 100)),
      ));
      await pumpEventQueue();
      // Distance unchanged after jump rejection
      expect(fuelTracker.rideDistanceKm, closeTo(1.413, 0.02));

      // (f) Verify diagnostics summary statistics & UTC ISO-8601 Z timestamps
      final summary = diagnostics.computeSummary();
      expect(summary.totalFixes, 10);
      // 2 of 10 fixes were rejected for accuracy (48 m and 85 m) -> 20.0%
      expect(summary.percentRejectedForAccuracy, closeTo(20.0, 0.2));
      expect(summary.medianAccuracyMeters, isNotNull);
      expect(summary.percentValidReportedSpeed, 0.0);
      expect(summary.longestGapWithoutAcceptedSeconds, closeTo(79.0, 0.5));
      expect(summary.maxCalculatedSpeedAcceptedKmh, greaterThan(50.0));

      final plainLog = diagnostics.formatLogAsPlainText();
      expect(plainLog, contains('=== SUMMARY ==='));
      expect(plainLog, contains('- Total Fixes: 10'));
      expect(plainLog, contains('Location Provider Mode: Fused Location Provider (default, forceLocationManager: false)'));
      // Every event timestamp in the log is formatted in UTC ISO-8601 with a trailing Z
      for (final event in diagnostics.events) {
        expect(MotionMath.formatUtcIso8601(event.timestamp).endsWith('Z'), isTrue);
      }

      await fuelTracker.stopRide();
    });

    test('6a. GPS-only provider setting persists in LocalStore and restarts active location streams with forceLocationManager: true', () async {
      final prefs = await SharedPreferences.getInstance();
      LocalStore.instance = LocalStore(prefs);
      SettingsController.instance.resetForTesting();

      await fuelTracker.startRide();
      expect(fakeLocation.lastForceLocationManager, isFalse);
      final initialSubs = fakeLocation.streamSubscriptionCount;

      await SettingsController.instance.setGpsOnlyLocationProvider(true);
      expect(SettingsController.instance.gpsOnlyLocationProvider, isTrue);
      expect(fakeLocation.lastForceLocationManager, isTrue);
      expect(fakeLocation.streamSubscriptionCount, greaterThan(initialSubs));

      // Verify persistence in LocalStore across reload
      final loaded = await SettingsController.instance.repository.loadSettings();
      expect(loaded.gpsOnlyLocationProvider, isTrue);

      await fuelTracker.stopRide();
    });

    testWidgets('6b. TrackingDiagnosticsScreen GPS-only switch toggles mode and restarts active stream', (tester) async {
      await fuelTracker.startRide();
      expect(fakeLocation.lastForceLocationManager, isFalse);
      final initialSubs = fakeLocation.streamSubscriptionCount;

      await tester.pumpWidget(
        const MaterialApp(
          home: TrackingDiagnosticsScreen(),
        ),
      );
      await tester.pump();

      final switchFinder = find.byKey(const ValueKey('tracking_diag_gps_only_switch'));
      expect(switchFinder, findsOneWidget);
      expect(find.text('Fused Location Provider (default)'), findsOneWidget);

      // Toggle the experimental GPS-only switch ON
      await tester.tap(switchFinder);
      await tester.pump();

      expect(SettingsController.instance.gpsOnlyLocationProvider, isTrue);
      expect(fakeLocation.lastForceLocationManager, isTrue);
      expect(fakeLocation.streamSubscriptionCount, greaterThan(initialSubs));
      expect(find.text('GPS-only (forceLocationManager: true)'), findsOneWidget);

      await fuelTracker.stopRide();
    });
  });

  group('BATCH S4-3c-2: Snap Dot to Route, Steady Turn Progress & Sane Rerouting', () {
    late FakeInProgressRideRepository fakeInProgressRepo;
    late ActiveBikeController bikeController;
    late PostRideReportController reportController;
    late FakeLocationService fakeLocation;
    late FakeRoutingService fakeRouting;
    late FuelTrackerService fuelTracker;
    late TrackingDiagnostics diagnostics;

    // Build a straight east-bound 1000 m leg followed by a north-bound 1000 m leg:
    // Start (33.68440, 73.04790) -> Turn (33.68440, 73.05868) (~1000 m East, bearing ~90°)
    // -> End (33.69340, 73.05868) (~1000 m North, bearing ~0°)
    const LatLng kStartPt = LatLng(33.68440, 73.04790);
    const LatLng kTurnPt = LatLng(33.68440, 73.05868);
    const LatLng kEndPt = LatLng(33.69340, 73.05868);

    RouteResult buildTestRoute() {
      final poly = <LatLng>[
        kStartPt,
        const LatLng(33.68440, 73.05329), // ~500 m East
        kTurnPt, // ~1000 m East
        const LatLng(33.68890, 73.05868), // ~500 m North of turn
        kEndPt, // ~1000 m North of turn
      ];
      final cum = RouteProgress.computeCumulativeDistances(poly);
      final leg1Dist = cum[2];
      final leg2Dist = cum[4] - cum[2];
      return RouteResult(
        polyline: poly,
        distanceMeters: cum.last,
        durationSeconds: 200.0,
        steps: [
          RouteStep(
            maneuverType: 'depart',
            streetName: 'Margalla Ave',
            distanceMeters: leg1Dist,
            durationSeconds: 100.0,
            location: kStartPt,
            instruction: 'Head out on Margalla Ave',
          ),
          RouteStep(
            maneuverType: 'turn',
            maneuverModifier: 'left',
            streetName: '9th Ave',
            distanceMeters: leg2Dist,
            durationSeconds: 100.0,
            location: kTurnPt,
            instruction: 'Turn left onto 9th Ave',
          ),
          const RouteStep(
            maneuverType: 'arrive',
            streetName: 'Sector F-8',
            distanceMeters: 0.0,
            durationSeconds: 0.0,
            location: kEndPt,
            instruction: 'Arrive at destination',
          ),
        ],
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LocalStore.instance.resetForTesting();

      fakeInProgressRepo = FakeInProgressRideRepository();
      AppRepositories.resetWith(
        bikeRepository: _FakeBikeRepository(),
        rideReportRepository: FakeRideReportRepository(),
        inProgressRideRepository: fakeInProgressRepo,
      );

      SettingsController.instance.resetForTesting();

      bikeController = ActiveBikeController.instance;
      bikeController.resetForTesting();

      reportController = PostRideReportController.instance;
      reportController.repository = AppRepositories.instance.rideReportRepository;
      reportController.reset();

      const testBike = Bike(
        id: 'bike-s4-3c-2',
        make: 'Yamaha',
        modelName: 'YBR 125G',
        modelYear: 2024,
        odometerKm: 2000,
        preciseOdometerKm: 2000.0,
        fuelLevelOdometerKm: 2000.0,
        fuelTankCapacityLiters: 13.0,
        fuelAverageKmPerLiter: 40.0,
        fuelRemainingLiters: 8.0,
      );
      bikeController.addBike(testBike, setActive: true);
      await bikeController.flush();

      fakeLocation = FakeLocationService(
        initialPosition: PositionData(
          latitude: kStartPt.latitude,
          longitude: kStartPt.longitude,
          accuracy: 8.0,
          speed: 0.0,
          heading: 90.0,
          timestamp: DateTime.utc(2026, 6, 1, 12, 0, 0),
        ),
      );
      fakeRouting = FakeRoutingService(cannedResult: buildTestRoute());

      diagnostics = TrackingDiagnostics.instance;
      diagnostics.clear();

      fuelTracker = FuelTrackerService.instance;
      fuelTracker.resetForTesting();
      fuelTracker.setDependenciesForTesting(
        locationService: fakeLocation,
        bikeController: bikeController,
        notificationService: _FakeFuelNotificationService(),
        inProgressRideRepository: fakeInProgressRepo,
      );
    });

    tearDown(() {
      fuelTracker.resetForTesting();
      diagnostics.clear();
      SettingsController.instance.resetForTesting();
    });

    test('1. Snapping onto polyline and monotonic progress (allows <= 20 m backward search slack, clamps along-route monotonically)', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();
      await nav.openRoutePreview(
        const PlaceSearchResult(
          name: 'Sector F-8',
          displayName: 'Sector F-8, Islamabad',
          location: kEndPt,
        ),
      );
      await nav.startNavigation();

      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);

      // Fix 200 m East along leg 1, offset 18 m North of road (cross-track ~18 m <= max(30 m, 10 m))
      // 18 m North ≈ +0.000162 deg lat; 200 m East ≈ +0.002156 deg lon
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440 + 0.000162,
        longitude: 73.04790 + 0.002156,
        accuracy: 10.0,
        speed: 10.0,
        heading: 135.0, // noisy GPS heading
        timestamp: t0.add(const Duration(seconds: 10)),
      ));
      await pumpEventQueue();

      // Map dot must snap onto the road (latitude == 33.68440) and heading must be segment bearing (~90°)
      expect(nav.snappedPosition, isNotNull);
      expect(nav.userLatLng!.latitude, closeTo(33.68440, 1e-4));
      expect(nav.userLatLng!.longitude, closeTo(73.04790 + 0.002156, 1e-4));
      expect(nav.currentHeading, closeTo(90.0, 1.0));
      final totalDist = nav.route!.distanceMeters;
      final remainingAt200m = nav.remainingDistanceMeters;
      expect(totalDist - remainingAt200m, closeTo(200.0, 10.0));

      // Emit a noisy fix 10 m behind the previous fix (at ~190 m East): progress must stay monotonic!
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440 - 0.000090,
        longitude: 73.04790 + 0.002048,
        accuracy: 10.0,
        speed: 10.0,
        heading: 90.0,
        timestamp: t0.add(const Duration(seconds: 12)),
      ));
      await pumpEventQueue();
      expect(nav.remainingDistanceMeters, equals(remainingAt200m));

      // Emit a fix 35 m North of the road with accuracy 10 m (cross-track 35 m > max(30 m, 10 m)):
      // Dot must use raw good position instead of snapping
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440 + 0.000315, // ~35 m North
        longitude: 73.04790 + 0.002500,
        accuracy: 10.0,
        speed: 10.0,
        heading: 82.0,
        timestamp: t0.add(const Duration(seconds: 15)),
      ));
      await pumpEventQueue();
      expect(nav.snappedPosition, isNull);
      expect(nav.userLatLng!.latitude, closeTo(33.68440 + 0.000315, 1e-6));
      expect(nav.currentHeading, closeTo(82.0, 0.1));

      await fuelTracker.stopRide();
      nav.dispose();
    });

    test('2. Step advance (< 15 m before maneuver or passing step end) and steady countdown under +-25 m random GPS noise', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();
      await nav.openRoutePreview(
        const PlaceSearchResult(
          name: 'Sector F-8',
          displayName: 'Sector F-8, Islamabad',
          location: kEndPt,
        ),
      );
      await nav.startNavigation();

      final rng = math.Random(42);
      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);
      final initialDistToTurn = nav.currentStep!.distanceMeters;
      expect(initialDistToTurn, closeTo(1000.0, 15.0));
      expect(nav.currentStepIndex, 0);

      double lastDistToTurn = initialDistToTurn;

      // Ride East from 100 m to 900 m in 100 m increments with random +-25 m noise
      for (int step = 1; step <= 9; step++) {
        final trueEastMeters = step * 100.0;
        // Random noise in [-25 m, +25 m]
        final noiseNorthMeters = (rng.nextDouble() * 50.0) - 25.0;
        final noiseEastMeters = (rng.nextDouble() * 30.0) - 15.0;

        final lat = kStartPt.latitude + (noiseNorthMeters / 111320.0);
        final lon = kStartPt.longitude +
            ((trueEastMeters + noiseEastMeters) /
                (111320.0 * math.cos(kStartPt.latitude * math.pi / 180.0)));

        fakeLocation.emitPosition(PositionData(
          latitude: lat,
          longitude: lon,
          accuracy: 25.0,
          speed: 12.0,
          heading: 90.0,
          timestamp: t0.add(Duration(seconds: step * 8)),
        ));
        await pumpEventQueue();

        expect(nav.currentStepIndex, 0);
        expect(nav.currentStep!.distanceMeters, lessThan(lastDistToTurn));
        lastDistToTurn = nav.currentStep!.distanceMeters;
      }

      // Move to 10 m before kTurnPt (distance to maneuver < 15 m): step must advance to step 1 ("Turn left onto 9th Ave")!
      final lon10mBeforeTurn = kTurnPt.longitude -
          (10.0 / (111320.0 * math.cos(kStartPt.latitude * math.pi / 180.0)));
      fakeLocation.emitPosition(PositionData(
        latitude: kTurnPt.latitude,
        longitude: lon10mBeforeTurn,
        accuracy: 8.0,
        speed: 10.0,
        heading: 90.0,
        timestamp: t0.add(const Duration(seconds: 80)),
      ));
      await pumpEventQueue();

      expect(nav.currentStepIndex, 1);
      expect(nav.currentStep!.instruction, 'Turn left onto 9th Ave');
      // Now counting down along leg 2 (~1000 m + 10 m remaining)
      expect(nav.currentStep!.distanceMeters, closeTo(1010.0, 20.0));

      await fuelTracker.stopRide();
      nav.dispose();
    });

    test('3. Remaining distance and ETA update proportionally from along-route progress', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();
      await nav.openRoutePreview(
        const PlaceSearchResult(
          name: 'Sector F-8',
          displayName: 'Sector F-8, Islamabad',
          location: kEndPt,
        ),
      );
      await nav.startNavigation();

      final totalDist = nav.route!.distanceMeters;
      expect(nav.remainingDistanceMeters, closeTo(totalDist, 1.0));
      expect(nav.remainingDurationSeconds, closeTo(200.0, 1.0));

      final tMid = DateTime.utc(2026, 6, 1, 12, 1, 40);
      // Move to kTurnPt (exactly halfway along the 2000 m route)
      fakeLocation.emitPosition(PositionData(
        latitude: kTurnPt.latitude,
        longitude: kTurnPt.longitude,
        accuracy: 8.0,
        speed: 10.0,
        heading: 0.0,
        timestamp: tMid,
      ));
      await pumpEventQueue();

      expect(nav.remainingDistanceMeters, closeTo(totalDist / 2.0, 15.0));
      expect(nav.remainingDurationSeconds, closeTo(100.0, 2.0));
      expect(
        nav.eta!.difference(tMid).inSeconds,
        closeTo(100, 3),
      );

      await fuelTracker.stopRide();
      nav.dispose();
    });

    test('4. Off-route requires >= 3 consecutive good fixes spanning >= 8 s with cross-track > max(40 m, 2 * accuracy), and respects 30 s cooldown + 1 in-flight request', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();
      await nav.openRoutePreview(
        const PlaceSearchResult(
          name: 'Sector F-8',
          displayName: 'Sector F-8, Islamabad',
          location: kEndPt,
        ),
      );
      await nav.startNavigation();

      final callsAfterStart = fakeRouting.callCount;
      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);

      // (a) Single bad-accuracy fix (> 30 m) 200 m away -> gated out, no reroute
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68620,
        longitude: 73.04790,
        accuracy: 45.0,
        speed: 10.0,
        timestamp: t0.add(const Duration(seconds: 5)),
      ));
      await pumpEventQueue();
      expect(fakeRouting.callCount, callsAfterStart);

      // (b) Single good off-route fix (100 m North of road, accuracy 10 m) -> no reroute
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68530,
        longitude: 73.04900,
        accuracy: 10.0,
        speed: 10.0,
        timestamp: t0.add(const Duration(seconds: 10)),
      ));
      await pumpEventQueue();
      expect(fakeRouting.callCount, callsAfterStart);

      // (c) 2nd and 3rd consecutive off-route fixes, but only 6 s elapsed since 1st (< 8 s) -> still no reroute!
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68530,
        longitude: 73.04950,
        accuracy: 10.0,
        speed: 10.0,
        timestamp: t0.add(const Duration(seconds: 13)),
      ));
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68530,
        longitude: 73.05000,
        accuracy: 10.0,
        speed: 10.0,
        timestamp: t0.add(const Duration(seconds: 16)),
      ));
      await pumpEventQueue();
      expect(fakeRouting.callCount, callsAfterStart);
      expect(
        diagnostics.events.any((e) =>
            e.type == TrackingEventType.offRoute &&
            e.isOffRouteState == true),
        isFalse,
      );

      // (d) 4th off-route fix at t0+19s (9 s span >= 8 s): triggers reroute!
      // Make this reroute fail so rider stays off-route and we can test the 30 s cooldown & in-flight lock.
      final routeCompleter = Completer<RouteResult>();
      fakeRouting.onGetRoute = ({
        required waypoints,
        requestAlternatives = true,
        startBearingDegrees,
        startBearingToleranceDegrees = 45.0,
        startRadiusMeters,
      }) =>
          routeCompleter.future;

      fakeLocation.emitPosition(PositionData(
        latitude: 33.68530,
        longitude: 73.05050,
        accuracy: 10.0,
        speed: 10.0,
        heading: 90.0,
        timestamp: t0.add(const Duration(seconds: 19)),
      ));
      await pumpEventQueue();
      expect(
        diagnostics.events.any((e) =>
            e.type == TrackingEventType.offRoute &&
            e.isOffRouteState == true),
        isTrue,
      );
      expect(fakeRouting.callCount, callsAfterStart + 1);

      // Emit another off-route fix while first request is still in flight -> no duplicate call!
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68530,
        longitude: 73.05100,
        accuracy: 10.0,
        speed: 10.0,
        heading: 90.0,
        timestamp: t0.add(const Duration(seconds: 25)),
      ));
      await pumpEventQueue();
      expect(fakeRouting.callCount, callsAfterStart + 1);

      // Complete the in-flight request with an error (offline); immediate relaxed retry also fails
      fakeRouting.onGetRoute = null;
      fakeRouting.shouldThrow = true;
      routeCompleter.completeError(Exception('Offline'));
      await pumpEventQueue();
      // Attempt 1 (constrained) + Attempt 2 (immediate relaxed retry) = 2 calls
      expect(fakeRouting.callCount, callsAfterStart + 2);

      // Off-route fix at t0+35s (16 s after t0+19s < 30 s cooldown) -> throttled by cooldown!
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68530,
        longitude: 73.05150,
        accuracy: 10.0,
        speed: 10.0,
        heading: 90.0,
        timestamp: t0.add(const Duration(seconds: 35)),
      ));
      await pumpEventQueue();
      expect(fakeRouting.callCount, callsAfterStart + 2);

      // Off-route fix at t0+50s (31 s after t0+19s >= 30 s cooldown) -> retries reroute (Attempt 1 + Attempt 2)!
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68530,
        longitude: 73.05200,
        accuracy: 10.0,
        speed: 10.0,
        heading: 90.0,
        timestamp: t0.add(const Duration(seconds: 50)),
      ));
      await pumpEventQueue();
      expect(fakeRouting.callCount, callsAfterStart + 4);

      // Verify diagnostics logged both OFF_ROUTE and REROUTE events with UTC Z timestamps
      final offRouteEvents = diagnostics.events
          .where((e) => e.type == TrackingEventType.offRoute)
          .toList();
      final rerouteEvents = diagnostics.events
          .where((e) => e.type == TrackingEventType.reroute)
          .toList();
      expect(offRouteEvents, isNotEmpty);
      expect(rerouteEvents.length, 4);
      expect(rerouteEvents.first.formattedTimestampUtc.endsWith('Z'), isTrue);

      await fuelTracker.stopRide();
      nav.dispose();
    });

    test('5. Reroute passes OSRM bearings & radiuses, discards > 120° hook routes, trims accepted routes, sets step index from snapping, and replaces "Head out" with "Continue on <road>"', () async {
      // Verify OsrmRoutingService URI construction includes bearings and radiuses
      final osrm = OsrmRoutingService();
      final uri = osrm.buildRouteUri(
        waypoints: const [kStartPt, kEndPt],
        requestAlternatives: false,
        startBearingDegrees: 90.0,
        startBearingToleranceDegrees: 45.0,
        startRadiusMeters: 40.0,
      );
      expect(uri.toString(), contains('bearings=90,45;'));
      expect(uri.toString(), contains('radiuses=40;unlimited'));

      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();
      await nav.openRoutePreview(
        const PlaceSearchResult(
          name: 'Sector F-8',
          displayName: 'Sector F-8, Islamabad',
          location: kEndPt,
        ),
      );
      await nav.startNavigation();

      // Fresh navigation session step 0 shows "Head out on Margalla Ave"
      expect(nav.currentStep!.instruction, 'Head out on Margalla Ave');

      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);
      const riderOffRoutePt = LatLng(33.68550, 73.05000); // ~122 m North of leg 1

      // First configure FakeRoutingService to return a HOOK route that heads West (270°, 180° opposite rider's 90° East heading) for 150 m
      const westHookPt = LatLng(33.68550, 73.04800); // ~185 m West of riderOffRoutePt
      fakeRouting.cannedResult = const RouteResult(
        polyline: [riderOffRoutePt, westHookPt, kEndPt],
        distanceMeters: 1500.0,
        durationSeconds: 180.0,
        steps: [
          RouteStep(
            maneuverType: 'depart',
            streetName: 'Hook Spur Rd',
            distanceMeters: 185.0,
            durationSeconds: 25.0,
            location: riderOffRoutePt,
            instruction: 'Head out on Hook Spur Rd',
          ),
          RouteStep(
            maneuverType: 'arrive',
            streetName: 'Sector F-8',
            distanceMeters: 0.0,
            durationSeconds: 0.0,
            location: kEndPt,
            instruction: 'Arrive at destination',
          ),
        ],
      );

      // Emit 3 consecutive off-route fixes spanning 10 s while moving East (heading 90°, speed 8 m/s >= 2 m/s)
      for (int i = 0; i < 3; i++) {
        fakeLocation.emitPosition(PositionData(
          latitude: riderOffRoutePt.latitude,
          longitude: riderOffRoutePt.longitude + (i * 0.0002),
          accuracy: 8.0,
          speed: 8.0,
          heading: 90.0,
          timestamp: t0.add(Duration(seconds: 5 + (i * 5))),
        ));
        await pumpEventQueue();
      }

      // Verify OSRM bearing (90°, tolerance 45°) and radius (40 m) were passed
      expect(fakeRouting.lastStartBearingDegrees, closeTo(90.0, 1.0));
      expect(fakeRouting.requests.last.startBearingToleranceDegrees, 45.0);
      expect(fakeRouting.requests.last.startRadiusMeters, 40.0);

      // The hook route must have been DISCARDED and the original route retained!
      expect(nav.route!.steps.first.streetName, 'Margalla Ave');
      final lastRerouteEvent = diagnostics.events
          .firstWhere((e) => e.type == TrackingEventType.reroute);
      expect(lastRerouteEvent.isRejected, isTrue);
      expect(lastRerouteEvent.reason, contains('Hook/U-turn'));

      // Now after the 30 s cooldown (at t0 + 50 s), return a valid East-bound route where the rider is already 50 m past its first vertex:
      const newRouteOrigin = LatLng(33.68550, 73.04980);
      const riderAtReroute = LatLng(33.68550, 73.05060); // ~74 m East of newRouteOrigin
      const newRouteMid = LatLng(33.68550, 73.05868);
      fakeRouting.cannedResult = const RouteResult(
        polyline: [newRouteOrigin, newRouteMid, kEndPt],
        distanceMeters: 1800.0,
        durationSeconds: 180.0,
        steps: [
          RouteStep(
            maneuverType: 'depart',
            streetName: 'Service Rd North',
            distanceMeters: 800.0,
            durationSeconds: 80.0,
            location: newRouteOrigin,
            instruction: 'Head out on Service Rd North',
          ),
          RouteStep(
            maneuverType: 'turn',
            maneuverModifier: 'left',
            streetName: '9th Ave',
            distanceMeters: 1000.0,
            durationSeconds: 100.0,
            location: newRouteMid,
            instruction: 'Turn left onto 9th Ave',
          ),
          RouteStep(
            maneuverType: 'arrive',
            streetName: 'Sector F-8',
            distanceMeters: 0.0,
            durationSeconds: 0.0,
            location: kEndPt,
            instruction: 'Arrive at destination',
          ),
        ],
      );

      fakeLocation.emitPosition(PositionData(
        latitude: riderAtReroute.latitude,
        longitude: riderAtReroute.longitude,
        accuracy: 8.0,
        speed: 8.0,
        heading: 90.0,
        timestamp: t0.add(const Duration(seconds: 50)),
      ));
      await pumpEventQueue();

      // Accepted! Leading point trimmed to start at the snapped rider position,
      // and banner wording replaced "Head out on Service Rd North" with "Continue on Service Rd North"!
      expect(nav.route!.polyline.first.longitude, closeTo(riderAtReroute.longitude, 1e-4));
      expect(nav.currentStep!.instruction, 'Continue on Service Rd North');
      expect(nav.currentStep!.instruction.startsWith('Head out'), isFalse);

      final acceptedRerouteEvent = diagnostics.events
          .firstWhere((e) => e.type == TrackingEventType.reroute);
      expect(acceptedRerouteEvent.isAccepted, isTrue);

      await fuelTracker.stopRide();
      nav.dispose();
    });

    test('6. Restarting navigation while a ride is active does not reset the tracked ride distance', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();
      await nav.openRoutePreview(
        const PlaceSearchResult(
          name: 'First Stop',
          displayName: 'First Stop, Islamabad',
          location: kEndPt,
        ),
      );
      await nav.startNavigation();
      expect(fuelTracker.isRiding, isTrue);

      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);
      // Emit baseline fix at start point, then ride ~300 m East
      fakeLocation.emitPosition(PositionData(
        latitude: kStartPt.latitude,
        longitude: kStartPt.longitude,
        accuracy: 8.0,
        speed: 8.0,
        heading: 90.0,
        timestamp: t0,
      ));
      await pumpEventQueue();
      fakeLocation.emitPosition(PositionData(
        latitude: kStartPt.latitude,
        longitude: kStartPt.longitude + 0.0032,
        accuracy: 8.0,
        speed: 10.0,
        heading: 90.0,
        timestamp: t0.add(const Duration(seconds: 30)),
      ));
      await pumpEventQueue();

      final distanceBeforeRestart = fuelTracker.rideDistanceKm;
      expect(distanceBeforeRestart, greaterThan(0.25));

      // Stop navigation and start navigation to a new destination while the ride remains active
      nav.stopNavigation();
      expect(fuelTracker.isRiding, isTrue);
      expect(fuelTracker.rideDistanceKm, equals(distanceBeforeRestart));

      await nav.openRoutePreview(
        const PlaceSearchResult(
          name: 'Second Stop',
          displayName: 'Second Stop, Islamabad',
          location: kEndPt,
        ),
      );
      await nav.startNavigation();

      // Tracked ride distance must not reset!
      expect(fuelTracker.isRiding, isTrue);
      expect(fuelTracker.rideDistanceKm, equals(distanceBeforeRestart));

      await fuelTracker.stopRide();
      nav.dispose();
    });
  });

  group('BATCH S4-3c-3: Odometer & Fuel Consistency on Discard/Restart & Reroute Fallback', () {
    late FakeLocationService fakeLocation;
    late FakeRoutingService fakeRouting;
    late FakeInProgressRideRepository fakeInProgressRepo;
    late _FakeBikeRepository fakeBikeRepo;
    late ActiveBikeController bikeController;
    late PostRideReportController reportController;
    late FuelTrackerService fuelTracker;
    late TrackingDiagnostics diagnostics;

    const kStartPt = LatLng(33.68440, 73.04790);
    const kCornerPt = LatLng(33.68440, 73.05868);
    const kEndPt = LatLng(33.69340, 73.05868);

    RouteResult buildTestRoute() {
      return const RouteResult(
        polyline: [kStartPt, kCornerPt, kEndPt],
        distanceMeters: 2000.0,
        durationSeconds: 240.0,
        steps: [
          RouteStep(
            maneuverType: 'depart',
            streetName: 'Margalla Ave',
            distanceMeters: 1000.0,
            durationSeconds: 120.0,
            location: kStartPt,
            instruction: 'Head out on Margalla Ave',
          ),
          RouteStep(
            maneuverType: 'turn',
            maneuverModifier: 'left',
            streetName: 'Faisal Ave',
            distanceMeters: 1000.0,
            durationSeconds: 120.0,
            location: kCornerPt,
            instruction: 'Turn left onto Faisal Ave',
          ),
          RouteStep(
            maneuverType: 'arrive',
            streetName: 'Sector F-8',
            distanceMeters: 0.0,
            durationSeconds: 0.0,
            location: kEndPt,
            instruction: 'Arrive at destination',
          ),
        ],
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LocalStore.instance.resetForTesting();

      fakeInProgressRepo = FakeInProgressRideRepository();
      fakeBikeRepo = _FakeBikeRepository();
      AppRepositories.resetWith(
        bikeRepository: fakeBikeRepo,
        rideReportRepository: FakeRideReportRepository(),
        inProgressRideRepository: fakeInProgressRepo,
      );

      SettingsController.instance.resetForTesting();

      bikeController = ActiveBikeController.instance;
      bikeController.resetForTesting();

      reportController = PostRideReportController.instance;
      reportController.repository = AppRepositories.instance.rideReportRepository;
      reportController.reset();

      const testBike = Bike(
        id: 'bike-s4-3c-3',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2024,
        odometerKm: 5000,
        preciseOdometerKm: 5000.0,
        fuelLevelOdometerKm: 5000.0,
        fuelTankCapacityLiters: 16.0,
        fuelAverageKmPerLiter: 20.0,
        fuelRemainingLiters: 10.0,
      );
      bikeController.addBike(testBike, setActive: true);
      await bikeController.flush();

      fakeLocation = FakeLocationService(
        initialPosition: PositionData(
          latitude: kStartPt.latitude,
          longitude: kStartPt.longitude,
          accuracy: 8.0,
          speed: 0.0,
          heading: 90.0,
          timestamp: DateTime.utc(2026, 6, 1, 12, 0, 0),
        ),
      );
      fakeRouting = FakeRoutingService(cannedResult: buildTestRoute());

      diagnostics = TrackingDiagnostics.instance;
      diagnostics.clear();

      fuelTracker = FuelTrackerService.instance;
      fuelTracker.resetForTesting();
      fuelTracker.setDependenciesForTesting(
        locationService: fakeLocation,
        bikeController: bikeController,
        notificationService: _FakeFuelNotificationService(),
        inProgressRideRepository: fakeInProgressRepo,
      );
    });

    tearDown(() {
      fuelTracker.resetForTesting();
      diagnostics.clear();
      SettingsController.instance.resetForTesting();
    });

    testWidgets('1. Discard from UnfinishedRideRecoverySheet and RideSummarySheet shows confirmation and removes exact applied km from odometer & restores fuel', (tester) async {
      // Re-bind to FakeAsync zone inside testWidgets
      fakeLocation = FakeLocationService(
        initialPosition: PositionData(
          latitude: kStartPt.latitude,
          longitude: kStartPt.longitude,
          accuracy: 8.0,
          speed: 0.0,
          heading: 90.0,
          timestamp: DateTime.utc(2026, 6, 1, 12, 0, 0),
        ),
      );
      fuelTracker.setDependenciesForTesting(
        locationService: fakeLocation,
        bikeController: bikeController,
        notificationService: _FakeFuelNotificationService(),
        inProgressRideRepository: fakeInProgressRepo,
      );

      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);
      await fuelTracker.startRide(routeTitle: 'Trail Leg');
      expect(fuelTracker.preRideOdometerKm, 5000.0);

      // Baseline fix
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 15.0,
        timestamp: t0,
      ));
      await tester.pump();

      // Move ~2.22 km North (+0.02 deg latitude)
      fakeLocation.emitPosition(PositionData(
        latitude: 33.70440,
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 15.0,
        timestamp: t0.add(const Duration(seconds: 120)),
      ));
      await tester.pump();

      final appliedKm = fuelTracker.appliedToOdometerKm;
      expect(appliedKm, closeTo(2.22, 0.05));
      expect(bikeController.activeBike!.preciseOdometerKm, closeTo(5000.0 + appliedKm, 1e-4));
      expect(bikeController.activeBike!.odometerKm, 5002);
      expect(FuelEstimator.currentLiters(bikeController.activeBike!), lessThan(10.0));

      final savedRide = fakeInProgressRepo.savedRide!;
      expect(savedRide.appliedToOdometerKm, closeTo(appliedKm, 1e-5));
      expect(savedRide.preRideOdometerKm, 5000.0);

      // A) Open UnfinishedRideRecoverySheet and tap Discard -> verify confirmation text -> confirm Discard
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => UnfinishedRideRecoverySheet.show(ctx, savedRide),
                child: const Text('Open Unfinished'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Unfinished'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.byKey(const ValueKey('unfinished_ride_discard_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final expectedConfirmText =
          'Discard this ride? This also removes ${appliedKm.toStringAsFixed(1)} km from your odometer.';
      expect(find.text(expectedConfirmText), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('confirm_discard_ride_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Odometer and fuel estimate are restored to pre-ride values!
      expect(bikeController.activeBike!.preciseOdometerKm, 5000.0);
      expect(bikeController.activeBike!.odometerKm, 5000);
      expect(FuelEstimator.currentLiters(bikeController.activeBike!), 10.0);
      expect(fakeInProgressRepo.savedRide, isNull);
      expect(reportController.reports, isEmpty);

      // B) Start a second ride (~1.11 km), finish it, then tap Discard on RideSummarySheet
      await fuelTracker.startRide(routeTitle: 'Second Leg');
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 15.0,
        timestamp: t0.add(const Duration(seconds: 200)),
      ));
      await tester.pump();
      fakeLocation.emitPosition(PositionData(
        latitude: 33.69440, // ~1.11 km North
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 15.0,
        timestamp: t0.add(const Duration(seconds: 260)),
      ));
      await tester.pump();

      final secondAppliedKm = fuelTracker.appliedToOdometerKm;
      final report = await fuelTracker.finishRide();
      expect(report, isNotNull);
      expect(reportController.reports.length, 1);
      expect(bikeController.activeBike!.preciseOdometerKm, closeTo(5000.0 + secondAppliedKm, 1e-4));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => RideSummarySheet.show(ctx, report!),
                child: const Text('Open Summary'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Summary'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.byKey(const ValueKey('ride_summary_discard_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.text(
          'Discard this ride? This also removes ${secondAppliedKm.toStringAsFixed(1)} km from your odometer.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('confirm_discard_ride_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Report removed and odometer restored to 5000.0!
      expect(reportController.reports, isEmpty);
      expect(bikeController.activeBike!.preciseOdometerKm, 5000.0);
      expect(bikeController.activeBike!.odometerKm, 5000);
    });

    test('2. Too-short ride (< 0.1 km) removes its applied km; Finish (>= 0.1 km) keeps and persists them', () async {
      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);
      await fuelTracker.startRide(routeTitle: 'Short Hop');

      // Baseline fix
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 8.0,
        timestamp: t0,
      ));
      await pumpEventQueue();

      // Move ~67 m North (0.0006 deg latitude < 0.1 km)
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68500,
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 8.0,
        timestamp: t0.add(const Duration(seconds: 10)),
      ));
      await pumpEventQueue();

      expect(fuelTracker.rideDistanceKm, closeTo(0.067, 0.01));
      expect(fuelTracker.appliedToOdometerKm, closeTo(0.067, 0.01));
      expect(bikeController.activeBike!.preciseOdometerKm, greaterThan(5000.0));

      // Finishing a short ride (< 0.1 km) returns null and subtracts the applied km
      final shortReport = await fuelTracker.finishRide();
      expect(shortReport, isNull);
      expect(reportController.reports, isEmpty);
      expect(bikeController.activeBike!.preciseOdometerKm, 5000.0);
      expect(bikeController.activeBike!.odometerKm, 5000);

      // Now ride >= 0.1 km (~1.11 km) and finish: odometer keeps the applied km and persists to repository
      await fuelTracker.startRide(routeTitle: 'Real Ride');
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 12.0,
        timestamp: t0.add(const Duration(seconds: 30)),
      ));
      await pumpEventQueue();
      fakeLocation.emitPosition(PositionData(
        latitude: 33.69440,
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 12.0,
        timestamp: t0.add(const Duration(seconds: 90)),
      ));
      await pumpEventQueue();

      final appliedReal = fuelTracker.appliedToOdometerKm;
      expect(appliedReal, closeTo(1.11, 0.03));

      final validReport = await fuelTracker.finishRide();
      expect(validReport, isNotNull);
      expect(bikeController.activeBike!.preciseOdometerKm, closeTo(5000.0 + appliedReal, 1e-4));
      expect(bikeController.activeBike!.odometerKm, 5001);
      final persistedBikes = await fakeBikeRepo.loadBikes();
      expect(persistedBikes.first.preciseOdometerKm, closeTo(5000.0 + appliedReal, 1e-4));
    });

    test('3. Continue after a simulated app restart keeps appliedToOdometerKm without double-applying or losing distance', () async {
      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);
      await fuelTracker.startRide(routeTitle: 'Restart Leg');

      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 14.0,
        timestamp: t0,
      ));
      await pumpEventQueue();

      // Ride ~2.22 km before simulated app kill
      fakeLocation.emitPosition(PositionData(
        latitude: 33.70440,
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 14.0,
        timestamp: t0.add(const Duration(seconds: 120)),
      ));
      await pumpEventQueue();

      final preKillApplied = fuelTracker.appliedToOdometerKm;
      expect(preKillApplied, closeTo(2.22, 0.05));
      expect(bikeController.activeBike!.preciseOdometerKm, closeTo(5000.0 + preKillApplied, 1e-4));

      // Round-trip InProgressRide through JSON to simulate cold app restart
      final savedJson = fakeInProgressRepo.savedRide!.toJson();
      final recoveredRide = InProgressRide.fromJson(savedJson);
      expect(recoveredRide.appliedToOdometerKm, closeTo(preKillApplied, 1e-5));
      expect(recoveredRide.preRideOdometerKm, 5000.0);

      // Simulate cold start in-memory reset
      fuelTracker.resetForTesting();
      expect(fuelTracker.isRiding, isFalse);

      // Resume ride: must restore appliedToOdometerKm and NOT double-apply it to the bike odometer
      final resumed = await fuelTracker.resumeRide(recoveredRide);
      expect(resumed, isTrue);
      expect(fuelTracker.isRiding, isTrue);
      expect(fuelTracker.appliedToOdometerKm, closeTo(preKillApplied, 1e-5));
      expect(fuelTracker.preRideOdometerKm, 5000.0);
      expect(bikeController.activeBike!.preciseOdometerKm, closeTo(5000.0 + preKillApplied, 1e-4));

      // Ride another ~1.11 km after resume
      fakeLocation.emitPosition(PositionData(
        latitude: 33.70440,
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 14.0,
        timestamp: t0.add(const Duration(seconds: 180)),
      ));
      await pumpEventQueue();
      fakeLocation.emitPosition(PositionData(
        latitude: 33.71440,
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 14.0,
        timestamp: t0.add(const Duration(seconds: 240)),
      ));
      await pumpEventQueue();

      final totalApplied = fuelTracker.appliedToOdometerKm;
      expect(totalApplied, closeTo(preKillApplied + 1.11, 0.05));
      expect(bikeController.activeBike!.preciseOdometerKm, closeTo(5000.0 + totalApplied, 1e-4));

      // Discarding now removes the entire totalApplied (~3.33 km) back to 5000.0
      await fuelTracker.discardSavedRide();
      expect(bikeController.activeBike!.preciseOdometerKm, 5000.0);
      expect(bikeController.activeBike!.odometerKm, 5000);
    });

    testWidgets('4. Double discard does not subtract twice, odometer never goes below pre-ride value, and no re-save after discard (35 s fake time)', (tester) async {
      fakeLocation = FakeLocationService(
        initialPosition: PositionData(
          latitude: kStartPt.latitude,
          longitude: kStartPt.longitude,
          accuracy: 8.0,
          speed: 0.0,
          heading: 90.0,
          timestamp: DateTime.utc(2026, 6, 1, 12, 0, 0),
        ),
      );
      fuelTracker.setDependenciesForTesting(
        locationService: fakeLocation,
        bikeController: bikeController,
        notificationService: _FakeFuelNotificationService(),
        inProgressRideRepository: fakeInProgressRepo,
      );

      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);
      await fuelTracker.startRide(routeTitle: 'Double Discard Test');

      fakeLocation.emitPosition(PositionData(
        latitude: 33.68440,
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 14.0,
        timestamp: t0,
      ));
      await tester.pump();
      fakeLocation.emitPosition(PositionData(
        latitude: 33.70440, // ~2.22 km
        longitude: 73.04790,
        accuracy: 6.0,
        speed: 14.0,
        timestamp: t0.add(const Duration(seconds: 120)),
      ));
      await tester.pump();

      final savedSnapshot = fakeInProgressRepo.savedRide!;
      expect(bikeController.activeBike!.preciseOdometerKm, greaterThan(5002.0));

      // First discard subtracts the applied distance back to 5000.0
      await fuelTracker.discardSavedRide(savedSnapshot);
      expect(bikeController.activeBike!.preciseOdometerKm, 5000.0);
      expect(bikeController.activeBike!.odometerKm, 5000);
      expect(fakeInProgressRepo.savedRide, isNull);

      // Second discard (both with the same savedSnapshot and without args) must NOT subtract again!
      await fuelTracker.discardSavedRide(savedSnapshot);
      await fuelTracker.discardSavedRide();
      expect(bikeController.activeBike!.preciseOdometerKm, 5000.0);
      expect(bikeController.activeBike!.odometerKm, 5000);

      // Advance fake time by 35 seconds (past the 30 s periodic save timer): repository stays null!
      await tester.pump(const Duration(seconds: 35));
      expect(fakeInProgressRepo.savedRide, isNull);
      expect(fuelTracker.isRiding, isFalse);

      // Floor protection: even if a saved ride reports appliedToOdometerKm = 15.0 while bike is at 5003.0
      // with preRideOdometerKm = 5000.0, discarding clamps at 5000.0 (never below pre-ride value).
      bikeController.updateBike(
        bikeController.activeBike!.copyWith(
          odometerKm: 5003,
          preciseOdometerKm: 5003.0,
        ),
      );
      final exaggeratedRide = InProgressRide(
        id: 'floor-test-ride',
        startedAt: t0.add(const Duration(minutes: 10)),
        distanceKm: 15.0,
        appliedToOdometerKm: 15.0,
        preRideOdometerKm: 5000.0,
        bikeId: 'bike-s4-3c-3',
      );
      await fakeInProgressRepo.saveInProgressRide(exaggeratedRide);
      await fuelTracker.discardSavedRide(exaggeratedRide);
      expect(bikeController.activeBike!.preciseOdometerKm, 5000.0);
      expect(bikeController.activeBike!.odometerKm, 5000);
    });

    testWidgets('5. Returning to Maps does not create another ride, and exiting navigation (X or arrival) keeps tracking unless Finish ride is chosen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeLocation = FakeLocationService(
        initialPosition: PositionData(
          latitude: kStartPt.latitude,
          longitude: kStartPt.longitude,
          accuracy: 8.0,
          speed: 0.0,
          heading: 90.0,
          timestamp: DateTime.utc(2026, 6, 1, 12, 0, 0),
        ),
      );
      fuelTracker.setDependenciesForTesting(
        locationService: fakeLocation,
        bikeController: bikeController,
        notificationService: _FakeFuelNotificationService(),
        inProgressRideRepository: fakeInProgressRepo,
      );

      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();

      // Opening NavigationMapScreen while idle does not start a ride
      await tester.pumpWidget(
        MaterialApp(
          home: NavigationMapScreen(
            controller: nav,
            locationService: fakeLocation,
            tileProvider: _TransparentTileProvider(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(fuelTracker.isRiding, isFalse);

      // Start navigation -> starts tracking
      await nav.openRoutePreview(
        const PlaceSearchResult(
          name: 'Sector F-8',
          displayName: 'Sector F-8, Islamabad',
          location: kEndPt,
        ),
      );
      await nav.startNavigation();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(fuelTracker.isRiding, isTrue);

      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);
      fakeLocation.emitPosition(PositionData(
        latitude: kStartPt.latitude,
        longitude: kStartPt.longitude,
        accuracy: 6.0,
        speed: 10.0,
        timestamp: t0,
      ));
      await tester.pump();
      fakeLocation.emitPosition(PositionData(
        latitude: kStartPt.latitude,
        longitude: kStartPt.longitude + 0.0040, // ~370 m East
        accuracy: 6.0,
        speed: 10.0,
        timestamp: t0.add(const Duration(seconds: 30)),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final trackedKm = fuelTracker.rideDistanceKm;
      expect(trackedKm, greaterThan(0.3));

      // Leaving and returning to NavigationMapScreen does not reset or create another ride
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Away'))));
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: NavigationMapScreen(
            controller: nav,
            locationService: fakeLocation,
            tileProvider: _TransparentTileProvider(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(fuelTracker.isRiding, isTrue);
      expect(fuelTracker.rideDistanceKm, equals(trackedKm));

      // Arrival state: tapping "Keep tracking" dismisses arrival sheet while keeping ride active
      fakeLocation.emitPosition(PositionData(
        latitude: kEndPt.latitude,
        longitude: kEndPt.longitude,
        accuracy: 5.0,
        speed: 2.0,
        timestamp: t0.add(const Duration(seconds: 120)),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(nav.state, NavigationState.arrived);
      expect(find.byType(NavArrivedSheet), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('arrived_keep_tracking_button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(nav.state, NavigationState.idle);
      expect(fuelTracker.isRiding, isTrue);

      await fuelTracker.stopRide();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      nav.dispose();
    });

    test('6. Reroute fallback: constrained attempt fails -> immediate relaxed retry (radiuses 100 m, no bearings) succeeds, hook-route discard applies to retry, both fail keeps old route, and 30 s cooldown applies', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();
      await nav.openRoutePreview(
        const PlaceSearchResult(
          name: 'Sector F-8',
          displayName: 'Sector F-8, Islamabad',
          location: kEndPt,
        ),
      );
      await nav.startNavigation();

      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);
      const riderOffRoutePt = LatLng(33.68550, 73.05000);
      const newRouteMid = LatLng(33.68550, 73.05868);

      const validRelaxedRoute = RouteResult(
        polyline: [riderOffRoutePt, newRouteMid, kEndPt],
        distanceMeters: 1700.0,
        durationSeconds: 170.0,
        steps: [
          RouteStep(
            maneuverType: 'depart',
            streetName: 'Relaxed Service Rd',
            distanceMeters: 700.0,
            durationSeconds: 70.0,
            location: riderOffRoutePt,
            instruction: 'Head out on Relaxed Service Rd',
          ),
          RouteStep(
            maneuverType: 'arrive',
            streetName: 'Sector F-8',
            distanceMeters: 0.0,
            durationSeconds: 0.0,
            location: kEndPt,
            instruction: 'Arrive at destination',
          ),
        ],
      );

      // Case A: Constrained attempt (bearings != null, radius 40 m) throws NoSegment,
      // immediate relaxed retry (bearings == null, radius 100 m) succeeds!
      fakeRouting.requests.clear();
      fakeRouting.onGetRoute = ({
        required waypoints,
        requestAlternatives = true,
        startBearingDegrees,
        startBearingToleranceDegrees = 45.0,
        startRadiusMeters,
      }) async {
        if (startBearingDegrees != null) {
          throw Exception('NoSegment: Could not find a matching segment');
        }
        return validRelaxedRoute;
      };

      for (int i = 0; i < 3; i++) {
        fakeLocation.emitPosition(PositionData(
          latitude: riderOffRoutePt.latitude,
          longitude: riderOffRoutePt.longitude + (i * 0.0002),
          accuracy: 8.0,
          speed: 9.0,
          heading: 90.0,
          timestamp: t0.add(Duration(seconds: 5 + (i * 5))),
        ));
        await pumpEventQueue();
      }

      // Exactly 2 requests made immediately: Attempt 1 (constrained) + Attempt 2 (relaxed 100 m, no bearings)
      expect(fakeRouting.requests.length, 2);
      expect(fakeRouting.requests[0].startBearingDegrees, closeTo(90.0, 1.0));
      expect(fakeRouting.requests[0].startRadiusMeters, 40.0);
      expect(fakeRouting.requests[1].startBearingDegrees, isNull);
      expect(fakeRouting.requests[1].startRadiusMeters, 100.0);

      // Route updated from the relaxed retry!
      expect(nav.currentStep!.instruction, 'Continue on Relaxed Service Rd');
      final rerouteEventsA = diagnostics.events
          .where((e) => e.type == TrackingEventType.reroute)
          .toList();
      expect(rerouteEventsA.length, 2);
      expect(
        rerouteEventsA.any(
          (e) => e.isAccepted && (e.reason?.contains('Attempt 2') ?? false),
        ),
        isTrue,
      );
      expect(
        rerouteEventsA.any(
          (e) => e.isRejected && (e.reason?.contains('Attempt 1') ?? false),
        ),
        isTrue,
      );

      // Case B: After 30 s cooldown, go off-route again. Constrained attempt fails,
      // and relaxed retry returns a > 120° hook route -> hook route is discarded!
      diagnostics.clear();
      fakeRouting.requests.clear();
      const westHookPt = LatLng(33.68660, 73.04800);
      const riderOffRoutePt2 = LatLng(33.68660, 73.05100);
      fakeRouting.onGetRoute = ({
        required waypoints,
        requestAlternatives = true,
        startBearingDegrees,
        startBearingToleranceDegrees = 45.0,
        startRadiusMeters,
      }) async {
        if (startBearingDegrees != null) {
          throw Exception('NoSegment');
        }
        return const RouteResult(
          polyline: [riderOffRoutePt2, westHookPt, kEndPt],
          distanceMeters: 1800.0,
          durationSeconds: 180.0,
          steps: [
            RouteStep(
              maneuverType: 'depart',
              streetName: 'Hook Retry Spur',
              distanceMeters: 200.0,
              durationSeconds: 20.0,
              location: riderOffRoutePt2,
              instruction: 'Head out on Hook Retry Spur',
            ),
            RouteStep(
              maneuverType: 'arrive',
              streetName: 'Sector F-8',
              distanceMeters: 0.0,
              durationSeconds: 0.0,
              location: kEndPt,
              instruction: 'Arrive at destination',
            ),
          ],
        );
      };

      for (int i = 0; i < 3; i++) {
        fakeLocation.emitPosition(PositionData(
          latitude: riderOffRoutePt2.latitude,
          longitude: riderOffRoutePt2.longitude + (i * 0.0002),
          accuracy: 8.0,
          speed: 9.0,
          heading: 90.0,
          timestamp: t0.add(Duration(seconds: 50 + (i * 5))),
        ));
        await pumpEventQueue();
      }

      expect(fakeRouting.requests.length, 2);
      // Hook route from Attempt 2 was discarded, keeping 'Relaxed Service Rd'
      expect(nav.route!.steps.first.streetName, 'Relaxed Service Rd');
      final rerouteEventsB = diagnostics.events
          .where((e) => e.type == TrackingEventType.reroute)
          .toList();
      expect(rerouteEventsB.first.isRejected, isTrue);
      expect(rerouteEventsB.first.reason, contains('Attempt 2'));
      expect(rerouteEventsB.first.reason, contains('Hook/U-turn'));

      // Case C: Both constrained and relaxed attempts fail -> old route is kept, and 30 s cooldown applies
      diagnostics.clear();
      fakeRouting.requests.clear();
      fakeRouting.onGetRoute = ({
        required waypoints,
        requestAlternatives = true,
        startBearingDegrees,
        startBearingToleranceDegrees = 45.0,
        startRadiusMeters,
      }) async {
        throw Exception('NoSegment on both');
      };

      // At t0 + 95 s (>= 30 s after t0 + 60 s), triggers Attempt 1 + Attempt 2 (both fail)
      fakeLocation.emitPosition(PositionData(
        latitude: riderOffRoutePt2.latitude,
        longitude: riderOffRoutePt2.longitude + 0.0006,
        accuracy: 8.0,
        speed: 9.0,
        heading: 90.0,
        timestamp: t0.add(const Duration(seconds: 95)),
      ));
      await pumpEventQueue();

      expect(fakeRouting.requests.length, 2);
      expect(nav.route!.steps.first.streetName, 'Relaxed Service Rd');

      // Fix 10 s later (t0 + 105 s < 30 s cooldown) -> blocked by cooldown!
      fakeLocation.emitPosition(PositionData(
        latitude: riderOffRoutePt2.latitude,
        longitude: riderOffRoutePt2.longitude + 0.0008,
        accuracy: 8.0,
        speed: 9.0,
        heading: 90.0,
        timestamp: t0.add(const Duration(seconds: 105)),
      ));
      await pumpEventQueue();
      expect(fakeRouting.requests.length, 2);

      await fuelTracker.stopRide();
      nav.dispose();
    });
  });

  group('BATCH S4-3c-4: Stop the Odometer Losing Small Distances', () {
    late FakeLocationService fakeLocation;
    late FakeInProgressRideRepository fakeInProgressRepo;
    late ActiveBikeController bikeController;
    late FuelTrackerService fuelTracker;

    const double startOdo = 46360.0;
    const double baseLat = 33.6844;
    const double baseLon = 73.0479;
    // ~30 m of latitude per step.
    const double stepDeg = 30.0 / 111194.9;

    PositionData fix(int i) => PositionData(
          latitude: baseLat + i * stepDeg,
          longitude: baseLon,
          accuracy: 8.0,
          speed: 10.0,
          heading: 0.0,
          timestamp: DateTime.utc(2026, 6, 1, 12, 0, 0).add(Duration(seconds: 3 * i)),
        );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LocalStore.instance.resetForTesting();
      fakeInProgressRepo = FakeInProgressRideRepository();
      AppRepositories.resetWith(
        bikeRepository: _FakeBikeRepository(),
        rideReportRepository: FakeRideReportRepository(),
        inProgressRideRepository: fakeInProgressRepo,
      );
      SettingsController.instance.resetForTesting();
      bikeController = ActiveBikeController.instance;
      bikeController.resetForTesting();
      bikeController.addBike(
        const Bike(
          id: 'bike-s4-3c-4',
          make: 'Yamaha',
          modelName: 'Tenere 700',
          modelYear: 2024,
          odometerKm: 46360,
          preciseOdometerKm: startOdo,
          fuelLevelOdometerKm: startOdo,
          fuelTankCapacityLiters: 16.0,
          fuelAverageKmPerLiter: 20.0,
          fuelRemainingLiters: 10.0,
        ),
        setActive: true,
      );
      await bikeController.flush();
      fakeLocation = FakeLocationService(initialPosition: fix(0));
      fuelTracker = FuelTrackerService.instance;
      fuelTracker.resetForTesting();
      fuelTracker.setDependenciesForTesting(
        locationService: fakeLocation,
        bikeController: bikeController,
        notificationService: _FakeFuelNotificationService(),
        inProgressRideRepository: fakeInProgressRepo,
      );
    });

    tearDown(() {
      fuelTracker.resetForTesting();
      SettingsController.instance.resetForTesting();
    });

    testWidgets('1. 100 segments of 30 m add ~3.0 km, fuel drops accordingly', (tester) async {
      await fuelTracker.startRide(routeTitle: 'Small steps');
      final litersBefore = FuelEstimator.currentLiters(bikeController.activeBike!);
      fuelTracker.handlePositionUpdate(fix(0));
      for (var i = 1; i <= 100; i++) {
        fuelTracker.handlePositionUpdate(fix(i));
      }
      final bike = bikeController.activeBike!;
      expect(bike.preciseOdometerKm! - startOdo, closeTo(3.0, 0.01));
      expect(fuelTracker.rideDistanceKm, closeTo(3.0, 0.01));
      expect(bike.odometerKm, 46363);
      final litersAfter = FuelEstimator.currentLiters(bike);
      expect(litersBefore! - litersAfter!, closeTo(3.0 / 20.0, 0.001));
      await fuelTracker.stopRide();
    });

    testWidgets('2. Discard removes exactly the applied amount', (tester) async {
      await fuelTracker.startRide(routeTitle: 'Discard me');
      fuelTracker.handlePositionUpdate(fix(0));
      for (var i = 1; i <= 100; i++) {
        fuelTracker.handlePositionUpdate(fix(i));
      }
      expect(bikeController.activeBike!.preciseOdometerKm, greaterThan(startOdo));
      await fuelTracker.discardSavedRide();
      expect(bikeController.activeBike!.preciseOdometerKm, startOdo);
      expect(bikeController.activeBike!.odometerKm, 46360);
    });

    test('3. Whole-km odometer rounds correctly', () {
      expect(46363.4.round(), 46363);
      expect(46363.6.round(), 46364);
    });

    test('4. Bike JSON accepts old 1-decimal and new full-precision values', () {
      final base = const Bike(
        id: 'b',
        make: 'Y',
        modelName: 'T',
        modelYear: 2024,
        odometerKm: 46363,
      ).toJson();

      final oldJson = Map<String, dynamic>.from(base)
        ..['odometerKm'] = 46363
        ..['preciseOdometerKm'] = 46363.4;
      expect(Bike.fromJson(oldJson).preciseOdometerKm, 46363.4);

      final newJson = Map<String, dynamic>.from(base)
        ..['odometerKm'] = 46363
        ..['preciseOdometerKm'] = 46363.428571;
      final loaded = Bike.fromJson(newJson);
      expect(loaded.preciseOdometerKm, 46363.428571);
      expect(loaded.odometerKm, 46363);

      final roundTrip = Bike.fromJson(loaded.toJson());
      expect(roundTrip.preciseOdometerKm, 46363.428571);

      final noWhole = Map<String, dynamic>.from(base)
        ..remove('odometerKm')
        ..['preciseOdometerKm'] = 46363.6;
      expect(Bike.fromJson(noWhole).odometerKm, 46364);
    });
  });

  group('BATCH S4-3c-5: Reliable Reroute Heading from GPS Fixes (No Fake 0° Heading)', () {
    late FakeLocationService fakeLocation;
    late FakeInProgressRideRepository fakeInProgressRepo;
    late ActiveBikeController bikeController;
    late PostRideReportController reportController;
    late FuelTrackerService fuelTracker;
    late FakeRoutingService fakeRouting;
    late TrackingDiagnostics diagnostics;

    const kStart = LatLng(33.68440, 73.04790);
    const kTurn = LatLng(33.68440, 73.05868);
    const kDest = LatLng(33.69340, 73.05868);

    RouteResult buildBaseRoute() {
      final poly = <LatLng>[
        kStart,
        const LatLng(33.68440, 73.05329),
        kTurn,
        kDest,
      ];
      final cum = RouteProgress.computeCumulativeDistances(poly);
      return RouteResult(
        polyline: poly,
        distanceMeters: cum.last,
        durationSeconds: 200.0,
        steps: [
          RouteStep(
            maneuverType: 'depart',
            streetName: 'Margalla Ave',
            distanceMeters: cum[2],
            durationSeconds: 120.0,
            location: kStart,
            instruction: 'Head out on Margalla Ave',
          ),
          RouteStep(
            maneuverType: 'arrive',
            streetName: 'Destination Point',
            distanceMeters: cum.last - cum[2],
            durationSeconds: 80.0,
            location: kDest,
            instruction: 'Arrive at destination',
          ),
        ],
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LocalStore.instance.resetForTesting();

      fakeInProgressRepo = FakeInProgressRideRepository();
      AppRepositories.resetWith(
        bikeRepository: _FakeBikeRepository(),
        rideReportRepository: FakeRideReportRepository(),
        inProgressRideRepository: fakeInProgressRepo,
      );

      SettingsController.instance.resetForTesting();

      bikeController = ActiveBikeController.instance;
      bikeController.resetForTesting();

      reportController = PostRideReportController.instance;
      reportController.repository = AppRepositories.instance.rideReportRepository;
      reportController.reset();

      const testBike = Bike(
        id: 'bike-s4-3c-5',
        make: 'Honda',
        modelName: 'CB150F',
        modelYear: 2024,
        odometerKm: 3000,
        preciseOdometerKm: 3000.0,
        fuelLevelOdometerKm: 3000.0,
        fuelTankCapacityLiters: 13.0,
        fuelAverageKmPerLiter: 35.0,
        fuelRemainingLiters: 8.0,
      );
      bikeController.addBike(testBike, setActive: true);
      await bikeController.flush();

      fakeLocation = FakeLocationService(
        initialPosition: PositionData(
          latitude: kStart.latitude,
          longitude: kStart.longitude,
          accuracy: 8.0,
          speed: 0.0,
          timestamp: DateTime.utc(2026, 6, 1, 12, 0, 0),
        ),
      );
      fakeRouting = FakeRoutingService(cannedResult: buildBaseRoute());

      fuelTracker = FuelTrackerService.instance;
      fuelTracker.resetForTesting();
      fuelTracker.setDependenciesForTesting(
        locationService: fakeLocation,
        bikeController: bikeController,
        notificationService: _FakeFuelNotificationService(),
        inProgressRideRepository: fakeInProgressRepo,
      );

      diagnostics = TrackingDiagnostics.instance;
      diagnostics.clear();
    });

    tearDown(() {
      fuelTracker.resetForTesting();
      SettingsController.instance.resetForTesting();
      diagnostics.clear();
    });

    test('1. Heading is derived from last two good fixes >= 20 m apart and logged in TrackingDiagnostics', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();
      await nav.openRoutePreview(
        const PlaceSearchResult(
          name: 'Destination Point',
          displayName: 'Destination Point',
          location: kDest,
        ),
      );
      await nav.startNavigation();

      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);
      // Rider travels East at 8 m/s (> 2 m/s), off-route (> 50 m North of leg 1):
      // Fix 0 at (33.68550, 73.05000)
      // Fix 1 at (33.68550, 73.05030) -> ~27.8 m from Fix 0 (>= 20 m apart)
      // Fix 2 at (33.68550, 73.05060) -> ~27.8 m from Fix 1 (>= 20 m apart)
      // 3 consecutive off-route fixes over 10 s (> 8 s) triggers reroute!
      for (int i = 0; i < 3; i++) {
        fakeLocation.emitPosition(PositionData(
          latitude: 33.68550,
          longitude: 73.05000 + (i * 0.00030),
          accuracy: 8.0,
          speed: 8.0,
          // Notice: phone heading is null or absent!
          heading: null,
          timestamp: t0.add(Duration(seconds: 5 + (i * 5))),
        ));
        await pumpEventQueue();
      }

      // Verify OSRM bearing was derived from fixes (bearing East = ~90.0°)
      expect(fakeRouting.requests.isNotEmpty, isTrue);
      final lastReq = fakeRouting.requests.last;
      expect(lastReq.startBearingDegrees, isNotNull);
      expect(lastReq.startBearingDegrees, closeTo(90.0, 1.0));
      expect(lastReq.startRadiusMeters, 40.0);

      // Verify TrackingDiagnostics REROUTE event records heading and origin
      final rerouteEvent = diagnostics.events
          .firstWhere((e) => e.type == TrackingEventType.reroute);
      expect(rerouteEvent.heading, isNotNull);
      expect(rerouteEvent.heading, closeTo(90.0, 1.0));
      expect(rerouteEvent.headingSource, 'from last good fixes');
      expect(rerouteEvent.message, contains('90.0° (from last good fixes)'));

      await fuelTracker.stopRide();
      nav.dispose();
    });

    test('2. When heading is unreliable (speed < 2 m/s or fixes < 20 m apart), sends NO bearing to OSRM and skips hook check', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();
      await nav.openRoutePreview(
        const PlaceSearchResult(
          name: 'Destination Point',
          displayName: 'Destination Point',
          location: kDest,
        ),
      );
      await nav.startNavigation();

      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);

      // Configure fake routing to return a route that heads West (270°), opposite of previous route,
      // which would normally trigger the hook check (> 120°) IF heading were reliable.
      const offRouteOrigin = LatLng(33.68550, 73.05000);
      const hookWestPt = LatLng(33.68550, 73.04800);
      fakeRouting.cannedResult = const RouteResult(
        polyline: [offRouteOrigin, hookWestPt, kDest],
        distanceMeters: 1400.0,
        durationSeconds: 150.0,
        steps: [
          RouteStep(
            maneuverType: 'depart',
            streetName: 'Westbound Lane',
            distanceMeters: 200.0,
            durationSeconds: 30.0,
            location: offRouteOrigin,
            instruction: 'Head out on Westbound Lane',
          ),
          RouteStep(
            maneuverType: 'arrive',
            streetName: 'Destination Point',
            distanceMeters: 0.0,
            durationSeconds: 0.0,
            location: kDest,
            instruction: 'Arrive at destination',
          ),
        ],
      );

      // Subcase A: Speed is 1.2 m/s (< 2.0 m/s), even though fixes are 28 m apart
      for (int i = 0; i < 3; i++) {
        fakeLocation.emitPosition(PositionData(
          latitude: offRouteOrigin.latitude,
          longitude: offRouteOrigin.longitude + (i * 0.00030),
          accuracy: 8.0,
          speed: 1.2, // < 2.0 m/s minimum speed
          heading: null,
          timestamp: t0.add(Duration(seconds: 5 + (i * 5))),
        ));
        await pumpEventQueue();
      }

      // Verify: NO bearing was passed to OSRM (radius only)
      expect(fakeRouting.requests.isNotEmpty, isTrue);
      expect(fakeRouting.requests.last.startBearingDegrees, isNull);
      expect(fakeRouting.requests.last.startRadiusMeters, 40.0);

      // Verify: Hook check was SKIPPED, so the route was NOT discarded as a hook turn!
      final rerouteEvent = diagnostics.events
          .firstWhere((e) => e.type == TrackingEventType.reroute);
      expect(rerouteEvent.isAccepted, isTrue);
      expect(rerouteEvent.heading, isNull);
      expect(rerouteEvent.headingSource, 'none');
      expect(rerouteEvent.message, contains('Heading: none'));

      await fuelTracker.stopRide();
      nav.dispose();
    });

    test('3. When good fixes are < 20 m apart, sends NO bearing to OSRM and skips hook check', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();
      await nav.openRoutePreview(
        const PlaceSearchResult(
          name: 'Destination Point',
          displayName: 'Destination Point',
          location: kDest,
        ),
      );
      await nav.startNavigation();

      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);

      // Configure fake routing to return a westbound hook route
      const offRouteOrigin = LatLng(33.68550, 73.05000);
      const hookWestPt = LatLng(33.68550, 73.04800);
      fakeRouting.cannedResult = const RouteResult(
        polyline: [offRouteOrigin, hookWestPt, kDest],
        distanceMeters: 1400.0,
        durationSeconds: 150.0,
        steps: [
          RouteStep(
            maneuverType: 'depart',
            streetName: 'Westbound Lane',
            distanceMeters: 200.0,
            durationSeconds: 30.0,
            location: offRouteOrigin,
            instruction: 'Head out on Westbound Lane',
          ),
          RouteStep(
            maneuverType: 'arrive',
            streetName: 'Destination Point',
            distanceMeters: 0.0,
            durationSeconds: 0.0,
            location: kDest,
            instruction: 'Arrive at destination',
          ),
        ],
      );

      // Emit 3 off-route fixes that are only ~3.7 m apart (total span ~7.4 m < 20 m),
      // with speed 5.0 m/s (>= 2.0 m/s).
      for (int i = 0; i < 3; i++) {
        fakeLocation.emitPosition(PositionData(
          latitude: offRouteOrigin.latitude,
          longitude: offRouteOrigin.longitude + (i * 0.00004), // ~3.7 m apart
          accuracy: 8.0,
          speed: 5.0, // >= 2.0 m/s, but fixes < 20 m apart
          heading: null,
          timestamp: t0.add(Duration(seconds: 5 + (i * 5))),
        ));
        await pumpEventQueue();
      }

      // Verify: NO bearing was passed to OSRM (radius only)
      expect(fakeRouting.requests.isNotEmpty, isTrue);
      expect(fakeRouting.requests.last.startBearingDegrees, isNull);
      expect(fakeRouting.requests.last.startRadiusMeters, 40.0);

      // Verify: Hook check was SKIPPED, so route was accepted
      final rerouteEvent = diagnostics.events
          .firstWhere((e) => e.type == TrackingEventType.reroute);
      expect(rerouteEvent.isAccepted, isTrue);
      expect(rerouteEvent.heading, isNull);
      expect(rerouteEvent.headingSource, 'none');

      await fuelTracker.stopRide();
      nav.dispose();
    });

    test('4. A valid reroute going South-East is accepted when rider is heading South-East without using fake 0° heading', () async {
      final nav = NavigationController(
        locationService: fakeLocation,
        bikeController: bikeController,
        routingService: fakeRouting,
      );
      await nav.initialize();
      await nav.openRoutePreview(
        const PlaceSearchResult(
          name: 'Destination Point',
          displayName: 'Destination Point',
          location: kDest,
        ),
      );
      await nav.startNavigation();

      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);

      // Rider is moving South-East:
      // lat is decreasing (-0.00020 ≈ -22 m), lon is increasing (+0.00025 ≈ +23 m)
      // Distance per step ≈ 32 m (>= 20 m apart).
      // Bearing from (33.68600, 73.05000) to (33.68580, 73.05025) is ~136° (South-East).
      const seRouteStart = LatLng(33.68560, 73.05050);
      const seRouteMid = LatLng(33.68300, 73.05350); // also South-East (~136°)
      fakeRouting.cannedResult = const RouteResult(
        polyline: [seRouteStart, seRouteMid, kDest],
        distanceMeters: 2000.0,
        durationSeconds: 200.0,
        steps: [
          RouteStep(
            maneuverType: 'depart',
            streetName: 'South East Expressway',
            distanceMeters: 800.0,
            durationSeconds: 80.0,
            location: seRouteStart,
            instruction: 'Head out on South East Expressway',
          ),
          RouteStep(
            maneuverType: 'arrive',
            streetName: 'Destination Point',
            distanceMeters: 0.0,
            durationSeconds: 0.0,
            location: kDest,
            instruction: 'Arrive at destination',
          ),
        ],
      );

      // Emit 3 off-route fixes moving South-East at 7 m/s (>= 2 m/s).
      // Note: phone heading is 0.0 (the fake North heading phones often emit!).
      for (int i = 0; i < 3; i++) {
        fakeLocation.emitPosition(PositionData(
          latitude: 33.68600 - (i * 0.00020),
          longitude: 73.05000 + (i * 0.00025),
          accuracy: 8.0,
          speed: 7.0,
          heading: 0.0, // Phone reports fake 0.0 (North), which MUST be ignored!
          timestamp: t0.add(Duration(seconds: 5 + (i * 5))),
        ));
        await pumpEventQueue();
      }

      // Verify startBearing passed to OSRM is ~136° (South-East), NOT 0.0 (North)!
      expect(fakeRouting.requests.isNotEmpty, isTrue);
      final req = fakeRouting.requests.last;
      expect(req.startBearingDegrees, isNotNull);
      expect(req.startBearingDegrees, closeTo(136.0, 3.0));

      // Under the old code, if 0.0 was used, this 136° route would be discarded (> 120° deviation).
      // Under S4-3c-5, heading is ~136° from fixes, deviation is ~0°, so reroute is ACCEPTED!
      final rerouteEvent = diagnostics.events
          .firstWhere((e) => e.type == TrackingEventType.reroute);
      expect(rerouteEvent.isAccepted, isTrue);
      expect(rerouteEvent.heading, closeTo(136.0, 3.0));
      expect(rerouteEvent.headingSource, 'from last good fixes');
      expect(nav.currentStep!.instruction, 'Continue on South East Expressway');

      await fuelTracker.stopRide();
      nav.dispose();
    });
  });
}

