import 'dart:io';
import 'package:camp/core/data/account_model.dart';
import 'package:camp/core/data/account_repository_local.dart';
import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/data/password_hasher.dart';
import 'package:camp/core/data/profile_repository_local.dart';
import 'package:camp/core/data/session_repository_local.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/auth/controllers/auth_controller.dart';
import 'package:camp/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:camp/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:camp/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:camp/features/auth/presentation/widgets/auth_brand_header.dart';
import 'package:camp/features/auth/presentation/widgets/auth_google_button.dart';
import 'package:camp/features/dashboard/controllers/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Batch H-1: Source Code Fake Strings Guard Tests', () {
    test('Auth sources contain no hardcoded demo emails, passwords, tokens, or names', () {
      final authDir = Directory('lib/features/auth');
      final dartFiles = authDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final bannedPatterns = [
        'moto.rider@example.com',
        'Adventure#2026',
        'Alex Henderson',
        'alex@bmwmoto.com',
        'CampMotoRider2026!',
        '+1 (555) 019',
        'defaultRider',
        'Elena Vance',
        'Apex Navigator',
        'Ghost Rider',
      ];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final banned in bannedPatterns) {
          expect(
            content.contains(banned),
            isFalse,
            reason: 'File ${file.path} contains banned demo string "$banned"',
          );
        }
      }
    });
  });

  group('Batch H-1: Account Repository & Password Security Tests', () {
    late LocalStore store;
    late AccountRepositoryLocal accountRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = LocalStore(prefs);
      accountRepo = AccountRepositoryLocal(store);
    });

    test('PasswordHasher generates random salts and hashes differ from plaintext', () {
      final salt1 = PasswordHasher.generateSalt();
      final salt2 = PasswordHasher.generateSalt();

      expect(salt1.isNotEmpty, isTrue);
      expect(salt2.isNotEmpty, isTrue);
      expect(salt1, isNot(equals(salt2)));

      const password = 'SuperSecretPassword#2026';
      final hash1 = PasswordHasher.hashPassword(password, salt1);
      final hash2 = PasswordHasher.hashPassword(password, salt2);

      expect(hash1, isNot(equals(password)));
      expect(hash2, isNot(equals(password)));
      expect(hash1, isNot(equals(hash2)));

      expect(
        PasswordHasher.verify(
          candidatePassword: password,
          salt: salt1,
          expectedHash: hash1,
        ),
        isTrue,
      );

      expect(
        PasswordHasher.verify(
          candidatePassword: 'WrongPassword',
          salt: salt1,
          expectedHash: hash1,
        ),
        isFalse,
      );
    });

    test('PasswordHasher constantTimeCompare checks strings securely', () {
      expect(PasswordHasher.constantTimeCompare('abc', 'abc'), isTrue);
      expect(PasswordHasher.constantTimeCompare('abc', 'abd'), isFalse);
      expect(PasswordHasher.constantTimeCompare('abc', 'abcd'), isFalse);
      expect(PasswordHasher.constantTimeCompare('', ''), isTrue);
    });

    test('AccountRepositoryLocal creates, persists, and normalizes email to lowercase', () async {
      final now = DateTime.now().toUtc();
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hashPassword('Secret1234', salt);

      final account = AccountModel(
        id: 'acc-001',
        name: 'Tariq Khan',
        email: 'Tariq.Khan@EXAMPLE.COM',
        phone: '+92 300 1234567',
        passwordHash: hash,
        salt: salt,
        createdAt: now,
        updatedAt: now,
      );

      await accountRepo.saveAccount(account);
      await accountRepo.flush();

      // Retrieve by lowercase email
      final retrieved = await accountRepo.findByEmail('tariq.khan@example.com');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('acc-001'));
      expect(retrieved.email, equals('tariq.khan@example.com'));
      expect(retrieved.name, equals('Tariq Khan'));
      expect(retrieved.phone, equals('+92 300 1234567'));
      expect(retrieved.passwordHash, equals(hash));

      // Case-insensitive lookup test
      final mixedCaseRetrieved =
          await accountRepo.findByEmail('TaRiQ.KhAn@Example.Com');
      expect(mixedCaseRetrieved, isNotNull);
      expect(mixedCaseRetrieved!.id, equals('acc-001'));

      // Retrieve by ID
      final byId = await accountRepo.findById('acc-001');
      expect(byId, isNotNull);
      expect(byId!.name, equals('Tariq Khan'));
    });

    test('AccountModel tolerant JSON parsing handles missing or dirty data safely', () {
      final minimalJson = {
        'id': 'acc-999',
        'email': '  TEST@Domain.Org  ',
      };

      final parsed = AccountModel.fromJson(minimalJson);
      expect(parsed.id, equals('acc-999'));
      expect(parsed.email, equals('test@domain.org'));
      expect(parsed.name, equals(''));
      expect(parsed.phone, equals(''));
      expect(parsed.passwordHash, equals(''));
      expect(parsed.salt, equals(''));
      expect(parsed.createdAt, isA<DateTime>());
      expect(parsed.updatedAt, isA<DateTime>());
    });
  });

  group('Batch H-1: Auth Controller Flow & Session Tests', () {
    late LocalStore store;
    late AccountRepositoryLocal accountRepo;
    late SessionRepositoryLocal sessionRepo;
    late ProfileRepositoryLocal profileRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = LocalStore(prefs);
      accountRepo = AccountRepositoryLocal(store);
      sessionRepo = SessionRepositoryLocal(store);
      profileRepo = ProfileRepositoryLocal(store);

      AppRepositories.resetWith(
        accountRepository: accountRepo,
        sessionRepository: sessionRepo,
        profileRepository: profileRepo,
      );

      ProfileController.instance.resetForTesting();
      await AuthController.instance.signOut();
    });

    test('Sign up input validations fail with clear error messages', () async {
      final controller = AuthController.instance;

      // Empty name
      final res1 = await controller.signUp(
        fullName: '  ',
        email: 'rider@example.com',
        phone: '12345678',
        password: 'Password123!',
      );
      expect(res1, isFalse);
      expect(controller.state.errorMessage, equals('Full name is required.'));

      // Invalid email
      final res2 = await controller.signUp(
        fullName: 'Zain Ahmed',
        email: 'invalid-email-address',
        phone: '12345678',
        password: 'Password123!',
      );
      expect(res2, isFalse);
      expect(
        controller.state.errorMessage,
        equals('Please enter a valid email address.'),
      );

      // Empty phone
      final res3 = await controller.signUp(
        fullName: 'Zain Ahmed',
        email: 'zain@example.com',
        phone: '',
        password: 'Password123!',
      );
      expect(res3, isFalse);
      expect(controller.state.errorMessage, equals('Phone number is required.'));

      // Password < 8 characters
      final res4 = await controller.signUp(
        fullName: 'Zain Ahmed',
        email: 'zain@example.com',
        phone: '03001234567',
        password: 'short',
      );
      expect(res4, isFalse);
      expect(
        controller.state.errorMessage,
        equals('Password must be at least 8 characters.'),
      );
    });

    test('Successful sign up then sign in flow with session persistence and sign out', () async {
      final controller = AuthController.instance;

      // 1. Sign up new account
      final successSignUp = await controller.signUp(
        fullName: 'Hamza Malik',
        email: 'hamza@motorider.pk',
        phone: '+92 321 9876543',
        password: 'Adventure2026!',
      );
      expect(successSignUp, isTrue);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.currentUser?.name, equals('Hamza Malik'));
      expect(controller.currentUser?.email, equals('hamza@motorider.pk'));
      expect(controller.currentUser?.phone, equals('+92 321 9876543'));

      // Verify ProfileController was synchronized
      expect(ProfileController.instance.fullName, equals('Hamza Malik'));
      expect(ProfileController.instance.email, equals('hamza@motorider.pk'));
      expect(ProfileController.instance.phone, equals('+92 321 9876543'));

      // 2. Duplicate email sign-up fails
      final duplicateSignUp = await controller.signUp(
        fullName: 'Hamza Duplicate',
        email: 'HAMZA@motorider.pk',
        phone: '03000000000',
        password: 'AnotherPassword123!',
      );
      expect(duplicateSignUp, isFalse);
      expect(
        controller.state.errorMessage,
        equals('An account with this email already exists.'),
      );

      // 3. Sign out clears session
      await controller.signOut();
      expect(controller.isAuthenticated, isFalse);
      expect(controller.currentUser, isNull);
      expect(await accountRepo.getCurrentAccountId(), isNull);
      expect(await sessionRepo.isLoggedIn(), isFalse);

      // 4. Sign in with unknown email
      final unknownEmailRes = await controller.signIn(
        riderIdOrEmail: 'unknown@example.com',
        password: 'Adventure2026!',
      );
      expect(unknownEmailRes, isFalse);
      expect(
        controller.state.errorMessage,
        equals('No account found for this email.'),
      );

      // 5. Sign in with wrong password
      final wrongPasswordRes = await controller.signIn(
        riderIdOrEmail: 'hamza@motorider.pk',
        password: 'WrongPassword!',
      );
      expect(wrongPasswordRes, isFalse);
      expect(controller.state.errorMessage, equals('Incorrect password.'));

      // 6. Sign in with correct password restores user
      final successSignIn = await controller.signIn(
        riderIdOrEmail: 'HAMZA@motorider.pk',
        password: 'Adventure2026!',
      );
      expect(successSignIn, isTrue);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.currentUser?.name, equals('Hamza Malik'));
      expect(await accountRepo.getCurrentAccountId(), isNotNull);

      // 7. Session persistence across reload
      await controller.load(accountRepo);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.currentUser?.email, equals('hamza@motorider.pk'));
    });
  });

  group('Batch H-1: UI Widgets & Screen Honesty Tests', () {
    setUp(() async {
      await AuthController.instance.signOut();
    });
    testWidgets('SignInScreen starts with empty fields, hints, and no removed pills', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SignInScreen()),
        ),
      );
      await tester.pump();

      // Check text fields start empty
      final emailFinder = find.widgetWithText(TextField, '');
      expect(emailFinder, findsWidgets);

      // Verify hint texts
      expect(find.text('Email'), findsWidgets);
      expect(find.text('Password'), findsWidgets);

      // Verify removed items are NOT present
      expect(find.text('Quick Sign In'), findsNothing);
      expect(find.text('OR EXPRESS TAP'), findsNothing);
      expect(find.text('EXPEDITION • ADVENTURE'), findsNothing);
      expect(find.byIcon(Icons.explore_outlined), findsNothing);

      // Verify Continue with Google button is present
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('Continue with Google button shows snackbar and does not authenticate', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SignInScreen()),
        ),
      );
      await tester.pump();

      final googleButton = find.byType(AuthGoogleButton);
      expect(googleButton, findsOneWidget);

      await tester.tap(googleButton);
      await tester.pump();

      expect(find.text('Google sign-in is coming soon'), findsOneWidget);
      expect(AuthController.instance.isAuthenticated, isFalse);
    });

    testWidgets('SignUpScreen starts with empty fields, no SYNC pill, and min 8 char hint', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SignUpScreen()),
        ),
      );
      await tester.pump();

      // Verify field hints
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Email'), findsWidgets);
      expect(find.text('Phone number'), findsOneWidget);
      expect(find.text('Password (min. 8 characters)'), findsOneWidget);

      // Verify SYNC pill is removed
      expect(find.text('SYNC'), findsNothing);
      expect(find.byIcon(Icons.wifi_tethering_rounded), findsNothing);
    });

    testWidgets('ForgotPasswordScreen starts with empty field and shows honest message on submit', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ForgotPasswordScreen()),
        ),
      );
      await tester.pump();

      // Verify field starts empty
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals(''));

      // Enter email and submit
      await tester.enterText(find.byType(TextField), 'rider@camp.pk');
      await tester.tap(find.text('Request Password Reset'));
      await tester.pump();

      expect(
        find.text('Password reset by email will be available when online accounts are added.'),
        findsWidgets,
      );
    });

    testWidgets('AuthBrandHeader renders CAMP brand mark without the orange dot', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AuthBrandHeader.signIn(),
                AuthBrandHeader.signUp(),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Expect CAMP wordmark in both headers
      expect(find.text('CAMP'), findsNWidgets(2));

      // No orange dot widget in headers
      // (The old orange dot was a 6x6 circle container next to CAMP text)
      final containers = tester.widgetList<Container>(find.byType(Container));
      final orangeDots = containers.where((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration && dec.shape == BoxShape.circle) {
          final width = c.constraints?.maxWidth ?? 0;
          final height = c.constraints?.maxHeight ?? 0;
          return width <= 8 && height <= 8;
        }
        return false;
      });

      expect(orangeDots.isEmpty, isTrue);
    });
  });
}

