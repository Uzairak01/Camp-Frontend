import 'dart:convert';
import 'package:camp/app/routes.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/core/widgets/camp_app_bar.dart';
import 'package:camp/core/widgets/gps_live_pill.dart';
import 'package:camp/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:camp/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:camp/features/auth/presentation/widgets/auth_brand_header.dart';
import 'package:camp/features/dashboard/presentation/screens/home_screen.dart';
import 'package:camp/features/dashboard/presentation/screens/profile_screen.dart';
import 'package:camp/features/dashboard/presentation/widgets/app_drawer_widget.dart';
import 'package:camp/features/dashboard/presentation/widgets/app_header_widget.dart';
import 'package:camp/features/garage/presentation/screens/garage_screen.dart';
import 'package:camp/features/maintenance/presentation/screens/finance_rig_health_screen.dart';
import 'package:camp/features/mechanics/presentation/screens/mechanics_home_screen.dart';
import 'package:camp/features/navigation/presentation/screens/navigation_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_location_service.dart';

class _FakeTileProvider extends TileProvider {
  _FakeTileProvider();

  static const String _whiteTile =
      'iVBORw0KGgoAAAANSUhEUgAAAQAAAAEAAQMAAABmvDolAAAAAXNSR0IB2cksfwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAANQTFRF////p8QbyAAAAB9JREFUeJztwQENAAAAwqD3T20ON6AAAAAAAAAAAL4NIQAAAfFnIe4AAAAASUVORK5CYII=';
  static final _whiteTileBytes = base64Decode(_whiteTile);

  @override
  ImageProvider<Object> getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_whiteTileBytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    LocalStore.instance = LocalStore(prefs);
  });

  group('BATCH UI-1: CAMP Brand Mark in Headers', () {
    testWidgets('1. Home header shows the logo and word CAMP with no dot, keeping menu and GPS LIVE pill',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            CampRoutes.addBike: (context) => const Scaffold(body: Text('Add Bike Mock')),
            CampRoutes.navigationMap: (context) => const Scaffold(body: Text('Map Mock')),
            CampRoutes.profile: (context) => const Scaffold(body: Text('Profile Mock')),
            CampRoutes.voiceCopilot: (context) => const Scaffold(body: Text('Voice Mock')),
          },
          home: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Home header widget is present
      expect(find.byType(AppHeaderWidget), findsOneWidget);

      // Home header displays the app icon logo and CAMP text
      expect(find.byType(CampLogo), findsOneWidget);
      expect(find.text('CAMP'), findsOneWidget);

      // Orange dot MUST be absent from the Home header
      expect(find.byKey(const ValueKey('camp_logo_dot')), findsNothing);

      // Menu button and GPS LIVE pill stay unchanged
      expect(find.byType(GpsLivePill), findsOneWidget);
    });

    testWidgets('2. Garage screen header has no CAMP brand mark (icon, word, or dot)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            CampRoutes.addBike: (context) => const Scaffold(body: Text('Add Bike Mock')),
          },
          home: const GarageScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Header exists and shows back button and GARAGE pill
      expect(find.byType(CampAppBar), findsOneWidget);
      expect(find.text('GARAGE'), findsOneWidget);

      // Entire CAMP brand mark is absent from header
      expect(find.byType(CampLogo), findsNothing);
      expect(find.byKey(const ValueKey('camp_logo_dot')), findsNothing);
    });

    testWidgets('3. Navigation screen header has no CAMP brand mark',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: NavigationMapScreen(
            locationService: FakeLocationService(),
            tileProvider: _FakeTileProvider(),
          ),
        ),
      );
      await tester.pump();

      // No header brand mark
      expect(find.byType(CampLogo), findsNothing);
      expect(find.byKey(const ValueKey('camp_logo_dot')), findsNothing);
    });

    testWidgets('4. Mechanics screen header has no CAMP brand mark',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: MechanicsHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // No header brand mark
      expect(find.byType(CampLogo), findsNothing);
      expect(find.byKey(const ValueKey('camp_logo_dot')), findsNothing);
    });

    testWidgets('5. Finances & Rig Health screen header has no CAMP brand mark',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: FinanceRigHealthScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Header exists and shows FINANCES & RIG HEALTH action pill
      expect(find.byType(CampAppBar), findsOneWidget);
      expect(find.text('FINANCES & RIG HEALTH'), findsOneWidget);

      // Brand mark is absent from header
      expect(find.byType(CampLogo), findsNothing);
      expect(find.byKey(const ValueKey('camp_logo_dot')), findsNothing);
    });

    testWidgets('6. Profile screen header has no CAMP brand mark',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Header exists and shows PROFILE pill
      expect(find.byType(CampAppBar), findsOneWidget);
      expect(find.text('PROFILE'), findsOneWidget);

      // Brand mark is absent from header
      expect(find.byType(CampLogo), findsNothing);
      expect(find.byKey(const ValueKey('camp_logo_dot')), findsNothing);
    });

    testWidgets('7. Login screen still shows its CAMP brand header',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignInScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // AuthBrandHeader must be present with CAMP text
      expect(find.byType(AuthBrandHeader), findsOneWidget);
      expect(find.text('CAMP'), findsOneWidget);
    });

    testWidgets('8. Sign-up screen still shows its CAMP auth header and brand agreement',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // AuthBrandHeader must be present with CAMP brand agreement
      expect(find.byType(AuthBrandHeader), findsOneWidget);
      expect(find.textContaining('CAMP'), findsWidgets);
    });

    testWidgets('9. Navigation drawer still shows its full brand mark with dot',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: const AppDrawerWidget(),
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                child: const Text('Open Drawer'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Drawer has CampLogo with dot
      expect(find.byType(CampLogo), findsOneWidget);
      expect(find.byKey(const ValueKey('camp_logo_dot')), findsOneWidget);
    });
  });
}
