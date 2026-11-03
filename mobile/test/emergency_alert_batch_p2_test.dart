import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/data/profile_repository_local.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/controllers/profile_controller.dart';
import 'package:camp/features/dashboard/domain/emergency_contact_model.dart';
import 'package:camp/features/dashboard/domain/emergency_phone_helper.dart';
import 'package:camp/features/dashboard/presentation/screens/edit_profile_screen.dart';
import 'package:camp/features/emergency_sos/domain/emergency_qr_payload.dart';
import 'package:camp/features/emergency_sos/domain/emergency_sos_helpers.dart';
import 'package:camp/features/emergency_sos/presentation/widgets/alert_contacts_bottom_sheet.dart';
import 'package:camp/features/emergency_sos/presentation/widgets/emergency_contact_card.dart';
import 'package:camp/features/navigation/domain/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fake URL launcher tracking all dispatched URIs and simulating failure scenarios.
class _FakeEmergencyUrlLauncher {
  final List<Uri> launchedUris = [];
  bool simulateWhatsAppFailure = false;

  Future<bool> launch(Uri uri, {LaunchMode mode = LaunchMode.externalApplication}) async {
    if (simulateWhatsAppFailure && (uri.scheme == 'whatsapp' || (uri.scheme == 'https' && uri.host == 'wa.me'))) {
      return false;
    }
    launchedUris.add(uri);
    return true;
  }
}

/// Fake location service returning fixed coordinates for deterministic SMS body testing.
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
  GoogleFonts.config.allowRuntimeFetching = false;

  late ProfileRepositoryLocal repo;
  late _FakeEmergencyUrlLauncher fakeLauncher;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await LocalStore.instance.init(prefs);
    repo = ProfileRepositoryLocal(LocalStore.instance);
    AppRepositories.instance = AppRepositories(profileRepository: repo);
    ProfileController.instance.resetForTesting();
    ProfileController.instance.repository = repo;

    fakeLauncher = _FakeEmergencyUrlLauncher();
    setEmergencyUrlLauncherForTesting(fakeLauncher.launch);
    // Simulate the native camp/share channel reporting failure so launchSms falls back
    // to the (faked) url_launcher sms: path that these tests assert on.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('camp/share'), (call) async => false);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('camp/share'), null);
    setEmergencyUrlLauncherForTesting(null);
  });

  group('1. Number Entry, Parsing & Picker Auto-Detection', () {
    test('03212699353 strips leading 0 and combines with 92 picker to form E.164', () {
      final parsed = EmergencyPhoneHelper.parseInput(
        rawInput: '03212699353',
        selectedCountryCode: '92',
      );
      expect(parsed.countryCode, '92');
      expect(parsed.nationalNumber, '3212699353');
      expect(parsed.e164, '+923212699353');
      expect(parsed.isValid, isTrue);
    });

    test('3212699353 combines with 92 picker to form E.164', () {
      final parsed = EmergencyPhoneHelper.parseInput(
        rawInput: '3212699353',
        selectedCountryCode: '92',
      );
      expect(parsed.countryCode, '92');
      expect(parsed.nationalNumber, '3212699353');
      expect(parsed.e164, '+923212699353');
      expect(parsed.isValid, isTrue);
    });

    test('+923212699353 auto-matches 92 picker and extracts national number', () {
      final parsed = EmergencyPhoneHelper.parseInput(
        rawInput: '+923212699353',
      );
      expect(parsed.countryCode, '92');
      expect(parsed.nationalNumber, '3212699353');
      expect(parsed.e164, '+923212699353');
      expect(parsed.hasUnlistedCountryCode, isFalse);
      expect(parsed.isValid, isTrue);
    });

    test('00923212699353 converts leading 00 to + and auto-matches 92', () {
      final parsed = EmergencyPhoneHelper.parseInput(
        rawInput: '00923212699353',
      );
      expect(parsed.countryCode, '92');
      expect(parsed.nationalNumber, '3212699353');
      expect(parsed.e164, '+923212699353');
      expect(parsed.isValid, isTrue);
    });

    test('+92 (321) 269-9353 ignores spaces, dashes, and brackets', () {
      final parsed = EmergencyPhoneHelper.parseInput(
        rawInput: '+92 (321) 269-9353',
      );
      expect(parsed.countryCode, '92');
      expect(parsed.nationalNumber, '3212699353');
      expect(parsed.e164, '+923212699353');
      expect(parsed.isValid, isTrue);
    });

    test('+966 number auto-matches longest country code and extracts national number', () {
      final parsed = EmergencyPhoneHelper.parseInput(
        rawInput: '+966 51 234 5678',
      );
      expect(parsed.countryCode, '966');
      expect(parsed.nationalNumber, '512345678');
      expect(parsed.e164, '+966512345678');
      expect(parsed.isValid, isTrue);

      final parsed00 = EmergencyPhoneHelper.parseInput(
        rawInput: '00966512345678',
      );
      expect(parsed00.countryCode, '966');
      expect(parsed00.nationalNumber, '512345678');
      expect(parsed00.e164, '+966512345678');
    });

    test('Unlisted country code stores as typed with + prefix and flags unlisted', () {
      final parsed = EmergencyPhoneHelper.parseInput(
        rawInput: '+999 12 34 56 78',
      );
      expect(parsed.hasUnlistedCountryCode, isTrue);
      expect(parsed.e164, '+99912345678');
    });

    test('Validation enforces 7 to 12 national digits and digits only', () {
      final shortNum = EmergencyPhoneHelper.parseInput(rawInput: '12345', selectedCountryCode: '+92');
      expect(shortNum.isValidLength, isFalse);

      final longNum = EmergencyPhoneHelper.parseInput(rawInput: '12345678901234', selectedCountryCode: '+92');
      expect(longNum.isValidLength, isFalse);

      final alphaNum = EmergencyPhoneHelper.parseInput(rawInput: '3212699abc', selectedCountryCode: '+92');
      expect(alphaNum.isDigitsOnly, isFalse);

      final validNum = EmergencyPhoneHelper.parseInput(rawInput: '3212699353', selectedCountryCode: '+92');
      expect(validNum.isValid, isTrue);
    });
  });

  group('2. One-time Migration of Already Saved Numbers', () {
    test('Pakistani 03XXXXXXXXX numbers are migrated to +92 3XXXXXXXXX in E.164', () {
      final migrated1 = EmergencyPhoneHelper.migrateLegacyPhoneNumber('03212699353');
      expect(migrated1, '+923212699353');

      final migratedWithDashes = EmergencyPhoneHelper.migrateLegacyPhoneNumber('0321-2699353');
      expect(migratedWithDashes, '+923212699353');
    });

    test('Numbers already starting with + are cleaned and unchanged', () {
      final alreadyPlus = EmergencyPhoneHelper.migrateLegacyPhoneNumber('+923212699353');
      expect(alreadyPlus, '+923212699353');

      final spacedPlus = EmergencyPhoneHelper.migrateLegacyPhoneNumber('+92 321 2699353');
      expect(spacedPlus, '+923212699353');
    });

    test('Other formats are left as is and fail hasValidFormat check', () {
      final weirdNumber = EmergencyPhoneHelper.migrateLegacyPhoneNumber('12345');
      expect(weirdNumber, '12345');
      expect(EmergencyPhoneHelper.hasValidFormat(weirdNumber), isFalse);
    });

    test('UserProfile.fromJson and ProfileRepositoryLocal auto-migrate and persist', () async {
      final legacyJson = {
        'id': 'user_migration_test',
        'fullName': 'Rider Test',
        'emergencyContacts': [
          {
            'id': 'c1',
            'name': 'Kamran',
            'relation': 'Brother',
            'phone': '03212699353',
          },
          {
            'id': 'c2',
            'name': 'Zain',
            'relation': 'Friend',
            'phone': '+966512345678',
          },
        ],
      };

      await LocalStore.instance.writeJson(LocalStore.keyProfile, legacyJson);

      final loadedProfile = await repo.loadProfile();
      expect(loadedProfile, isNotNull);
      expect(loadedProfile!.emergencyContacts[0].phone, '+923212699353');
      expect(loadedProfile.emergencyContacts[1].phone, '+966512345678');

      // Verify that disk store received the migrated format
      final reloadedRaw = await LocalStore.instance.readJson(LocalStore.keyProfile) as Map;
      final reloadedContacts = reloadedRaw['emergencyContacts'] as List;
      expect(reloadedContacts[0]['phone'], '+923212699353');
    });
  });

  group('3. Display Numbers in Readable Form', () {
    test('formatPhoneReadable displays Pakistani numbers as +92 3XX XXXXXXX', () {
      final formatted = EmergencyPhoneHelper.formatPhoneReadable('+923212699353');
      expect(formatted, '+92 321 2699353');
    });

    test('formatPhoneReadable displays Saudi numbers as +966 5X XXX XXXX', () {
      final formatted = EmergencyPhoneHelper.formatPhoneReadable('+966512345678');
      expect(formatted, '+966 51 234 5678');
    });

    testWidgets('EditProfileScreen displays "Check number format" hint for malformed numbers', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = ProfileController.instance;
      controller.setEmergencyContacts([
        EmergencyContact(name: 'Broken Contact', phone: '12345'),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EditProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Check number format'), findsOneWidget);
    });
  });

  group('4. Alert Contacts Bottom Sheet is always shown when contacts exist', () {
    testWidgets('With exactly 1 contact, Alert my contacts opens the sheet instead of launching directly', (tester) async {
      final controller = ProfileController.instance;
      controller.setEmergencyContacts([
        EmergencyContact(name: 'Single Contact', phone: '+923212699353'),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmergencyContactCard(
              locationService: _FakeLocationService(
                position: PositionData(
                  latitude: 31.5204,
                  longitude: 74.3587,
                  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Alert my contacts"
      await tester.tap(find.text('Alert my contacts'));
      await tester.pumpAndSettle();

      // Batch P-4b: the sheet is shown even for a single contact; nothing launches yet.
      expect(find.byKey(const Key('alert_contacts_bottom_sheet')), findsOneWidget);
      expect(fakeLauncher.launchedUris, isEmpty);

      // Tapping the row's SMS button then launches the single-recipient sms: fallback
      // (no channel handler is registered in this test, so the channel call fails).
      await tester.tap(find.byKey(Key('btn_sms_${controller.emergencyContacts.first.id}')));
      await tester.pumpAndSettle();
      expect(fakeLauncher.launchedUris.length, 1);
      final launched = fakeLauncher.launchedUris.first;
      expect(launched.scheme, 'sms');
      expect(launched.path, '+923212699353');
      expect(launched.queryParameters['body'], contains('https://www.google.com/maps?q=31.5204,74.3587'));
    });

    testWidgets('With 2+ contacts, Alert my contacts opens the Alert contacts bottom sheet', (tester) async {
      final controller = ProfileController.instance;
      controller.setEmergencyContacts([
        EmergencyContact(name: 'Primary Contact', relation: 'Father', phone: '+923212699353'),
        EmergencyContact(name: 'Secondary Contact', relation: 'Brother', phone: '+923001112233'),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmergencyContactCard(
              locationService: _FakeLocationService(
                position: PositionData(
                  latitude: 31.5204,
                  longitude: 74.3587,
                  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Alert my contacts"
      await tester.tap(find.text('Alert my contacts'));
      await tester.pumpAndSettle();

      // Bottom sheet is displayed
      expect(find.byKey(const Key('alert_contacts_bottom_sheet')), findsOneWidget);
      expect(find.text('Alert Contacts'), findsOneWidget);
      expect(find.text('SMS everyone in turn'), findsOneWidget);
    });
  });

  group('5. Per-Contact SMS & WhatsApp Dispatch and "Opened" Tracking', () {
    testWidgets('Individual SMS button builds single-recipient sms: URI and marks row Opened', (tester) async {
      final contacts = [
        EmergencyContact(id: 'c1', name: 'Zeeshan Ali', relation: 'Friend', phone: '+923212699353'),
        EmergencyContact(id: 'c2', name: 'Fatima Noor', relation: 'Sister', phone: '+923005556677'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlertContactsBottomSheet(
              contacts: contacts,
              messageBody: 'I need help. My location: https://www.google.com/maps?q=31.5204,74.3587',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap SMS button for first contact
      await tester.tap(find.byKey(const Key('btn_sms_c1')));
      await tester.pumpAndSettle();

      expect(fakeLauncher.launchedUris.length, 1);
      final uri = fakeLauncher.launchedUris.first;
      expect(uri.scheme, 'sms');
      expect(uri.path, '+923212699353');
      expect(uri.queryParameters['body'], contains('https://www.google.com/maps?q=31.5204,74.3587'));

      // First row displays "Opened" chip, second does not
      expect(find.byKey(const Key('chip_opened_c1')), findsOneWidget);
      expect(find.byKey(const Key('chip_opened_c2')), findsNothing);
    });

    testWidgets('WhatsApp button builds wa.me or native link with digits only (no + or spaces)', (tester) async {
      final contacts = [
        EmergencyContact(id: 'c1', name: 'Ayesha', phone: '+92 321 2699353'),
        EmergencyContact(id: 'c2', name: 'Bilal', phone: '+966 51 234 5678'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlertContactsBottomSheet(
              contacts: contacts,
              messageBody: 'I need help.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap WhatsApp for first contact
      await tester.tap(find.byKey(const Key('btn_wa_c1')));
      await tester.pumpAndSettle();

      expect(fakeLauncher.launchedUris.length, 1);
      final waUri = fakeLauncher.launchedUris.first;
      expect(waUri.scheme == 'whatsapp' || waUri.scheme == 'https', isTrue);
      expect(waUri.toString(), contains('923212699353'));
      expect(find.byKey(const Key('chip_opened_c1')), findsOneWidget);

      // Tap WhatsApp for second contact (+966)
      await tester.tap(find.byKey(const Key('btn_wa_c2')));
      await tester.pumpAndSettle();

      expect(fakeLauncher.launchedUris.length, 2);
      final waUri2 = fakeLauncher.launchedUris.last;
      expect(waUri2.toString(), contains('966512345678'));
      expect(find.byKey(const Key('chip_opened_c2')), findsOneWidget);
    });

    testWidgets('WhatsApp launch failure shows "WhatsApp is not installed on this phone." and does not mark Opened', (tester) async {
      fakeLauncher.simulateWhatsAppFailure = true;

      final contacts = [
        EmergencyContact(id: 'c1', name: 'Tariq', phone: '+923212699353'),
        EmergencyContact(id: 'c2', name: 'Zubair', phone: '+923001112233'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlertContactsBottomSheet(
              contacts: contacts,
              messageBody: 'I need help.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_wa_c1')));
      await tester.pumpAndSettle();

      // Error message shown
      expect(find.text('WhatsApp is not installed on this phone.'), findsOneWidget);
      // Row is NOT marked Opened
      expect(find.byKey(const Key('chip_opened_c1')), findsNothing);
    });

    testWidgets('SMS everyone in turn opens contacts sequentially in order', (tester) async {
      final contacts = [
        EmergencyContact(id: 'c1', name: 'Primary', phone: '+923001111111'),
        EmergencyContact(id: 'c2', name: 'Second', phone: '+923002222222'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlertContactsBottomSheet(
              contacts: contacts,
              messageBody: 'Test emergency location',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "SMS everyone in turn"
      await tester.tap(find.byKey(const Key('btn_sms_everyone_in_turn')));
      await tester.pumpAndSettle();

      // First contact launched immediately
      expect(fakeLauncher.launchedUris.length, 1);
      expect(fakeLauncher.launchedUris.first.path, '+923001111111');
      expect(find.byKey(const Key('chip_opened_c1')), findsOneWidget);

      // Simulate rider returning to CAMP from the first SMS app
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Second contact launched automatically upon return
      expect(fakeLauncher.launchedUris.length, 2);
      expect(fakeLauncher.launchedUris.last.path, '+923002222222');
      expect(find.byKey(const Key('chip_opened_c2')), findsOneWidget);
    });
  });

  group('6. Emergency QR Payload & Decoding Verification', () {
    test('QR payload uses raw E.164 phone numbers and decodes properly', () {
      final contacts = [
        EmergencyContact(name: 'Father', relation: 'Dad', phone: '+923212699353'),
        EmergencyContact(name: 'Mother', relation: 'Mom', phone: '+923005556677'),
      ];

      final result = EmergencyQrPayloadBuilder.build(
        fullName: 'Hamza Khan',
        bloodGroup: 'O+',
        allergies: 'None',
        medicalNotes: 'No past medical conditions',
        emergencyContacts: contacts,
      );

      // Verifies E.164 strings are present
      expect(result.payload, contains('ICE Contact 1: Father (Dad) - +923212699353'));
      expect(result.payload, contains('ICE Contact 2: Mother (Mom) - +923005556677'));
      expect(result.totalLength, lessThanOrEqualTo(295));

      // QR encoding test
      final validation = QrValidator.validate(
        data: result.payload,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.Q,
      );
      expect(validation.status, QrValidationStatus.valid);
      expect(validation.qrCode, isNotNull);
    });
  });
}
