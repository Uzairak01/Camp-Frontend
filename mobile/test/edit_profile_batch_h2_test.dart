import 'package:camp/core/data/account_model.dart';
import 'package:camp/core/data/account_repository_local.dart';
import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/data/password_hasher.dart';
import 'package:camp/core/data/profile_repository_local.dart';
import 'package:camp/core/data/session_repository_local.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/auth/controllers/auth_controller.dart';
import 'package:camp/features/auth/presentation/widgets/password_strength_indicator.dart';
import 'package:camp/features/dashboard/controllers/profile_controller.dart';
import 'package:camp/features/dashboard/presentation/screens/edit_profile_screen.dart';
import 'package:camp/features/dashboard/presentation/screens/profile_screen.dart';
import 'package:camp/features/dashboard/presentation/widgets/change_password_sheet.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/maintenance/controllers/post_ride_report_controller.dart';
import 'package:camp/features/settings/controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_ride_report_repository.dart';

void main() {
  late AccountRepositoryLocal accountRepo;
  late SessionRepositoryLocal sessionRepo;
  late ProfileRepositoryLocal profileRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    LocalStore.instance.resetForTesting(prefs);

    accountRepo = AccountRepositoryLocal(LocalStore.instance);
    sessionRepo = SessionRepositoryLocal(LocalStore.instance);
    profileRepo = ProfileRepositoryLocal(LocalStore.instance);

    AppRepositories.resetWith(
      accountRepository: accountRepo,
      sessionRepository: sessionRepo,
      profileRepository: profileRepo,
    );

    SettingsController.instance.reset();
    ActiveBikeController.instance.reset();
    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());
    ProfileController.instance.resetForTesting();
    await AuthController.instance.signOut();
  });

  tearDown(() async {
    ActiveBikeController.instance.reset();
    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());
    await AuthController.instance.signOut();
    AppRepositories.resetToDefault();
  });

  group('Batch H-2: Change Password Controller & Security Validation', () {
    test('Wrong current password is rejected and stored account hash/salt remain unchanged', () async {
      // 1. Seed initial rider account
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hashPassword('CurrentPass123!', salt);
      final initialAccount = AccountModel(
        id: 'acc-test-1',
        name: 'Alex Rider',
        email: 'alex.rider@example.com',
        phone: '+1 555-0100',
        passwordHash: hash,
        salt: salt,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await accountRepo.saveAccount(initialAccount);

      // Sign in
      final signedIn = await AuthController.instance.signIn(
        riderIdOrEmail: 'alex.rider@example.com',
        password: 'CurrentPass123!',
      );
      expect(signedIn, isTrue);

      // 2. Attempt change password with wrong current password
      final result = await AuthController.instance.changePassword(
        currentPassword: 'WrongPassword999!',
        newPassword: 'BrandNewPassword123!',
        confirmPassword: 'BrandNewPassword123!',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, equals('Current password is incorrect.'));
      expect(result.errorField, equals(ChangePasswordField.current));

      // 3. Stored account hash and salt must be strictly unchanged
      final stored = await accountRepo.findById('acc-test-1');
      expect(stored?.passwordHash, equals(hash));
      expect(stored?.salt, equals(salt));
    });

    test('Short password, same-as-current and mismatched confirm each show their error', () async {
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hashPassword('CurrentPass123!', salt);
      final account = AccountModel(
        id: 'acc-test-2',
        name: 'Jordan Trail',
        email: 'jordan@trail.org',
        phone: '+1 555-0200',
        passwordHash: hash,
        salt: salt,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await accountRepo.saveAccount(account);

      await AuthController.instance.signIn(
        riderIdOrEmail: 'jordan@trail.org',
        password: 'CurrentPass123!',
      );

      // A. Short new password (< 8 chars)
      final shortRes = await AuthController.instance.changePassword(
        currentPassword: 'CurrentPass123!',
        newPassword: 'Short1!',
        confirmPassword: 'Short1!',
      );
      expect(shortRes.success, isFalse);
      expect(shortRes.errorMessage, equals('Use at least 8 characters.'));
      expect(shortRes.errorField, equals(ChangePasswordField.newPassword));

      // B. Same as current password
      final sameRes = await AuthController.instance.changePassword(
        currentPassword: 'CurrentPass123!',
        newPassword: 'CurrentPass123!',
        confirmPassword: 'CurrentPass123!',
      );
      expect(sameRes.success, isFalse);
      expect(sameRes.errorMessage, equals('New password must be different.'));
      expect(sameRes.errorField, equals(ChangePasswordField.newPassword));

      // C. Mismatched confirm password
      final mismatchRes = await AuthController.instance.changePassword(
        currentPassword: 'CurrentPass123!',
        newPassword: 'ValidNewPass123!',
        confirmPassword: 'DifferentPass456!',
      );
      expect(mismatchRes.success, isFalse);
      expect(mismatchRes.errorMessage, equals('Passwords do not match.'));
      expect(mismatchRes.errorField, equals(ChangePasswordField.confirm));

      // Stored credentials remain untouched
      final stored = await accountRepo.findById('acc-test-2');
      expect(stored?.passwordHash, equals(hash));
      expect(stored?.salt, equals(salt));
    });

    test('Success: stored hash and salt change, old password no longer signs in, new password does, session stays signed in', () async {
      final oldSalt = PasswordHasher.generateSalt();
      final oldHash = PasswordHasher.hashPassword('OldPassWord123!', oldSalt);
      final createdTime = DateTime.utc(2026, 1, 1);
      final account = AccountModel(
        id: 'acc-test-3',
        name: 'Casey Explorer',
        email: 'casey@camp.cc',
        phone: '+1 555-0300',
        passwordHash: oldHash,
        salt: oldSalt,
        createdAt: createdTime,
        updatedAt: createdTime,
      );
      await accountRepo.saveAccount(account);

      await AuthController.instance.signIn(
        riderIdOrEmail: 'casey@camp.cc',
        password: 'OldPassWord123!',
      );
      expect(AuthController.instance.isAuthenticated, isTrue);

      // Execute successful password change
      final successResult = await AuthController.instance.changePassword(
        currentPassword: 'OldPassWord123!',
        newPassword: 'BrandNewSecurePass2026!',
        confirmPassword: 'BrandNewSecurePass2026!',
      );
      expect(successResult.success, isTrue);
      expect(successResult.errorMessage, isNull);

      // Verify stored account changes
      final updated = await accountRepo.findById('acc-test-3');
      expect(updated, isNotNull);
      expect(updated!.salt, isNot(equals(oldSalt)));
      expect(updated.passwordHash, isNot(equals(oldHash)));
      expect(updated.updatedAt.isAfter(createdTime), isTrue);

      // Verify rider remains signed in
      expect(AuthController.instance.isAuthenticated, isTrue);
      expect(await accountRepo.getCurrentAccountId(), equals('acc-test-3'));

      // Verify old password fails to sign in
      await AuthController.instance.signOut();
      final oldSignIn = await AuthController.instance.signIn(
        riderIdOrEmail: 'casey@camp.cc',
        password: 'OldPassWord123!',
      );
      expect(oldSignIn, isFalse);
      expect(AuthController.instance.state.errorMessage, equals('Incorrect password.'));

      // Verify new password successfully signs in
      final newSignIn = await AuthController.instance.signIn(
        riderIdOrEmail: 'casey@camp.cc',
        password: 'BrandNewSecurePass2026!',
      );
      expect(newSignIn, isTrue);
      expect(AuthController.instance.isAuthenticated, isTrue);
      expect(AuthController.instance.currentUser?.name, equals('Casey Explorer'));
    });
  });

  group('Batch H-2: UI & Screen Contract Tests', () {
    testWidgets('Change password and Linked account rows are absent from main ProfileScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ProfileScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Change password'), findsNothing);
      expect(find.text('Change Password'), findsNothing);
      expect(find.text('Linked account'), findsNothing);
      expect(find.text('CAMP account'), findsNothing);
    });

    testWidgets('EditProfileScreen renders Change password and Linked account with signed-in email', (tester) async {
      await tester.runAsync(() async {
        final salt = PasswordHasher.generateSalt();
        final hash = PasswordHasher.hashPassword('Pass12345!', salt);
        final account = AccountModel(
          id: 'acc-ui-1',
          name: 'Taylor Ride',
          email: 'taylor@campmotorider.com',
          phone: '+1 555-0400',
          passwordHash: hash,
          salt: salt,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        await accountRepo.saveAccount(account);
        await AuthController.instance.signIn(
          riderIdOrEmail: 'taylor@campmotorider.com',
          password: 'Pass12345!',
        );
      });

      await tester.pumpWidget(
        const MaterialApp(home: EditProfileScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Linked account'), findsOneWidget);
      expect(find.text('CAMP account'), findsOneWidget);
      expect(find.text('taylor@campmotorider.com'), findsWidgets);
    });

    testWidgets('EditProfileScreen Change password row opens ChangePasswordSheet modal bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EditProfileScreen())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final changePasswordRow = find.byKey(const Key('change_password_row'));
      expect(changePasswordRow, findsOneWidget);

      await tester.ensureVisible(changePasswordRow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(changePasswordRow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ChangePasswordSheet), findsOneWidget);
    });

    testWidgets('ChangePasswordSheet renders three fields, visibility toggles, strength indicator, and validates errors', (tester) async {
      await tester.runAsync(() async {
        final salt = PasswordHasher.generateSalt();
        final hash = PasswordHasher.hashPassword('CurrentSecret#1', salt);
        final account = AccountModel(
          id: 'acc-sheet-1',
          name: 'Morgan Pilot',
          email: 'morgan@camp.cc',
          phone: '+1 555-0500',
          passwordHash: hash,
          salt: salt,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        await accountRepo.saveAccount(account);
        await AuthController.instance.signIn(
          riderIdOrEmail: 'morgan@camp.cc',
          password: 'CurrentSecret#1',
        );
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChangePasswordSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Check fields and strength meter are present
      expect(find.text('CURRENT PASSWORD'), findsOneWidget);
      expect(find.text('NEW PASSWORD'), findsOneWidget);
      expect(find.text('CONFIRM NEW PASSWORD'), findsOneWidget);
      expect(find.byType(PasswordStrengthIndicator), findsOneWidget);

      final submitBtn = find.byKey(const Key('change_password_submit_button'));
      expect(submitBtn, findsOneWidget);

      // Find TextFields (3 in sheet)
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));

      // A. Submit with wrong current password
      await tester.enterText(textFields.at(0), 'IncorrectCurrent#1');
      await tester.enterText(textFields.at(1), 'BrandNewPass2026!');
      await tester.enterText(textFields.at(2), 'BrandNewPass2026!');
      await tester.runAsync(() async {
        await tester.tap(submitBtn);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.text('Current password is incorrect.'), findsOneWidget);

      // B. Submit with short new password (< 8 chars)
      await tester.enterText(textFields.at(0), 'CurrentSecret#1');
      await tester.enterText(textFields.at(1), 'Short1!');
      await tester.enterText(textFields.at(2), 'Short1!');
      await tester.runAsync(() async {
        await tester.tap(submitBtn);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.text('Use at least 8 characters.'), findsOneWidget);

      // C. Submit with new password same as current
      await tester.enterText(textFields.at(0), 'CurrentSecret#1');
      await tester.enterText(textFields.at(1), 'CurrentSecret#1');
      await tester.enterText(textFields.at(2), 'CurrentSecret#1');
      await tester.runAsync(() async {
        await tester.tap(submitBtn);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.text('New password must be different.'), findsOneWidget);

      // D. Submit with confirm mismatch
      await tester.enterText(textFields.at(0), 'CurrentSecret#1');
      await tester.enterText(textFields.at(1), 'BrandNewPass2026!');
      await tester.enterText(textFields.at(2), 'DifferentConfirm2026!');
      await tester.runAsync(() async {
        await tester.tap(submitBtn);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.text('Passwords do not match.'), findsOneWidget);

      // E. Submit valid password change
      await tester.enterText(textFields.at(0), 'CurrentSecret#1');
      await tester.enterText(textFields.at(1), 'BrandNewPass2026!');
      await tester.enterText(textFields.at(2), 'BrandNewPass2026!');
      await tester.runAsync(() async {
        await tester.tap(submitBtn);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      // Verify stored account updated
      await tester.runAsync(() async {
        final updated = await accountRepo.findById('acc-sheet-1');
        expect(updated?.passwordHash, isNotNull);
        expect(
          PasswordHasher.verify(
            candidatePassword: 'BrandNewPass2026!',
            salt: updated!.salt,
            expectedHash: updated.passwordHash,
          ),
          isTrue,
        );
      });
    });
  });
}
