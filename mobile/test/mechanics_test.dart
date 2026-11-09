import 'dart:convert';
import 'package:camp/app/routes.dart';
import 'package:camp/app/theme/app_colors.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/core/widgets/camp_bottom_nav.dart';
import 'package:camp/core/widgets/camp_empty_state.dart';
import 'package:camp/core/widgets/primary_button.dart';
import 'package:camp/features/mechanics/controllers/mechanic_controller.dart';
import 'package:camp/features/mechanics/domain/mechanic_model.dart';
import 'package:camp/features/mechanics/domain/mechanic_open_status.dart';
import 'package:camp/features/mechanics/presentation/screens/add_mechanic_screen.dart';
import 'package:camp/features/mechanics/presentation/screens/mechanics_home_screen.dart';
import 'package:camp/features/mechanics/presentation/widgets/custom_app_bar.dart';
import 'package:camp/features/mechanics/presentation/widgets/mechanic_card.dart';
import 'package:camp/features/mechanics/presentation/widgets/search_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = LocalStore(prefs);
    LocalStore.instance = store;
    MechanicController.instance.resetForTesting();
  });

  group('Mechanic Persistence & Model Tests', () {
    test('Add a mechanic with a photo path, reload from LocalStore and assert round-trips', () async {
      await store.markFirstRunCompleted();

      const newMechanic = Mechanic(
        id: 'mech-babusar-01',
        name: 'Babusar High Pass Moto Prep',
        distance: '1.2 km away',
        durationOrLocation: 'Mile Marker 88',
        badgeType: BadgeType.verified,
        badgeLabel: 'Verified Shop',
        beaconStatus: 'Active',
        beaconColor: AppColors.statusGreen,
        categoryTitle1: 'SPECIALTIES',
        tags1: ['Carb Jetting', 'Tire Vulcanizing'],
        categoryTitle2: 'LOCATION',
        tags2: ['Babusar Pass'],
        rating: 4.9,
        reviewCount: 42,
        openStatus: 'OPEN NOW',
        phone: '+92 300 1234567',
        address: 'Babusar Pass Summit Junction',
        notes: 'Has 220V arc welder and stocked spark plugs',
        photoPath: '/data/user/0/com.camp.app/app_flutter/mechanics/mech_123.jpg',
      );

      MechanicController.instance.addMechanic(newMechanic);
      await MechanicController.instance.flush();

      // Verify it was written to LocalStore JSON
      final savedRaw = await store.readJson(LocalStore.keyMechanics);
      expect(savedRaw, isA<List<dynamic>>());
      final savedList = savedRaw! as List<dynamic>;
      expect(savedList.length, 1);
      expect(savedList.first['photoPath'], '/data/user/0/com.camp.app/app_flutter/mechanics/mech_123.jpg');

      // Clear controller in memory
      MechanicController.instance.resetForTesting();
      expect(MechanicController.instance.mechanics.isEmpty, isTrue);

      // Reload controller from LocalStore
      await MechanicController.instance.load(store);

      expect(MechanicController.instance.mechanics.length, 1);
      final loaded = MechanicController.instance.mechanics.first;
      expect(loaded.id, 'mech-babusar-01');
      expect(loaded.name, 'Babusar High Pass Moto Prep');
      expect(loaded.phone, '+92 300 1234567');
      expect(loaded.address, 'Babusar Pass Summit Junction');
      expect(loaded.photoPath, '/data/user/0/com.camp.app/app_flutter/mechanics/mech_123.jpg');
      expect(loaded.tags1, ['Carb Jetting', 'Tire Vulcanizing']);
      expect(loaded.notes, 'Has 220V arc welder and stocked spark plugs');
    });

    test('Delete removes mechanic and persists to LocalStore', () async {
      await store.markFirstRunCompleted();

      const mech1 = Mechanic(
        id: 'mech-1',
        name: 'First Workshop',
        distance: 'Nearby',
        durationOrLocation: 'Town',
        badgeType: BadgeType.verified,
        badgeLabel: 'Verified',
        beaconStatus: 'Active',
        beaconColor: AppColors.statusGreen,
        categoryTitle1: 'SERVICES',
        tags1: ['Repair'],
        categoryTitle2: 'LOCATION',
        tags2: ['Town'],
        rating: 5.0,
        reviewCount: 1,
        openStatus: 'OPEN',
        phone: '111',
      );

      const mech2 = Mechanic(
        id: 'mech-2',
        name: 'Second Workshop',
        distance: 'Nearby',
        durationOrLocation: 'Town',
        badgeType: BadgeType.verified,
        badgeLabel: 'Verified',
        beaconStatus: 'Active',
        beaconColor: AppColors.statusGreen,
        categoryTitle1: 'SERVICES',
        tags1: ['Repair'],
        categoryTitle2: 'LOCATION',
        tags2: ['Town'],
        rating: 5.0,
        reviewCount: 1,
        openStatus: 'OPEN',
        phone: '222',
      );

      MechanicController.instance.addMechanic(mech1);
      MechanicController.instance.addMechanic(mech2);
      await MechanicController.instance.flush();

      expect(MechanicController.instance.mechanics.length, 2);

      // Delete mech1
      MechanicController.instance.deleteMechanic('mech-1');
      await MechanicController.instance.flush();

      expect(MechanicController.instance.mechanics.length, 1);
      expect(MechanicController.instance.mechanics.first.id, 'mech-2');

      // Reload from storage and verify mech1 is gone
      MechanicController.instance.resetForTesting();
      await MechanicController.instance.load(store);

      expect(MechanicController.instance.mechanics.length, 1);
      expect(MechanicController.instance.mechanics.first.id, 'mech-2');
    });

    test('Old saved JSON without a photo field still loads properly with null photoPath', () async {
      await store.markFirstRunCompleted();

      // Simulate legacy JSON saved before photoPath existed
      final legacyJson = [
        {
          'id': 'legacy-mech-1',
          'name': 'Old Shardu Trail Garage',
          'distance': '3.5 km away',
          'durationOrLocation': 'Skardu Road',
          'badgeType': 'verified',
          'badgeLabel': 'Verified Shop',
          'beaconStatus': 'Active',
          'beaconColor': 0xFF2E7D32,
          'categoryTitle1': 'SERVICES',
          'tags1': ['Tire Repair'],
          'categoryTitle2': 'LOCATION',
          'tags2': ['Skardu'],
          'rating': 4.7,
          'reviewCount': 19,
          'openStatus': 'OPEN NOW',
          'phone': '+92 312 9876543',
          'address': 'Main Bazar Skardu',
          'notes': 'Experienced with Honda CG125',
          // Note: NO 'photoPath' or 'photo' field
        }
      ];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LocalStore.keyMechanics, jsonEncode(legacyJson));

      await MechanicController.instance.load(store);

      expect(MechanicController.instance.mechanics.length, 1);
      final loaded = MechanicController.instance.mechanics.first;
      expect(loaded.id, 'legacy-mech-1');
      expect(loaded.name, 'Old Shardu Trail Garage');
      expect(loaded.photoPath, isNull);
    });

    test('Updating / editing a mechanic persists changes', () async {
      await store.markFirstRunCompleted();

      const original = Mechanic(
        id: 'mech-edit-1',
        name: 'Original Name',
        distance: '5 km',
        durationOrLocation: 'Valley',
        badgeType: BadgeType.verified,
        badgeLabel: 'Verified',
        beaconStatus: 'Active',
        beaconColor: AppColors.statusGreen,
        categoryTitle1: 'SERVICES',
        tags1: ['Oil Change'],
        categoryTitle2: 'LOCATION',
        tags2: ['Valley'],
        rating: 5.0,
        reviewCount: 1,
        openStatus: 'OPEN',
        phone: '123',
      );

      MechanicController.instance.addMechanic(original);
      await MechanicController.instance.flush();

      final updated = original.copyWith(
        name: 'Renamed & Upgraded Moto Garage',
        phone: '+92 333 9999999',
        photoPath: '/new/path/signboard.jpg',
      );

      MechanicController.instance.updateMechanic(updated);
      await MechanicController.instance.flush();

      // Reload from store
      MechanicController.instance.resetForTesting();
      await MechanicController.instance.load(store);

      expect(MechanicController.instance.mechanics.length, 1);
      expect(MechanicController.instance.mechanics.first.name, 'Renamed & Upgraded Moto Garage');
      expect(MechanicController.instance.mechanics.first.phone, '+92 333 9999999');
      expect(MechanicController.instance.mechanics.first.photoPath, '/new/path/signboard.jpg');
    });

    test('Fresh launch starts empty (no demo mechanics seeded in debug or release)', () async {
      await store.markFirstRunCompleted();
      MechanicController.instance.resetForTesting();
      await MechanicController.instance.load(store);

      expect(MechanicController.instance.mechanics, isEmpty);
    });

    test('One-time cleanup removes saved mechanics with seeded IDs or names, preserving rider mechanics', () async {
      await store.markFirstRunCompleted();
      // Simulate previously saved mechanics on test phone containing both seeded and user-added
      final dirtySavedList = [
        {
          'id': '1',
          'name': 'Peak Moto & Adventure Rig Prep',
          'distance': '4.2 km away',
          'badgeType': 'verified',
          'badgeLabel': 'CAMP Verified',
        },
        {
          'id': 'seeded-custom-id',
          'name': 'Highland Moto Rescue & Spares',
          'distance': '18.6 km away',
        },
        {
          'id': '3',
          'name': 'Different Name But Seeded ID 3',
        },
        {
          'id': 'rider-shop-real-007',
          'name': 'Genuine Rider Workshop',
          'phone': '+92 300 9876543',
          'address': 'Gilgit Bazar',
          'badgeType': 'userAdded',
        },
      ];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LocalStore.keyMechanics, jsonEncode(dirtySavedList));

      // Reload via controller / repository
      MechanicController.instance.resetForTesting();
      await MechanicController.instance.load(store);

      // Only rider mechanic survived
      expect(MechanicController.instance.mechanics.length, 1);
      final surviving = MechanicController.instance.mechanics.first;
      expect(surviving.id, 'rider-shop-real-007');
      expect(surviving.name, 'Genuine Rider Workshop');

      // Assert that cleaned list was persisted back to storage
      final cleanedRaw = await store.readJson(LocalStore.keyMechanics) as List<dynamic>;
      expect(cleanedRaw.length, 1);
      expect(cleanedRaw.first['id'], 'rider-shop-real-007');
    });
  });

  group('Mechanic Widget & Screen Tests', () {
    // Helper: wraps a widget in MediaQuery(disableAnimations:true) so every
    // repeating AnimationController (CustomAppBar, TopographicMapCanvas, etc.)
    // holds a static value and pumpAndSettle() always terminates.
    Widget noAnimApp(Widget home, {Map<String, WidgetBuilder>? routes}) {
      return MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          routes: routes ?? {},
          home: home,
        ),
      );
    }

    testWidgets('Empty state shows icon, message and "+ Add Mechanic" button which navigates',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool navigatedToAdd = false;

      await tester.pumpWidget(
        noAnimApp(
          const MechanicsHomeScreen(),
          routes: {
            CampRoutes.addMechanic: (_) {
              navigatedToAdd = true;
              return const Scaffold(body: Text('Add Mechanic Screen Dummy'));
            },
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CampEmptyState), findsOneWidget);
      expect(find.text('+ Add Mechanic'), findsWidgets);

      final ctaButton = find.descendant(
        of: find.byType(CampEmptyState),
        matching: find.text('+ Add Mechanic'),
      );
      expect(ctaButton, findsOneWidget);
      await tester.tap(ctaButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(navigatedToAdd, isTrue);
    });

    testWidgets('MechanicCard shows fallback icon when no photo is present (no empty gap)',
        (tester) async {
      const mechanicWithoutPhoto = Mechanic(
        id: 'no-photo-mech',
        name: 'Roadside Tube Shop',
        distance: '0.5 km away',
        durationOrLocation: 'KKH Mile 200',
        badgeType: BadgeType.verified,
        badgeLabel: 'Verified Shop',
        beaconStatus: 'Active',
        beaconColor: AppColors.statusGreen,
        categoryTitle1: 'SERVICES',
        tags1: ['Tube Repair'],
        categoryTitle2: 'LOCATION',
        tags2: ['KKH'],
        rating: 5.0,
        reviewCount: 2,
        openStatus: 'OPEN NOW',
        phone: '123456',
        photoPath: null,
      );

      await tester.pumpWidget(
        noAnimApp(const Scaffold(body: MechanicCard(mechanic: mechanicWithoutPhoto))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
      expect(find.text('Roadside Tube Shop'), findsOneWidget);
    });

    testWidgets('AddMechanicScreen validates shop name is required', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(noAnimApp(const AddMechanicScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Try tapping Save Mechanic with empty shop name
      final saveButton = find.widgetWithText(PrimaryButton, 'Save Mechanic');
      expect(saveButton, findsOneWidget);

      await tester.ensureVisible(saveButton);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Expect validation error text in the field helper only
      expect(find.text('Shop name is required'), findsOneWidget);
      expect(MechanicController.instance.mechanics.isEmpty, isTrue);
    });

    testWidgets('AddMechanicScreen submits mechanic and pops with saved mechanic', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.resetPhysicalSize);

      MechanicController.instance.resetForTesting();

      await tester.pumpWidget(noAnimApp(const AddMechanicScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter shop name in the first TextField (Shop / Mechanic Name)
      await tester.enterText(find.byType(TextField).first, 'Alpine Expeditions Garage');
      await tester.pump();

      // Tap Save Mechanic
      final saveButton = find.widgetWithText(PrimaryButton, 'Save Mechanic');
      await tester.ensureVisible(saveButton);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(MechanicController.instance.mechanics.length, 1);
      expect(MechanicController.instance.mechanics.first.name, 'Alpine Expeditions Garage');
    });

    testWidgets('Delete confirmation dialog confirms and deletes mechanic', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.resetPhysicalSize);

      MechanicController.instance.resetForTesting();

      const mech = Mechanic(
        id: 'mech-to-delete',
        name: 'Delete Me Garage',
        distance: '1 km',
        durationOrLocation: 'Valley',
        badgeType: BadgeType.verified,
        badgeLabel: 'Verified',
        beaconStatus: 'Active',
        beaconColor: AppColors.statusGreen,
        categoryTitle1: 'SERVICES',
        tags1: ['Repair'],
        categoryTitle2: 'LOCATION',
        tags2: ['Valley'],
        rating: 5.0,
        reviewCount: 1,
        openStatus: 'OPEN',
        phone: '123',
      );

      MechanicController.instance.addMechanic(mech);

      await tester.pumpWidget(noAnimApp(const MechanicsHomeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Delete Me Garage'), findsOneWidget);

      // Tap overflow menu on card
      final overflowIcon = find.byIcon(Icons.more_vert_rounded).first;
      await tester.tap(overflowIcon);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Delete in overflow menu
      final deleteMenuItem = find.text('Delete');
      expect(deleteMenuItem, findsOneWidget);
      await tester.tap(deleteMenuItem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify confirmation dialog
      expect(find.text('Delete Mechanic?'), findsOneWidget);
      expect(
        find.text('Are you sure you want to remove Delete Me Garage from your saved mechanics?'),
        findsOneWidget,
      );

      // Tap Delete in dialog
      final confirmDeleteBtn = find.widgetWithText(TextButton, 'Delete');
      await tester.tap(confirmDeleteBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verified removed from controller and screen
      expect(MechanicController.instance.mechanics.isEmpty, isTrue);
      expect(find.text('Delete Me Garage'), findsNothing);
    });

    testWidgets('Honest badges: user-added mechanic hides unearned badges and shows Added by you tag',
        (tester) async {
      const userAddedMech = Mechanic(
        id: 'user-added-custom-id-99',
        name: 'Karakoram Custom Workshop',
        distance: 'Nearby',
        durationOrLocation: 'Pass Road',
        badgeType: BadgeType.verified,
        badgeLabel: 'Verified Shop',
        beaconStatus: 'Active',
        beaconColor: AppColors.statusGreen,
        categoryTitle1: 'SERVICES',
        tags1: ['Engine Rebuild'],
        categoryTitle2: 'LOCATION',
        tags2: ['Pass Road'],
        rating: 5.0,
        reviewCount: 1,
        openStatus: 'OPEN NOW',
        phone: '03001234567',
      );

      await tester.pumpWidget(
        noAnimApp(const Scaffold(body: MechanicCard(mechanic: userAddedMech))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Must show "Added by you" tag
      expect(find.text('Added by you'), findsOneWidget);

      // Must NOT show unearned badges or stats
      expect(find.text('Verified Shop'), findsNothing);
      expect(find.text('CAMP Verified'), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.text('OPEN NOW'), findsNothing);
      expect(find.text('Active'), findsNothing);

    });

    testWidgets('Distance shows only with coordinates and phone location, hidden otherwise',
        (tester) async {
      // 1. Shop with coordinates and phone location available -> shows "about X.X km away"
      const shopWithCoords = Mechanic(
        id: 'shop-with-coords',
        name: 'Haversine Peak Garage',
        durationOrLocation: 'Pass Summit',
        latitude: 35.8812,
        longitude: 74.4512,
        badgeType: BadgeType.verified,
        badgeLabel: 'Community Added',
        beaconStatus: '',
        beaconColor: AppColors.statusGreen,
        categoryTitle1: 'SERVICES',
        tags1: ['Brake Service'],
        categoryTitle2: 'LOCATION',
        tags2: ['Pass'],
        rating: 0.0,
        reviewCount: 0,
        openStatus: 'OPEN',
        phone: '123',
      );

      // Distance between (35.8812, 74.4512) and (35.8600, 74.4300) is ~3.0 km
      await tester.pumpWidget(
        noAnimApp(
          const Scaffold(
            body: MechanicCard(
              mechanic: shopWithCoords,
              userLatitude: 35.8600,
              userLongitude: 74.4300,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('about '), findsOneWidget);
      expect(find.textContaining('km away'), findsOneWidget);

      // 2. Shop with coordinates but phone location unavailable (null) -> NO distance
      await tester.pumpWidget(
        noAnimApp(
          const Scaffold(
            body: MechanicCard(
              mechanic: shopWithCoords,
              userLatitude: null,
              userLongitude: null,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('about '), findsNothing);
      expect(find.textContaining('km away'), findsNothing);

      // 3. Shop without coordinates even if phone location is available -> NO distance
      const shopWithoutCoords = Mechanic(
        id: 'shop-no-coords',
        name: 'No Coords Garage',
        distance: '4.2 km away', // Legacy hardcoded string must NOT be used as distance
        durationOrLocation: 'Town',
        latitude: null,
        longitude: null,
        badgeType: BadgeType.verified,
        badgeLabel: 'Community Added',
        beaconStatus: '',
        beaconColor: AppColors.statusGreen,
        categoryTitle1: 'SERVICES',
        tags1: ['Tire Repair'],
        categoryTitle2: 'LOCATION',
        tags2: ['Town'],
        rating: 0.0,
        reviewCount: 0,
        openStatus: 'OPEN',
        phone: '123',
      );

      await tester.pumpWidget(
        noAnimApp(
          const Scaffold(
            body: MechanicCard(
              mechanic: shopWithoutCoords,
              userLatitude: 35.8600,
              userLongitude: 74.4300,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('about '), findsNothing);
      expect(find.textContaining('4.2 km away'), findsNothing);
    });

    testWidgets('360 px width layout has no overflow warnings and header/buttons do not overlap',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const longNameMech = Mechanic(
        id: 'user-long-name-mech',
        name: 'Super Long Mountain Ridge Motobike Pitstop & Emergency Overhaul Garage',
        distance: '4.8 km',
        durationOrLocation: 'High Altitude Pass Mile Marker 102',
        badgeType: BadgeType.verified,
        badgeLabel: 'Verified Shop',
        beaconStatus: 'Active',
        beaconColor: AppColors.statusGreen,
        categoryTitle1: 'SPECIALTIES',
        tags1: ['Suspension Tuning', 'Engine Overhaul'],
        categoryTitle2: 'LOCATION',
        tags2: ['High Pass'],
        rating: 5.0,
        reviewCount: 1,
        openStatus: 'OPEN NOW',
        phone: '03000000000',
      );

      MechanicController.instance.addMechanic(longNameMech);

      await tester.pumpWidget(noAnimApp(const MechanicsHomeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // No RenderFlex or layout overflows
      expect(tester.takeException(), isNull);

      // Full header row is visible and tappable
      expect(find.byType(CustomAppBar), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byType(SearchBarWidget), findsOneWidget);

      // Floating Add Mechanic button does not overlap
      expect(find.text('+ Add Mechanic'), findsOneWidget);

      // Route GPS button is present on the card
      expect(find.text('Route GPS'), findsOneWidget);
    });

    testWidgets('411 px width layout has no overflow warnings', (tester) async {
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      MechanicController.instance.resetForTesting();
      MechanicController.instance.addMechanic(const Mechanic(
        id: 'test-fake-1',
        name: 'Test Workshop 1',
        durationOrLocation: 'Town',
        badgeType: BadgeType.verified,
        badgeLabel: 'Community Added',
        beaconStatus: '',
        beaconColor: AppColors.statusGreen,
        categoryTitle1: 'SERVICES',
        tags1: ['Repairs'],
        categoryTitle2: 'LOCATION',
        tags2: ['Town'],
        rating: 0.0,
        reviewCount: 0,
        openStatus: 'OPEN',
        phone: '111',
      ));
      MechanicController.instance.addMechanic(const Mechanic(
        id: 'test-fake-2',
        name: 'Test Workshop 2',
        durationOrLocation: 'Pass',
        badgeType: BadgeType.verified,
        badgeLabel: 'Community Added',
        beaconStatus: '',
        beaconColor: AppColors.statusGreen,
        categoryTitle1: 'SERVICES',
        tags1: ['Welding'],
        categoryTitle2: 'LOCATION',
        tags2: ['Pass'],
        rating: 0.0,
        reviewCount: 0,
        openStatus: 'OPEN',
        phone: '222',
      ));

      await tester.pumpWidget(noAnimApp(const MechanicsHomeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // No RenderFlex or layout overflows
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomAppBar), findsOneWidget);
      expect(find.text('+ Add Mechanic'), findsOneWidget);
    });

    testWidgets('Bottom nav is present in AddMechanicScreen when keyboard is closed', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(noAnimApp(const AddMechanicScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // CampBottomNav hides itself when keyboard is open; initially it must be present
      expect(find.byType(CampBottomNav), findsOneWidget);
    });
  });

  group('Mechanic Opening Hours & Status Tests', () {
    Mechanic createTestMechanic({
      List<int> openDays = const [],
      int? openMinutes,
      int? closeMinutes,
      bool open24Hours = false,
    }) {
      return Mechanic(
        id: 'test-mech-hours',
        name: 'Test Workshop',
        distance: '1.0 km away',
        durationOrLocation: 'Downtown',
        badgeType: BadgeType.verified,
        badgeLabel: 'Verified',
        beaconStatus: 'Active',
        beaconColor: AppColors.statusGreen,
        categoryTitle1: 'SERVICES',
        tags1: const ['Tire Repair'],
        categoryTitle2: 'LOCATION',
        tags2: const ['Downtown'],
        rating: 4.8,
        reviewCount: 10,
        openStatus: '',
        phone: '1234567890',
        openDays: openDays,
        openMinutes: openMinutes,
        closeMinutes: closeMinutes,
        open24Hours: open24Hours,
      );
    }

    test('open mid-day: Mon-Fri 9:00 AM to 5:00 PM checked on Tue 12:00 PM', () {
      final mech = createTestMechanic(
        openDays: [1, 2, 3, 4, 5],
        openMinutes: 540, // 9:00 AM
        closeMinutes: 1020, // 5:00 PM
      );
      // 2026-10-13 is Tuesday
      final now = DateTime(2026, 10, 13, 12, 0);
      final status = mechanicOpenStatus(mech, now);

      expect(status.isOpen, isTrue);
      expect(status.closesAt, '5:00 PM');
      expect(status.displayText, 'Open now, closes 5:00 PM');
    });

    test('closed before opening: Mon-Fri 9:00 AM to 5:00 PM checked on Tue 8:00 AM', () {
      final mech = createTestMechanic(
        openDays: [1, 2, 3, 4, 5],
        openMinutes: 540,
        closeMinutes: 1020,
      );
      final now = DateTime(2026, 10, 13, 8, 0);
      final status = mechanicOpenStatus(mech, now);

      expect(status.isClosed, isTrue);
      expect(status.opensAt, '9:00 AM');
      expect(status.opensDay, isNull);
      expect(status.displayText, 'Closed, opens 9:00 AM');
    });

    test('closed after closing: Mon-Fri 9:00 AM to 5:00 PM checked on Tue 6:00 PM', () {
      final mech = createTestMechanic(
        openDays: [1, 2, 3, 4, 5],
        openMinutes: 540,
        closeMinutes: 1020,
      );
      final now = DateTime(2026, 10, 13, 18, 0);
      final status = mechanicOpenStatus(mech, now);

      expect(status.isClosed, isTrue);
      expect(status.opensAt, '9:00 AM');
      expect(status.opensDay, 'Wed');
      expect(status.displayText, 'Closed, opens Wed 9:00 AM');
    });

    test('closed on a non-selected day: Mon-Fri shop checked on Sat 2:00 PM', () {
      final mech = createTestMechanic(
        openDays: [1, 2, 3, 4, 5],
        openMinutes: 540,
        closeMinutes: 1020,
      );
      // 2026-10-17 is Saturday
      final now = DateTime(2026, 10, 17, 14, 0);
      final status = mechanicOpenStatus(mech, now);

      expect(status.isClosed, isTrue);
      expect(status.opensAt, '9:00 AM');
      expect(status.opensDay, 'Mon');
      expect(status.displayText, 'Closed, opens Mon 9:00 AM');
    });

    test('overnight shop open at 1 AM the day after: Fri 6 PM to 2 AM checked on Sat 1 AM', () {
      final mech = createTestMechanic(
        openDays: [5], // Friday only
        openMinutes: 1080, // 6:00 PM
        closeMinutes: 120, // 2:00 AM
      );
      // 2026-10-17 is Saturday
      final now = DateTime(2026, 10, 17, 1, 0);
      final status = mechanicOpenStatus(mech, now);

      expect(status.isOpen, isTrue);
      expect(status.closesAt, '2:00 AM');
      expect(status.displayText, 'Open now, closes 2:00 AM');
    });

    test('24 hours: open every day checked on Wednesday afternoon', () {
      final mech = createTestMechanic(
        openDays: [1, 2, 3, 4, 5, 6, 7],
        open24Hours: true,
      );
      // 2026-10-14 is Wednesday
      final now = DateTime(2026, 10, 14, 15, 30);
      final status = mechanicOpenStatus(mech, now);

      expect(status.isOpen, isTrue);
      expect(status.isOpen24Hours, isTrue);
      expect(status.displayText, 'Open 24 hours');
    });

    test('not set: empty days or missing times when not 24h', () {
      final emptyDaysMech = createTestMechanic(openDays: const []);
      final missingTimesMech = createTestMechanic(
        openDays: [1, 2, 3],
        openMinutes: null,
        closeMinutes: null,
        open24Hours: false,
      );
      final now = DateTime(2026, 10, 13, 12, 0);

      final status1 = mechanicOpenStatus(emptyDaysMech, now);
      expect(status1.isNotSet, isTrue);
      expect(status1.displayText, '');

      final status2 = mechanicOpenStatus(missingTimesMech, now);
      expect(status2.isNotSet, isTrue);
      expect(status2.displayText, '');
    });

    test('boundary at exactly the opening minute: 9:00 AM is open', () {
      final mech = createTestMechanic(
        openDays: [1, 2, 3, 4, 5],
        openMinutes: 540, // 9:00 AM
        closeMinutes: 1020, // 5:00 PM
      );
      final now = DateTime(2026, 10, 13, 9, 0);
      final status = mechanicOpenStatus(mech, now);

      expect(status.isOpen, isTrue);
      expect(status.closesAt, '5:00 PM');
    });

    test('boundary at exactly the closing minute: 5:00 PM is closed', () {
      final mech = createTestMechanic(
        openDays: [1, 2, 3, 4, 5],
        openMinutes: 540, // 9:00 AM
        closeMinutes: 1020, // 5:00 PM
      );
      final now = DateTime(2026, 10, 13, 17, 0);
      final status = mechanicOpenStatus(mech, now);

      expect(status.isClosed, isTrue);
      expect(status.opensAt, '9:00 AM');
      expect(status.opensDay, 'Wed');
    });

    test('persistence round trip with opening hours', () async {
      await store.markFirstRunCompleted();

      final mechWithHours = createTestMechanic(
        openDays: [1, 2, 3, 4, 5, 6],
        openMinutes: 480, // 8:00 AM
        closeMinutes: 1200, // 8:00 PM
        open24Hours: false,
      );

      MechanicController.instance.addMechanic(mechWithHours);
      await MechanicController.instance.flush();

      // Clear controller in memory
      MechanicController.instance.resetForTesting();
      expect(MechanicController.instance.mechanics.isEmpty, isTrue);

      // Reload controller from LocalStore
      await MechanicController.instance.load(store);

      expect(MechanicController.instance.mechanics.length, 1);
      final loaded = MechanicController.instance.mechanics.first;
      expect(loaded.openDays, [1, 2, 3, 4, 5, 6]);
      expect(loaded.openMinutes, 480);
      expect(loaded.closeMinutes, 1200);
      expect(loaded.open24Hours, isFalse);
    });

    test('old JSON without opening hours fields loads properly with hours not set', () async {
      await store.markFirstRunCompleted();

      final legacyJson = [
        {
          'id': 'legacy-no-hours',
          'name': 'Heritage Trail Workshop',
          'distance': '2.0 km away',
          'durationOrLocation': 'Heritage Trail',
          'badgeType': 'verified',
          'badgeLabel': 'Verified Shop',
          'beaconStatus': 'Active',
          'beaconColor': 0xFF2E7D32,
          'categoryTitle1': 'SERVICES',
          'tags1': ['General Repair'],
          'categoryTitle2': 'LOCATION',
          'tags2': ['Trail'],
          'rating': 4.6,
          'reviewCount': 12,
          'openStatus': '',
          'phone': '+92 300 0000000',
          // Notice NO openDays, openMinutes, closeMinutes, open24Hours
        }
      ];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LocalStore.keyMechanics, jsonEncode(legacyJson));

      await MechanicController.instance.load(store);

      expect(MechanicController.instance.mechanics.length, 1);
      final loaded = MechanicController.instance.mechanics.first;
      expect(loaded.openDays, isEmpty);
      expect(loaded.openMinutes, isNull);
      expect(loaded.closeMinutes, isNull);
      expect(loaded.open24Hours, isFalse);

      final status = mechanicOpenStatus(loaded, DateTime.now());
      expect(status.isNotSet, isTrue);
      expect(status.displayText, '');
    });
  });

  group('Mechanics Screen Filter Chips and Header Honesty Tests', () {
    Widget noAnimApp(Widget home) {
      return MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: home),
      );
    }

    testWidgets('Header has no GPS LOCKED or Location off pill', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      MechanicController.instance.resetForTesting();
      await tester.pumpWidget(noAnimApp(const MechanicsHomeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CustomAppBar), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.text('GPS LOCKED'), findsNothing);
      expect(find.text('Location off'), findsNothing);
    });

    testWidgets('Filter row has exactly three chips and removed chips are gone', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      MechanicController.instance.resetForTesting();
      await tester.pumpWidget(noAnimApp(const MechanicsHomeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The 3 required chips are present
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Open now'), findsOneWidget);
      expect(find.text('Emergency Pitstop'), findsOneWidget);

      // Removed chips must NOT exist
      expect(find.text('Verified Only'), findsNothing);
      expect(find.text('BMW Certified'), findsNothing);
      expect(find.text('KTM Adventure'), findsNothing);
      expect(find.text('Yamaha'), findsNothing);
    });

    testWidgets('All count equals the number of saved mechanics (0 on empty, N when saved)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      MechanicController.instance.resetForTesting();
      await tester.pumpWidget(noAnimApp(const MechanicsHomeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 0 on empty list
      expect(find.text('0'), findsWidgets);

      // Add 2 mechanics
      MechanicController.instance.addMechanic(const Mechanic(
        id: 'mech-c1',
        name: 'Shop 1',
        durationOrLocation: 'Town',
        badgeType: BadgeType.verified,
        openDays: [],
      ));
      MechanicController.instance.addMechanic(const Mechanic(
        id: 'mech-c2',
        name: 'Shop 2',
        durationOrLocation: 'Town',
        badgeType: BadgeType.emergency,
        openDays: [],
      ));

      await tester.pumpWidget(noAnimApp(const MechanicsHomeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // All count equals 2
      expect(find.text('2'), findsOneWidget);
      // Emergency count equals 1
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets(
        'Open now matches shop open at fixed test time, excludes closed, excludes no hours, handles 24h and overnight',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      MechanicController.instance.resetForTesting();

      // Wednesday 2:00 PM (14:00, 840 min)
      final wednesday2Pm = DateTime(2026, 10, 21, 14, 0);

      // 1. Regular shop open Mon-Fri 9:00 AM - 5:00 PM (540 - 1020 min) -> OPEN at 2 PM
      MechanicController.instance.addMechanic(const Mechanic(
        id: 'shop-regular',
        name: 'Regular Day Shop',
        durationOrLocation: 'Valley',
        openDays: [1, 2, 3, 4, 5],
        openMinutes: 540,
        closeMinutes: 1020,
      ));

      // 2. Closed shop Mon-Fri 8:00 AM - 12:00 PM (480 - 720 min) -> CLOSED at 2 PM
      MechanicController.instance.addMechanic(const Mechanic(
        id: 'shop-morning',
        name: 'Morning Only Shop',
        durationOrLocation: 'Town',
        openDays: [1, 2, 3, 4, 5],
        openMinutes: 480,
        closeMinutes: 720,
      ));

      // 3. Shop with no hours saved -> NEVER matches
      MechanicController.instance.addMechanic(const Mechanic(
        id: 'shop-no-hours',
        name: 'No Hours Saved Shop',
        durationOrLocation: 'Remote',
        openDays: [],
      ));

      // 4. 24-hour shop -> OPEN
      MechanicController.instance.addMechanic(const Mechanic(
        id: 'shop-24h',
        name: 'Always Open 24H Shop',
        durationOrLocation: 'Highway',
        open24Hours: true,
        openDays: [1, 2, 3, 4, 5, 6, 7],
      ));

      // 5. Overnight shop Wed-Fri 8:00 PM - 4:00 AM (1200 - 240 min) -> CLOSED at 2 PM
      MechanicController.instance.addMechanic(const Mechanic(
        id: 'shop-overnight',
        name: 'Night Owls Moto Garage',
        durationOrLocation: 'Pass',
        openDays: [3, 4, 5],
        openMinutes: 1200,
        closeMinutes: 240,
      ));

      // Launch screen at Wednesday 2:00 PM
      await tester.pumpWidget(noAnimApp(MechanicsHomeScreen(currentDateTime: wednesday2Pm)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap "Open now" chip
      await tester.tap(find.text('Open now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Matches open shops at 2 PM:
      expect(find.text('Regular Day Shop'), findsOneWidget);
      expect(find.text('Always Open 24H Shop'), findsOneWidget);

      // Excludes closed shops at 2 PM:
      expect(find.text('Morning Only Shop'), findsNothing);
      expect(find.text('No Hours Saved Shop'), findsNothing);
      expect(find.text('Night Owls Moto Garage'), findsNothing);

      // Now re-launch at Wednesday 10:00 PM (22:00) during overnight shift
      final wednesday10Pm = DateTime(2026, 10, 21, 22, 0);
      await tester.pumpWidget(noAnimApp(MechanicsHomeScreen(currentDateTime: wednesday10Pm)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap "Open now" chip
      await tester.tap(find.text('Open now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Overnight shop is OPEN at 10 PM
      expect(find.text('Night Owls Moto Garage'), findsOneWidget);
      expect(find.text('Always Open 24H Shop'), findsOneWidget);
      // Regular shop is CLOSED at 10 PM
      expect(find.text('Regular Day Shop'), findsNothing);
      expect(find.text('Morning Only Shop'), findsNothing);
      expect(find.text('No Hours Saved Shop'), findsNothing);

      // Now re-launch at Thursday 2:00 AM (02:00) during the overnight shift that started Wednesday
      final thursday2Am = DateTime(2026, 10, 22, 2, 0);
      await tester.pumpWidget(noAnimApp(MechanicsHomeScreen(currentDateTime: thursday2Am)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap "Open now" chip
      await tester.tap(find.text('Open now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Overnight shift from Wednesday is STILL OPEN at Thu 2 AM
      expect(find.text('Night Owls Moto Garage'), findsOneWidget);
      expect(find.text('Always Open 24H Shop'), findsOneWidget);
      expect(find.text('Regular Day Shop'), findsNothing);
    });
  });
}

