import 'package:camp/app/routes.dart';
import 'package:camp/core/data/bike_repository_local.dart';
import 'package:camp/core/data/settings_repository_local.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/presentation/screens/profile_screen.dart';
import 'package:camp/features/emergency_sos/domain/emergency_qr_payload.dart';
import 'package:camp/features/emergency_sos/presentation/screens/emergency_qr_screen.dart';
import 'package:camp/features/emergency_sos/presentation/widgets/offline_medical_id_card.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/settings/controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const testBikeWithPlate = Bike(
  id: 'bike-1',
  make: 'BMW',
  modelName: 'R 1250 GS Adventure',
  modelYear: 2023,
  odometerKm: 14820,
  plateNumber: 'LEB-20-4567',
  color: 'Triple Black',
);

const testBikeNoPlate = Bike(
  id: 'bike-2',
  make: 'Honda',
  modelName: 'Africa Twin',
  modelYear: 2024,
  odometerKm: 4200,
  color: 'Grand Prix Red',
);

void main() {
  setUp(() {
    final store = LocalStore();
    SettingsController.instance.resetForTesting();
    ActiveBikeController.instance.reset();
    SettingsController.instance.repository = SettingsRepositoryLocal(store);
    ActiveBikeController.instance.repository = BikeRepositoryLocal(store);
  });

  group('1. Emergency QR Payload Generation', () {

    test('Payload WITH a bike and plate includes "Bike: <make model>, <plate>"', () {
      final result = EmergencyQrPayloadBuilder.build(
        fullName: 'Elena Vance',
        bloodGroup: 'O+',
        allergies: 'Penicillin',
        medicalNotes: 'Asthmatic, carries inhaler',
        emergencyContactName: 'Marcus Vance',
        emergencyContactPhone: '+1-555-0199',
        emergencyContactRelation: 'Spouse',
        bike: testBikeWithPlate,
        includeBike: true,
      );

      expect(result.payload, contains('CAMP EMERGENCY MEDICAL ID'));
      expect(result.payload, contains('Name: Elena Vance'));
      expect(result.payload, contains('Blood Type: O+'));
      expect(result.payload, contains('Allergies: Penicillin'));
      expect(result.payload, contains('Medical Notes: Asthmatic, carries inhaler'));
      expect(result.payload, contains('ICE Contact: Marcus Vance (Spouse) - +1-555-0199'));
      expect(result.payload, contains('Bike: BMW R 1250 GS Adventure, LEB-20-4567'));
      expect(result.isNotesTruncated, isFalse);
    });

    test('Payload WITH a bike without plate includes "Bike: <make model>"', () {
      final result = EmergencyQrPayloadBuilder.build(
        fullName: 'Elena Vance',
        bloodGroup: 'O+',
        allergies: 'None',
        medicalNotes: 'No existing conditions',
        emergencyContactName: 'Marcus Vance',
        emergencyContactPhone: '+1-555-0199',
        emergencyContactRelation: 'Brother',
        bike: testBikeNoPlate,
        includeBike: true,
      );

      expect(result.payload, contains('Bike: Honda Africa Twin'));
      expect(result.payload, isNot(contains('Bike: Honda Africa Twin,')));
      expect(result.isNotesTruncated, isFalse);
    });

    test('Payload WITHOUT a bike leaves the bike line out of the payload', () {
      final result = EmergencyQrPayloadBuilder.build(
        fullName: 'Elena Vance',
        bloodGroup: 'O+',
        allergies: 'None',
        medicalNotes: 'None',
        emergencyContactName: 'Marcus Vance',
        emergencyContactPhone: '+1-555-0199',
        emergencyContactRelation: 'Brother',
        bike: null,
        includeBike: true,
      );

      expect(result.payload, isNot(contains('Bike:')));
    });

    test('Payload with the toggle OFF leaves the bike line out of the payload', () {
      final result = EmergencyQrPayloadBuilder.build(
        fullName: 'Elena Vance',
        bloodGroup: 'O+',
        allergies: 'None',
        medicalNotes: 'None',
        emergencyContactName: 'Marcus Vance',
        emergencyContactPhone: '+1-555-0199',
        emergencyContactRelation: 'Brother',
        bike: testBikeWithPlate,
        includeBike: false,
      );

      expect(result.payload, isNot(contains('Bike:')));
      expect(result.bikeLine, isNull);
    });

    test('Payload exceeding length cap shortens medical notes first and flags truncation', () {
      const veryLongNotes =
          'Patient has severe allergy to NSAIDs, penicillin, and sulfa drugs. '
          'Requires immediate administration of epinephrine auto-injector upon anaphylaxis. '
          'Has previous surgical history for right tibia fixation. Type 1 diabetic using continuous glucose monitor.';

      final result = EmergencyQrPayloadBuilder.build(
        fullName: 'Elena Vance',
        bloodGroup: 'O-',
        allergies: 'Penicillin, Sulfa, Aspirin',
        medicalNotes: veryLongNotes,
        emergencyContactName: 'Marcus Alexander Vance',
        emergencyContactPhone: '+92-300-1234567',
        emergencyContactRelation: 'Emergency Contact',
        bike: testBikeWithPlate,
        includeBike: true,
        maxLength: 280,
      );

      expect(result.totalLength, lessThanOrEqualTo(280));
      expect(result.isNotesTruncated, isTrue);
      expect(result.payload, contains('Medical Notes:'));
      expect(result.payload, contains('...'));
      expect(result.payload, contains('Bike: BMW R 1250 GS Adventure, LEB-20-4567'));
    });
  });

  group('2. Bike Model JSON Round-Trip with and without plate/colour', () {
    test('Round-trip WITH plate and color', () {
      const bike = Bike(
        id: 'bike-pk-1',
        make: 'Yamaha',
        modelName: 'YBR 125G',
        modelYear: 2024,
        odometerKm: 3500,
        plateNumber: 'KHI-24-9012',
        color: 'Matte Blue',
      );

      final json = bike.toJson();
      expect(json['plateNumber'], 'KHI-24-9012');
      expect(json['color'], 'Matte Blue');

      final reconstructed = Bike.fromJson(json);
      expect(reconstructed.id, 'bike-pk-1');
      expect(reconstructed.make, 'Yamaha');
      expect(reconstructed.modelName, 'YBR 125G');
      expect(reconstructed.plateNumber, 'KHI-24-9012');
      expect(reconstructed.color, 'Matte Blue');
      expect(reconstructed.colour, 'Matte Blue');
    });

    test('Round-trip WITHOUT plate and color (tolerant of nulls / old records)', () {
      const bike = Bike(
        id: 'bike-old',
        make: 'Honda',
        modelName: 'CD 70',
        modelYear: 2020,
        odometerKm: 12000,
      );

      final json = bike.toJson();
      expect(json['plateNumber'], isNull);
      expect(json['color'], isNull);

      final reconstructed = Bike.fromJson(json);
      expect(reconstructed.plateNumber, isNull);
      expect(reconstructed.color, isNull);
      expect(reconstructed.colour, isNull);
    });

    test('Tolerant of legacy keys like licensePlate and colour in fromJson', () {
      final legacyJson = <String, dynamic>{
        'id': 'bike-legacy',
        'make': 'Suzuki',
        'modelName': 'GS 150',
        'modelYear': 2021,
        'odometerKm': 8500,
        'licensePlate': 'LEB-21-9988',
        'colour': 'Classic Red',
      };

      final bike = Bike.fromJson(legacyJson);
      expect(bike.plateNumber, 'LEB-21-9988');
      expect(bike.color, 'Classic Red');
      expect(bike.colour, 'Classic Red');
    });
  });

  group('3. Navigation: Both entry points navigate to the SAME Emergency QR Screen', () {
    Widget buildTestApp({required Widget home}) {
      return MaterialApp(
        routes: {
          CampRoutes.emergencyQr: (context) => const EmergencyQrScreen(),
          CampRoutes.profile: (context) => const ProfileScreen(),
          CampRoutes.addMotorcycle: (context) => const Scaffold(body: Text('Add Motorcycle Screen')),
          CampRoutes.editProfile: (context) => const Scaffold(body: Text('Edit Profile Screen')),
        },
        home: home,
      );
    }

    testWidgets('Profile screen QR button navigates to EmergencyQrScreen via CampRoutes.emergencyQr',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(home: const ProfileScreen()));
      await tester.pumpAndSettle();

      // Find QR icon next to Edit Profile
      final qrButtonFinder = find.byIcon(Icons.qr_code_2_rounded);
      expect(qrButtonFinder, findsOneWidget);

      await tester.tap(qrButtonFinder);
      await tester.pumpAndSettle();

      // Verify we arrived at EmergencyQrScreen
      expect(find.byType(EmergencyQrScreen), findsOneWidget);
      expect(find.text('Emergency QR'), findsOneWidget);
      expect(find.text('CAMP EMERGENCY MEDICAL ID'), findsOneWidget);
    });

    testWidgets('OfflineMedicalIdCard Emergency QR button navigates to EmergencyQrScreen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestApp(
          home: const Scaffold(
            body: SingleChildScrollView(
              child: OfflineMedicalIdCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final emergencyQrButtonFinder = find.text('Emergency QR');
      expect(emergencyQrButtonFinder, findsOneWidget);

      await tester.tap(emergencyQrButtonFinder);
      await tester.pumpAndSettle();

      // Verify we arrived at the exact same EmergencyQrScreen
      expect(find.byType(EmergencyQrScreen), findsOneWidget);
      expect(find.text('Emergency QR'), findsOneWidget);
      expect(find.text('CAMP EMERGENCY MEDICAL ID'), findsOneWidget);
    });
  });

  group('4. EmergencyQrScreen UI & Settings Toggle', () {
    Widget buildQrApp() {
      return MaterialApp(
        routes: {
          CampRoutes.emergencyQr: (context) => const EmergencyQrScreen(),
          CampRoutes.addMotorcycle: (context) => const Scaffold(body: Text('Add Motorcycle Screen')),
          CampRoutes.editProfile: (context) => const Scaffold(body: Text('Edit Profile Screen')),
        },
        home: const EmergencyQrScreen(),
      );
    }

    testWidgets('Displays active bike line and details when toggle is ON', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      ActiveBikeController.instance.addBike(testBikeWithPlate, setActive: true);

      await tester.pumpWidget(buildQrApp());
      await tester.pumpAndSettle();

      expect(find.text('Bike details in QR'), findsOneWidget);
      expect(find.text('BMW R 1250 GS Adventure (2023)'), findsOneWidget);
      expect(find.text('LEB-20-4567'), findsOneWidget);
    });

    testWidgets('Toggling bike details OFF removes bike line and persists in SettingsController',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      ActiveBikeController.instance.addBike(testBikeWithPlate, setActive: true);

      await tester.pumpWidget(buildQrApp());
      await tester.pumpAndSettle();

      final switchFinder = find.byKey(const Key('switch_bike_details'));
      expect(switchFinder, findsOneWidget);

      // Toggle off
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(SettingsController.instance.showBikeOnEmergencyQr, isFalse);
      expect(find.text('LEB-20-4567'), findsNothing);
    });

    testWidgets('Displays hint when active bike has no plate', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Add bike without plate and set active
      const noPlateBike = Bike(
        id: 'no-plate-1',
        make: 'Ducati',
        modelName: 'DesertX',
        modelYear: 2024,
        odometerKm: 1200,
      );
      ActiveBikeController.instance.addBike(noPlateBike, setActive: true);

      await tester.pumpWidget(buildQrApp());
      await tester.pumpAndSettle();

      expect(find.text('Ducati DesertX (2024)'), findsOneWidget);
      expect(find.text('Add your plate number to help identify the bike'), findsOneWidget);
    });
  });
}
