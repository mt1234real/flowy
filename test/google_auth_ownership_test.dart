import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/features/onboarding/controllers/onboarding_controller.dart';
import 'package:pfm_app/screens/main_scaffold.dart';
import 'package:pfm_app/screens/settings_screen.dart';
import 'package:pfm_app/services/auth_profile_service.dart';
import 'package:pfm_app/services/backup_state.dart';
import 'package:pfm_app/services/cloud_backup_service.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GooglePlatform extends GoogleSignInPlatform {
  int interactive = 0, silent = 0;
  final recoverAuth = <bool?>[];
  GoogleSignInUserData? session;
  Completer<GoogleSignInUserData?>? chooser;
  final chooserStarted = Completer<void>();
  bool rejectPassiveTokens = false;
  static final account = GoogleSignInUserData(
      id: 'A',
      email: 'a@example.invalid',
      displayName: 'An',
      photoUrl: 'https://example.invalid/avatar=s96-c');
  @override
  Future<void> initWithParams(SignInInitParameters params) async {
    expect(
        params.scopes,
        containsAll(
            ['email', 'https://www.googleapis.com/auth/drive.appdata']));
  }

  @override
  Future<GoogleSignInUserData?> signIn() async {
    interactive++;
    if (!chooserStarted.isCompleted) {
      chooserStarted.complete();
    }
    return session = await (chooser?.future ?? Future.value(account));
  }

  @override
  Future<GoogleSignInUserData?> signInSilently() async {
    silent++;
    return session;
  }

  @override
  Future<GoogleSignInTokenData> getTokens(
      {required String email, bool? shouldRecoverAuth}) async {
    recoverAuth.add(shouldRecoverAuth);
    if (rejectPassiveTokens && shouldRecoverAuth == false) {
      throw StateError('expired credentials');
    }
    return GoogleSignInTokenData(accessToken: 'test-token');
  }

  @override
  Future<bool> isSignedIn() async => session != null;
  @override
  Future<void> signOut() async {
    session = null;
  }
}

class _Drive implements drive.DriveApi {
  @override
  final _Files files = _Files();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Files implements drive.FilesResource {
  int lists = 0;
  void Function()? beforeList;
  Completer<drive.FileList>? held;
  @override
  Future<drive.FileList> list(
      {String? spaces,
      String? q,
      String? orderBy,
      int? pageSize,
      String? $fields,
      String? corpora,
      String? corpus,
      String? driveId,
      bool? includeItemsFromAllDrives,
      bool? includeTeamDriveItems,
      String? pageToken,
      bool? supportsAllDrives,
      bool? supportsTeamDrives,
      String? teamDriveId,
      String? includePermissionsForView,
      String? includeLabels}) async {
    lists++;
    beforeList?.call();
    if (held != null) return held!.future;
    return drive.FileList()..files = [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedProfile extends AuthProfileService {
  final loaded = Completer<UserProfile>();
  @override
  Future<UserProfile> loadProfile() => loaded.future;
  @override
  Future<UserProfile> signInWithGoogle() async => UserProfile.guest()
      .copyWith(email: 'a@example.invalid', displayName: 'An');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GoogleSignInPlatform previousPlatform;
  late _GooglePlatform platform;
  late _Drive api;
  late AppDatabase db;
  late SharedPreferences prefs;
  late ProviderContainer container;
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    previousPlatform = GoogleSignInPlatform.instance;
    GoogleSignInPlatform.instance = platform = _GooglePlatform();
    api = _Drive();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      cloudBackupServiceProvider.overrideWith(
          (ref) => CloudBackupService(db: db, ref: ref, driveApi: api)),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    GoogleSignInPlatform.instance = previousPlatform;
  });
  Future<void> settleProfile() async {
    container.read(userProfileNotifierProvider);
    // Await local persistence, not a timing-dependent auth delay.
    await container.read(authProfileServiceProvider).loadProfile();
    await Future<void>.value();
  }

  Future<void> mount(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: MaterialApp(home: home)));
    await tester.runAsync(settleProfile);
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pumpAndSettle();
    await tester.runAsync(() => db.close());
    await tester.pump();
  }

  testWidgets('fresh_guest_launch_doesNotTriggerInteractiveGoogleSignIn',
      (tester) async {
    await mount(tester, const MainScaffold());
    expect(find.byType(SettingsScreen, skipOffstage: false), findsOneWidget);
    expect(container.read(bottomNavIndexProvider), 0);
    expect(container.read(currentUserProfileProvider).isSignedIn, false);
    expect(platform.interactive, 0);
    expect(platform.silent, 0);
    expect(api.files.lists, 0);
    await unmount(tester);
  });
  testWidgets('inactiveSettingsTab_doesNotTriggerInteractiveAuth',
      (tester) async {
    await mount(tester, const MainScaffold());
    await tester.runAsync(() =>
        container.read(cloudBackupNotifierProvider.notifier).loadBackups());
    container.read(bottomNavIndexProvider.notifier).state = 1;
    await tester.pump();
    expect(platform.interactive, 0);
    expect(api.files.lists, 0);
    await unmount(tester);
  });
  testWidgets(
      'settingsConnectGoogle_signsInExactlyOnce_andPublishesChosenProfile',
      (tester) async {
    await mount(tester, const SettingsScreen());
    platform.chooser = Completer();
    final listed = Completer<void>();
    api.files.beforeList = () {
      expect(container.read(currentUserProfileProvider).email,
          'a@example.invalid');
      listed.complete();
    };
    await tester.tap(find.text('🔗 Kết nối Google Drive ❯'));
    await tester.runAsync(() async {
      await platform.chooserStarted.future;
      expect(platform.interactive, 1);
      platform.chooser!.complete(_GooglePlatform.account);
    });
    await tester.pump();
    await tester.pump();
    expect(listed.isCompleted, true);
    expect(
        container.read(currentUserProfileProvider).email, 'a@example.invalid');
    expect(container.read(currentUserProfileProvider).displayName, 'An');
    expect(prefs.getString('user_email'), 'a@example.invalid');
    expect(api.files.lists, 1);
    expect(platform.interactive, 1);
    await unmount(tester);
  });
  test('backupLoad_withoutSession_isSilent', () async {
    await settleProfile();
    await container.read(cloudBackupNotifierProvider.notifier).loadBackups();
    expect(platform.interactive, 0);
    expect(api.files.lists, 0);
    expect(container.read(currentUserProfileProvider).isSignedIn, false);
  });
  test('backupLoad_signedProfileWithoutPluginSession_isSilent', () async {
    await prefs.setString('user_email', 'a@example.invalid');
    await settleProfile();
    await container.read(cloudBackupNotifierProvider.notifier).loadBackups();
    expect(platform.silent, greaterThan(0));
    expect(platform.interactive, 0);
    expect(api.files.lists, 0);
  });
  test('backupLoad_existingSession_usesDriveWithoutInteractiveLogin', () async {
    await prefs.setString('user_email', 'a@example.invalid');
    platform.session = _GooglePlatform.account;
    await settleProfile();
    await container.read(cloudBackupServiceProvider).listBackups();
    expect(api.files.lists, 1);
    expect(platform.interactive, 0);
  });
  test('onboardingGoogleAction_usesSingleInteractiveSignIn', () async {
    await settleProfile();
    api.files.beforeList = () =>
        expect(container.read(currentUserProfileProvider).isSignedIn, true);
    final result = await container
        .read(onboardingControllerProvider.notifier)
        .signInWithGoogleAndCheckBackup();
    expect(result, true);
    expect(platform.interactive, 1);
    expect(api.files.lists, 1);
    expect(container.read(onboardingControllerProvider).displayName, 'An');
    expect(container.read(onboardingControllerProvider).photoUrl,
        contains('=s256-c'));
    expect(container.read(currentUserProfileProvider).email,
        _GooglePlatform.account.email);
  });
  test('canonicalAccountMismatch_failsClosed_beforeDrive', () async {
    await prefs.setString('user_email', 'b@example.invalid');
    platform.session = _GooglePlatform.account;
    await expectLater(container.read(cloudBackupServiceProvider).listBackups(),
        throwsA(isA<BackupAuthenticationFailure>()));
    expect(api.files.lists, 0);
    expect(platform.interactive, 0);
    expect(prefs.getString('user_email'), 'b@example.invalid');
  });
  test('partialPluginSession_doesNotConvertGuestProfile', () async {
    platform.session = _GooglePlatform.account;
    await settleProfile();
    await container.read(cloudBackupNotifierProvider.notifier).loadBackups();
    expect(container.read(currentUserProfileProvider).isSignedIn, false);
    expect(prefs.containsKey('user_email'), false);
    expect(api.files.lists, 0);
  });
  test('passiveTokenAcquisition_disablesInteractiveRecovery', () async {
    await prefs.setString('user_email', 'a@example.invalid');
    platform.session = _GooglePlatform.account;
    platform.rejectPassiveTokens = true;
    final c =
        ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    try {
      await expectLater(
          c.read(cloudBackupServiceProvider).listBackups(), throwsStateError);
      expect(platform.recoverAuth, [false]);
      expect(platform.interactive, 0);
    } finally {
      c.dispose();
    }
  });
  test('backgroundBackup_authUnavailable_neverCallsInteractiveSignIn',
      () async {
    await prefs.setString('user_email', 'a@example.invalid');
    await expectLater(
        container.read(cloudBackupServiceProvider).performBackup(silent: true),
        throwsA(isA<BackupAuthenticationFailure>()));
    expect(platform.interactive, 0);
    expect(prefs.containsKey('flowy_last_backup_at'), false);
  });
  test('foregroundConsumers_useCanonicalClientAndScopes', () async {
    final client = container.read(googleSignInProvider);
    expect(identical(client, container.read(googleSignInProvider)), true);
    expect(client.scopes,
        ['email', 'https://www.googleapis.com/auth/drive.appdata']);
    await container
        .read(userProfileNotifierProvider.notifier)
        .signInWithGoogle();
    expect(client.currentUser?.email,
        container.read(currentUserProfileProvider).email);
    expect(platform.interactive, 1);
  });
  test('pendingProfileInitialization_cannotOverwriteChosenIdentity', () async {
    final service = _DelayedProfile();
    final notifier = UserProfileNotifier(service);
    await notifier.signInWithGoogle();
    service.loaded.complete(UserProfile.guest());
    await Future<void>.value();
    expect(notifier.state.valueOrNull?.email, 'a@example.invalid');
    notifier.dispose();
  });
}
