import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

/// The SQLite transaction also excludes isolates in the same POSIX process.
/// No financial tables are used; process death releases both coordination locks.
Future<BackupAccessGuard> acquireBackupAccess(String directory,
    {String name = 'restore_access.lock'}) async {
  final coordinator = sql.sqlite3.open(p.join(directory, '$name.sqlite'));
  RandomAccessFile? file;
  try {
    while (true) {
      try {
        coordinator.execute('BEGIN EXCLUSIVE');
        break;
      } on sql.SqliteException catch (error) {
        if (error.resultCode != 5 && error.resultCode != 6) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    file = await File(p.join(directory, name)).open(mode: FileMode.append);
    await file.lock(FileLock.blockingExclusive);
    return BackupAccessGuard._(coordinator, file);
  } catch (_) {
    try {
      await file?.close();
    } finally {
      coordinator.close();
    }
    rethrow;
  }
}

class BackupAccessGuard {
  final sql.Database _coordinator;
  final RandomAccessFile _file;
  bool _released = false;
  BackupAccessGuard._(this._coordinator, this._file);

  Future<void> unlock() async {
    if (_released) return;
    await _file.unlock();
    _coordinator.execute('ROLLBACK');
    _released = true;
  }

  Future<void> close() async {
    try {
      await unlock();
    } finally {
      try {
        await _file.close();
      } finally {
        _coordinator.close();
      }
    }
  }
}

Future<T> withBackupAccess<T>(String directory, Future<T> Function() action,
    {String name = 'restore_access.lock'}) async {
  final guard = await acquireBackupAccess(directory, name: name);
  try {
    return await action();
  } finally {
    await guard.close();
  }
}
