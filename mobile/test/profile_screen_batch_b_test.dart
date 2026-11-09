import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/data/session_repository.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/presentation/screens/profile_screen.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/maintenance/controllers/post_ride_report_controller.dart';
import 'package:camp/features/maintenance/domain/post_ride_report.dart';
import 'package:camp/features/settings/controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_ride_report_repository.dart';

class FakeSessionRepository implements SessionRepository {
  bool _loggedIn = true;

  @override
  Future<bool> isLoggedIn() async => _loggedIn;

  @override
  Future<void> setLoggedIn(bool value) async => _loggedIn = value;

  @override
  Future<void> clearSession() async => _loggedIn = false;

  @override
  Future<void> flush() async {}
}

void main() {
  late FakeSessionRepository fakeSession;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStore.instance.resetForTesting();
    fakeSession = FakeSessionRepository();
    AppRepositories.resetWith(sessionRepository: fakeSession);
    SettingsController.instance.reset();
    ActiveBikeController.instance.reset();
    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());
  });

  tearDown(() {
    ActiveBikeController.instance.reset();
    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());
    AppRepositories.resetToDefault();
  });

  testWidgets('Batch B: Empty state rendering for ProfileScreen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Completely empty ride history and empty garage
    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());
    ActiveBikeController.instance.resetForTesting();

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Stat cards show pure zero / empty states
    expect(find.text('0'), findsWidgets);
    expect(find.text('KM'), findsWidgets);
    expect(find.text('Rides'), findsOneWidget);
    // Saddle time and Longest ride show '-'
    expect(find.text('-'), findsNWidgets(2));
    // Status state labels show "No rides yet"
    expect(find.text('No rides yet'), findsWidgets);

    // 2. Touring Tier shows Rookie
    expect(find.textContaining('Level 1: Rookie'), findsOneWidget);
    expect(find.textContaining('500 KM to go'), findsOneWidget);

    // 3. Badges show 0/6 unlocked
    expect(find.text('0/6 UNLOCKED'), findsOneWidget);

    // 4. Empty garage shows "No motorcycles in garage" and "Add motorcycle" button
    expect(find.text('No motorcycles in garage'), findsOneWidget);
    expect(find.text('Add motorcycle'), findsOneWidget);

    // Scroll down to check recent trips
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Completed rides will appear here with distance, duration, and terrain summary.'), findsOneWidget);
  });

  testWidgets('Batch B: Absolute absence of invented telemetry and fake chips', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Hero card fake passports and chips must NOT exist
    expect(find.text('PASSPORT: CAMP-9942-GS'), findsNothing);
    expect(find.text('GARMIN INREACH SYNC'), findsNothing);
    expect(find.text('Elev. +142,500m'), findsNothing);
    expect(find.text('Alps, Pyrenees, Balk.'), findsNothing);
    expect(find.text('124 Days / 418 Active Hours'), findsNothing);
    expect(find.text('780 km TET Sector 04'), findsNothing);
    expect(find.text('Babusar Pass Summit & Alpine Ridge'), findsNothing);

    // Fake maintenance percentages must NOT exist
    expect(find.text('82%'), findsNothing);
    expect(find.text('78% Wear'), findsNothing);
    expect(find.text('65% Wear'), findsNothing);
  });

  testWidgets('Batch B: Badges unlock dynamically and render requirement text when locked', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());
    // Add one ride of 150 km
    PostRideReportController.instance.addReport(
      PostRideReport(
        id: 'test-r1',
        bikeId: 'bike-1',
        date: DateTime.now(),
        distanceKm: 150.0,
        durationHours: 2.5,
        terrainTags: const ['Off-road'],
        notes: 'Great mountain trail',
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 150 km unlocks First Ride, 100 km Club, and Long Haul (3 badges)
    expect(find.text('3/6 UNLOCKED'), findsOneWidget);

    // Requirement texts for locked badges should be displayed in the badge cards
    expect(find.text('500 km lifetime distance'), findsOneWidget);
    expect(find.text('1,000 km lifetime distance'), findsOneWidget);
  });

  testWidgets('Batch B: Log out button opens confirmation dialog explaining local data preservation',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    expect(await fakeSession.isLoggedIn(), isTrue);

    String navigatedRoute = '';

    await tester.pumpWidget(
      MaterialApp(
        home: const ProfileScreen(),
        onGenerateRoute: (settings) {
          navigatedRoute = settings.name ?? '';
          return MaterialPageRoute(
            builder: (context) => Scaffold(body: Text('Destination: ${settings.name}')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    final logOutButton = find.text('Log Out');
    expect(logOutButton, findsOneWidget);

    await tester.tap(logOutButton);
    await tester.pumpAndSettle();

    // Verify confirmation dialog title and copy
    expect(find.text('Log Out'), findsWidgets);
    expect(
      find.text('Are you sure you want to log out? Local ride history and bike data will be preserved.'),
      findsOneWidget,
    );

    // Tap Cancel first -> dialog dismissed, still logged in
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await fakeSession.isLoggedIn(), isTrue);

    // Tap Log Out again and confirm
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    // In dialog, find the action Log Out button
    final dialogLogOut = find.widgetWithText(TextButton, 'Log Out');
    expect(dialogLogOut, findsOneWidget);
    await tester.tap(dialogLogOut);
    await tester.pumpAndSettle();

    // Session is terminated and user is navigated to sign-in screen
    expect(await fakeSession.isLoggedIn(), isFalse);
    expect(navigatedRoute, '/sign-in');
  });
}
