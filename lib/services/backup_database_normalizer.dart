import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

import '../data/database.dart';
import 'backup_capsule.dart';

/// Returns a current-schema copy beside the original and its manifests.
/// The downloaded/recovery artifact is never migrated in place.
Future<String> prepareBackupForInspection(String sourcePath) async {
  final source = File(sourcePath);
  final staged = File(p.join(source.parent.path,
      'prepared_${DateTime.now().microsecondsSinceEpoch}.sqlite'));
  try {
    await source.copy(staged.path);
    await normalizeStagedBackup(staged.path);
    return staged.path;
  } catch (_) {
    await _deleteStagingFiles(staged.path);
    rethrow;
  }
}

Future<void> _deleteStagingFiles(String path) async {
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final file = File('$path$suffix');
    if (await file.exists()) await file.delete();
  }
}

/// Caller must supply a disposable staging copy, never the live/original DB.
Future<void> normalizeStagedBackup(String path) async {
  final db = _BackupMigrationDatabase(File(path));
  try {
    validateBackupDatabase(path, db.schemaVersion);
    // Opening runs the application's upgrade sequence, without startup cleanup.
    await db.customSelect('SELECT 1').get();
    await db.close();
    validateBackupDatabase(path, db.schemaVersion);
    final raw = sql.sqlite3.open(path, mode: sql.OpenMode.readOnly);
    try {
      if (raw.select('PRAGMA user_version').first.values.first !=
          db.schemaVersion) {
        throw const FormatException('Phiên bản dữ liệu chưa được nâng cấp');
      }
      // A version stamp alone cannot certify a complete, usable schema.
      for (final table in db.allTables) {
        final columns = raw
            .select('PRAGMA table_info("${table.actualTableName}")')
            .map((row) => row['name'])
            .toSet();
        if (table.$columns.any((column) => !columns.contains(column.name))) {
          throw const FormatException('Bản sao lưu thiếu cấu trúc dữ liệu');
        }
      }
    } finally {
      raw.close();
    }
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
        'Không thể nâng cấp hoặc kiểm tra bản sao lưu này. Dữ liệu trên máy chưa thay đổi.');
  } finally {
    await db.close();
  }
}

class _BackupMigrationDatabase extends AppDatabase {
  _BackupMigrationDatabase(File file) : super.forTesting(NativeDatabase(file));

  @override
  MigrationStrategy get migration {
    final appMigration = super.migration;
    return MigrationStrategy(
      onCreate: (_) async =>
          throw const FormatException('Thiếu phiên bản dữ liệu'),
      onUpgrade: (_, from, to) => transaction(
          () => appMigration.onUpgrade(_BackupMigrator(this), from, to)),
      beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
    );
  }
}

/// The historical sequence creates some tables from today's definitions.
/// Don't add those columns twice; rebuild only the v6 timestamp addition,
/// which SQLite cannot ADD with a non-constant default on a populated table.
class _BackupMigrator extends Migrator {
  _BackupMigrator(super.database);

  @override
  Future<void> addColumn(TableInfo table, GeneratedColumn column) async {
    final existing = await database
        .customSelect('PRAGMA table_info("${table.actualTableName}")')
        .get();
    if (existing.any((row) => row.data['name'] == column.name)) return;
    if (table.actualTableName == 'wallets' && column.name == 'updated_at') {
      await alterTable(TableMigration(table, newColumns: [column]));
    } else {
      await super.addColumn(table, column);
    }
  }
}
