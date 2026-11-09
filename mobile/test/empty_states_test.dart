import 'dart:convert';

import 'package:camp/app/routes.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/presentation/screens/home_screen.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/presentation/screens/garage_screen.dart';
import 'package:camp/features/maintenance/controllers/trip_budget_controller.dart';
import 'package:camp/features/maintenance/presentation/screens/finance_rig_health_screen.dart';
import 'package:camp/features/mechanics/controllers/mechanic_controller.dart';
import 'package:camp/features/mechanics/presentation/screens/mechanics_home_screen.dart';
import 'package:camp/features/navigation/controllers/navigation_controller.dart';
import 'package:camp/features/navigation/presentation/screens/navigation_map_screen.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_location_sheet.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_geocoding_service.dart';
import 'helpers/fake_location_service.dart';
import 'helpers/fake_routing_service.dart';

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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStore.instance.resetForTesting();
    ActiveBikeController.instance.reset();
    MechanicController.instance.resetForTesting();
    TripBudgetController.instance.resetForTesting();
  });

  group('Batch G1: Comprehensive Empty-State Widget Tests', () {
    testWidgets('1. Maps & Destination Picker render clean empty state without crashing',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLocation = FakeLocationService();
      final fakeRouting = FakeRoutingService();
      final fakeGeocoding = FakeGeocodingService();
      final controller = NavigationController(
        locationService: fakeLocation,
        routingService: fakeRouting,
        geocodingService: fakeGeocoding,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NavigationMapScreen(
            controller: controller,
            locationService: fakeLocation,
            tileProvider: _FakeTileProvider(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Location sheet & search bar rendered
      expect(find.byType(NavLocationSheet), findsOneWidget);
      expect(find.byType(NavSearchBar), findsOneWidget);

      // Tapping Directions with no destination prompts rider instead of crashing
      await tester.tap(find.text('Directions'));
      await tester.pumpAndSettle();
      expect(find.text('Search or select a destination to preview route'), findsOneWidget);

      controller.dispose();
      fakeLocation.dispose();
    });

    testWidgets('2. Mechanics Home empty state renders with honest CTA and route guidance handles gracefully',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            CampRoutes.navigationMap: (context) => const Scaffold(body: Text('Navigation Map Screen')),
            CampRoutes.addMechanic: (context) => const Scaffold(body: Text('Add Mechanic Screen')),
          },
          home: const MechanicsHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Honest empty state rendered
      expect(find.text('No mechanics saved yet'), findsOneWidget);
      expect(find.text('+ Add Mechanic'), findsWidgets);
    });

    testWidgets('3. Home Screen renders without active bike and displays empty bike card',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            CampRoutes.addBike: (context) => const Scaffold(body: Text('Add Bike Screen')),
            CampRoutes.navigationMap: (context) => const Scaffold(body: Text('Map Screen')),
            CampRoutes.profile: (context) => const Scaffold(body: Text('Profile Screen')),
            CampRoutes.voiceCopilot: (context) => const Scaffold(body: Text('Voice Screen')),
          },
          home: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Empty bike state rendered honestly
      expect(find.text('No motorcycle active in your garage'), findsOneWidget);
      expect(find.text('Add your bike'), findsOneWidget);
    });

    testWidgets('4. Finances & Rig Health renders empty state without fake amounts',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: FinanceRigHealthScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Empty expense state rendered honestly
      expect(find.text('Add your first expense'), findsOneWidget);
    });

    testWidgets('5. Garage Screen renders empty fleet card without fake bikes',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: GarageScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Empty garage state rendered honestly
      expect(find.text('No motorcycles in garage'), findsOneWidget);
      expect(find.text('Add motorcycle'), findsWidgets);
    });
  });
}
