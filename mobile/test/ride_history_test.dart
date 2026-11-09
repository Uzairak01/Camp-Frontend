import 'package:camp/features/dashboard/controllers/profile_controller.dart';
import 'package:camp/features/dashboard/domain/profile_stats.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/controllers/post_ride_report_controller.dart';
import 'package:camp/features/maintenance/domain/post_ride_report.dart';
import 'package:camp/features/ride_history/presentation/screens/ride_history_screen.dart';
import 'package:camp/features/ride_history/presentation/widgets/expedition_card_widget.dart';
import 'package:camp/features/ride_history/presentation/widgets/season_summary_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_ride_report_repository.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());
    ActiveBikeController.instance.resetForTesting();
    ProfileController.instance.resetForTesting();
  });

  tearDown(() {
    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());
    ActiveBikeController.instance.resetForTesting();
    ProfileController.instance.resetForTesting();
  });

  testWidgets('1. Summary totals come from saved rides',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Active bike with fuel average 23.5 km/L
    const bike = Bike(
      id: 'bike-bmw-1250',
      make: 'BMW',
      modelName: 'R 1250 GS',
      modelYear: 2024,
      odometerKm: 14820,
      fuelAverageKmPerLiter: 23.5,
    );
    ActiveBikeController.instance.addBike(bike);
    ActiveBikeController.instance.setActiveBike('bike-bmw-1250');

    // Add 2 real saved rides
    PostRideReportController.instance.addReport(
      PostRideReport(
        id: 'real-ride-1',
        bikeId: 'bike-bmw-1250',
        date: DateTime(2026, 10, 20),
        distanceKm: 120.0,
        durationHours: 2.5,
        terrainTags: const ['Highway'],
        notes: 'North highway transit',
      ),
    );
    PostRideReportController.instance.addReport(
      PostRideReport(
        id: 'real-ride-2',
        bikeId: 'bike-bmw-1250',
        date: DateTime(2026, 10, 22),
        distanceKm: 80.0,
        durationHours: 1.5,
        terrainTags: const ['Off-road'],
        notes: 'Gravel track testing',
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: RideHistoryScreen()));
    await tester.pump();

    // Verify Title "Your rides"
    expect(find.text('Your rides'), findsWidgets);

    // Verify total distance (120 + 80 = 200 KM)
    expect(find.text('200'), findsOneWidget);
    expect(find.text('KM'), findsWidgets);

    // Verify rides count (2)
    expect(find.text('2'), findsWidgets);

    // Verify saddle time (2.5 + 1.5 = 4 HRS)
    expect(find.text('4'), findsOneWidget);
    expect(find.text('HRS'), findsOneWidget);

    // Verify active bike fuel average labelled "Bike average"
    expect(find.text('Bike average'), findsOneWidget);
    expect(find.text('23.5'), findsOneWidget);
  });

  testWidgets('Summary card hides saddle time when no durations entered',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Ride with no duration entered
    PostRideReportController.instance.addReport(
      PostRideReport(
        id: 'no-dur-ride',
        bikeId: 'bike-1',
        date: DateTime(2026, 10, 20),
        distanceKm: 50.0,
        terrainTags: const ['City'],
        durationHours: null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SeasonSummaryCardWidget())),
    );
    await tester.pump();

    expect(find.text('Your rides'), findsOneWidget);
    expect(find.text('Saddle time'), findsNothing);
  });

  testWidgets('Summary card shows empty state when no rides exist',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SeasonSummaryCardWidget())),
    );
    await tester.pump();

    expect(find.text('Your rides'), findsOneWidget);
    expect(find.text('No rides logged yet'), findsOneWidget);
  });

  testWidgets('2. Fake texts are completely gone from Ride History screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    PostRideReportController.instance.addReport(
      PostRideReport(
        id: 'real-ride-1',
        bikeId: 'bike-1',
        date: DateTime(2026, 10, 20),
        distanceKm: 75.0,
        terrainTags: const ['City'],
        notes: 'Real ride notes',
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: RideHistoryScreen()));
    await tester.pump();

    // Summary fake texts
    expect(find.text('SEASON 2024 SUMMARY'), findsNothing);
    expect(find.text('BMW GS #441 / KTM 890'), findsNothing);
    expect(find.text('BMW GS #441 • KTM 890'), findsNothing);
    expect(find.text('100% Synced'), findsNothing);
    expect(find.text('TOTAL ELEV'), findsNothing);
    expect(find.text('+142.5k'), findsNothing);
    expect(find.text('4.8 L/100km'), findsNothing);

    // Filter chip fake texts
    expect(find.text('Passes'), findsNothing);
    expect(find.text('Rally Tracks'), findsNothing);
    expect(find.byIcon(Icons.near_me_rounded), findsNothing);

    // Latest ride hero card fake texts
    expect(find.text('LATEST EXPEDITION'), findsNothing);
    expect(find.text('Active Fleet'), findsNothing);
    expect(find.text('Replay Track'), findsNothing);
    expect(find.text('Waypoint Log'), findsNothing);
    expect(find.text('Basecamp'), findsNothing);
    expect(find.text('Summit'), findsNothing);
    expect(find.text('Waypoint'), findsNothing);
    expect(find.text('ELEVATION & INCLINE PROFILE'), findsNothing);
    expect(find.text('Demo data'), findsNothing);

    // Top right download icon
    expect(find.byIcon(Icons.download_rounded), findsNothing);
  });

  testWidgets('3. Terrain chip counts match saved rides and filter accurately',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Add 2 Highway rides and 1 Off-road ride (no Mountain, no City)
    PostRideReportController.instance.addReport(
      PostRideReport(
        id: 'r-hw-1',
        bikeId: 'bike-1',
        date: DateTime(2026, 10, 1),
        distanceKm: 100.0,
        terrainTags: const ['Highway'],
        notes: 'Highway 1',
      ),
    );
    PostRideReportController.instance.addReport(
      PostRideReport(
        id: 'r-hw-2',
        bikeId: 'bike-1',
        date: DateTime(2026, 10, 2),
        distanceKm: 120.0,
        terrainTags: const ['Highway'],
        notes: 'Highway 2',
      ),
    );
    PostRideReportController.instance.addReport(
      PostRideReport(
        id: 'r-off-1',
        bikeId: 'bike-1',
        date: DateTime(2026, 10, 3),
        distanceKm: 60.0,
        terrainTags: const ['Off-road'],
        notes: 'Off-road 1',
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: RideHistoryScreen()));
    await tester.pump();

    // All rides chip count
    expect(find.text('All rides'), findsOneWidget);
    expect(find.text('3'), findsWidgets);

    // Highway chip count (2)
    expect(find.text('Highway'), findsWidgets);
    expect(find.text('2'), findsWidgets);

    // Off-road chip count (1)
    expect(find.text('Off-road'), findsWidgets);
    expect(find.text('1'), findsWidgets);

    // Terrains with 0 rides do NOT have chips
    expect(find.widgetWithText(GestureDetector, 'Mountain'), findsNothing);
    expect(find.widgetWithText(GestureDetector, 'City'), findsNothing);

    // Tapping Off-road filters the past list to only Off-road 1
    await tester.tap(find.widgetWithText(GestureDetector, 'Off-road').first);
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(ExpeditionCardWidget),
        matching: find.text('Off-road 1'),
      ),
      findsOneWidget,
    );
    expect(find.text('Highway 1'), findsNothing);
    expect(find.text('Highway 2'), findsNothing);
  });

  testWidgets('4. Header count equals "All rides" count',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Case A: 0 rides
    await tester.pumpWidget(const MaterialApp(home: RideHistoryScreen()));
    await tester.pump();

    expect(find.text('0 Logged'), findsOneWidget);
    expect(find.text('All rides'), findsOneWidget);
    expect(find.text('0'), findsWidgets);

    // Case B: 3 rides
    for (int i = 0; i < 3; i++) {
      PostRideReportController.instance.addReport(
        PostRideReport(
          id: 'test-ride-$i',
          bikeId: 'bike-1',
          date: DateTime.now().subtract(Duration(days: i)),
          distanceKm: 50.0,
          terrainTags: const ['City'],
        ),
      );
    }

    await tester.pump();

    expect(find.text('3 Logged'), findsOneWidget);
    expect(find.text('All rides'), findsOneWidget);
  });

  testWidgets('5. Delete ride with undo updates totals and Profile stats',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final r1 = PostRideReport(
      id: 'r-delete-1',
      bikeId: 'bike-1',
      date: DateTime(2026, 10, 10),
      distanceKm: 120.0,
      terrainTags: const ['Highway'],
      notes: 'Trip to northern pass',
    );
    final r2 = PostRideReport(
      id: 'r-delete-2',
      bikeId: 'bike-1',
      date: DateTime(2026, 10, 12),
      distanceKm: 80.0,
      terrainTags: const ['Off-road'],
      notes: 'Trail loop',
    );
    PostRideReportController.instance.addReport(r1);
    PostRideReportController.instance.addReport(r2);

    expect(
        ProfileStats(PostRideReportController.instance.reports).ridesCount, 2);
    expect(
        ProfileStats(PostRideReportController.instance.reports)
            .lifetimeDistanceKm,
        200.0);

    await tester.pumpWidget(const MaterialApp(home: RideHistoryScreen()));
    await tester.pump();

    expect(find.text('2 Logged'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);

    // Open popup menu on the latest ride card
    final moreBtn = find.byIcon(Icons.more_horiz_rounded).first;
    await tester.tap(moreBtn);
    await tester.pumpAndSettle();

    // Verify Export GPX and Hide from Archive are NOT present
    expect(find.text('Export GPX'), findsNothing);
    expect(find.text('Hide from Archive'), findsNothing);

    // Tap Delete ride
    expect(find.text('Delete ride'), findsOneWidget);
    await tester.tap(find.text('Delete ride'));
    await tester.pumpAndSettle();

    // Verify confirmation dialog
    expect(find.text('Delete ride?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Totals updated: 1 ride remaining, 120 km
    expect(PostRideReportController.instance.reports.length, 1);
    expect(find.text('1 Logged'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);

    // ProfileStats updated
    final statsAfterDelete =
        ProfileStats(PostRideReportController.instance.reports);
    expect(statsAfterDelete.ridesCount, 1);
    expect(statsAfterDelete.lifetimeDistanceKm, 120.0);

    // SnackBar undo action
    expect(find.text('Ride deleted'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // Tap Undo
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    // Totals restored: 2 rides, 200 km
    expect(PostRideReportController.instance.reports.length, 2);
    expect(find.text('2 Logged'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);

    final statsAfterUndo =
        ProfileStats(PostRideReportController.instance.reports);
    expect(statsAfterUndo.ridesCount, 2);
    expect(statsAfterUndo.lifetimeDistanceKm, 200.0);
  });

  test('6. Seeded demo rides are cleaned up while real user rides stay intact',
      () async {
    final fakeRepo = FakeRideReportRepository();

    // Seed repository with legacy demo rides AND a genuine user-logged ride
    final seeded1 = PostRideReport(
      id: 'rep-bmw-1',
      bikeId: 'bike-bmw-1250',
      date: DateTime(2026, 9, 1),
      distanceKm: 215.0,
      terrainTags: const ['Off-road'],
      notes: 'Babusar Pass ascent over rocky trail and loose scree.',
    );
    final seeded2 = PostRideReport(
      id: 'rep-bmw-3',
      bikeId: 'bike-bmw-1250',
      date: DateTime(2026, 9, 10),
      distanceKm: 185.0,
      terrainTags: const ['Off-road'],
      notes: 'River valley gravel track and stream ford crossings.',
    );
    final userRealRide = PostRideReport(
      id: 'user-ride-genuine-99',
      bikeId: 'bike-user-1',
      date: DateTime(2026, 10, 15),
      distanceKm: 135.5,
      terrainTags: const ['Mountain', 'Highway'],
      notes: 'Real ride across the pass with friends',
    );

    await fakeRepo.saveReports([seeded1, seeded2, userRealRide]);
    expect((await fakeRepo.loadReports()).length, 3);

    // Load reports via PostRideReportController
    await PostRideReportController.instance.load(fakeRepo);

    // Controller should contain ONLY the real ride
    final loaded = PostRideReportController.instance.reports;
    expect(loaded.length, 1);
    expect(loaded.first.id, 'user-ride-genuine-99');
    expect(loaded.first.distanceKm, 135.5);
    expect(loaded.first.notes, 'Real ride across the pass with friends');

    // Repo storage must be cleaned up as well
    final repoCleaned = await fakeRepo.loadReports();
    expect(repoCleaned.length, 1);
    expect(repoCleaned.first.id, 'user-ride-genuine-99');
  });
}
