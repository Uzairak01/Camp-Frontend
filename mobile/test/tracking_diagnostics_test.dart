import 'package:camp/app/routes.dart';
import 'package:camp/app/theme/app_colors.dart';
import 'package:camp/features/dashboard/presentation/screens/profile_screen.dart';
import 'package:camp/features/dashboard/presentation/widgets/app_drawer_widget.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/garage/services/fuel_tracker_service.dart';
import 'package:camp/features/garage/services/tracking_diagnostics.dart';
import 'package:camp/features/navigation/domain/location_service.dart';
import 'package:camp/features/settings/presentation/screens/settings_screen.dart';
import 'package:camp/features/settings/presentation/screens/tracking_diagnostics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_in_progress_ride_repository.dart';
import 'helpers/fake_location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLocationService fakeLocationService;

  const testBike = Bike(
    id: 'bike-diag-1',
    make: 'BMW',
    modelName: 'R 1250 GS',
    modelYear: 2022,
    plateNumber: 'DIAG-123',
    fuelTankCapacityLiters: 20.0,
    fuelRemainingLiters: 15.0,
    fuelAverageKmPerLiter: 20.0,
    odometerKm: 10000,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeLocationService = FakeLocationService();
    ActiveBikeController.instance.resetForTesting();
    ActiveBikeController.instance.addBike(testBike, setActive: true);

    FuelTrackerService.instance.resetForTesting();
    FuelTrackerService.instance.setDependenciesForTesting(
      locationService: fakeLocationService,
      bikeController: ActiveBikeController.instance,
      inProgressRideRepository: FakeInProgressRideRepository(),
    );
    TrackingDiagnostics.instance.clear();
  });

  tearDown(() {
    TrackingDiagnostics.instance.clear();
    FuelTrackerService.instance.resetForTesting();
  });

  group('TrackingDiagnostics Unit Tests', () {
    test('enforces strict log cap at 500 events and drops oldest', () {
      final diag = TrackingDiagnostics.instance;
      final baseTime = DateTime(2026, 11, 1, 12, 0, 0);

      // Record 550 events
      for (int i = 0; i < 550; i++) {
        diag.recordFix(
          timestamp: baseTime.add(Duration(seconds: i)),
          latitude: 31.52040,
          longitude: 74.35870,
          accuracy: 10.0,
          speed: 10.0,
          accepted: true,
          reason: 'Fix #$i',
          segmentMeters: 10.0,
        );
      }

      // Assert cap at 500
      expect(diag.events.length, equals(500));

      // The newest event should be index 0
      expect(diag.events.first.reason, equals('Fix #549'));

      // The oldest retained event should be Fix #50 (events 0..49 dropped)
      expect(diag.events.last.reason, equals('Fix #50'));
    });

    test('records accepted vs rejected fixes with exact filter reasons', () async {
      final diag = TrackingDiagnostics.instance;
      final fuelTracker = FuelTrackerService.instance;
      final t0 = DateTime(2026, 11, 1, 14, 0, 0);

      // Fix before riding starts
      fuelTracker.handlePositionUpdate(PositionData(
        latitude: 31.52040,
        longitude: 74.35870,
        timestamp: t0,
        accuracy: 15.0,
        speed: 10.0,
      ));

      expect(diag.rejectedCount, equals(1));
      expect(diag.events.first.reason,
          contains('Not navigating (ride not started / stopped)'));
      expect(diag.events.first.isRejected, isTrue);

      // Start ride
      await fuelTracker.startRide();
      expect(diag.trackerState, equals('started'));

      // Fix with excessive inaccuracy (>30m)
      fuelTracker.handlePositionUpdate(PositionData(
        latitude: 31.52040,
        longitude: 74.35870,
        timestamp: t0.add(const Duration(seconds: 1)),
        accuracy: 35.0,
        speed: 10.0,
      ));

      expect(diag.rejectedCount, equals(1)); // started reset counters
      expect(diag.events.first.reason,
          contains('Accuracy filter (> 30 m: 35.0 m)'));

      // Baseline fix (first valid fix)
      fuelTracker.handlePositionUpdate(PositionData(
        latitude: 31.52000,
        longitude: 74.35800,
        timestamp: t0.add(const Duration(seconds: 2)),
        accuracy: 12.0,
        speed: 8.0,
      ));

      expect(diag.acceptedCount, equals(1));
      expect(diag.events.first.isAccepted, isTrue);
      expect(diag.events.first.reason, contains('Baseline fix'));

      // Tiny movement (< 5m)
      fuelTracker.handlePositionUpdate(PositionData(
        latitude: 31.52001,
        longitude: 74.35801,
        timestamp: t0.add(const Duration(seconds: 3)),
        accuracy: 10.0,
        speed: 5.0,
      ));

      expect(diag.rejectedCount, equals(2));
      expect(diag.events.first.reason, contains('Minimum distance filter (< 5 m'));

      // Valid movement: ~22m at 11 m/s
      fuelTracker.handlePositionUpdate(PositionData(
        latitude: 31.52020,
        longitude: 74.35800,
        timestamp: t0.add(const Duration(seconds: 5)),
        accuracy: 8.0,
        speed: 11.0,
      ));

      expect(diag.acceptedCount, equals(2));
      expect(diag.events.first.isAccepted, isTrue);
      expect(diag.events.first.reason, contains('Accepted (+'));
      expect(diag.accumulatedDistanceMeters, greaterThan(15.0));

      // Implausible jump: 1 degree lat (~111 km) in 1 second
      fuelTracker.handlePositionUpdate(PositionData(
        latitude: 32.52020,
        longitude: 74.35800,
        timestamp: t0.add(const Duration(seconds: 6)),
        accuracy: 8.0,
        speed: 15.0,
      ));

      expect(diag.rejectedCount, equals(3));
      expect(diag.events.first.reason, contains('Jump filter'));
    });

    test('highlights gaps exceeding 30 seconds with dedicated gap event', () {
      final diag = TrackingDiagnostics.instance;
      final t0 = DateTime(2026, 11, 1, 15, 0, 0);

      // First fix
      diag.recordFix(
        timestamp: t0,
        latitude: 31.52040,
        longitude: 74.35870,
        accuracy: 10.0,
        speed: 8.0,
        accepted: true,
        reason: 'Baseline',
      );

      // Second fix 45 seconds later (e.g. screen locked)
      diag.recordFix(
        timestamp: t0.add(const Duration(seconds: 45)),
        latitude: 31.52200,
        longitude: 74.35870,
        accuracy: 10.0,
        speed: 10.0,
        accepted: true,
        reason: 'Accepted movement',
        segmentMeters: 50.0,
      );

      // In diag.events (newest first):
      // index 0 is fix #2
      // index 1 is gap event (45s)
      // index 2 is fix #1
      expect(diag.events.length, equals(3));
      final gapEvent = diag.events[1];
      expect(gapEvent.isGap, isTrue);
      expect(gapEvent.gapDuration?.inSeconds, equals(45));
      expect(gapEvent.message, contains('45s elapsed since previous fix'));
    });

    test('plain text log format contains all required metrics and thresholds', () {
      final diag = TrackingDiagnostics.instance;
      final t0 = DateTime(2026, 11, 1, 16, 0, 0);

      diag.recordTrackerState('started');
      diag.recordFix(
        timestamp: t0,
        latitude: 31.520401,
        longitude: 74.358701,
        accuracy: 12.34,
        speed: 9.87,
        accepted: true,
        reason: 'Baseline fix',
        segmentMeters: 0.0,
      );
      diag.recordFix(
        timestamp: t0.add(const Duration(seconds: 40)),
        latitude: 31.520551,
        longitude: 74.358801,
        accuracy: 38.0,
        speed: 10.0,
        accepted: false,
        reason: 'Accuracy filter (> 30 m: 38.0 m)',
      );

      final log = diag.formatLogAsPlainText(
        maxAccuracyMeters: FuelTrackerService.maxAccuracyMeters,
        minDistanceMeters: FuelTrackerService.minDistanceMeters,
        minSpeedMps: FuelTrackerService.minSpeedMps,
        maxSpeedMps: FuelTrackerService.maxSpeedMps,
      );

      expect(log, contains('=== CAMP TRACKING DIAGNOSTICS LOG ==='));
      expect(log, contains('Tracker State: started'));
      expect(log, contains('Max Accuracy: 30.0 m'));
      expect(log, contains('Min Distance: 5.0 m'));
      expect(log, contains('Min Speed: 1.0 m/s'));
      expect(log, contains('Max Speed: 55.56 m/s'));
      expect(log, contains('Lat: 31.52040, Lng: 74.35870')); // 5 decimal places
      expect(log, contains('[ACCEPTED]'));
      expect(log, contains('[REJECTED]'));
      expect(log, contains('[GAP] ⚠️ 40s elapsed'));
    });

    test('formatLogAsPlainText with oldestFirst true contains all events and starts with oldest', () {
      final diag = TrackingDiagnostics.instance;
      final t0 = DateTime(2026, 11, 1, 10, 0, 0);

      // Record 120 events to verify complete export with no arbitrary size capping
      for (int i = 0; i < 120; i++) {
        diag.recordFix(
          timestamp: t0.add(Duration(seconds: i * 5)),
          latitude: 31.52000 + (i * 0.0001),
          longitude: 74.35000 + (i * 0.0001),
          accuracy: 10.0,
          speed: 8.0,
          accepted: true,
          reason: 'Waypoint #$i',
          segmentMeters: 10.0,
        );
      }

      expect(diag.events.length, equals(120));

      // Test default/newest-first (for Copy log)
      final newestFirstLog = diag.formatLogAsPlainText(oldestFirst: false);
      expect(newestFirstLog, contains('=== EVENTS (120 of 500, newest first) ==='));
      final newestFirstIdxOldest = newestFirstLog.indexOf('Waypoint #0');
      final newestFirstIdxNewest = newestFirstLog.indexOf('Waypoint #119');
      expect(newestFirstIdxNewest, isNot(-1));
      expect(newestFirstIdxOldest, isNot(-1));
      // In newest-first, Waypoint #119 appears before Waypoint #0
      expect(newestFirstIdxNewest, lessThan(newestFirstIdxOldest));

      // Test oldest-first export (for file export)
      final oldestFirstLog = diag.formatLogAsPlainText(oldestFirst: true);
      expect(oldestFirstLog, contains('=== EVENTS (120 of 500, oldest first) ==='));

      // Check all 120 events are present (not capped by any string/count limit)
      for (int i = 0; i < 120; i++) {
        expect(oldestFirstLog, contains('Waypoint #$i'));
      }

      final oldestFirstIdxOldest = oldestFirstLog.indexOf('Waypoint #0');
      final oldestFirstIdxNewest = oldestFirstLog.indexOf('Waypoint #119');
      // In oldest-first, Waypoint #0 (the oldest event) appears before Waypoint #119 (the newest event)
      expect(oldestFirstIdxOldest, lessThan(oldestFirstIdxNewest));
    });
  });

  group('TrackingDiagnostics Widget & Visibility Tests', () {
    testWidgets('settings screen hides diagnostics row when isDebugMode is false',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(isDebugMode: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tracking diagnostics (debug)'), findsNothing);
      expect(find.byKey(const ValueKey('settings_tracking_diagnostics_row')),
          findsNothing);
    });

    testWidgets('settings screen shows diagnostics row when isDebugMode is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(isDebugMode: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tracking diagnostics (debug)'), findsOneWidget);
      expect(find.byKey(const ValueKey('settings_tracking_diagnostics_row')),
          findsOneWidget);
    });

    testWidgets('tracking diagnostics screen hides panel when isDebugMode is false',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrackingDiagnosticsScreen(isDebugMode: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TRACKING DIAGNOSTICS'), findsNothing);
      expect(find.text('Tracking diagnostics is only available in debug builds.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('tracking_diag_copy_button')),
          findsNothing);
    });

    testWidgets(
        'tracking diagnostics screen renders telemetry, actions, and red gap styling when isDebugMode is true',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final diag = TrackingDiagnostics.instance;
      final t0 = DateTime(2026, 11, 1, 17, 0, 0);

      diag.recordTrackerState('started');
      diag.recordFix(
        timestamp: t0,
        latitude: 31.52040,
        longitude: 74.35870,
        accuracy: 10.0,
        speed: 5.0,
        accepted: true,
        reason: 'Accepted movement',
        segmentMeters: 25.0,
      );
      // Trigger gap
      diag.recordFix(
        timestamp: t0.add(const Duration(seconds: 40)),
        latitude: 31.52060,
        longitude: 74.35890,
        accuracy: 35.0,
        speed: 5.0,
        accepted: false,
        reason: 'Accuracy filter (> 30 m: 35.0 m)',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrackingDiagnosticsScreen(isDebugMode: true),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and thresholds
      expect(find.text('TRACKING DIAGNOSTICS'), findsOneWidget);
      expect(find.text('DEVICE & SERVICE STATUS'), findsOneWidget);
      expect(find.text('LIVE TRACKER TELEMETRY'), findsOneWidget);
      expect(find.text('ACTIVE TRACKER THRESHOLDS'), findsOneWidget);

      // Verify buttons
      expect(find.byKey(const ValueKey('tracking_diag_copy_button')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('tracking_diag_share_file_button')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('tracking_diag_clear_button')),
          findsOneWidget);

      // Verify events rendered
      expect(find.text('ACCEPTED'), findsOneWidget);
      expect(find.text('REJECTED'), findsOneWidget);
      expect(find.text('⚠️ GAP: 40s WITHOUT FIXES'), findsOneWidget);

      // Verify red styling on gap container
      final gapContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration) {
          final border = dec.border;
          if (border is Border) {
            return border.top.color == AppColors.alertRed;
          }
        }
        return false;
      });
      expect(gapContainers, isNotEmpty);

      // Tap clear button
      await tester.tap(find.byKey(const ValueKey('tracking_diag_clear_button')));
      await tester.pumpAndSettle();

      expect(diag.events, isEmpty);
      expect(find.text('No tracking events recorded yet.'), findsOneWidget);
    });

    testWidgets(
        'opens Settings via route CampRoutes.settings in debug mode and finds diagnostics row',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed(CampRoutes.settings),
                      child: const Text('Go to Settings'),
                    ),
                  ),
                ),
            CampRoutes.settings: (context) => const SettingsScreen(),
            CampRoutes.trackingDiagnostics: (context) =>
                const TrackingDiagnosticsScreen(),
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go to Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Tracking diagnostics (debug)'), findsOneWidget);
      expect(find.byKey(const ValueKey('settings_tracking_diagnostics_row')),
          findsOneWidget);

      // Verify tapping it opens Tracking Diagnostics screen via CampRoutes.trackingDiagnostics
      await tester.tap(find.byKey(const ValueKey('settings_tracking_diagnostics_row')));
      await tester.pumpAndSettle();

      expect(find.text('TRACKING DIAGNOSTICS'), findsOneWidget);
    });

    testWidgets(
        'opens Settings from AppDrawerWidget in debug mode and finds diagnostics row',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (context) => const Scaffold(
                  drawer: AppDrawerWidget(),
                  body: Center(child: Text('Home')),
                ),
            CampRoutes.settings: (context) => const SettingsScreen(),
            CampRoutes.trackingDiagnostics: (context) =>
                const TrackingDiagnosticsScreen(),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Tap Settings in drawer
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Tracking diagnostics (debug)'), findsOneWidget);
      expect(find.byKey(const ValueKey('settings_tracking_diagnostics_row')),
          findsOneWidget);
    });

    testWidgets(
        'Profile tab shows diagnostics row and navigates to Settings',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (context) => const ProfileScreen(),
            CampRoutes.settings: (context) => const SettingsScreen(),
            CampRoutes.trackingDiagnostics: (context) =>
                const TrackingDiagnosticsScreen(),
          },
        ),
      );
      await tester.pumpAndSettle();

      // In Profile tab's SETTINGS section:
      expect(find.text('Tracking diagnostics (debug)'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_tracking_diagnostics_row')),
          findsOneWidget);

      // Tapping Help & Support from Profile tab opens SettingsScreen with diagnostics row
      await tester.tap(find.text('Help & Support'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('settings_tracking_diagnostics_row')),
          findsOneWidget);
    });

    testWidgets(
        'tracking diagnostics screen renders Share log as file button and does not overflow on 360px screen',
        (tester) async {
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: TrackingDiagnosticsScreen(isDebugMode: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('tracking_diag_copy_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('tracking_diag_share_file_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('tracking_diag_clear_button')), findsOneWidget);
      expect(find.text('Share log as file'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
