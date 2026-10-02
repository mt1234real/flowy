import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'vault_security_service.dart';
import 'avatar_storage.dart';
import 'backup_schedule.dart';
import 'backup_crypto.dart';

const backupCadencePreferenceKeys = <String>{
  'pfm_backup_cadence_mode',
  'pfm_backup_custom_unit',
  'pfm_backup_custom_value',
  'pfm_backup_wifi_only',
  'pfm_backup_battery_safe',
};

/// Explicit allowlist: never export authentication, encryption keys or eyes.
const backupPreferenceKeys = <String>{
  ...backupCadencePreferenceKeys,
  'flowy_theme_mode',
  'flowy_accent_preset',
  'flowy_font_family',
  'flowy_currency_font',
  'notification_preferences_v1',
  'flowy_classification_schemes_v1',
  'notification_cycle_snapshot',
  'flowy_cycle_start_day',
  'flowy_day_cutoff_hour',
  'flowy_day_cutoff_minute',
  'user_display_name',
  'user_avatar_type',
  'user_avatar_value',
  'user_avatar_color_hex',
  'vault_biometrics_enabled',
};

Future<Map<String, Object>> exportBackupPreferences(
    SharedPreferences prefs) async {
  final values = <String, Object>{
    for (final key in backupPreferenceKeys)
      if (prefs.get(key) != null) key: prefs.get(key)!,
  };
  if (values['user_avatar_type'] == 'customImage') {
    final avatar = File(values['user_avatar_value'] as String? ?? '');
    if (await avatar.exists()) {
      if (await avatar.length() > maxAvatarBytes) {
        throw StateError(
            'Ảnh đại diện lớn hơn 2 MB. Hãy chọn ảnh nhỏ hơn trước khi sao lưu.');
      }
      values['user_avatar_image_base64'] =
          base64Encode(await avatar.readAsBytes());
      values.remove('user_avatar_value');
    } else {
      values['user_avatar_type'] = 'initials';
      values['user_avatar_value'] = '';
    }
  }
  return values;
}

Future<void> applyBackupPreferences(
    SharedPreferences prefs, Map<String, dynamic> values,
    {BackupWorkScheduler? scheduler}) async {
  validatePreferences(values);
  values = Map<String, dynamic>.from(values);
  if (values['user_avatar_image_base64'] is String) {
    final bytes = base64Decode(values['user_avatar_image_base64'] as String);
    final image = await storeAvatarBytes(bytes);
    values['user_avatar_value'] = image.path;
  } else if (values['user_avatar_type'] == 'customImage') {
    // Legacy source-device paths cannot be used on the destination device.
    values['user_avatar_type'] = 'initials';
    values['user_avatar_value'] = '';
  }
  for (final key in backupPreferenceKeys) {
    // Older backups predate these settings: retain local/default configuration.
    if (backupCadencePreferenceKeys.contains(key) && !values.containsKey(key)) {
      continue;
    }
    final value = values[key];
    final bool saved;
    if (value == null) {
      saved = await prefs.remove(key);
    } else if (value is int) {
      saved = await prefs.setInt(key, value);
    } else if (value is bool) {
      saved = await prefs.setBool(key, value);
    } else {
      saved = await prefs.setString(key, value as String);
    }
    if (!saved) throw StateError('Không lưu được thiết lập $key');
  }
  // Restore writes are configuration, not new user mutations.
  await recoverPendingBackup(prefs, scheduler: scheduler);
}

void validatePreferences(Map<String, dynamic> values) {
  for (final entry in values.entries) {
    if ((!backupPreferenceKeys.contains(entry.key) &&
            entry.key != 'user_avatar_image_base64') ||
        (entry.key == 'vault_biometrics_enabled' ||
                entry.key == 'pfm_backup_wifi_only' ||
                entry.key == 'pfm_backup_battery_safe'
            ? entry.value is! bool
            : entry.key == 'flowy_cycle_start_day' ||
                    entry.key == 'flowy_day_cutoff_hour' ||
                    entry.key == 'flowy_day_cutoff_minute' ||
                    entry.key == 'pfm_backup_cadence_mode' ||
                    entry.key == 'pfm_backup_custom_value'
                ? entry.value is! int
                : entry.value is! String)) {
      throw const FormatException('Thiết lập sao lưu không hợp lệ');
    }
  }
  final cadence = values['pfm_backup_cadence_mode'] as int?;
  final unit = values['pfm_backup_custom_unit'] as String?;
  if ((cadence != null && (cadence < 0 || cadence > 4)) ||
      (unit != null && !{'hours', 'days', 'weeks'}.contains(unit))) {
    throw const FormatException('Thiết lập lịch sao lưu không hợp lệ');
  }
  final cutoffHour = values['flowy_day_cutoff_hour'] as int? ?? 0;
  final cutoffMinute = values['flowy_day_cutoff_minute'] as int? ?? 0;
  if (cutoffHour < 0 || cutoffHour > 6 || cutoffMinute < 0 || cutoffMinute > 59 || cutoffHour * 60 + cutoffMinute > 360) {
    throw const FormatException('Mốc bắt đầu ngày mới không hợp lệ');
  }
  if (values['user_avatar_image_base64'] != null &&
      base64Decode(values['user_avatar_image_base64'] as String).length >
          maxAvatarBytes) {
    throw const FormatException('Ảnh đại diện vượt giới hạn');
  }
  for (final key in [
    'notification_preferences_v1',
    'flowy_classification_schemes_v1',
    'notification_cycle_snapshot'
  ]) {
    if (values[key] == null) continue;
    final decoded = jsonDecode(values[key] as String);
    if (key == 'flowy_classification_schemes_v1') {
      if (decoded is! List || decoded.any((v) => v is! Map)) {
        throw const FormatException('Góc nhìn phân tích không hợp lệ');
      }
    } else if (key == 'notification_cycle_snapshot') {
      if (decoded is! Map ||
          decoded.values.any((v) => v is! int || v < 1 || v > 31)) {
        throw const FormatException('Ngày bắt đầu chu kỳ không hợp lệ');
      }
    } else if (decoded is! Map ||
        decoded.values.any((v) => v is! bool && v is! int && v is! List)) {
      throw const FormatException('Thiết lập nhắc nhở không hợp lệ');
    }
  }
}

/// Invoked with compute: ZIP and AES never block the rendering isolate.
Future<String> packBackup(Map<String, dynamic> args) async {
  final folder = args['folder'] as String;
  final encoder = ZipFileEncoder()..create(p.join(folder, 'capsule.zip'));
  try {
    for (final name in [
      'pfm_local_vault.sqlite',
      'preferences_manifest.json',
      'security_manifest.json',
      'backup_metadata.json'
    ]) {
      await encoder.addFile(File(p.join(folder, name)));
    }
  } finally {
    encoder.close();
  }
  final encrypted = encryptBackupV2(
      await File(p.join(folder, 'capsule.zip')).readAsBytes(),
      BackupMasterKey(args['master'] as List<int>),
      args['accountId'] as String);
  final output = File(p.join(folder, 'capsule.enc'));
  await output.writeAsBytes(encrypted, flush: true);
  return output.path;
}

Future<String> unpackBackup(Map<String, dynamic> args) async {
  final folder = args['folder'] as String;
  final bytes = await File(p.join(folder, 'downloaded.enc')).readAsBytes();
  if (bytes.length < 32 || bytes.length > 256 * 1024 * 1024) {
    throw const FormatException('Kích thước bản sao lưu không hợp lệ');
  }
  final zip = decryptBackupEnvelope(bytes,
      accountId: args['accountId'] as String,
      master: args['master'] == null
          ? null
          : BackupMasterKey(args['master'] as List<int>));
  final archive = ZipDecoder().decodeBytes(zip, verify: true);
  final seen = <String>{};
  var total = 0;
  for (final entry in archive) {
    if (!entry.isFile) continue;
    final name = entry.name;
    if (![
          'pfm_local_vault.sqlite',
          'preferences_manifest.json',
          'security_manifest.json',
          'backup_metadata.json'
        ].contains(name) ||
        !seen.add(name)) {
      throw const FormatException('Nội dung gói sao lưu không hợp lệ');
    }
    total += entry.size;
    if (total > 512 * 1024 * 1024 ||
        (name.endsWith('.json') && entry.size > 4 * 1024 * 1024)) {
      throw const FormatException('Bản sao lưu vượt giới hạn dung lượng');
    }
    await File(p.join(folder, name)).writeAsBytes(entry.content, flush: true);
  }
  final db = File(p.join(folder, 'pfm_local_vault.sqlite'));
  validateBackupDatabase(db.path, args['schema'] as int);
  final metadata = readManifest(folder, 'backup_metadata.json');
  if (metadata != null) {
    if (metadata['version'] != 4 || seen.length != 4) {
      throw const FormatException('Phiên bản gói sao lưu không được hỗ trợ');
    }
    validatePreferences(readManifest(folder, 'preferences_manifest.json')!);
    VaultSecurityConfig.fromJson(
        readManifest(folder, 'security_manifest.json')!);
  } else if (seen.length != 1) {
    throw const FormatException('Gói sao lưu thiếu thông tin phiên bản');
  }
  return db.path;
}

Map<String, dynamic>? readManifest(String folder, String name) {
  final file = File(p.join(folder, name));
  return file.existsSync()
      ? Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map)
      : null;
}

void validateBackupDatabase(String path, int supportedSchema) {
  final db = sql.sqlite3.open(path, mode: sql.OpenMode.readOnly);
  try {
    final version = db.select('PRAGMA user_version').first.values.first as int;
    if (version > supportedSchema) {
      throw const FormatException('Bản sao lưu cần phiên bản Flowy mới hơn');
    }
    if (version < 1 ||
        db.select('PRAGMA quick_check').first.values.first != 'ok' ||
        db.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw const FormatException('Cơ sở dữ liệu sao lưu không hợp lệ');
    }
    db.select('SELECT id FROM transactions LIMIT 1');
    db.select('SELECT id FROM wallets LIMIT 1');
  } finally {
    db.close();
  }
}

bool _isSavingsReconcileRow(Map<String, dynamic> row) =>
    row['goal_id'] != null || row['envelope_type'] == 'savings';

const _savingsReconcileBlockedReason =
    'Không thể gộp riêng khoản nạp/rút tiết kiệm vì số dư ví và hũ cần được khôi phục cùng nhau.';

Map<String, int> backupStatistics(String path) {
  final db = sql.sqlite3.open(path, mode: sql.OpenMode.readOnly);
  try {
    final row = db
        .select('SELECT COUNT(*) AS count, MAX(date) AS latest FROM '
            '(SELECT date FROM transactions UNION ALL SELECT date FROM debt_transactions)')
        .first;
    return {
      'transactions': row['count'] as int,
      'wallets': db
          .select('SELECT COUNT(*) AS count FROM wallets')
          .first['count'] as int,
      'latest': row['latest'] as int? ?? 0
    };
  } finally {
    db.close();
  }
}

class ReconcileEntry {
  final String table;
  final Map<String, dynamic> row;
  final String? blockedReason;
  final List<Map<String, dynamic>> dependencies;
  const ReconcileEntry(
      this.table, this.row, this.blockedReason, this.dependencies);
  String get key => '$table:${row['id']}';
  String get walletId => row['wallet_id'] as String;
}

class BackupReconciliation {
  final List<ReconcileEntry> entries;
  final int conflicts;
  final List<Map<String, dynamic>> wallets;
  final Map<String, String> localWalletNames;
  final String fingerprint;
  const BackupReconciliation(this.entries, this.conflicts, this.wallets,
      this.localWalletNames, this.fingerprint);
}

String ledgerFingerprint(String path) {
  final db = sql.sqlite3.open(path, mode: sql.OpenMode.readOnly);
  try {
    return sha256
        .convert(utf8.encode(jsonEncode({
          for (final table in [
            'wallets',
            'transactions',
            'debt_transactions',
            'categories',
            'debt_contacts',
            'savings_goals',
            'budgets',
            'project_budgets'
          ])
            table: db
                .select('SELECT * FROM $table ORDER BY id')
                .map((r) => Map<String, dynamic>.from(r))
                .toList(),
        })))
        .toString();
  } finally {
    db.close();
  }
}

BackupReconciliation inspectReconciliation(String localPath, String cloudPath) {
  final local = sql.sqlite3.open(localPath, mode: sql.OpenMode.readOnly);
  final cloud = sql.sqlite3.open(cloudPath, mode: sql.OpenMode.readOnly);
  try {
    final entries = <ReconcileEntry>[];
    var conflicts = 0;
    for (final table in ['transactions', 'debt_transactions']) {
      final exists = cloud.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [table]).isNotEmpty;
      final remote = {
        if (exists)
          for (final row in cloud.select('SELECT * FROM $table')) row['id']: row
      };
      for (final row in local.select('SELECT * FROM $table')) {
        if (remote.containsKey(row['id'])) {
          if (row.keys.any((k) => row[k] != remote[row['id']]![k])) conflicts++;
          continue;
        }
        String? reason;
        if (!exists) reason = 'Bản Cloud cũ chưa hỗ trợ sổ nợ';
        if (table == 'transactions' && _isSavingsReconcileRow(row)) {
          reason = _savingsReconcileBlockedReason;
        }
        // Dependencies must have the same identity and meaning. Never guess a category/contact.
        final dependencies = table == 'transactions'
            ? {
                'categories': row['category_id'],
                'project_budgets': row['project_budget_id']
              }
            : {'debt_contacts': row['contact_id']};
        final missing = <Map<String, dynamic>>[];
        final visited = <String>{};
        String? checkDependency(String table, Object id) {
          if (!visited.add('$table:$id')) return 'Liên kết danh mục bị lặp';
          final a = local.select('SELECT * FROM $table WHERE id=?', [id]);
          final b = cloud.select('SELECT * FROM $table WHERE id=?', [id]);
          if (a.isEmpty) return 'Thiếu danh mục, dự án hoặc đối tác gốc';
          final keys = table == 'categories'
              ? ['name', 'type', 'parent_id']
              : table == 'debt_contacts'
                  ? ['name', 'phone']
                  : ['title', 'tag'];
          if (b.isNotEmpty && keys.any((k) => a.first[k] != b.first[k])) {
            return 'Danh mục, dự án hoặc đối tác trùng ID nhưng khác nội dung';
          }
          if (table == 'categories' && a.first['parent_id'] != null) {
            final error =
                checkDependency(table, a.first['parent_id'] as String);
            if (error != null) return error;
          }
          if (b.isEmpty) {
            final row = Map<String, dynamic>.from(a.first);
            if (table == 'debt_contacts') row['net_balance'] = 0.0;
            missing.add({'table': table, 'row': row});
          }
          return null;
        }

        for (final dep in dependencies.entries) {
          if (dep.value != null) {
            reason ??= checkDependency(dep.key, dep.value!);
          }
        }
        entries.add(ReconcileEntry(
            table, Map<String, dynamic>.from(row), reason, missing));
      }
    }
    return BackupReconciliation(
        entries,
        conflicts,
        cloud
            .select('SELECT * FROM wallets WHERE is_archived=0')
            .map((r) => Map<String, dynamic>.from(r))
            .toList(),
        {
          for (final r in local.select('SELECT id,name FROM wallets'))
            r['id'] as String: r['name'] as String
        },
        ledgerFingerprint(localPath));
  } finally {
    local.close();
    cloud.close();
  }
}

/// Recovery journal is checked before opening any SQLite connection at startup.
Future<void> recoverInterruptedRestore(
    String documents, SharedPreferences prefs) async {
  final folder = p.join(documents, 'restore_recovery');
  final marker = File(p.join(folder, 'pending'));
  if (!await marker.exists()) return;
  if (await marker.readAsString() == 'prepared') {
    await marker.delete();
    return;
  }
  final target = p.join(documents, 'pfm_local_vault.sqlite');
  for (final suffix in ['-wal', '-shm']) {
    final file = File('$target$suffix');
    if (await file.exists()) await file.delete();
  }
  await File(p.join(folder, 'pfm_local_vault.sqlite')).copy(target);
  await applyBackupPreferences(
      prefs, readManifest(folder, 'preferences_manifest.json')!);
  await VaultSecurityService.restoreManifest(
      readManifest(folder, 'security_manifest.json')!);
  await marker.delete();
}

/// Applies selected new rows to a staging copy, never to the live database.
/// All balance deltas and inserts are committed together; any failure rolls back.
void reconcileBackup(String path, BackupReconciliation diff,
    Set<String> selected, Map<String, String> mapping) {
  // Recheck the row itself: execution must not trust an earlier UI decision.
  for (final entry in diff.entries.where((e) => selected.contains(e.key))) {
    if (entry.table == 'transactions' && _isSavingsReconcileRow(entry.row)) {
      throw StateError(_savingsReconcileBlockedReason);
    }
    if (entry.blockedReason != null) throw StateError(entry.blockedReason!);
  }
  final db = sql.sqlite3.open(path);
  try {
    db.execute('PRAGMA foreign_keys=ON');
    db.execute('BEGIN IMMEDIATE');
    for (final entry in diff.entries.where((e) => selected.contains(e.key))) {
      for (final dependency in entry.dependencies) {
        final table = dependency['table'] as String;
        final data = dependency['row'] as Map<String, dynamic>;
        if (db
            .select('SELECT id FROM $table WHERE id=?', [data['id']]).isEmpty) {
          db.execute(
              'INSERT INTO $table (${data.keys.map((k) => '"$k"').join(',')}) VALUES (${List.filled(data.length, '?').join(',')})',
              data.values.toList());
        }
      }
      final row = Map<String, dynamic>.from(entry.row);
      final wallet = mapping[entry.walletId];
      if (wallet == null || !diff.wallets.any((w) => w['id'] == wallet)) {
        throw StateError('Hãy chọn ví nhận cho từng nhóm');
      }
      row['wallet_id'] = wallet;
      String? destination;
      if (entry.table == 'transactions' && row['type'] == 3) {
        destination = mapping[row['to_wallet_id']];
        if (destination == null ||
            destination == wallet ||
            !diff.wallets.any((w) => w['id'] == destination)) {
          throw StateError('Cần hai ví khác nhau cho khoản chuyển tiền');
        }
        row['to_wallet_id'] = destination;
      }
      final amount = (row['amount'] as num).toDouble();
      if (!amount.isFinite || amount <= 0) {
        throw StateError('Số tiền không hợp lệ');
      }
      db.execute(
          'INSERT INTO ${entry.table} (${row.keys.map((k) => '"$k"').join(',')}) VALUES (${List.filled(row.length, '?').join(',')})',
          row.values.toList());
      if (row['deleted_at'] != null) continue;
      final type = row['type'];
      final income = entry.table == 'transactions'
          ? type == 1
          : type == 'BORROW' || type == 'COLLECT';
      if (entry.table == 'transactions' && ![0, 1, 3].contains(type)) {
        throw StateError('Giao dịch cần đối soát riêng');
      }
      if (entry.table == 'debt_transactions' &&
          !['LEND', 'COLLECT', 'BORROW', 'REPAY'].contains(type)) {
        throw StateError('Loại giao dịch nợ không hợp lệ');
      }
      db.execute(
          'UPDATE wallets SET balance=balance+?, updated_at=? WHERE id=?', [
        income ? amount : -amount,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        wallet
      ]);
      if (destination != null) {
        db.execute('UPDATE wallets SET balance=balance+? WHERE id=?',
            [amount, destination]);
      }
      if (entry.table == 'debt_transactions') {
        db.execute(
            'UPDATE debt_contacts SET net_balance=net_balance+? WHERE id=?', [
          type == 'LEND' || type == 'REPAY' ? amount : -amount,
          row['contact_id']
        ]);
      }
    }
    if (db.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw StateError('Liên kết dữ liệu không hợp lệ');
    }
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  } finally {
    db.close();
  }
}
