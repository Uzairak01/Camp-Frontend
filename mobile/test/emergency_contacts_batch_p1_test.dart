import 'package:camp/app/routes.dart';
import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/data/profile_repository_local.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/controllers/profile_controller.dart';
import 'package:camp/features/dashboard/domain/emergency_contact_model.dart';
import 'package:camp/features/dashboard/domain/user_profile_model.dart';
import 'package:camp/features/dashboard/presentation/screens/edit_profile_screen.dart';
import 'package:camp/features/dashboard/presentation/screens/profile_screen.dart';
import 'package:camp/features/emergency_sos/domain/emergency_qr_payload.dart';
import 'package:camp/features/emergency_sos/domain/emergency_sos_helpers.dart';
import 'package:camp/features/emergency_sos/presentation/screens/emergency_qr_screen.dart';
import 'package:camp/features/emergency_sos/presentation/widgets/emergency_contact_card.dart';
import 'package:camp/features/emergency_sos/presentation/widgets/offline_medical_id_card.dart';
import 'package:camp/features/navigation/domain/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLocationService implements LocationService {
  const _FakeLocationService({this.position});
  final PositionData? position;

  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<bool> checkPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<PositionData?> getCurrentPosition() async => position;
  @override
  Future<PositionData?> getLastKnownPosition() async => position;
  @override
  Stream<PositionData> getPositionStream({
    bool highAccuracy = false,
    bool enableForegroundNotification = false,
    bool? forceLocationManager,
  }) async* {
    if (position != null) yield position!;
  }
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProfileRepositoryLocal repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    LocalStore.instance.resetForTesting(prefs);
    repo = ProfileRepositoryLocal(LocalStore.instance);
    AppRepositories.instance = AppRepositories(profileRepository: repo);
    ProfileController.instance.resetForTesting();
    ProfileController.instance.repository = repo;
  });

  group('1. One-time Migration from Legacy Single Contact', () {
    test('UserProfile.fromJson converts legacy contact fields into first EmergencyContact', () {
      final legacyJson = {
        'id': 'user_123',
        'fullName': 'Hamza Ali',
        'emergencyContactName': 'Tariq Ali',
        'emergencyContactRelation': 'Father',
        'emergencyContactPhone': '+923001234567',
        'bloodGroup': 'B+',
      };

      final profile = UserProfile.fromJson(legacyJson);

      expect(profile.emergencyContacts.length, 1);
      final primary = profile.emergencyContacts.first;
      expect(primary.name, 'Tariq Ali');
      expect(primary.relation, 'Father');
      expect(primary.phone, '+923001234567');
      expect(profile.emergencyContactName, 'Tariq Ali');
      expect(profile.emergencyContactRelation, 'Father');
      expect(profile.emergencyContactPhone, '+923001234567');
    });

    test('ProfileRepositoryLocal migrates legacy JSON and writes new emergencyContacts list to store', () async {
      final legacyJson = {
        'id': 'user_migrated',
        'fullName': 'Rider User',
        'emergencyContactName': 'Sonia Khan',
        'emergencyContactRelation': 'Spouse',
        'emergencyContactPhone': '+923219876543',
        'bloodGroup': 'O+',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };

      await LocalStore.instance.writeJson(LocalStore.keyProfile, legacyJson);

      // Loading profile triggers one-time migration and resaves new format
      final loaded = await repo.loadProfile();
      expect(loaded, isNotNull);
      expect(loaded!.emergencyContacts.length, 1);
      expect(loaded.emergencyContacts.first.name, 'Sonia Khan');
      expect(loaded.emergencyContacts.first.phone, '+923219876543');

      // Verify the persisted JSON in store now contains 'emergencyContacts'
      final rawStored = await LocalStore.instance.readJson(LocalStore.keyProfile) as Map<String, dynamic>;
      expect(rawStored['emergencyContacts'], isNotNull);
      final list = rawStored['emergencyContacts'] as List;
      expect(list.length, 1);
      expect(list.first['name'], 'Sonia Khan');
    });
  });

  group('2. Contact Management: Add, Edit, Delete, Make Primary, Max 5 Limit', () {
    test('Add, Edit, Delete and Make Primary work as expected on controller', () async {
      final controller = ProfileController.instance;

      final c1 = EmergencyContact(name: 'Contact 1', phone: '+923001111111', relation: 'Friend');
      final c2 = EmergencyContact(name: 'Contact 2', phone: '+923002222222', relation: 'Brother');
      final c3 = EmergencyContact(name: 'Contact 3', phone: '+923003333333', relation: 'Sister');

      await controller.addEmergencyContact(c1);
      await controller.addEmergencyContact(c2);
      await controller.addEmergencyContact(c3);

      expect(controller.emergencyContacts.length, 3);
      expect(controller.primaryEmergencyContact!.name, 'Contact 1');

      // Make Contact 2 primary
      await controller.setPrimaryEmergencyContact(c2.id);
      expect(controller.primaryEmergencyContact!.name, 'Contact 2');
      expect(controller.emergencyContacts[1].name, 'Contact 1');
      expect(controller.emergencyContacts[2].name, 'Contact 3');

      // Edit Contact 3
      final updatedC3 = c3.copyWith(name: 'Contact 3 Edited', relation: 'Spouse');
      await controller.updateEmergencyContact(updatedC3);
      expect(controller.emergencyContacts.last.name, 'Contact 3 Edited');
      expect(controller.emergencyContacts.last.relation, 'Spouse');

      // Delete Contact 1
      await controller.removeEmergencyContact(c1.id);
      expect(controller.emergencyContacts.length, 2);
      expect(controller.emergencyContacts.any((c) => c.name == 'Contact 1'), isFalse);
    });

    test('Maximum 5 emergency contacts limit is strictly enforced', () async {
      final controller = ProfileController.instance;

      for (int i = 1; i <= 5; i++) {
        await controller.addEmergencyContact(
          EmergencyContact(name: 'Contact $i', phone: '+92300000000$i'),
        );
      }
      expect(controller.emergencyContacts.length, 5);

      // Attempting to add 6th contact is blocked
      await controller.addEmergencyContact(
        EmergencyContact(name: 'Contact 6', phone: '+923000000006'),
      );
      expect(controller.emergencyContacts.length, 5);
      expect(controller.emergencyContacts.any((c) => c.name == 'Contact 6'), isFalse);
    });
  });

  group('3. EditProfileScreen: Validation, Duplicate Phone, UI Actions', () {
    testWidgets('Duplicate phone number is rejected during contact addition', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = ProfileController.instance;
      await tester.runAsync(() async {
        await controller.addEmergencyContact(
          EmergencyContact(name: 'Ali Khan', phone: '+923001234567', relation: 'Brother'),
        );
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EditProfileScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open Add dialog
      final addBtn = find.byKey(const Key('add_another_contact_btn'));
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter same phone number (with formatting spaces)
      await tester.enterText(find.byKey(const Key('input_contact_name')), 'Duplicate Contact');
      await tester.enterText(find.byKey(const Key('input_contact_phone')), '+92 300 1234567');
      await tester.tap(find.byKey(const Key('btn_save_contact')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify rejection error is shown and dialog is still open
      expect(find.text('This phone number is already added'), findsOneWidget);

      // Enter an invalid non-digit phone number
      await tester.enterText(find.byKey(const Key('input_contact_phone')), 'not-a-number');
      await tester.tap(find.byKey(const Key('btn_save_contact')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byWidgetPredicate((w) => w is Text && (w.data?.contains('digits') ?? false)), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Empty state shows Add Contact button and adds contact successfully', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EditProfileScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No emergency contacts yet'), findsOneWidget);

      // Tap Add button in empty state
      final emptyAddBtn = find.byKey(const Key('add_emergency_contact_btn'));
      expect(emptyAddBtn, findsOneWidget);
      await tester.tap(emptyAddBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Submit empty - validates required name and phone
      await tester.tap(find.byKey(const Key('btn_save_contact')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Phone number is required'), findsOneWidget);

      // Enter valid contact
      await tester.enterText(find.byKey(const Key('input_contact_name')), 'Ayesha Khan');
      await tester.enterText(find.byKey(const Key('input_contact_relation')), 'Sister');
      await tester.enterText(find.byKey(const Key('input_contact_phone')), '+923009988776');
      await tester.tap(find.byKey(const Key('btn_save_contact')));
      await tester.pumpAndSettle();

      // Verify added contact appears in list with PRIMARY chip
      expect(find.text('Ayesha Khan'), findsOneWidget);
      expect(find.text('(Sister)'), findsOneWidget);
      expect(find.text('+92 300 9988776'), findsOneWidget);
      expect(find.byKey(const Key('chip_primary_contact')), findsOneWidget);
    });
  });

  group('4. Profile Card Reactive Update and Badge Text', () {
    testWidgets('Badge text displays "Add a contact" when 0 contacts and "SOS ready" when 1+', (tester) async {
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll to Rider Medical & SOS ID Card
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -1200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 0 contacts -> shows "Add a contact" badge
      expect(find.byKey(const Key('badge_add_contact')), findsOneWidget);
      expect(find.text('Add a contact'), findsOneWidget);
      expect(find.text('Emergency Contact Not Set'), findsOneWidget);

      // Add 1 contact and verify reactive update without navigating away
      await tester.runAsync(() async {
        await ProfileController.instance.addEmergencyContact(
          EmergencyContact(name: 'Bilal Khan', relation: 'Brother', phone: '+923001112233'),
        );
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('badge_sos_ready')), findsOneWidget);
      expect(find.text('SOS ready'), findsOneWidget);
      expect(find.text('Bilal Khan (Brother) • +92 300 1112233'), findsOneWidget);

      // Add a 2nd contact -> shows "(+1 more)"
      await tester.runAsync(() async {
        await ProfileController.instance.addEmergencyContact(
          EmergencyContact(name: 'Usman Ali', relation: 'Friend', phone: '+923004445566'),
        );
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Bilal Khan (Brother) • +92 300 1112233 (+1 more)'), findsOneWidget);
    });

    testWidgets('Saving in EditProfileScreen updates ProfileScreen card immediately on pop', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (context) => const ProfileScreen(),
            CampRoutes.editProfile: (context) => const EditProfileScreen(),
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Emergency Contact Not Set'), findsOneWidget);

      // Navigate to EditProfileScreen via badge tap
      await tester.tap(find.byKey(const Key('badge_add_contact')));
      await tester.pumpAndSettle();

      final addBtn = find.byKey(const Key('add_emergency_contact_btn'));
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('input_contact_name')), 'Fatima Noor');
      await tester.enterText(find.byKey(const Key('input_contact_relation')), 'Mother');
      await tester.enterText(find.byKey(const Key('input_contact_country_code')), '92');
      await tester.enterText(find.byKey(const Key('input_contact_phone')), '3005556677');
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_save_contact')));
      await tester.pumpAndSettle();

      // Tap Save Profile app bar action
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // We are back on ProfileScreen: card must reflect saved contact immediately
      expect(find.text('Fatima Noor (Mother) • +92 300 5556677'), findsOneWidget);
      expect(find.text('SOS ready'), findsOneWidget);
    });
  });

  group('5. SOS Medical ID Card & Emergency QR Reactive Updates', () {
    testWidgets('OfflineMedicalIdCard and EmergencyContactCard update reactively when contacts change', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const OfflineMedicalIdCard(),
                  EmergencyContactCard(
                    locationService: _FakeLocationService(
                      position: PositionData(
                        latitude: 31.5204,
                        longitude: 74.3587,
                        timestamp: DateTime.now(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially empty
      expect(find.text('No emergency contact saved'), findsOneWidget);

      // Add emergency contact and blood type
      await tester.runAsync(() async {
        await ProfileController.instance.updateProfile(
          bloodGroup: 'AB+',
          emergencyContacts: [
            EmergencyContact(name: 'Ali Raza', relation: 'Father', phone: '+923001234567'),
            EmergencyContact(name: 'Hassan Raza', relation: 'Brother', phone: '+923007654321'),
          ],
        );
      });
      await tester.pumpAndSettle();

      // EmergencyContactCard reactively displays primary contact and "+1 more" note
      expect(find.text('Ali Raza'), findsOneWidget);
      expect(find.text('Father'), findsOneWidget);
      expect(find.text('+92 300 1234567'), findsOneWidget);
      expect(find.text('+1 more contact will be alerted'), findsOneWidget);

      // OfflineMedicalIdCard displays blood type
      expect(find.text('AB+'), findsOneWidget);
    });

    testWidgets('EmergencyQrScreen reactively updates QR payload when contacts change', (tester) async {
      await tester.runAsync(() async {
        await ProfileController.instance.updateProfile(
          fullName: 'Zain Malik',
          bloodGroup: 'O-',
          allergies: 'None',
          medicalNotes: 'Fit',
          emergencyContacts: [
            EmergencyContact(name: 'Contact One', phone: '+923001111111'),
          ],
        );
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencyQrScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Contact One'), findsWidgets);

      // Add second contact
      await tester.runAsync(() async {
        await ProfileController.instance.addEmergencyContact(
          EmergencyContact(name: 'Contact Two', phone: '+923002222222'),
        );
      });
      await tester.pumpAndSettle();

      // Toggle subtitle indicates multiple contacts
      expect(find.text('Contact One (+1 more)'), findsOneWidget);
    });
  });

  group('6. Emergency Calling & Per-Contact Messaging Format', () {
    test('buildSingleEmergencySmsUri formats single recipient and buildWhatsAppUri formats wa.me', () {
      const phone = '+923001111111';
      const body = 'I need help. My location: https://www.google.com/maps?q=31.5204,74.3587';

      final smsUri = buildSingleEmergencySmsUri(phone, body);
      expect(smsUri.scheme, 'sms');
      expect(smsUri.path, '+923001111111');
      expect(smsUri.queryParameters['body'], body);

      final waUri = buildWhatsAppUri(phone, body);
      expect(waUri.scheme, 'https');
      expect(waUri.host, 'wa.me');
      expect(waUri.path, '/923001111111');
      expect(waUri.queryParameters['text'], body);
    });

    test('EmergencyContactCard uses primary contact for direct phone calls', () {
      final controller = ProfileController.instance;
      final c1 = EmergencyContact(name: 'Primary Contact', phone: '+923001111111');
      final c2 = EmergencyContact(name: 'Secondary Contact', phone: '+923002222222');
      controller.setEmergencyContacts([c1, c2]);

      expect(controller.primaryEmergencyContact!.phone, '+923001111111');
    });
  });

  group('7. Emergency QR Payload Formatting & Limits', () {
    test('EmergencyQrPayloadBuilder formats up to 3 contacts and maintains scannable size', () {
      final contacts = [
        EmergencyContact(name: 'Father', relation: 'Dad', phone: '+923001111111'),
        EmergencyContact(name: 'Mother', relation: 'Mom', phone: '+923002222222'),
        EmergencyContact(name: 'Doctor', relation: 'Physician', phone: '+923003333333'),
        EmergencyContact(name: 'Friend', relation: 'Buddy', phone: '+923004444444'),
      ];

      final result = EmergencyQrPayloadBuilder.build(
        fullName: 'Ahmed Khan',
        bloodGroup: 'A+',
        allergies: 'Penicillin',
        medicalNotes: 'Asthmatic, carries inhaler',
        emergencyContacts: contacts,
      );

      // Verify up to 3 contacts are included
      expect(result.payload, contains('ICE Contact 1: Father (Dad) - +923001111111'));
      expect(result.payload, contains('ICE Contact 2: Mother (Mom) - +923002222222'));
      expect(result.payload, contains('ICE Contact 3: Doctor (Physician) - +923003333333'));
      // 4th contact is not in QR payload to preserve scannability
      expect(result.payload, isNot(contains('ICE Contact 4')));
      expect(result.payload, isNot(contains('Friend')));

      // Must remain within default max length (295 characters)
      expect(result.totalLength, lessThanOrEqualTo(295));
      expect(result.payload.length, lessThanOrEqualTo(295));
    });

    test('EmergencyQrPayloadBuilder formats single contact with legacy ICE Contact label', () {
      final contacts = [
        EmergencyContact(name: 'Sara Khan', relation: 'Spouse', phone: '+923009988776'),
      ];

      final result = EmergencyQrPayloadBuilder.build(
        fullName: 'Ahmed Khan',
        bloodGroup: 'A+',
        allergies: 'None',
        medicalNotes: 'None',
        emergencyContacts: contacts,
      );

      expect(result.payload, contains('ICE Contact: Sara Khan (Spouse) - +923009988776'));
      expect(result.totalLength, lessThanOrEqualTo(295));
    });
  });
}
