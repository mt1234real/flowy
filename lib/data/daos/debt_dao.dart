// ==============================================================================
// File: lib/data/daos/debt_dao.dart
// Architecture: Debt Counterparty Ledger DAO & Riverpod Reactive Streams with Soft-Delete
// Stack: drift, flutter_riverpod
// Features:
// 1. Reactive Streams sử dụng .watch() của Drift SQLite:
//    - Tự động phát tín hiệu (emit event) tức thì khi có INSERT, UPDATE, DELETE trên bảng nợ.
// 2. watchAllDebtTransactionsInRange:
//    - Cung cấp Stream giao dịch nợ theo chu kỳ/thời gian phục vụ Sổ Giao Dịch hợp nhất,
//      bắt buộc lọc `d.deletedAt.isNull()`.
// 3. Cơ chế Xóa Mềm & Thùng Rác (Soft-Delete & Recycle Bin Engine cho Nợ):
//    - softDeleteDebt(debtId): Cập nhật deletedAt = now, hoàn tác delta ví & netBalance.
//    - restoreDebt(debtId): Đặt deletedAt = null, tái áp dụng delta ví & netBalance.
//    - permanentDeleteDebt(debtId): Xóa vĩnh viễn dòng bản ghi khỏi SQLite.
// 4. Toàn vẹn giao dịch ACID & Tự động đồng bộ số dư Ví và NetBalance đối tác.
// ==============================================================================

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database.dart';

// ==========================================
// RIVERPOD REACTIVE STREAM PROVIDERS
// ==========================================

/// Stream danh bạ vay nợ (Debt Contacts) sắp xếp theo trạng thái nợ & giá trị tuyệt đối giảm dần
final debtContactsStreamProvider = StreamProvider.autoDispose<List<DebtContact>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllDebtContacts();
});

/// Stream lịch sử giao dịch vay nợ theo từng contact cụ thể (chỉ lấy giao dịch chưa xóa mềm: deletedAt.isNull())
final debtTransactionsByContactStreamProvider =
StreamProvider.autoDispose.family<List<DebtTransaction>, String>((ref, contactId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.debtTransactions)
    ..where((t) => t.contactId.equals(contactId) & t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm.desc(t.date)]))
      .watch();
});

/// Stream 3 chỉ số tổng quan nợ: Khoản phải thu, Khoản phải trả, và Điều chỉnh tài sản ròng
final debtSummaryStreamProvider = StreamProvider.autoDispose<DebtSummary>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchDebtSummary();
});

/// StreamProvider theo dõi các khoản trả nợ liên kết với 1 khoản vay gốc (chỉ lấy chưa xóa: deletedAt.isNull())
final linkedRepaymentsStreamProvider =
StreamProvider.autoDispose.family<List<DebtTransaction>, String>((ref, parentTxId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.debtTransactions)
    ..where((t) => t.note.contains('#ref:$parentTxId') & t.deletedAt.isNull()))
      .watch();
});

/// StreamProvider tự động lắng nghe toàn bộ biến động giao dịch Vay/Nợ chưa xóa trong dải ngày
final debtTransactionsInRangeStreamProvider =
StreamProvider.autoDispose.family<List<DebtTransaction>, ({DateTime start, DateTime end})>((ref, range) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.debtTransactions)
    ..where((d) =>
    d.deletedAt.isNull() &
    d.date.isBiggerOrEqualValue(range.start) &
    d.date.isSmallerOrEqualValue(range.end))
    ..orderBy([(d) => OrderingTerm.desc(d.date)]))
      .watch();
});

// ==========================================
// DEBT REPOSITORY / SERVICE FACADE PROVIDER
// ==========================================

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DebtRepository(db);
});

class DebtRepository {
  final AppDatabase _db;

  DebtRepository(this._db);

  /// Lắng nghe Reactive Stream các giao dịch vay nợ trong dải ngày (chỉ lấy mục chưa xóa: deletedAt.isNull())
  Stream<List<DebtTransaction>> watchDebtTransactionsInRange(DateTime start, DateTime end) {
    return (_db.select(_db.debtTransactions)
      ..where((d) =>
      d.deletedAt.isNull() &
      d.date.isBiggerOrEqualValue(start) &
      d.date.isSmallerOrEqualValue(end))
      ..orderBy([(d) => OrderingTerm.desc(d.date)]))
        .watch();
  }

  /// Tạo hoặc cập nhật thông tin đối tượng vay nợ
  Future<void> upsertContact({
    required String id,
    required String name,
    String? phone,
    String? avatarUrl,
  }) async {
    await _db.upsertDebtContact(
      DebtContactsCompanion(
        id: Value(id),
        name: Value(name),
        phone: Value(phone),
        avatarUrl: Value(avatarUrl),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Ghi nhận giao dịch Vay / Nợ nguyên tử (Atomic ACID):
  /// - LEND: Tôi cho vay (+netBalance, -wallet.balance)
  /// - COLLECT: Thu hồi nợ (-netBalance, +wallet.balance)
  /// - BORROW: Tôi đi vay (-netBalance, +wallet.balance)
  /// - REPAY: Tôi trả nợ (+netBalance, -wallet.balance)
  Future<void> recordTransaction({
    required String id,
    required String contactId,
    required String walletId,
    required String type,
    required double amount,
    required DateTime date,
    DateTime? dueDate,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Số tiền giao dịch vay nợ phải lớn hơn 0');
    }

    await _db.createDebtTransaction(
      id: id,
      contactId: contactId,
      walletId: walletId,
      type: type,
      amount: amount,
      date: date,
      dueDate: dueDate,
      note: note,
    );
  }

  /// Xóa mềm giao dịch vay nợ (đưa vào Thùng rác và hoàn trả số dư)
  Future<void> softDeleteDebt(String transactionId) async {
    await _db.softDeleteDebtTransaction(transactionId);
  }

  /// Khôi phục giao dịch vay nợ từ Thùng rác
  Future<void> restoreDebt(String transactionId) async {
    await _db.restoreDebtTransaction(transactionId);
  }

  /// Xóa vĩnh viễn giao dịch nợ khỏi SQLite
  Future<void> permanentDeleteDebt(String transactionId) async {
    await _db.permanentDeleteDebtTransaction(transactionId);
  }

  /// Tương thích ngược: Gọi xóa mềm
  Future<void> deleteTransaction(String transactionId) async {
    await _db.softDeleteDebtTransaction(transactionId);
  }
}