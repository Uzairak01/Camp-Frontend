import 'package:camp/app/routes.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/core/widgets/camp_bottom_nav.dart';
import 'package:camp/features/bike_scan/presentation/screens/add_motorcycle_screen.dart';
import 'package:camp/features/bike_scan/presentation/screens/bike_details_screen.dart';
import 'package:camp/features/dashboard/presentation/screens/home_screen.dart';
import 'package:camp/features/dashboard/presentation/screens/profile_screen.dart';
import 'package:camp/features/emergency_sos/presentation/screens/emergency_sos_screen.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/presentation/screens/bike_profile_screen.dart';
import 'package:camp/features/garage/presentation/screens/garage_screen.dart';
import 'package:camp/features/maintenance/presentation/screens/finance_rig_health_screen.dart';
import 'package:camp/features/maintenance/presentation/screens/maintenance_screen.dart';
import 'package:camp/features/mechanics/presentation/screens/add_mechanic_screen.dart';
import 'package:camp/features/mechanics/presentation/screens/mechanics_home_screen.dart';
import 'package:camp/features/navigation/presentation/screens/navigation_map_screen.dart';
import 'package:camp/features/navigation/presentation/screens/route_packs_screen.dart';
import 'package:camp/features/ride_history/presentation/screens/ride_history_screen.dart';
import 'package:camp/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStore.instance.resetForTesting();
    ActiveBikeController.instance.resetForTesting();
  });

  group('CampTab enum specifications', () {
    test('Contains exactly the 6 defined tabs in order', () {
      expect(CampTab.values, [
        CampTab.home,
        CampTab.garage,
        CampTab.navigation,
        CampTab.mechanics,
        CampTab.finances,
        CampTab.profile,
      ]);
    });

    test('CampTab.rootRoute matches pre-refactor routes exactly for all 6 tabs', () {
      const preRefactorRoutes = {
        CampTab.home: CampRoutes.home, // index 0: '/'
        CampTab.garage: CampRoutes.addBike, // index 1: '/add-bike' (AddMotorcycleScreen)
        CampTab.navigation: CampRoutes.navigationMap, // index 2: '/navigation'
        CampTab.mechanics: CampRoutes.mechanics, // index 3: '/mechanics'
        CampTab.finances: CampRoutes.financeRigHealth, // index 4: '/finance-rig-health'
        CampTab.profile: CampRoutes.profile, // index 5: '/profile'
      };

      for (final tab in CampTab.values) {
        expect(tab.rootRoute, preRefactorRoutes[tab],
            reason: '$tab rootRoute must strictly match pre-refactor target route ${preRefactorRoutes[tab]}');
      }
    });
  });

  group('CampBottomNav component highlight & interaction tests', () {
    testWidgets('Renders all 6 tabs and highlights active tab by enum',
        (WidgetTester tester) async {
      for (final tab in CampTab.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: CampBottomNav(selected: tab),
              ),
            ),
          ),
        );
        await tester.pump();

        final navFinder = find.byType(CampBottomNav);
        expect(navFinder, findsOneWidget);
        final navWidget = tester.widget<CampBottomNav>(navFinder);
        expect(navWidget.selected, tab);
      }
    });

    testWidgets('Renders unselected (no active highlight) when selected is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CampBottomNav(selected: null),
            ),
          ),
        ),
      );
      await tester.pump();

      final navWidget = tester.widget<CampBottomNav>(find.byType(CampBottomNav));
      expect(navWidget.selected, isNull);
    });

    testWidgets('Tapping highlighted tab while on its root screen does nothing',
        (WidgetTester tester) async {
      var routesPushed = 0;

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: CampRoutes.addBike,
          routes: {
            CampRoutes.home: (context) => const SizedBox(),
            CampRoutes.addBike: (context) => const Scaffold(
                  body: Center(
                    child: CampBottomNav(selected: CampTab.garage),
                  ),
                ),
          },
          navigatorObservers: [
            _TestNavigatorObserver(onPushed: (_) => routesPushed++),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final initialPushed = routesPushed;
      // Tap Garage tab (tab 1, Bike icon)
      await tester.tap(find.byIcon(Icons.two_wheeler_rounded));
      await tester.pumpAndSettle();

      // No new route should be pushed because we are already on Garage root (AddMotorcycleScreen)
      expect(routesPushed, initialPushed);
    });

    testWidgets('Tapping a tab from a sub-screen navigates to that tab root without stacking duplicates',
        (WidgetTester tester) async {
      String? lastPushedRoute;

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: CampRoutes.home,
          routes: {
            CampRoutes.home: (context) => const Scaffold(
                  body: Center(
                    child: CampBottomNav(selected: CampTab.home),
                  ),
                ),
            CampRoutes.addBike: (context) => const Scaffold(
                  body: Center(
                    child: CampBottomNav(selected: CampTab.garage),
                  ),
                ),
            CampRoutes.mechanics: (context) => const Scaffold(
                  body: Center(
                    child: CampBottomNav(selected: CampTab.mechanics),
                  ),
                ),
            CampRoutes.addMechanic: (context) => const Scaffold(
                  body: Center(
                    child: CampBottomNav(selected: CampTab.mechanics),
                  ),
                ),
          },
          navigatorObservers: [
            _TestNavigatorObserver(
              onPushed: (route) => lastPushedRoute = route.settings.name,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to /mechanics
      await tester.tap(find.byIcon(Icons.handyman_rounded));
      await tester.pumpAndSettle();
      expect(lastPushedRoute, CampRoutes.mechanics);

      // Now push a sub-screen /add-mechanic
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(CampRoutes.addMechanic);
      await tester.pumpAndSettle();
      expect(lastPushedRoute, CampRoutes.addMechanic);

      // From /add-mechanic, tapping Garage navigates directly to /add-bike, keeping Home base
      await tester.tap(find.byIcon(Icons.two_wheeler_rounded));
      await tester.pumpAndSettle();
      expect(lastPushedRoute, CampRoutes.addBike);
    });

    testWidgets('Tapping each of the 6 tabs triggers navigation to its root route',
        (WidgetTester tester) async {
      final tabRoutes = {
        CampTab.home: CampRoutes.home,
        CampTab.garage: CampRoutes.addBike,
        CampTab.navigation: CampRoutes.navigationMap,
        CampTab.mechanics: CampRoutes.mechanics,
        CampTab.finances: CampRoutes.financeRigHealth,
        CampTab.profile: CampRoutes.profile,
      };

      for (final entry in tabRoutes.entries) {
        String? targetPushed;

        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            // Start from an arbitrary route so any tab is not current
            initialRoute: '/initial',
            routes: {
              '/initial': (context) => const Scaffold(
                    body: Center(
                      child: CampBottomNav(selected: null),
                    ),
                  ),
              CampRoutes.home: (context) => const SizedBox(),
              CampRoutes.addBike: (context) => const SizedBox(),
              CampRoutes.navigationMap: (context) => const SizedBox(),
              CampRoutes.mechanics: (context) => const SizedBox(),
              CampRoutes.financeRigHealth: (context) => const SizedBox(),
              CampRoutes.profile: (context) => const SizedBox(),
            },
            navigatorObservers: [
              _TestNavigatorObserver(
                onPushed: (route) => targetPushed = route.settings.name,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final icon = CampBottomNav.defaultItems.firstWhere((i) => i.tab == entry.key).icon;
        await tester.tap(find.byIcon(icon));
        await tester.pumpAndSettle();

        expect(targetPushed, entry.value, reason: 'Tab ${entry.key} should navigate to ${entry.value}');
      }
    });
  });

  group('Screen Tab Assignment Verification', () {
    testWidgets('HomeScreen renders CampBottomNav with selected == CampTab.home',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pump();

      final nav = tester.widget<CampBottomNav>(find.byType(CampBottomNav));
      expect(nav.selected, CampTab.home);
    });

    testWidgets('GarageScreen renders CampBottomNav with selected == CampTab.garage',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GarageScreen(),
        ),
      );
      await tester.pump();

      final nav = tester.widget<CampBottomNav>(find.byType(CampBottomNav));
      expect(nav.selected, CampTab.garage);
    });

    testWidgets('BikeProfileScreen renders CampBottomNav with selected == CampTab.garage',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BikeProfileScreen(),
        ),
      );
      await tester.pump();

      final nav = tester.widget<CampBottomNav>(find.byType(CampBottomNav));
      expect(nav.selected, CampTab.garage);
    });

    testWidgets('AddMotorcycleScreen renders CampBottomNav with selected == CampTab.garage',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddMotorcycleScreen(),
        ),
      );
      await tester.pump();

      final nav = tester.widget<CampBottomNav>(find.byType(CampBottomNav));
      expect(nav.selected, CampTab.garage);
    });

    testWidgets('BikeDetailsScreen renders CampBottomNav with selected == CampTab.garage',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BikeDetailsScreen(),
        ),
      );
      await tester.pump();

      final nav = tester.widget<CampBottomNav>(find.byType(CampBottomNav));
      expect(nav.selected, CampTab.garage);
    });

    testWidgets('NavigationMapScreen renders CampBottomNav with selected == CampTab.navigation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NavigationMapScreen(),
        ),
      );
      await tester.pump();

      final nav = tester.widget<CampBottomNav>(find.byType(CampBottomNav));
      expect(nav.selected, CampTab.navigation);
    });

    testWidgets('RoutePacksScreen renders CampBottomNav with selected == CampTab.navigation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RoutePacksScreen(),
        ),
      );
      await tester.pump();

      final nav = tester.widget<CampBottomNav>(find.byType(CampBottomNav));
      expect(nav.selected, CampTab.navigation);
    });

    testWidgets('MechanicsHomeScreen renders CampBottomNav with selected == CampTab.mechanics',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MechanicsHomeScreen(),
        ),
      );
      await tester.pump();

      final nav = tester.widget<CampBottomNav>(find.byType(CampBottomNav));
      expect(nav.selected, CampTab.mechanics);
    });

    testWidgets('AddMechanicScreen renders CampBottomNav with selected == CampTab.mechanics',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddMechanicScreen(),
        ),
      );
      await tester.pump();

      final nav = tester.widget<CampBottomNav>(find.byType(CampBottomNav));
      expect(nav.selected, CampTab.mechanics);
    });

    testWidgets('FinanceRigHealthScreen renders CampBottomNav with selected == CampTab.finances',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FinanceRigHealthScreen(),
        ),
      );
      await tester.pump();

      final nav = tester.widget<CampBottomNav>(find.byType(CampBottomNav));
      expect(nav.selected, CampTab.finances);
    });

    testWidgets('MaintenanceScreen renders CampBottomNav with selected == CampTab.finances',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MaintenanceScreen(),
        ),
      );
      await tester.pump();

      final nav = tester.widget<CampBottomNav>(find.byType(CampBottomNav));
      expect(nav.selected, CampTab.finances);
    });

    testWidgets('ProfileScreen renders CampBottomNav with selected == CampTab.profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pump();

      final nav = tester.widget<CampBottomNav>(find.byType(CampBottomNav));
      expect(nav.selected, CampTab.profile);
    });

    testWidgets('SettingsScreen renders CampBottomNav with selected == CampTab.profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pump();

      final nav = tester.widget<CampBottomNav>(find.byType(CampBottomNav));
      expect(nav.selected, CampTab.profile);
    });

    testWidgets('RideHistoryScreen renders CampBottomNav with selected == CampTab.profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RideHistoryScreen(),
        ),
      );
      await tester.pump();

      final nav = tester.widget<CampBottomNav>(find.byType(CampBottomNav));
      expect(nav.selected, CampTab.profile);
    });

    testWidgets('EmergencySosScreen renders CampBottomNav with selected == null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencySosScreen(),
        ),
      );
      await tester.pump();

      final nav = tester.widget<CampBottomNav>(find.byType(CampBottomNav));
      expect(nav.selected, isNull);
    });
  });

  group('AddMotorcycleScreen specific interaction tests', () {
    testWidgets('Tapping Garage tab while already on AddMotorcycleScreen does nothing (early return)',
        (WidgetTester tester) async {
      var routesPushed = 0;

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: CampRoutes.addBike,
          routes: {
            CampRoutes.home: (context) => const SizedBox(),
            CampRoutes.addBike: (context) => const AddMotorcycleScreen(),
          },
          navigatorObservers: [
            _TestNavigatorObserver(onPushed: (_) => routesPushed++),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final initialPushed = routesPushed;
      // Tap Garage tab (tab 1, Bike icon)
      await tester.tap(find.byIcon(Icons.two_wheeler_rounded));
      await tester.pumpAndSettle();

      expect(routesPushed, initialPushed);
    });

    testWidgets('Take Bike Photo card on AddMotorcycleScreen navigates to bikeScan',
        (WidgetTester tester) async {
      String? lastPushed;

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: CampRoutes.addBike,
          routes: {
            CampRoutes.home: (context) => const SizedBox(),
            CampRoutes.addBike: (context) => const AddMotorcycleScreen(),
            CampRoutes.bikeScan: (context) => const SizedBox(),
          },
          navigatorObservers: [
            _TestNavigatorObserver(onPushed: (r) => lastPushed = r.settings.name),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Take Bike Photo'));
      await tester.pumpAndSettle();

      expect(lastPushed, CampRoutes.bikeScan);
    });

    testWidgets('View Garage card on AddMotorcycleScreen navigates to garage',
        (WidgetTester tester) async {
      String? lastPushed;

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: CampRoutes.addBike,
          routes: {
            CampRoutes.home: (context) => const SizedBox(),
            CampRoutes.addBike: (context) => const AddMotorcycleScreen(),
            CampRoutes.garage: (context) => const SizedBox(),
          },
          navigatorObservers: [
            _TestNavigatorObserver(onPushed: (r) => lastPushed = r.settings.name),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Garage'));
      await tester.pumpAndSettle();

      expect(lastPushed, CampRoutes.garage);
    });
  });
}

class _TestNavigatorObserver extends NavigatorObserver {
  _TestNavigatorObserver({this.onPushed});

  final void Function(Route<dynamic> route)? onPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onPushed?.call(route);
    super.didPush(route, previousRoute);
  }
}
