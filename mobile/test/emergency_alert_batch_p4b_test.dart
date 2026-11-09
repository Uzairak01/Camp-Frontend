import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/data/profile_repository_local.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/controllers/profile_controller.dart';
import 'package:camp/features/dashboard/domain/emergency_contact_model.dart';
import 'package:camp/features/emergency_sos/domain/emergency_sos_helpers.dart';
import 'package:camp/features/emergency_sos/presentation/widgets/alert_contacts_bottom_sheet.dart';
import 'package:camp/features/emergency_sos/presentation/widgets/emergency_contact_card.dart';
import 'package:camp/features/emergency_sos/presentation/widgets/sos_hold_button.dart';
import 'package:camp/features/navigation/domain/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fake `camp/share` channel recording every call made by the emergency helpers.
class _FakeShareChannel {
  /// Value returned for `openSms`; false simulates a native failure.
  bool openSmsResult = true;

  /// Value returned for `shareText`.
  bool shareTextResult = true;

  /// Every `openSms` argument map received, in order.
  final List<Map<Object?, Object?>> openSmsCalls = [];

  /// Every `shareText` argument map received, in order.
  final List<Map<Object?, Object?>> shareTextCalls = [];

  Future<Object?> handle(MethodCall call) async {
    final args = Map<Object?, Object?>.from(call.arguments as Map);
    if (call.method == 'openSms') {
      openSmsCalls.add(args);
      return openSmsResult;
    }
    if (call.method == 'shareText') {
      shareTextCalls.add(args);
      return shareTextResult;
    }
    throw MissingPluginException();
  }
}

/// Fake url_launcher replacement recording the URIs it receives.
class _FakeUrlLauncher {
  final List<Uri> launched = [];

  Future<bool> launch(Uri uri, {LaunchMode mode = LaunchMode.externalApplication}) async {
    launched.add(uri);
    return true;
  }
}

/// Fake location service with a fixed (or missing) GPS fix.
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

PositionData _fix() => PositionData(
      latitude: 31.5204,
      longitude: 74.3587,
      timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const channel = MethodChannel('camp/share');
  late _FakeShareChannel fakeChannel;
  late _FakeUrlLauncher fakeLauncher;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await LocalStore.instance.init(prefs);
    final repo = ProfileRepositoryLocal(LocalStore.instance);
    AppRepositories.instance = AppRepositories(profileRepository: repo);
    ProfileController.instance.resetForTesting();
    ProfileController.instance.repository = repo;

    fakeChannel = _FakeShareChannel();
    fakeLauncher = _FakeUrlLauncher();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, fakeChannel.handle);
    setEmergencyUrlLauncherForTesting(fakeLauncher.launch);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    setEmergencyUrlLauncherForTesting(null);
  });

  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('P-4b launchSms / shareAlert helpers', () {
    test('launchSms calls openSms with exactly one number and the body', () async {
      const body = 'I need help. My location: https://www.google.com/maps?q=31.5204,74.3587';
      final ok = await launchSms('+92 321-2699353', body);

      expect(ok, isTrue);
      expect(fakeChannel.openSmsCalls.length, 1);
      expect(fakeChannel.openSmsCalls.first['number'], '+923212699353');
      expect(fakeChannel.openSmsCalls.first['body'], body);
      // The implicit url_launcher path must not be used when the channel succeeds.
      expect(fakeLauncher.launched, isEmpty);
    });

    test('channel returning false falls back to the url_launcher sms: link', () async {
      fakeChannel.openSmsResult = false;
      final ok = await launchSms('+923212699353', 'I need help.');

      expect(ok, isTrue);
      expect(fakeChannel.openSmsCalls.length, 1);
      expect(fakeLauncher.launched.length, 1);
      expect(fakeLauncher.launched.first.scheme, 'sms');
      expect(fakeLauncher.launched.first.path, '+923212699353');
    });

    test('shareAlert calls shareText with the body and reports the result', () async {
      expect(await shareAlert('hello body'), isTrue);
      expect(fakeChannel.shareTextCalls.single['body'], 'hello body');

      fakeChannel.shareTextResult = false;
      expect(await shareAlert('again'), isFalse);
    });

    test('message body always has the location link or "location not available yet"', () {
      expect(
        buildEmergencySmsBody(_fix()),
        contains('https://www.google.com/maps?q=31.5204,74.3587'),
      );
      expect(buildEmergencySmsBody(null), contains('location not available yet'));
    });
  });

  group('P-4b sheet is always shown when contacts exist', () {
    testWidgets('Alert my contacts shows the sheet for exactly 1 contact', (tester) async {
      useTallViewport(tester);
      ProfileController.instance.setEmergencyContacts([
        EmergencyContact(id: 'c1', name: 'Solo', phone: '+923212699353'),
      ]);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EmergencyContactCard(locationService: _FakeLocationService(position: _fix())),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alert my contacts'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('alert_contacts_bottom_sheet')), findsOneWidget);
      expect(fakeChannel.openSmsCalls, isEmpty);
      expect(fakeLauncher.launched, isEmpty);
    });

    testWidgets('Alert my contacts shows the sheet for 3 contacts', (tester) async {
      useTallViewport(tester);
      ProfileController.instance.setEmergencyContacts([
        EmergencyContact(id: 'c1', name: 'One', phone: '+923212699353'),
        EmergencyContact(id: 'c2', name: 'Two', phone: '+923001112233'),
        EmergencyContact(id: 'c3', name: 'Three', phone: '+966512345678'),
      ]);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EmergencyContactCard(locationService: _FakeLocationService(position: _fix())),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alert my contacts'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('alert_contacts_bottom_sheet')), findsOneWidget);
      expect(find.byKey(const Key('btn_other_c3')), findsOneWidget);
    });

    testWidgets('3-second hold shows the sheet for 1 contact and for 3 contacts', (tester) async {
      useTallViewport(tester);

      for (final count in [1, 3]) {
        ProfileController.instance.setEmergencyContacts([
          for (var i = 1; i <= count; i++)
            EmergencyContact(id: 'h$count$i', name: 'Hold $i', phone: '+92300000000$i'),
        ]);

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SosHoldButton(locationService: _FakeLocationService(position: _fix())),
            ),
          ),
        ));
        await tester.pump();

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(CircularProgressIndicator).first),
        );
        // First pump lets the tap-down deadline fire so the hold animation starts.
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(seconds: 4));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('alert_contacts_bottom_sheet')), findsOneWidget);
        expect(fakeChannel.openSmsCalls, isEmpty);

        // Dismiss the sheet before the next iteration.
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('3-second hold with no contacts shows the snackbar with an Add button', (tester) async {
      useTallViewport(tester);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SosHoldButton(locationService: _FakeLocationService(position: _fix())),
          ),
        ),
      ));
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CircularProgressIndicator).first),
      );
      // First pump lets the tap-down deadline fire so the hold animation starts.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(seconds: 4));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('No emergency contact saved. Please add one in your profile.'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.byKey(const Key('alert_contacts_bottom_sheet')), findsNothing);
    });
  });

  group('P-4b sheet buttons', () {
    testWidgets('Other apps calls shareText with the same body and marks Opened', (tester) async {
      useTallViewport(tester);
      const body = 'I need help. My location: location not available yet';
      final contacts = [
        EmergencyContact(id: 'c1', name: 'Ayesha', phone: '+923212699353'),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AlertContactsBottomSheet(contacts: contacts, messageBody: body),
        ),
      ));
      await tester.pumpAndSettle();

      // The hint tells the rider to pick the person inside the other app.
      expect(find.byKey(const Key('hint_other_c1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_other_c1')));
      await tester.pumpAndSettle();

      expect(fakeChannel.shareTextCalls.single['body'], body);
      expect(find.byKey(const Key('chip_opened_c1')), findsOneWidget);
    });

    testWidgets('Other apps failure shows a message and does not mark Opened', (tester) async {
      useTallViewport(tester);
      fakeChannel.shareTextResult = false;
      final contacts = [
        EmergencyContact(id: 'c1', name: 'Ayesha', phone: '+923212699353'),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AlertContactsBottomSheet(contacts: contacts, messageBody: 'x'),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_other_c1')));
      await tester.pumpAndSettle();

      expect(find.text('Could not open the share menu.'), findsOneWidget);
      expect(find.byKey(const Key('chip_opened_c1')), findsNothing);
    });

    testWidgets('SMS button and SMS everyone in turn go through openSms with one number', (tester) async {
      useTallViewport(tester);
      final contacts = [
        EmergencyContact(id: 'c1', name: 'Ayesha', phone: '+923212699353'),
        EmergencyContact(id: 'c2', name: 'Bilal', phone: '+966512345678'),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AlertContactsBottomSheet(contacts: contacts, messageBody: 'body'),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_sms_c2')));
      await tester.pumpAndSettle();
      expect(fakeChannel.openSmsCalls.single['number'], '+966512345678');

      await tester.tap(find.byKey(const Key('btn_sms_everyone_in_turn')));
      await tester.pumpAndSettle();
      expect(fakeChannel.openSmsCalls.length, 2);
      expect(fakeChannel.openSmsCalls.last['number'], '+923212699353');
      expect(fakeLauncher.launched, isEmpty);
    });
  });
}

