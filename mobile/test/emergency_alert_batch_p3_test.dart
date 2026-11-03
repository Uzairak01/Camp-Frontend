import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/data/profile_repository_local.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/controllers/profile_controller.dart';
import 'package:camp/features/dashboard/domain/emergency_contact_model.dart';
import 'package:camp/features/dashboard/domain/emergency_phone_helper.dart';
import 'package:camp/features/dashboard/presentation/screens/edit_profile_screen.dart';
import 'package:camp/features/emergency_sos/domain/emergency_sos_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late ProfileRepositoryLocal repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await LocalStore.instance.init(prefs);
    repo = ProfileRepositoryLocal(LocalStore.instance);
    AppRepositories.instance = AppRepositories(profileRepository: repo);
    ProfileController.instance.resetForTesting();
    ProfileController.instance.repository = repo;
    await ProfileController.instance.load();
  });

  tearDown(() {
    setEmergencyUrlLauncherForTesting(null);
  });

  group('BATCH P-3 Unit Tests: Phone Helper, Splitting & Validation', () {
    test('03212699353 with code 92 -> +923212699353; 3212699353 with code 92 -> same', () {
      final parsedWithZero = EmergencyPhoneHelper.parseInput(
        rawInput: '03212699353',
        selectedCountryCode: '92',
      );
      final parsedWithoutZero = EmergencyPhoneHelper.parseInput(
        rawInput: '3212699353',
        selectedCountryCode: '92',
      );

      expect(parsedWithZero.e164, '+923212699353');
      expect(parsedWithoutZero.e164, '+923212699353');
      expect(parsedWithZero.e164, parsedWithoutZero.e164);
      expect(parsedWithZero.nationalNumber, '3212699353');
      expect(parsedWithoutZero.nationalNumber, '3212699353');
      expect(parsedWithZero.isValid, isTrue);
      expect(parsedWithoutZero.isValid, isTrue);
    });

    test('pasted +923212699353 with an empty code box splits correctly', () {
      final split = EmergencyPhoneHelper.trySplitPastedNumber('+923212699353');
      expect(split, isNotNull);
      expect(split!.countryCode, '92');
      expect(split.nationalNumber, '3212699353');

      // Also verify 00 prefix
      final split00 = EmergencyPhoneHelper.trySplitPastedNumber('00923212699353');
      expect(split00, isNotNull);
      expect(split00!.countryCode, '92');
      expect(split00.nationalNumber, '3212699353');
    });

    test('pasted +966501234567 splits to code 966', () {
      final split = EmergencyPhoneHelper.trySplitPastedNumber('+966501234567');
      expect(split, isNotNull);
      expect(split!.countryCode, '966');
      expect(split.nationalNumber, '501234567');
    });

    test('existing contacts reopen with code and national number split correctly', () {
      final pakSplit = EmergencyPhoneHelper.splitE164('+923212699353');
      expect(pakSplit.countryCode, '92');
      expect(pakSplit.nationalNumber, '3212699353');

      final saudiSplit = EmergencyPhoneHelper.splitE164('+966501234567');
      expect(saudiSplit.countryCode, '966');
      expect(saudiSplit.nationalNumber, '501234567');

      final usSplit = EmergencyPhoneHelper.splitE164('+15551234567');
      expect(usSplit.countryCode, '1');
      expect(usSplit.nationalNumber, '5551234567');
    });

    test('digits extraction for WhatsApp strips +, spaces, and leading zeros', () {
      expect(EmergencyPhoneHelper.extractE164Digits('+923212699353'), '923212699353');
      expect(EmergencyPhoneHelper.extractE164Digits('+92 321 2699353'), '923212699353');
      expect(EmergencyPhoneHelper.extractE164Digits('03212699353'), '923212699353');
      expect(EmergencyPhoneHelper.extractE164Digits('+9203212699353'), '923212699353');
      expect(EmergencyPhoneHelper.extractE164Digits('00923212699353'), '923212699353');
      expect(EmergencyPhoneHelper.extractE164Digits('+966501234567'), '966501234567');
    });
  });

  group('BATCH P-3 Unit Tests: WhatsApp Link Check & URI Builders', () {
    test('wa.me builder output for examples: digits only, no leading 0, no +', () {
      const message = 'I need help. My location: https://www.google.com/maps?q=31.5204,74.3587';
      final waUriPak = buildWhatsAppWebUri('+923212699353', message);

      expect(waUriPak.scheme, 'https');
      expect(waUriPak.host, 'wa.me');
      expect(waUriPak.path, '/923212699353');
      expect(waUriPak.path.contains('+'), isFalse);
      expect(waUriPak.path.contains(' '), isFalse);
      expect(waUriPak.path.startsWith('/0'), isFalse);
      expect(waUriPak.queryParameters['text'], message);

      final waUriSaudi = buildWhatsAppWebUri('+966501234567', message);
      expect(waUriSaudi.path, '/966501234567');
      expect(waUriSaudi.path.contains('+'), isFalse);
    });

    test('native whatsapp:// scheme builder output: phone has digits only and text is URL encoded', () {
      const message = 'I need help. My location: https://www.google.com/maps?q=31.5204,74.3587';
      final nativeUri = buildWhatsAppNativeUri('+923212699353', message);

      expect(nativeUri.scheme, 'whatsapp');
      expect(nativeUri.host, 'send');
      expect(nativeUri.queryParameters['phone'], '923212699353');
      expect(nativeUri.queryParameters['phone']!.contains('+'), isFalse);
      expect(nativeUri.queryParameters['text'], message);
      expect(nativeUri.toString(), contains('phone=923212699353'));
      expect(nativeUri.toString(), contains('text=I+need+help'));
    });
  });

  group('BATCH P-3 Widget Tests: Country Code Field & Edit Contact Dialog', () {
    testWidgets('empty code is rejected with message "Country code is required"', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EditProfileScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final addBtn = find.byKey(const Key('add_emergency_contact_btn'));
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter name and phone without code
      await tester.enterText(find.byKey(const Key('input_contact_name')), 'Test Person');
      await tester.enterText(find.byKey(const Key('input_contact_phone')), '3212699353');
      await tester.enterText(find.byKey(const Key('input_contact_country_code')), '');
      await tester.pump();

      // Tap Save
      await tester.tap(find.byKey(const Key('btn_save_contact')));
      await tester.pump();

      // Dialog stays open and displays country code required error
      expect(find.text('Country code is required'), findsOneWidget);
    });

    testWidgets('code box accepts only digits 1 to 3', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EditProfileScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final addBtn = find.byKey(const Key('add_emergency_contact_btn'));
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter non-digits and 4 digits
      final codeField = find.byKey(const Key('input_contact_country_code'));
      await tester.enterText(codeField, '92abc99');
      await tester.pump();

      // FilteringTextInputFormatter and LengthLimitingTextInputFormatter ensure max 3 digits only
      final TextField fieldWidget = tester.widget<TextField>(codeField);
      expect(fieldWidget.controller!.text, '929');
    });

    testWidgets('last used code is remembered through profile repository and prefilled on next contact', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EditProfileScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // First time: open Add Contact dialog
      final addBtn = find.byKey(const Key('add_emergency_contact_btn'));
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initial code box is empty first time
      expect(tester.widget<TextField>(find.byKey(const Key('input_contact_country_code'))).controller!.text, '');

      // Fill and save first contact with code 966
      await tester.enterText(find.byKey(const Key('input_contact_name')), 'Saudi Friend');
      await tester.enterText(find.byKey(const Key('input_contact_country_code')), '966');
      await tester.enterText(find.byKey(const Key('input_contact_phone')), '501234567');
      await tester.pump();

      await tester.tap(find.byKey(const Key('btn_save_contact')));
      await tester.pumpAndSettle();

      // Open Add Another Contact dialog
      final addAnotherBtn = find.byKey(const Key('add_another_contact_btn'));
      expect(addAnotherBtn, findsOneWidget);
      await tester.tap(addAnotherBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Second contact dialog opens prefilled with code 966
      expect(tester.widget<TextField>(find.byKey(const Key('input_contact_country_code'))).controller!.text, '966');
    });

    testWidgets('pasted +923212699353 into national field with empty code box splits correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EditProfileScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final addBtn = find.byKey(const Key('add_emergency_contact_btn'));
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Ensure code box is empty
      await tester.enterText(find.byKey(const Key('input_contact_country_code')), '');
      await tester.pump();

      // Paste +923212699353 into national field
      await tester.enterText(find.byKey(const Key('input_contact_phone')), '+923212699353');
      await tester.pump();

      // Code box receives 92, phone field receives 3212699353
      expect(tester.widget<TextField>(find.byKey(const Key('input_contact_country_code'))).controller!.text, '92');
      expect(tester.widget<TextField>(find.byKey(const Key('input_contact_phone'))).controller!.text, '3212699353');
    });

    testWidgets('pasted +966501234567 into national field with empty code box splits to code 966', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EditProfileScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final addBtn = find.byKey(const Key('add_emergency_contact_btn'));
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_contact_country_code')), '');
      await tester.pump();

      await tester.enterText(find.byKey(const Key('input_contact_phone')), '+966501234567');
      await tester.pump();

      expect(tester.widget<TextField>(find.byKey(const Key('input_contact_country_code'))).controller!.text, '966');
      expect(tester.widget<TextField>(find.byKey(const Key('input_contact_phone'))).controller!.text, '501234567');
    });

    testWidgets('duplicate detection by full E.164 rejects saving existing contact number', (tester) async {
      ProfileController.instance.setEmergencyContacts([
        EmergencyContact(name: 'Existing Contact', phone: '+923212699353'),
      ]);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EditProfileScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap add another contact
      final addAnotherBtn = find.byKey(const Key('add_another_contact_btn'));
      await tester.ensureVisible(addAnotherBtn);
      await tester.tap(addAnotherBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_contact_name')), 'New Name');
      await tester.enterText(find.byKey(const Key('input_contact_country_code')), '92');
      // Enter duplicate number with leading 0 to verify E.164 normalization
      await tester.enterText(find.byKey(const Key('input_contact_phone')), '03212699353');
      await tester.pump();

      await tester.tap(find.byKey(const Key('btn_save_contact')));
      await tester.pump();

      expect(find.text('This phone number is already added'), findsOneWidget);
    });

    testWidgets('the dialog does not overflow at 320 px width', (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EditProfileScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final addBtn = find.byKey(const Key('add_emergency_contact_btn'));
      await tester.ensureVisible(addBtn);
      await tester.tap(addBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify no Flutter layout overflow exceptions occurred
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('input_contact_country_code')), findsOneWidget);
      expect(find.byKey(const Key('input_contact_phone')), findsOneWidget);
    });
  });
}
