import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/data/bike_repository.dart';
import 'package:camp/core/data/in_progress_ride_model.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/presentation/screens/home_screen.dart';
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
import 'package:camp/features/navigation/presentation/widgets/nav_arrived_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_in_progress_ride_repository.dart';
import 'helpers/fake_location_service.dart';
import 'helpers/fake_ride_report_repository.dart';
import 'helpers/fake_routing_service.dart';

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
      expect(nav.previousPosition?.latitude, 33.68440);

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

      // Stationary fix 4 s after the good speed (> 3 s hold window) drops to 0
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68476,
        longitude: 73.04790,
        accuracy: 12.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 8)),
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

      // Move ~8.9 m north in 3 s (dist < 15.0 m accuracy) with reported speed 0.0
      fakeLocation.emitPosition(PositionData(
        latitude: 33.68448,
        longitude: 73.04790,
        accuracy: 15.0,
        speed: 0.0,
        timestamp: t0.add(const Duration(seconds: 3)),
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
}

