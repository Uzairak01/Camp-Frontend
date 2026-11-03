import 'package:camp/core/widgets/camp_app_bar.dart';
import 'package:camp/features/dashboard/controllers/profile_controller.dart';
import 'package:camp/features/dashboard/presentation/screens/profile_screen.dart';
import 'package:camp/features/maintenance/controllers/post_ride_report_controller.dart';
import 'package:camp/features/maintenance/domain/post_ride_report.dart';
import 'package:camp/features/settings/controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_ride_report_repository.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    SettingsController.instance.reset();
    ProfileController.instance.updateProfile(
      fullName: 'Test Rider',
      username: 'testrider',
      email: 'test@example.com',
    );
    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());
    PostRideReportController.instance.addReport(
      PostRideReport(
        id: 'test-profile-1',
        bikeId: 'bike-bmw-1250',
        distanceKm: 600,
        durationHours: 6.5,
        date: DateTime(2026, 5, 1),
        terrainTags: const ['Mountain'],
      ),
    );
  });

  tearDown(() {
    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());
  });
  testWidgets('ProfileScreen renders all sections matching reference screenshots in order',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Header (Brand mark removed per BATCH UI-1)
    expect(find.byType(CampLogo), findsNothing);
    expect(find.text('PROFILE'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    // 2. Cockpit Hero Card
    expect(find.text('Test Rider'), findsOneWidget);
    expect(find.text('ADV PRO'), findsNothing);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_2_rounded), findsOneWidget);

    // 3. Stats Grid (Computed from pure ProfileStats)
    expect(find.text('LIFETIME DISTANCE'), findsOneWidget);
    expect(find.text('RIDES COMPLETED'), findsOneWidget);
    expect(find.text('SADDLE TIME'), findsOneWidget);
    expect(find.text('LONGEST SINGLE RIDE'), findsOneWidget);

    // 4. Touring Tier Progress
    expect(find.text('TOURING TIER PROGRESS'), findsOneWidget);
    expect(find.textContaining('Level 2: Explorer'), findsOneWidget);

    // 5. Earned Trail Badges
    expect(find.text('EARNED TRAIL BADGES'), findsOneWidget);
    expect(find.text('First Ride'), findsOneWidget);
    expect(find.text('100 km Club'), findsOneWidget);
    expect(find.text('500 km Club'), findsOneWidget);
    expect(find.text('1,000 km Club'), findsOneWidget);
    expect(find.text('Long Haul'), findsOneWidget);
    expect(find.text('Ten Rides'), findsOneWidget);

    // 6. My Garage
    expect(find.text('MY GARAGE'), findsOneWidget);

    // Scroll down to reveal lower sections
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -1000));
    await tester.pumpAndSettle();

    // 7. Maintenance Health Card
    expect(find.text('MAINTENANCE HEALTH'), findsOneWidget);

    // 8. Recent Trips
    expect(find.text('RECENT TRIPS'), findsOneWidget);

    // Scroll to the very bottom
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();

    // 9. Rider Medical & SOS ID Card
    expect(find.text('RIDER MEDICAL & SOS ID'), findsOneWidget);
    expect(find.text('Add a contact'), findsOneWidget);
    expect(find.text('System Armed'), findsNothing);
    expect(find.text('Emergency ICE:'), findsOneWidget);
    expect(find.text('Blood & Allergies:'), findsOneWidget);
    expect(find.text('Emergency SOS Method:'), findsOneWidget);
    expect(find.text('View Emergency Protocols & Health Card'), findsOneWidget);

    // 10. Settings List Card
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('Edit Personal Info'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Offline Maps'), findsOneWidget);
    expect(find.text('Privacy & Data'), findsOneWidget);
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('About CAMP'), findsOneWidget);

    // 11. Log Out Button fully visible and rendered
    expect(find.text('Log Out'), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
  });

  testWidgets('ProfileScreen Settings card updates reactively when SettingsController changes',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Initial state check
    expect(find.text('Enabled'), findsOneWidget); // Notifications

    // Update settings in SettingsController
    final settings = SettingsController.instance;
    settings.setNotificationsEnabled(false);
    await tester.pumpAndSettle();

    // Verify values updated reactively without rebuilding/restarting screen
    expect(find.text('Disabled'), findsOneWidget);
  });

  testWidgets('ProfileScreen Settings rows navigate to /settings and /edit-profile',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    var lastPushedRoute = '';

    await tester.pumpWidget(
      MaterialApp(
        home: const ProfileScreen(),
        onGenerateRoute: (settings) {
          lastPushedRoute = settings.name ?? '';
          return MaterialPageRoute(
            builder: (context) => Scaffold(body: Text('Destination: ${settings.name}')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    // Tap Offline Maps -> should navigate to /settings
    await tester.tap(find.text('Offline Maps'));
    await tester.pumpAndSettle();
    expect(lastPushedRoute, '/settings');

    // Pop back
    Navigator.of(tester.element(find.text('Destination: /settings'))).pop();
    await tester.pumpAndSettle();

    // Tap Notifications -> should navigate to /settings
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(lastPushedRoute, '/settings');

    // Pop back
    Navigator.of(tester.element(find.text('Destination: /settings'))).pop();
    await tester.pumpAndSettle();

    // Tap Offline Maps -> should navigate to /settings
    await tester.tap(find.text('Offline Maps'));
    await tester.pumpAndSettle();
    expect(lastPushedRoute, '/settings');

    // Pop back
    Navigator.of(tester.element(find.text('Destination: /settings'))).pop();
    await tester.pumpAndSettle();

    // Tap Privacy & Data -> should navigate to /settings
    await tester.tap(find.text('Privacy & Data'));
    await tester.pumpAndSettle();
    expect(lastPushedRoute, '/settings');

    // Pop back
    Navigator.of(tester.element(find.text('Destination: /settings'))).pop();
    await tester.pumpAndSettle();

    // Tap Help & Support -> should navigate to /settings
    await tester.tap(find.text('Help & Support'));
    await tester.pumpAndSettle();
    expect(lastPushedRoute, '/settings');

    // Pop back
    Navigator.of(tester.element(find.text('Destination: /settings'))).pop();
    await tester.pumpAndSettle();

    // Tap About CAMP -> should navigate to /settings
    await tester.tap(find.text('About CAMP'));
    await tester.pumpAndSettle();
    expect(lastPushedRoute, '/settings');

    // Pop back
    Navigator.of(tester.element(find.text('Destination: /settings'))).pop();
    await tester.pumpAndSettle();

    // Tap Edit Personal Info -> should navigate to /edit-profile
    await tester.tap(find.text('Edit Personal Info'));
    await tester.pumpAndSettle();
    expect(lastPushedRoute, '/edit-profile');
  });
}

