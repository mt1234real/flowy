import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/services/auth_profile_service.dart';
import 'package:pfm_app/services/backup_capsule.dart';
import 'package:pfm_app/services/backup_database_normalizer.dart';
import 'package:pfm_app/services/cloud_backup_service.dart';
import 'package:pfm_app/services/vault_security_service.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

Future<void> _seed(File file,
    {double wallet = 10000000, double goal = 0}) async {
  final db = AppDatabase.forTesting(NativeDatabase(file));
  try {
    for (final id in ['source', 'destination']) {
      await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: id, name: id, type: 'cash', balance: Value(wallet)));
    }
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'food', name: 'Food', type: CategoryType.expense));
    await db.into(db.savingsGoals).insert(SavingsGoalsCompanion.insert(
        id: 'goal',
        title: 'Goal',
        targetAmount: 5000000,
        currentAmount: Value(goal)));
    await db
        .into(db.debtContacts)
        .insert(DebtContactsCompanion.insert(id: 'contact', name: 'Contact'));
  } finally {
    await db.close();
  }
}

void _tx(File file, String id,
    {int type = 0,
    double amount = 1000000,
    String? goal,
    String? envelope,
    String? destination,
    int? deleted}) {
  final db = sql.sqlite3.open(file.path);
  try {
    db.execute(
        'INSERT INTO transactions '
        '(id,wallet_id,category_id,amount,type,date,goal_id,envelope_type,to_wallet_id,deleted_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          'source',
          'food',
          amount,
          type,
          1700000000,
          goal,
          envelope,
          destination,
          deleted
        ]);
  } finally {
    db.close();
  }
}

void _legacy(File file, int version) {
  final db = sql.sqlite3.open(file.path);
  try {
    db.execute('PRAGMA foreign_keys=OFF');
    if (version < 12) db.execute('DROP TABLE budget_rhythms');
    if (version < 11) {
      db.execute('ALTER TABLE transactions DROP COLUMN goal_id');
    }
    if (version < 10) db.execute('DROP TABLE entity_archives');
    if (version < 9) {
      db.execute('DROP TABLE app_notifications');
      db.execute('DROP TABLE notification_receipts');
    }
    if (version < 8) {
      db.execute('ALTER TABLE debt_transactions DROP COLUMN deleted_at');
    }
    if (version < 7) {
      db.execute('ALTER TABLE transactions DROP COLUMN deleted_at');
    }
    if (version < 6) {
      db.execute('ALTER TABLE transactions DROP COLUMN to_wallet_id');
      for (final column in [
        'credit_limit',
        'statement_day',
        'payment_due_day',
        'is_default',
        'is_archived',
        'sort_order',
        'updated_at'
      ]) {
        db.execute('ALTER TABLE wallets DROP COLUMN $column');
      }
    }
    if (version < 5) db.execute('DROP TABLE savings_goals');
    if (version < 4) {
      db.execute('ALTER TABLE transactions DROP COLUMN project_budget_id');
      db.execute('DROP TABLE project_budgets');
    }
    if (version < 3) {
      db.execute('DROP TABLE debt_transactions');
      db.execute('DROP TABLE debt_contacts');
    }
    db.execute('PRAGMA user_version=$version');
  } finally {
    db.close();
  }
}

T _read<T>(File file, T Function(sql.Database) fn) {
  final db = sql.sqlite3.open(file.path, mode: sql.OpenMode.readOnly);
  try {
    return fn(db);
  } finally {
    db.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late File local;
  late File cloud;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('flowy-backup-integrity-');
    local = File('${root.path}/local.sqlite');
    cloud = File('${root.path}/cloud.sqlite');
    await _seed(local, wallet: 9000000, goal: 1000000);
    await _seed(cloud);
  });
  tearDown(() async => root.delete(recursive: true));

  for (final marker in [
    (goal: 'goal', envelope: 'savings'),
    (goal: 'goal', envelope: null),
    (goal: 'goal', envelope: 'needs'),
    (goal: null, envelope: 'savings'),
  ]) {
    for (final type in [0, 1]) {
      test('Savings marker $marker type $type is blocked before any mutation',
          () {
        _tx(local, 'savings',
            goal: marker.goal, envelope: marker.envelope, type: type);
        _tx(local, 'normal-before-blocked', amount: 100);
        final diff = inspectReconciliation(local.path, cloud.path);
        final entry = diff.entries.singleWhere((e) => e.row['id'] == 'savings');
        expect(entry.blockedReason, contains('số dư ví và hũ'));
        final before = ledgerFingerprint(cloud.path);
        expect(
            () => reconcileBackup(cloud.path, diff,
                diff.entries.map((e) => e.key).toSet(), {'source': 'source'}),
            throwsStateError);
        // Also reject a forged/stale inspection result without a blockedReason.
        final forged = BackupReconciliation(
            [ReconcileEntry(entry.table, entry.row, null, entry.dependencies)],
            diff.conflicts,
            diff.wallets,
            diff.localWalletNames,
            diff.fingerprint);
        expect(
            () => reconcileBackup(
                cloud.path, forged, {entry.key}, {'source': 'source'}),
            throwsStateError);
        expect(ledgerFingerprint(cloud.path), before);
        _read(cloud, (db) {
          expect(
              db.select('SELECT balance FROM wallets WHERE id=?',
                  ['source']).single['balance'],
              10000000);
          expect(
              db
                  .select('SELECT current_amount FROM savings_goals')
                  .single['current_amount'],
              0);
          expect(db.select('SELECT * FROM transactions'), isEmpty);
        });
      });
    }
  }

  for (final envelope in [null, 'needs', 'wants']) {
    test('Normal expense/income with envelope $envelope remains reconcilable',
        () {
      _tx(local, 'expense', envelope: envelope, amount: 400000);
      _tx(local, 'income', type: 1, envelope: envelope, amount: 700000);
      final diff = inspectReconciliation(local.path, cloud.path);
      expect(diff.entries.every((entry) => entry.blockedReason == null), true);
      reconcileBackup(cloud.path, diff, diff.entries.map((e) => e.key).toSet(),
          {'source': 'source'});
      _read(cloud, (db) {
        expect(
            db.select('SELECT balance FROM wallets WHERE id=?',
                ['source']).single['balance'],
            10300000);
        expect(db.select('SELECT COUNT(*) n FROM transactions').single['n'], 2);
      });
    });
  }

  for (final version in List.generate(12, (index) => index + 1)) {
    test(
        'Schema $version normalizes before inspection and selective accounting',
        () async {
      _legacy(cloud, version);
      final original = await cloud.readAsBytes();
      _tx(local, 'expense', amount: 400000);
      _tx(local, 'income', type: 1, amount: 700000);
      _tx(local, 'transfer',
          type: 3, amount: 3000000, destination: 'destination');
      _tx(local, 'fee', amount: 100000);
      final debtDb = sql.sqlite3.open(local.path);
      try {
        for (final debt in [
          ('LEND', 100000),
          ('COLLECT', 200000),
          ('BORROW', 300000),
          ('REPAY', 400000)
        ]) {
          debtDb.execute(
              'INSERT INTO debt_transactions (id,contact_id,wallet_id,type,amount,date) VALUES (?,?,?,?,?,?)',
              [debt.$1, 'contact', 'source', debt.$1, debt.$2, 1700000000]);
        }
      } finally {
        debtDb.close();
      }
      final prepared = File(await prepareBackupForInspection(cloud.path));
      expect(await cloud.readAsBytes(), original);
      validateBackupDatabase(prepared.path, 12);
      expect(backupStatistics(prepared.path)['wallets'], 2);
      final diff = inspectReconciliation(local.path, prepared.path);
      expect(diff.entries.length, 8);
      expect(diff.entries.every((e) => e.blockedReason == null), true);
      reconcileBackup(
          prepared.path,
          diff,
          diff.entries.map((e) => e.key).toSet(),
          {'source': 'source', 'destination': 'destination'});
      _read(prepared, (db) {
        expect(db.select('PRAGMA user_version').single.values.single, 12);
        expect(db.select('PRAGMA quick_check').single.values.single, 'ok');
        expect(db.select('PRAGMA foreign_key_check'), isEmpty);
        expect(
            db.select('SELECT balance FROM wallets WHERE id=?',
                ['source']).single['balance'],
            7200000);
        expect(
            db.select('SELECT balance FROM wallets WHERE id=?',
                ['destination']).single['balance'],
            13000000);
        expect(
            db
                .select('SELECT net_balance FROM debt_contacts')
                .single['net_balance'],
            0);
        expect(db.select('SELECT COUNT(*) n FROM transactions').single['n'], 4);
        expect(
            db.select('SELECT COUNT(*) n FROM debt_transactions').single['n'],
            4);
      });
    });
  }

  for (final type in ['LEND', 'COLLECT', 'BORROW', 'REPAY']) {
    test('Legacy normalized reconcile preserves $type wallet/contact deltas',
        () async {
      _legacy(cloud, 10);
      final raw = sql.sqlite3.open(local.path);
      raw.execute(
          'INSERT INTO debt_transactions (id,contact_id,wallet_id,type,amount,date) VALUES (?,?,?,?,?,?)',
          ['debt', 'contact', 'source', type, 1000000, 1700000000]);
      raw.close();
      final prepared = File(await prepareBackupForInspection(cloud.path));
      final diff = inspectReconciliation(local.path, prepared.path);
      reconcileBackup(
          prepared.path, diff, {diff.entries.single.key}, {'source': 'source'});
      _read(prepared, (db) {
        expect(
            db.select('SELECT balance FROM wallets WHERE id=?',
                ['source']).single['balance'],
            type == 'COLLECT' || type == 'BORROW' ? 11000000 : 9000000);
        expect(
            db
                .select('SELECT net_balance FROM debt_contacts')
                .single['net_balance'],
            type == 'LEND' || type == 'REPAY' ? 1000000 : -1000000);
      });
    });
  }

  test(
      'Normalization preserves old deleted rows and notifications without startup cleanup',
      () async {
    _tx(cloud, 'old-deleted', deleted: 1600000000);
    final raw = sql.sqlite3.open(cloud.path);
    raw.execute(
        'INSERT INTO app_notifications (id,title,body,type,created_at) VALUES (?,?,?,?,?)',
        ['old', 'Old', 'Body', 'system', 1600000000]);
    raw.close();
    _legacy(cloud, 10);
    final prepared = File(await prepareBackupForInspection(cloud.path));
    _read(prepared, (db) {
      expect(
          db.select('SELECT id FROM transactions').single['id'], 'old-deleted');
      expect(db.select('SELECT id FROM app_notifications').single['id'], 'old');
    });
  });

  for (final invalid in [
    'newer',
    'malformed',
    'incomplete-current',
    'unsupported-zero',
    'broken-foreign-key'
  ]) {
    test('$invalid backup is rejected and temporary artifacts are removed',
        () async {
      if (invalid == 'malformed') {
        await cloud.writeAsString('not a sqlite database');
      } else {
        final raw = sql.sqlite3.open(cloud.path);
        try {
          if (invalid == 'newer') raw.execute('PRAGMA user_version=13');
          if (invalid == 'unsupported-zero') {
            raw.execute('PRAGMA user_version=0');
          }
          if (invalid == 'incomplete-current') {
            raw.execute('DROP TABLE debt_transactions');
          }
          if (invalid == 'broken-foreign-key') {
            raw.execute(
                'INSERT INTO transactions (id,wallet_id,category_id,amount,type,date) VALUES (?,?,?,?,?,?)',
                ['bad', 'missing', 'food', 1, 0, 1700000000]);
          }
        } finally {
          raw.close();
        }
      }
      final original = await cloud.readAsBytes();
      final before = ledgerFingerprint(local.path);
      await expectLater(prepareBackupForInspection(cloud.path),
          throwsA(isA<FormatException>()));
      expect(await cloud.readAsBytes(), original);
      expect(ledgerFingerprint(local.path), before);
      expect(
          root.listSync().where((f) => f.path.contains('prepared_')), isEmpty);
    });
  }

  for (final version in [1, 5, 10, 11, 12, 13, 0, -1, -2]) {
    final label = switch (version) {
      -1 => 'malformed file',
      -2 => 'damaged schema 5 migration',
      _ => 'schema $version',
    };
    test(
        'Actual restore of $label preserves data or safely rejects invalid backup',
        () async {
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      final docs = Directory('${root.path}/docs')..createSync();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              pathChannel,
              (call) async => switch (call.method) {
                    'getApplicationDocumentsDirectory' => docs.path,
                    'getTemporaryDirectory' => root.path,
                    _ => throw UnsupportedError(call.method),
                  });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null));
      expect((await getApplicationDocumentsDirectory()).path, docs.path);
      SharedPreferences.setMockInitialValues(
          {'user_display_name': 'Local sentinel'});
      FlutterSecureStorage.setMockInitialValues({
        VaultSecurityService.storageKey: jsonEncode({
          'algorithm': 'pbkdf2-sha256',
          'salt': base64Encode(List.filled(16, 0)),
          'hash': base64Encode(List.filled(32, 0)),
          'iterations': 120000,
          'length': 4,
          'isCustom': false,
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final rejected = version > 12 || version <= 0;
      if (rejected) FlutterSecureStorage.setMockInitialValues({});
      final beforeSecurity = await VaultSecurityService.storage.readAll();
      final beforePrefs = {
        for (final key in prefs.getKeys()) key: prefs.get(key)
      };
      final live = File('${docs.path}/pfm_local_vault.sqlite');
      final opened = <AppDatabase>[];
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWith((ref) {
          final db = AppDatabase.forTesting(NativeDatabase(live));
          opened.add(db);
          ref.onDispose(() => db.close());
          return db;
        }),
      ]);
      try {
        final liveDb = container.read(databaseProvider);
        await liveDb.into(liveDb.wallets).insert(WalletsCompanion.insert(
            id: 'sentinel',
            name: 'Sentinel',
            type: 'cash',
            balance: const Value(123)));
        _tx(local, 'savings', goal: 'goal', envelope: 'savings');
        if (version == -1) {
          await local.writeAsString('malformed backup');
        } else if (version == -2) {
          // A damaged v5 DB fails during the wallet timestamp rebuild.
          _legacy(local, 5);
          final raw = sql.sqlite3.open(local.path);
          raw.execute('ALTER TABLE wallets DROP COLUMN currency');
          raw.close();
        } else {
          _legacy(local, version);
        }
        final original = await local.readAsBytes();
        container.read(userProfileNotifierProvider);
        while (container.read(userProfileNotifierProvider).isLoading) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        final service = container.read(cloudBackupServiceProvider);
        if (rejected) {
          await expectLater(service.restorePreparedBackup(local),
              throwsA(isA<FormatException>()));
          expect(
              (await liveDb.select(liveDb.wallets).get()).single.balance, 123);
          expect(prefs.getString('user_display_name'), 'Local sentinel');
          expect(prefs.getBool('flowy_restored_private'), isNull);
          expect({for (final key in prefs.getKeys()) key: prefs.get(key)},
              beforePrefs);
          expect(await VaultSecurityService.storage.readAll(), beforeSecurity);
          expect(
              Directory('${docs.path}/restore_recovery').existsSync(), false);
        } else {
          await service.restorePreparedBackup(local);
          _read(live, (db) {
            expect(db.select('PRAGMA user_version').single.values.single, 12);
            expect(
                db.select('SELECT balance FROM wallets WHERE id=?',
                    ['source']).single['balance'],
                9000000);
            if (version >= 5) {
              expect(
                  db
                      .select('SELECT current_amount FROM savings_goals')
                      .single['current_amount'],
                  1000000);
            }
            expect(db.select('SELECT id FROM transactions').single['id'],
                'savings');
          });
        }
        expect(await local.readAsBytes(), original);
        expect(
            root.listSync().where((f) => f.path.contains('staged_')), isEmpty);
      } finally {
        container.dispose();
        for (final db in opened) {
          await db.close();
        }
      }
    });
  }
}
