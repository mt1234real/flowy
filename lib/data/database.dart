// ==============================================================================
// File: lib/data/database.dart
// Architecture: Local-First Reactive Drift Database (SQLite) with Soft-Delete & Vault Isolation
// Stack: drift, sqlite3_flutter_libs, path_provider, flutter_riverpod
// Features: 2-Tier Hierarchical Categories, Reactive Streams, Transactions,
//           Budgets, Debt Counterparty Ledger (DebtContacts & DebtTransactions),
//           Project Budgets (Event & Project Finance System),
//           Savings Goals (Secret Vault Savings System & Isolated Audit Ledger),
//           Executive Wealth Source Management & Internal Transfers,
//           Soft-Delete Engine with 30-Day Auto Cleanup & Recycle Bin Recovery for BOTH
//           Transactions and DebtTransactions,
//           Two-Way Reversal Mutation & Vault Atomic Resolutions
// Schema Version: 11 (Migration: add Transactions.goalId in v11 for Vault Isolation)
// ACID Integrity: Atomic Balance Updates, Safe Soft-Deletions, Balance Reversal / Re-application,
//                 Permanent Erase, Empty Bin Cleanup
// ==============================================================================

import 'dart:io';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

// --- ENUMS ---
enum CategoryType { expense, income, debt, transfer }
enum EnvelopeType { needs, wants, savings }

class VaultTransactionDeletionException implements Exception {
  final String message;

  const VaultTransactionDeletionException(this.message);
}

// --- TABLES DEFINITION ---

class Wallets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => text().withLength(min: 1, max: 50)(); // cash, bank, ewallet, credit, savings
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  TextColumn get currency => text().withDefault(const Constant('VND'))();
  TextColumn get icon => text().withDefault(const Constant('Wallet'))();
  TextColumn get color => text().withDefault(const Constant('#10B981'))();
  BoolColumn get isExcludedFromTotal => boolean().withDefault(const Constant(false))();
  RealColumn get creditLimit => real().nullable()(); // Hạn mức thẻ tín dụng
  IntColumn get statementDay => integer().nullable()(); // Ngày chốt sao kê (1-31)
  IntColumn get paymentDueDay => integer().nullable()(); // Ngày đến hạn thanh toán (1-31)
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))(); // Ví mặc định
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))(); // Ẩn / Lưu trữ ví
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable().references(Categories, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get type => intEnum<CategoryType>()();
  TextColumn get icon => text().withDefault(const Constant('Folder'))();
  TextColumn get color => text().withDefault(const Constant('#6366F1'))();
  RealColumn get budgetLimit => real().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ProjectBudgets extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get tag => text()();
  TextColumn get icon => text().withDefault(const Constant('🌴'))();
  TextColumn get colorHex => text().withDefault(const Constant('#0EA5E9'))();
  RealColumn get targetAmount => real()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class SavingsGoals extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get icon => text().withDefault(const Constant('🐖'))();
  TextColumn get colorHex => text().withDefault(const Constant('#10B981'))();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get walletId => text().references(Wallets, #id, onDelete: KeyAction.cascade)();
  TextColumn get categoryId => text().references(Categories, #id, onDelete: KeyAction.restrict)();
  RealColumn get amount => real()();
  IntColumn get type => intEnum<CategoryType>()();
  TextColumn get envelopeType => text().nullable()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get merchant => text().nullable()();
  BoolColumn get isAiParsed => boolean().withDefault(const Constant(false))();
  TextColumn get rawReceiptText => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isCycleStart => boolean().withDefault(const Constant(false))();
  TextColumn get projectBudgetId => text().nullable().references(ProjectBudgets, #id, onDelete: KeyAction.setNull)();
  TextColumn get toWalletId => text().nullable().references(Wallets, #id, onDelete: KeyAction.setNull)();
  // 🌟 Cột liên kết Hũ Tiết Kiệm: Phục vụ tách dòng tiền Két & làm sạch Sổ GD chính
  TextColumn get goalId => text().nullable().references(SavingsGoals, #id, onDelete: KeyAction.cascade)();
  // 🌟 Cột soft-delete: Lưu thời điểm bị đưa vào Thùng rác (null = đang hoạt động)
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id, onDelete: KeyAction.cascade)();
  RealColumn get amount => real()();
  IntColumn get cycleStartDay => integer().withDefault(const Constant(1))();
  DateTimeColumn get periodMonth => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class DebtContacts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get phone => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  RealColumn get netBalance => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class DebtTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get contactId => text().references(DebtContacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get walletId => text().references(Wallets, #id)();
  TextColumn get type => text()(); // 'LEND', 'COLLECT', 'BORROW', 'REPAY'
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isSettled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- DTO: HIERARCHICAL CATEGORY MODEL ---
class CategoryHierarchyNode {
  final Category parent;
  final List<Category> subcategories;

  CategoryHierarchyNode({
    required this.parent,
    required this.subcategories,
  });
}

// --- DTO: TỔNG HỢP VỊ THẾ NỢ RÒNG ---
class DebtSummary {
  final double totalReceivable;
  final double totalPayable;
  final double netWorthAdjustment;

  const DebtSummary({
    required this.totalReceivable,
    required this.totalPayable,
    required this.netWorthAdjustment,
  });
}

// --- DTO: DỰ ÁN ENRICHED CHO VIEW & STATUS ---
class EnrichedProjectBudget {
  final ProjectBudget budget;
  final String computedStatus;
  final double spentAmount;
  final double remainingAmount;
  final double progressPercent;
  final int remainingDays;

  const EnrichedProjectBudget({
    required this.budget,
    required this.computedStatus,
    required this.spentAmount,
    required this.remainingAmount,
    required this.progressPercent,
    required this.remainingDays,
  });
}

// --- DTO: BẢN GHI THÙNG RÁC KÈM SỐ NGÀY ĐẾM NGƯỢC ---
class DeletedTransactionItem {
  final Transaction transaction;
  final Category? category;
  final Wallet? wallet;
  final int daysRemaining;

  const DeletedTransactionItem({
    required this.transaction,
    this.category,
    this.wallet,
    required this.daysRemaining,
  });
}

// --- DTO: BẢN GHI NHẬT KÝ DÒNG TIỀN KÉT TIẾT KIỆM (VAULT AUDIT ITEM) ---
class VaultTransactionItem {
  final Transaction transaction;
  final SavingsGoal? goal;
  final Wallet? wallet;

  const VaultTransactionItem({
    required this.transaction,
    this.goal,
    this.wallet,
  });

  bool get isDeposit => transaction.type == CategoryType.expense;
  bool get isWithdrawal => transaction.type == CategoryType.income;
}

// --- APP DATABASE & DAO IMPLEMENTATION ---

class EntityArchives extends Table {
  TextColumn get entityId => text()();
  TextColumn get entityType => text()();
  DateTimeColumn get archivedAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {entityId, entityType};
}

class NotificationReceipts extends Table {
  TextColumn get dedupKey => text()();
  @override
  Set<Column> get primaryKey => {dedupKey};
}

class AppNotifications extends Table {
  TextColumn get id => text()();
  TextColumn get dedupKey => text().nullable().unique()();
  TextColumn get title => text().withLength(min: 1, max: 150)();
  TextColumn get body => text()();
  TextColumn get type => text()();
  TextColumn get payload => text().nullable()();
  TextColumn get relatedEntityId => text().nullable()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  BoolColumn get isDismissed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Wallets,
  Categories,
  Transactions,
  Budgets,
  DebtContacts,
  DebtTransactions,
  ProjectBudgets,
  SavingsGoals,
  AppNotifications,
  NotificationReceipts,
  EntityArchives,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 11; // 🌟 v11: Thêm Transactions.goalId phục vụ Vault Isolation

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 3) {
          await m.createTable(debtContacts);
          await m.createTable(debtTransactions);
        }
        if (from < 4) {
          await m.createTable(projectBudgets);
          await m.addColumn(transactions, transactions.projectBudgetId);
        }
        if (from < 5) {
          await m.createTable(savingsGoals);
        }
        if (from < 6) {
          await m.addColumn(wallets, wallets.creditLimit);
          await m.addColumn(wallets, wallets.statementDay);
          await m.addColumn(wallets, wallets.paymentDueDay);
          await m.addColumn(wallets, wallets.isDefault);
          await m.addColumn(wallets, wallets.isArchived);
          await m.addColumn(wallets, wallets.sortOrder);
          await m.addColumn(wallets, wallets.updatedAt);
          await m.addColumn(transactions, transactions.toWalletId);
        }
        if (from < 7) {
          await m.addColumn(transactions, transactions.deletedAt);
        }
        if (from < 8) {
          await m.addColumn(debtTransactions, debtTransactions.deletedAt);
        }
        if (from < 9) {
          await m.createTable(appNotifications);
          await m.createTable(notificationReceipts);
        }
        if (from < 10) {
          await m.createTable(entityArchives);
        }
        if (from < 11) {
          await m.addColumn(transactions, transactions.goalId);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        // Repair the former category editor's self-parent bug without changing
        // category IDs or any linked transactions and budgets.
        await customStatement(
          'UPDATE categories SET parent_id = NULL WHERE parent_id = id',
        );
        await purgeOldNotifications();
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        await (delete(transactions)
          ..where((t) => t.deletedAt.isNotNull() & t.deletedAt.isSmallerThanValue(thirtyDaysAgo)))
            .go();
        await (delete(debtTransactions)
          ..where((d) => d.deletedAt.isNotNull() & d.deletedAt.isSmallerThanValue(thirtyDaysAgo)))
            .go();
      },
    );
  }

  SimpleSelectStatement<EntityArchives, EntityArchive> _archives(String type) =>
      select(entityArchives)..where((a) => a.entityType.equals(type));

  /// Keep edits within the two-level category tree, using fresh database state.
  Future<void> saveCategoryInHierarchy({
    required String id,
    required String name,
    required CategoryType type,
    required String icon,
    required String color,
    required bool isEditing,
    String? parentId,
  }) async {
    await transaction(() async {
      if (isEditing) {
        final existing = await (select(categories)..where((c) => c.id.equals(id)))
            .getSingleOrNull();
        if (existing == null) {
          throw ArgumentError('Danh mục không còn tồn tại. Hãy mở lại danh sách.');
        }
      }
      if (parentId != null) {
        if (parentId == id) {
          throw ArgumentError('Không thể chọn chính danh mục này làm nhóm cha.');
        }
        final parent = await (select(categories)
              ..where((c) => c.id.equals(parentId) & categoryAvailable(c)))
            .getSingleOrNull();
        if (parent == null || parent.type != type ||
            (parent.parentId != null && parent.parentId!.isNotEmpty)) {
          throw ArgumentError('Hãy chọn một nhóm cha hợp lệ trong cùng loại thu chi.');
        }
        final children = await (select(categories)
              ..where((c) => c.parentId.equals(id))
              ..limit(1))
            .get();
        if (children.isNotEmpty) {
          throw ArgumentError('Nhóm này đang có danh mục con. Hãy chuyển các danh mục con sang nhóm khác trước.');
        }
      }
      if (isEditing) {
        await (update(categories)..where((c) => c.id.equals(id))).write(
          CategoriesCompanion(name: Value(name), icon: Value(icon),
              color: Value(color), parentId: Value(parentId)),
        );
      } else {
        await into(categories).insert(CategoriesCompanion.insert(
          id: id, name: name, type: type, icon: Value(icon),
          color: Value(color), parentId: Value(parentId),
        ));
      }
    });
  }

  Expression<bool> categoryAvailable(Categories c) {
    final archived = selectOnly(entityArchives)
      ..addColumns([entityArchives.entityId])
      ..where(entityArchives.entityType.equals('category'));
    return c.id.isNotInQuery(archived) &
    (c.parentId.isNull() | c.parentId.isNotInQuery(archived));
  }

  Stream<List<Category>> watchAvailableCategories() =>
      (select(categories)..where(categoryAvailable)).watch();

  Stream<List<DebtContact>> watchAvailableDebtContacts() {
    final archived = selectOnly(entityArchives)
      ..addColumns([entityArchives.entityId])
      ..where(entityArchives.entityType.equals('contact'));
    return (select(debtContacts)..where((c) => c.id.isNotInQuery(archived) | c.netBalance.abs().isBiggerThanValue(.001))).watch();
  }

  Future<void> archiveEntity(String type, String id) => transaction(() async {
    if (type == 'contact') {
      final contact = await (select(debtContacts)..where((c) => c.id.equals(id))).getSingleOrNull();
      final outstanding = await (select(debtTransactions)..where((d) =>
      d.contactId.equals(id) & d.deletedAt.isNull() & d.isSettled.equals(false) & d.type.isIn(['LEND', 'BORROW']))).get();
      if (contact == null || contact.netBalance.abs() > .001 || outstanding.isNotEmpty) {
        throw StateError('Hãy tất toán các khoản vay trước khi lưu trữ đối tác.');
      }
    } else if (type == 'category') {
      final category = await (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();
      final protectedChildren = await (select(categories)..where((c) => c.parentId.equals(id) & c.isSystem.equals(true))).get();
      if (category == null || category.isSystem || protectedChildren.isNotEmpty) {
        throw StateError('Danh mục hệ thống cần được giữ lại.');
      }
    } else {
      throw ArgumentError.value(type);
    }
    await into(entityArchives).insert(EntityArchivesCompanion.insert(entityId: id, entityType: type), mode: InsertMode.insertOrIgnore);
  });

  Future<void> restoreArchivedEntity(String type, String id) async {
    await (delete(entityArchives)..where((a) => a.entityType.equals(type) & a.entityId.equals(id))).go();
  }

  Stream<List<EntityArchive>> watchEntityArchives(String type) => _archives(type).watch();

  Future<void> restoreNotification(String id) async {
    await (update(appNotifications)..where((n) => n.id.equals(id)))
        .write(const AppNotificationsCompanion(isDismissed: Value(false)));
  }

  Stream<List<AppNotification>> watchNotifications({String? filterType}) {
    return (select(appNotifications)
      ..where((n) => n.isDismissed.equals(false) &
      n.createdAt.isSmallerOrEqualValue(DateTime.now()) &
      (filterType == null ? const Constant(true) :
      filterType == 'reminder' ? n.type.isIn(['reminder', 'digest', 'system']) : n.type.equals(filterType)))
      ..orderBy([(n) => OrderingTerm.desc(n.createdAt)])).watch();
  }

  Stream<int> watchUnreadNotificationCount() {
    final count = appNotifications.id.count();
    return (selectOnly(appNotifications)..addColumns([count])
      ..where(appNotifications.isRead.equals(false) & appNotifications.isDismissed.equals(false) &
      appNotifications.createdAt.isSmallerOrEqualValue(DateTime.now())))
        .watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<AppNotification?> createNotificationIfNotExists({
    required String dedupKey, required String title, required String body,
    required String type, String? payload, String? relatedEntityId, DateTime? createdAt,
  }) => transaction(() async {
    final receipt = await (select(notificationReceipts)..where((n) => n.dedupKey.equals(dedupKey))).getSingleOrNull();
    if (receipt != null) return null;
    final existing = await (select(appNotifications)..where((n) => n.dedupKey.equals(dedupKey))).getSingleOrNull();
    if (existing != null) return null;
    final id = const Uuid().v4();
    await into(appNotifications).insert(AppNotificationsCompanion.insert(
      id: id, dedupKey: Value(dedupKey), title: title, body: body, type: type,
      payload: Value(payload), relatedEntityId: Value(relatedEntityId),
      createdAt: Value(createdAt ?? DateTime.now()),
    ), mode: InsertMode.insertOrIgnore);
    return (select(appNotifications)..where((n) => n.id.equals(id))).getSingleOrNull();
  });

  Future<void> markAsRead(String id, {bool isRead = true}) async {
    await (update(appNotifications)..where((n) => n.id.equals(id)))
        .write(AppNotificationsCompanion(isRead: Value(isRead)));
  }
  Future<void> markAllAsRead() async {
    await (update(appNotifications)..where((n) => n.createdAt.isSmallerOrEqualValue(DateTime.now())))
        .write(const AppNotificationsCompanion(isRead: Value(true)));
  }
  Future<void> deleteNotification(String id) async {
    await (update(appNotifications)..where((n) => n.id.equals(id)))
        .write(const AppNotificationsCompanion(isDismissed: Value(true)));
  }
  Future<void> revokeNotificationByEntityId(String entityId) async {
    await (update(appNotifications)..where((n) => n.relatedEntityId.equals(entityId)))
        .write(const AppNotificationsCompanion(isDismissed: Value(true)));
  }
  Future<void> purgeOldNotifications() async {
    await transaction(() async {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final old = await (select(appNotifications)..where((n) => n.createdAt.isSmallerThanValue(cutoff))).get();
      for (final item in old) {
        if (item.dedupKey != null) {
          await into(notificationReceipts).insert(NotificationReceiptsCompanion.insert(dedupKey: item.dedupKey!), mode: InsertMode.insertOrIgnore);
        }
      }
      await (delete(appNotifications)..where((n) => n.createdAt.isSmallerThanValue(cutoff))).go();
    });
  }

  // ==========================================
  // TRANSACTION DAOs & REACTIVE STREAMS
  // ==========================================

  Stream<List<Transaction>> watchAllTransactions() {
    return (select(transactions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]))
        .watch();
  }

  Stream<List<Transaction>> watchTransactionsByDateRange(DateTime start, DateTime end) {
    return (select(transactions)
      ..where((t) =>
      t.deletedAt.isNull() &
      t.date.isBiggerOrEqualValue(start) &
      t.date.isSmallerOrEqualValue(end))
      ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<void> insertTransactionWithBalanceUpdate(TransactionsCompanion tx) async {
    await transaction(() async {
      await into(transactions).insert(tx);

      final wallet = await (select(wallets)..where((w) => w.id.equals(tx.walletId.value))).getSingleOrNull();
      if (wallet != null) {
        double delta = 0.0;
        if (tx.type.value == CategoryType.income) {
          delta = tx.amount.value;
        } else if (tx.type.value == CategoryType.expense) {
          delta = -tx.amount.value;
        }

        if (delta != 0.0) {
          await (update(wallets)..where((w) => w.id.equals(tx.walletId.value))).write(
            WalletsCompanion(
              balance: Value(wallet.balance + delta),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }
    });
  }

  // ===========================================================================
  // ATOMIC TRANSACTION MUTATION ENGINE
  // ===========================================================================

  Future<void> updateTransactionAtomically({
    required String transactionId,
    required String walletId,
    required String categoryId,
    required double amount,
    required CategoryType type,
    required DateTime date,
    String? note,
    String? merchant,
    String? envelopeType,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Số tiền giao dịch phải lớn hơn 0 ₫');
    }
    if (type != CategoryType.expense && type != CategoryType.income) {
      throw ArgumentError('updateTransactionAtomically chỉ hỗ trợ khoản chi / khoản thu');
    }

    await transaction(() async {
      final persisted = await (select(transactions)
        ..where((t) => t.id.equals(transactionId)))
          .getSingleOrNull();
      if (persisted == null) {
        throw StateError('Không tìm thấy giao dịch cần cập nhật');
      }
      if (persisted.type != CategoryType.expense &&
          persisted.type != CategoryType.income) {
        throw StateError('Không thể chỉnh sửa loại giao dịch này bằng Quick Entry');
      }

      final category = await (select(categories)
        ..where((c) => c.id.equals(categoryId)))
          .getSingleOrNull();
      if (category == null || category.type != type) {
        throw StateError('Danh mục không hợp lệ với loại giao dịch đã chọn');
      }

      final targetWallet = await (select(wallets)
        ..where((w) => w.id.equals(walletId)))
          .getSingleOrNull();
      if (targetWallet == null) {
        throw StateError('Không tìm thấy nguồn tiền đã chọn');
      }

      if (persisted.deletedAt == null) {
        final oldWallet = await (select(wallets)..where((w) => w.id.equals(persisted.walletId))).getSingleOrNull();
        if (oldWallet == null) {
          throw StateError('Không tìm thấy nguồn tiền gốc của giao dịch');
        }

        final oldReversal = persisted.type == CategoryType.income
            ? -persisted.amount
            : persisted.amount;

        await (update(wallets)..where((w) => w.id.equals(persisted.walletId))).write(
          WalletsCompanion(
            balance: Value(oldWallet.balance + oldReversal),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      final affected = await (update(transactions)
        ..where((t) => t.id.equals(transactionId)))
          .write(
        TransactionsCompanion(
          walletId: Value(walletId),
          categoryId: Value(categoryId),
          amount: Value(amount),
          type: Value(type),
          envelopeType: Value(envelopeType),
          date: Value(date),
          note: Value(note),
          merchant: Value(merchant),
          deletedAt: const Value<DateTime?>(null),
        ),
      );
      if (affected != 1) {
        throw StateError('Không thể cập nhật giao dịch');
      }

      final walletAfterRollback = await (select(wallets)..where((w) => w.id.equals(walletId))).getSingleOrNull();
      if (walletAfterRollback == null) {
        throw StateError('Không tìm thấy nguồn tiền sau khi đối soát');
      }

      final newDelta = type == CategoryType.income ? amount : -amount;
      await (update(wallets)..where((w) => w.id.equals(walletId))).write(
        WalletsCompanion(
          balance: Value(walletAfterRollback.balance + newDelta),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> convertTransactionToDebtAtomically({
    required String transactionId,
    required String contactId,
    required String walletId,
    required String debtType,
    required double amount,
    required DateTime date,
    DateTime? dueDate,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Số tiền giao dịch vay nợ phải lớn hơn 0 ₫');
    }
    if (debtType != 'LEND' &&
        debtType != 'COLLECT' &&
        debtType != 'BORROW' &&
        debtType != 'REPAY') {
      throw ArgumentError('Loại giao dịch vay nợ không hợp lệ');
    }

    await transaction(() async {
      final persisted = await (select(transactions)..where((t) => t.id.equals(transactionId))).getSingleOrNull();
      if (persisted == null) {
        throw StateError('Không tìm thấy giao dịch cần chuyển đổi');
      }
      if (persisted.type != CategoryType.expense &&
          persisted.type != CategoryType.income) {
        throw StateError('Chỉ có thể chuyển khoản chi / khoản thu sang vay nợ');
      }

      final contact = await (select(debtContacts)..where((c) => c.id.equals(contactId))).getSingleOrNull();
      if (contact == null) {
        throw StateError('Không tìm thấy người liên quan');
      }

      final targetWallet = await (select(wallets)..where((w) => w.id.equals(walletId))).getSingleOrNull();
      if (targetWallet == null) {
        throw StateError('Không tìm thấy nguồn tiền đã chọn');
      }

      await into(debtTransactions).insert(
        DebtTransactionsCompanion(
          id: Value(transactionId),
          contactId: Value(contactId),
          walletId: Value(walletId),
          type: Value(debtType),
          amount: Value(amount),
          date: Value(date),
          dueDate: Value(dueDate),
          note: Value(note),
          isSettled: const Value(false),
          createdAt: Value(persisted.createdAt),
          deletedAt: const Value<DateTime?>(null),
        ),
      );

      if (persisted.deletedAt == null) {
        final oldWallet = await (select(wallets)..where((w) => w.id.equals(persisted.walletId))).getSingleOrNull();
        if (oldWallet == null) {
          throw StateError('Không tìm thấy nguồn tiền gốc của giao dịch');
        }

        final oldReversal = persisted.type == CategoryType.income
            ? -persisted.amount
            : persisted.amount;
        await (update(wallets)..where((w) => w.id.equals(persisted.walletId))).write(
          WalletsCompanion(
            balance: Value(oldWallet.balance + oldReversal),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      double contactDelta;
      double walletDelta;
      switch (debtType) {
        case 'LEND':
          contactDelta = amount;
          walletDelta = -amount;
          break;
        case 'COLLECT':
          contactDelta = -amount;
          walletDelta = amount;
          break;
        case 'BORROW':
          contactDelta = -amount;
          walletDelta = amount;
          break;
        case 'REPAY':
          contactDelta = amount;
          walletDelta = -amount;
          break;
        default:
          throw StateError('Loại giao dịch vay nợ không hợp lệ');
      }

      final walletAfterRollback = await (select(wallets)..where((w) => w.id.equals(walletId))).getSingleOrNull();
      if (walletAfterRollback == null) {
        throw StateError('Không tìm thấy nguồn tiền sau khi đối soát');
      }

      await (update(wallets)..where((w) => w.id.equals(walletId))).write(
        WalletsCompanion(
          balance: Value(walletAfterRollback.balance + walletDelta),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await (update(debtContacts)..where((c) => c.id.equals(contactId))).write(
        DebtContactsCompanion(
          netBalance: Value(contact.netBalance + contactDelta),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final removed = await (delete(transactions)..where((t) => t.id.equals(transactionId))).go();
      if (removed != 1) {
        throw StateError('Không thể hoàn tất chuyển đổi giao dịch');
      }
    });
  }

  // ==========================================
  // 🌟 SOFT-DELETE & RECYCLE BIN ENGINE (TRANSACTIONS)
  // ==========================================

  Future<void> softDeleteTransaction(String txId) async {
    await transaction(() async {
      final tx = await (select(transactions)..where((t) => t.id.equals(txId)))
          .getSingleOrNull();
      if (tx == null || tx.deletedAt != null) return;
      await revokeNotificationByEntityId(txId);

      final wallet = await (select(wallets)
            ..where((w) => w.id.equals(tx.walletId)))
          .getSingleOrNull();
      if (tx.type == CategoryType.transfer) {
        await _applyTransferBalanceDelta(tx, sourceDelta: tx.amount);
      } else if (wallet != null) {
        double reversal = 0.0;
        if (tx.type == CategoryType.income) {
          reversal = -tx.amount;
        } else if (tx.type == CategoryType.expense) {
          reversal = tx.amount;
        }

        if (reversal != 0.0) {
          await (update(wallets)..where((w) => w.id.equals(tx.walletId))).write(
            WalletsCompanion(
              balance: Value(wallet.balance + reversal),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }

      await (update(transactions)..where((t) => t.id.equals(txId))).write(
        TransactionsCompanion(
          deletedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> restoreTransaction(String txId) async {
    await transaction(() async {
      final tx = await (select(transactions)..where((t) => t.id.equals(txId)))
          .getSingleOrNull();
      if (tx == null || tx.deletedAt == null) return;

      final wallet = await (select(wallets)
            ..where((w) => w.id.equals(tx.walletId)))
          .getSingleOrNull();
      if (tx.type == CategoryType.transfer) {
        await _applyTransferBalanceDelta(tx, sourceDelta: -tx.amount);
      } else if (wallet != null) {
        double delta = 0.0;
        if (tx.type == CategoryType.income) {
          delta = tx.amount;
        } else if (tx.type == CategoryType.expense) {
          delta = -tx.amount;
        }

        if (delta != 0.0) {
          await (update(wallets)..where((w) => w.id.equals(tx.walletId))).write(
            WalletsCompanion(
              balance: Value(wallet.balance + delta),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }

      await (update(transactions)..where((t) => t.id.equals(txId))).write(
        const TransactionsCompanion(
          deletedAt: Value(null),
        ),
      );
    });
  }

  // Called inside the delete/restore transaction; fees are separate expenses.
  Future<void> _applyTransferBalanceDelta(
    Transaction tx, {
    required double sourceDelta,
  }) async {
    final destinationId = tx.toWalletId;
    if (destinationId == null || destinationId == tx.walletId) {
      throw StateError('Giao dịch chuyển tiền không có đủ hai ví hợp lệ.');
    }
    final source = await (select(wallets)
          ..where((w) => w.id.equals(tx.walletId)))
        .getSingleOrNull();
    final destination = await (select(wallets)
          ..where((w) => w.id.equals(destinationId)))
        .getSingleOrNull();
    if (source == null || destination == null) {
      throw StateError('Không tìm thấy đủ hai ví để đối soát chuyển tiền.');
    }
    final now = DateTime.now();
    await (update(wallets)..where((w) => w.id.equals(source.id))).write(
      WalletsCompanion(
        balance: Value(source.balance + sourceDelta),
        updatedAt: Value(now),
      ),
    );
    await (update(wallets)..where((w) => w.id.equals(destination.id))).write(
      WalletsCompanion(
        balance: Value(destination.balance - sourceDelta),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> permanentDeleteTransaction(String txId) async {
    await (delete(transactions)..where((t) => t.id.equals(txId))).go();
  }

  // ==========================================
  // 🌟 SOFT-DELETE & RECYCLE BIN ENGINE (DEBT TRANSACTIONS)
  // ==========================================

  Future<void> softDeleteDebtTransaction(String txId) async {
    await transaction(() async {
      final tx = await (select(debtTransactions)..where((t) => t.id.equals(txId))).getSingleOrNull();
      if (tx == null || tx.deletedAt != null) return;
      await revokeNotificationByEntityId(txId);

      double contactReversal = 0.0;
      double walletReversal = 0.0;

      switch (tx.type) {
        case 'LEND':
          contactReversal = -tx.amount;
          walletReversal = tx.amount;
          break;
        case 'COLLECT':
          contactReversal = tx.amount;
          walletReversal = -tx.amount;
          break;
        case 'BORROW':
          contactReversal = tx.amount;
          walletReversal = -tx.amount;
          break;
        case 'REPAY':
          contactReversal = -tx.amount;
          walletReversal = tx.amount;
          break;
      }

      final contact = await (select(debtContacts)..where((c) => c.id.equals(tx.contactId))).getSingleOrNull();
      if (contact != null) {
        await (update(debtContacts)..where((c) => c.id.equals(tx.contactId))).write(
          DebtContactsCompanion(
            netBalance: Value(contact.netBalance + contactReversal),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      final wallet = await (select(wallets)..where((w) => w.id.equals(tx.walletId))).getSingleOrNull();
      if (wallet != null) {
        await (update(wallets)..where((w) => w.id.equals(tx.walletId))).write(
          WalletsCompanion(
            balance: Value(wallet.balance + walletReversal),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      await (update(debtTransactions)..where((t) => t.id.equals(txId))).write(
        DebtTransactionsCompanion(
          deletedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> restoreDebtTransaction(String txId) async {
    await transaction(() async {
      final tx = await (select(debtTransactions)..where((t) => t.id.equals(txId))).getSingleOrNull();
      if (tx == null || tx.deletedAt == null) return;

      double contactReapply = 0.0;
      double walletReapply = 0.0;

      switch (tx.type) {
        case 'LEND':
          contactReapply = tx.amount;
          walletReapply = -tx.amount;
          break;
        case 'COLLECT':
          contactReapply = -tx.amount;
          walletReapply = tx.amount;
          break;
        case 'BORROW':
          contactReapply = -tx.amount;
          walletReapply = tx.amount;
          break;
        case 'REPAY':
          contactReapply = tx.amount;
          walletReapply = -tx.amount;
          break;
      }

      final contact = await (select(debtContacts)..where((c) => c.id.equals(tx.contactId))).getSingleOrNull();
      if (contact != null) {
        await (update(debtContacts)..where((c) => c.id.equals(tx.contactId))).write(
          DebtContactsCompanion(
            netBalance: Value(contact.netBalance + contactReapply),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      final wallet = await (select(wallets)..where((w) => w.id.equals(tx.walletId))).getSingleOrNull();
      if (wallet != null) {
        await (update(wallets)..where((w) => w.id.equals(tx.walletId))).write(
          WalletsCompanion(
            balance: Value(wallet.balance + walletReapply),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      await (update(debtTransactions)..where((t) => t.id.equals(txId))).write(
        const DebtTransactionsCompanion(
          deletedAt: Value(null),
        ),
      );
    });
  }

  Future<void> permanentDeleteDebtTransaction(String txId) async {
    await (delete(debtTransactions)..where((t) => t.id.equals(txId))).go();
  }

  Future<int> emptyRecycleBin() async {
    return await transaction(() async {
      final countTx = await (delete(transactions)..where((t) => t.deletedAt.isNotNull())).go();
      final countDebt = await (delete(debtTransactions)..where((d) => d.deletedAt.isNotNull())).go();
      return countTx + countDebt;
    });
  }

  Future<int> purgeOldDeletedTransactions() async {
    final threshold = DateTime.now().subtract(const Duration(days: 30));
    return await transaction(() async {
      final countTx = await (delete(transactions)
        ..where((t) => t.deletedAt.isNotNull() & t.deletedAt.isSmallerThanValue(threshold)))
          .go();
      final countDebt = await (delete(debtTransactions)
        ..where((d) => d.deletedAt.isNotNull() & d.deletedAt.isSmallerThanValue(threshold)))
          .go();
      return countTx + countDebt;
    });
  }

  Stream<List<DeletedTransactionItem>> watchDeletedTransactions() {
    final query = select(transactions).join([
      leftOuterJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      leftOuterJoin(wallets, wallets.id.equalsExp(transactions.walletId)),
    ])
      ..where(transactions.deletedAt.isNotNull())
      ..orderBy([OrderingTerm.desc(transactions.deletedAt)]);

    return query.watch().map((rows) {
      final now = DateTime.now();
      return rows.map((row) {
        final tx = row.readTable(transactions);
        final cat = row.readTableOrNull(categories);
        final w = row.readTableOrNull(wallets);

        final deletedTime = tx.deletedAt ?? now;
        final elapsedDays = now.difference(deletedTime).inDays;
        final daysLeft = math.max(0, 30 - elapsedDays);

        return DeletedTransactionItem(
          transaction: tx,
          category: cat,
          wallet: w,
          daysRemaining: daysLeft,
        );
      }).toList();
    });
  }

  Stream<int> watchDeletedTransactionsCount() {
    final txCountExp = transactions.id.count();
    final txQuery = selectOnly(transactions)
      ..addColumns([txCountExp])
      ..where(transactions.deletedAt.isNotNull());

    final debtCountExp = debtTransactions.id.count();
    final debtQuery = selectOnly(debtTransactions)
      ..addColumns([debtCountExp])
      ..where(debtTransactions.deletedAt.isNotNull());

    return txQuery.watch().asyncMap((txRows) async {
      final debtRows = await debtQuery.get();
      final count1 = txRows.first.read(txCountExp) ?? 0;
      final count2 = debtRows.first.read(debtCountExp) ?? 0;
      return count1 + count2;
    });
  }

  Future<void> deleteTransactionWithBalanceReversal(String txId) async {
    await softDeleteTransaction(txId);
  }

  // ==========================================
  // 🌟 EXECUTIVE WEALTH SOURCE & INTERNAL TRANSFER DAOS
  // ==========================================

  Future<void> executeInternalTransfer({
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    double fee = 0.0,
    String? note,
    required DateTime date,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Số tiền chuyển phải lớn hơn 0 ₫');
    }
    if (fromWalletId == toWalletId) {
      throw ArgumentError('Ví nguồn và ví đích không được trùng nhau');
    }

    await transaction(() async {
      final fromWallet = await (select(wallets)..where((w) => w.id.equals(fromWalletId))).getSingleOrNull();
      if (fromWallet == null) {
        throw StateError('Không tìm thấy ví nguồn với ID: $fromWalletId');
      }

      final toWallet = await (select(wallets)..where((w) => w.id.equals(toWalletId))).getSingleOrNull();
      if (toWallet == null) {
        throw StateError('Không tìm thấy ví đích với ID: $toWalletId');
      }

      final totalDeduct = amount + fee;
      if (fromWallet.type != 'credit' && fromWallet.balance < totalDeduct) {
        throw StateError('Số dư ví "${fromWallet.name}" không đủ để chuyển tiền và trả phí');
      }

      await (update(wallets)..where((w) => w.id.equals(fromWalletId))).write(
        WalletsCompanion(
          balance: Value(fromWallet.balance - totalDeduct),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await (update(wallets)..where((w) => w.id.equals(toWalletId))).write(
        WalletsCompanion(
          balance: Value(toWallet.balance + amount),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final defaultCat = await (select(categories)..limit(1)).getSingleOrNull();
      final catId = defaultCat?.id ?? 'cat_default';

      final transferTxId = 'tx_xfer_${DateTime.now().millisecondsSinceEpoch}';
      await into(transactions).insert(
        TransactionsCompanion(
          id: Value(transferTxId),
          walletId: Value(fromWalletId),
          toWalletId: Value(toWalletId),
          categoryId: Value(catId),
          amount: Value(amount),
          type: const Value(CategoryType.transfer),
          envelopeType: const Value('needs'),
          date: Value(date),
          note: Value(note ?? 'Chuyển tiền: ${fromWallet.name} ➔ ${toWallet.name}'),
          merchant: Value('${fromWallet.name} ➔ ${toWallet.name}'),
          createdAt: Value(DateTime.now()),
        ),
      );

      if (fee > 0) {
        await into(transactions).insert(
          TransactionsCompanion(
            id: Value('tx_fee_${DateTime.now().millisecondsSinceEpoch}'),
            walletId: Value(fromWalletId),
            categoryId: Value(catId),
            amount: Value(fee),
            type: const Value(CategoryType.expense),
            envelopeType: const Value('needs'),
            date: Value(date),
            note: Value('Phí chuyển tiền: ${fromWallet.name} ➔ ${toWallet.name}'),
            merchant: Value('Phí giao dịch ngân hàng'),
            createdAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  Future<void> adjustWalletBalance({
    required String walletId,
    required double realBalance,
    required String reason,
  }) async {
    await transaction(() async {
      final wallet = await (select(wallets)..where((w) => w.id.equals(walletId))).getSingleOrNull();
      if (wallet == null) {
        throw StateError('Không tìm thấy ví với ID: $walletId');
      }

      final delta = realBalance - wallet.balance;
      if (delta.abs() < 0.001) return;

      await (update(wallets)..where((w) => w.id.equals(walletId))).write(
        WalletsCompanion(
          balance: Value(realBalance),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final defaultCat = await (select(categories)..limit(1)).getSingleOrNull();
      final catId = defaultCat?.id ?? 'cat_default';

      final isPositive = delta > 0;
      final auditAmount = delta.abs();

      await into(transactions).insert(
        TransactionsCompanion(
          id: Value('tx_audit_${DateTime.now().millisecondsSinceEpoch}'),
          walletId: Value(walletId),
          categoryId: Value(catId),
          amount: Value(auditAmount),
          type: Value(isPositive ? CategoryType.income : CategoryType.expense),
          envelopeType: const Value('needs'),
          date: Value(DateTime.now()),
          note: Value('Kiểm kê số dư ví [${wallet.name}]: $reason'),
          merchant: Value('Điều chỉnh kiểm kê sổ cái'),
          createdAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> setWalletAsDefault(String walletId) async {
    await transaction(() async {
      await update(wallets).write(
        const WalletsCompanion(isDefault: Value(false)),
      );
      await (update(wallets)..where((w) => w.id.equals(walletId))).write(
        const WalletsCompanion(isDefault: Value(true)),
      );
    });
  }

  Future<void> archiveWallet(String walletId) async {
    final wallet = await (select(wallets)..where((w) => w.id.equals(walletId))).getSingleOrNull();
    if (wallet == null) return;
    if (wallet.balance.abs() > 0.001) {
      throw StateError('Chỉ có thể lưu trữ ví khi số dư đã đưa về 0 ₫');
    }
    await (update(wallets)..where((w) => w.id.equals(walletId))).write(
      WalletsCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> unarchiveWallet(String walletId) async {
    await (update(wallets)..where((w) => w.id.equals(walletId))).write(
      WalletsCompanion(
        isArchived: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteWalletSafely(String walletId) async {
    final linkedTxs = await (select(transactions)
      ..where((t) => t.walletId.equals(walletId) | t.toWalletId.equals(walletId)))
        .get();
    if (linkedTxs.isNotEmpty) {
      throw StateError(
        'Ví này đã phát sinh ${linkedTxs.length} giao dịch. Không thể xóa cứng để bảo vệ tính toàn vẹn sổ sách. Hãy đưa số dư về 0 ₫ và chọn lưu trữ ví.',
      );
    }
    await (delete(wallets)..where((w) => w.id.equals(walletId))).go();
  }

  Future<void> updateWallet({
    required String id,
    String? name,
    String? type,
    String? color,
    bool? isExcludedFromTotal,
    double? creditLimit,
    int? statementDay,
    int? paymentDueDay,
    bool? isDefault,
  }) async {
    await (update(wallets)..where((w) => w.id.equals(id))).write(
      WalletsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        type: type != null ? Value(type) : const Value.absent(),
        color: color != null ? Value(color) : const Value.absent(),
        isExcludedFromTotal: isExcludedFromTotal != null ? Value(isExcludedFromTotal) : const Value.absent(),
        creditLimit: creditLimit != null ? Value(creditLimit) : const Value.absent(),
        statementDay: statementDay != null ? Value(statementDay) : const Value.absent(),
        paymentDueDay: paymentDueDay != null ? Value(paymentDueDay) : const Value.absent(),
        isDefault: isDefault != null ? Value(isDefault) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ==========================================
  // 2-TIER CATEGORY HIERARCHY QUERIES
  // ==========================================

  Future<List<CategoryHierarchyNode>> getCategoriesHierarchy({CategoryType? filterType}) async {
    final query = select(categories);
    if (filterType != null) {
      query.where((c) => c.type.equals(filterType.index));
    }
    query.orderBy([(c) => OrderingTerm(expression: c.sortOrder)]);

    final allCategories = await query.get();
    final parents = allCategories.where((c) => c.parentId == null).toList();

    return parents.map((parent) {
      final children = allCategories.where((c) => c.parentId == parent.id).toList();
      return CategoryHierarchyNode(parent: parent, subcategories: children);
    }).toList();
  }

  Stream<List<CategoryHierarchyNode>> watchCategoriesHierarchy({CategoryType? filterType}) {
    final query = select(categories);
    if (filterType != null) {
      query.where((c) => c.type.equals(filterType.index));
    }
    query.orderBy([(c) => OrderingTerm(expression: c.sortOrder)]);

    return query.watch().map((allCategories) {
      final parents = allCategories.where((c) => c.parentId == null).toList();
      return parents.map((parent) {
        final children = allCategories.where((c) => c.parentId == parent.id).toList();
        return CategoryHierarchyNode(parent: parent, subcategories: children);
      }).toList();
    });
  }

  // ==========================================
  // WALLET DAOs
  // ==========================================

  Stream<List<Wallet>> watchAllWallets({bool includeArchived = false}) {
    final query = select(wallets);
    if (!includeArchived) {
      query.where((w) => w.isArchived.equals(false));
    }
    query.orderBy([(w) => OrderingTerm.asc(w.sortOrder), (w) => OrderingTerm.asc(w.createdAt)]);
    return query.watch();
  }

  Future<int> insertWallet(WalletsCompanion wallet) {
    return into(wallets).insert(wallet);
  }

  // ==========================================
  // 🌟 DEBT DAO: REACTIVE STREAMS & ATOMIC MUTATIONS
  // ==========================================

  Stream<List<DebtContact>> watchAllDebtContacts() {
    return select(debtContacts).watch().map((contacts) {
      final sortedList = List<DebtContact>.from(contacts);
      sortedList.sort((a, b) {
        final aHasDebt = a.netBalance.abs() > 0.001;
        final bHasDebt = b.netBalance.abs() > 0.001;

        if (aHasDebt && !bHasDebt) return -1;
        if (!aHasDebt && bHasDebt) return 1;

        return b.netBalance.abs().compareTo(a.netBalance.abs());
      });
      return sortedList;
    });
  }

  Stream<List<DebtTransaction>> watchDebtTransactionsByContact(String contactId) {
    return (select(debtTransactions)
      ..where((t) => t.contactId.equals(contactId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Stream<DebtSummary> watchDebtSummary() {
    return select(debtContacts).watch().map((contacts) {
      double receivable = 0.0;
      double payable = 0.0;

      for (final c in contacts) {
        if (c.netBalance > 0) {
          receivable += c.netBalance;
        } else if (c.netBalance < 0) {
          payable += c.netBalance.abs();
        }
      }

      return DebtSummary(
        totalReceivable: receivable,
        totalPayable: payable,
        netWorthAdjustment: receivable - payable,
      );
    });
  }

  Future<void> createDebtTransaction({
    required String id,
    required String contactId,
    required String walletId,
    required String type,
    required double amount,
    required DateTime date,
    DateTime? dueDate,
    String? note,
  }) async {
    await transaction(() async {
      final contact = await (select(debtContacts)..where((c) => c.id.equals(contactId))).getSingleOrNull();
      if (contact == null) {
        throw StateError('Không tìm thấy đối tác nợ với ID: $contactId');
      }

      final wallet = await (select(wallets)..where((w) => w.id.equals(walletId))).getSingleOrNull();
      if (wallet == null) {
        throw StateError('Không tìm thấy ví nguồn/đích với ID: $walletId');
      }

      await into(debtTransactions).insert(
        DebtTransactionsCompanion(
          id: Value(id),
          contactId: Value(contactId),
          walletId: Value(walletId),
          type: Value(type),
          amount: Value(amount),
          date: Value(date),
          dueDate: Value(dueDate),
          note: Value(note),
          isSettled: const Value(false),
          createdAt: Value(DateTime.now()),
        ),
      );

      double contactDelta = 0.0;
      double walletDelta = 0.0;

      switch (type) {
        case 'LEND':
          contactDelta = amount;
          walletDelta = -amount;
          break;
        case 'COLLECT':
          contactDelta = -amount;
          walletDelta = amount;
          break;
        case 'BORROW':
          contactDelta = -amount;
          walletDelta = amount;
          break;
        case 'REPAY':
          contactDelta = amount;
          walletDelta = -amount;
          break;
        default:
          throw ArgumentError('Loại giao dịch vay nợ không hợp lệ: $type');
      }

      await (update(debtContacts)..where((c) => c.id.equals(contactId))).write(
        DebtContactsCompanion(
          netBalance: Value(contact.netBalance + contactDelta),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await (update(wallets)..where((w) => w.id.equals(walletId))).write(
        WalletsCompanion(
          balance: Value(wallet.balance + walletDelta),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> updateDebtTransaction({
    required DebtTransaction newTx,
  }) async {
    await transaction(() async {
      final persisted = await (select(debtTransactions)
            ..where((t) => t.id.equals(newTx.id)))
          .getSingleOrNull();
      if (persisted == null || persisted.deletedAt != null) {
        throw StateError('Khoản nợ không còn khả dụng để chỉnh sửa');
      }
      const supportedTypes = {'LEND', 'COLLECT', 'BORROW', 'REPAY'};
      if (!supportedTypes.contains(persisted.type) ||
          !supportedTypes.contains(newTx.type)) {
        throw StateError('Loại giao dịch vay nợ không hợp lệ');
      }
      if (!newTx.amount.isFinite || newTx.amount <= 0) {
        throw ArgumentError('Số tiền giao dịch phải lớn hơn 0');
      }
      final oldWallet = await (select(wallets)
            ..where((w) => w.id.equals(persisted.walletId)))
          .getSingleOrNull();
      final oldContact = await (select(debtContacts)
            ..where((c) => c.id.equals(persisted.contactId)))
          .getSingleOrNull();
      final newWallet = await (select(wallets)
            ..where((w) => w.id.equals(newTx.walletId)))
          .getSingleOrNull();
      final newContact = await (select(debtContacts)
            ..where((c) => c.id.equals(newTx.contactId)))
          .getSingleOrNull();
      if (oldWallet == null ||
          oldContact == null ||
          newWallet == null ||
          newContact == null) {
        throw StateError('Không tìm thấy đầy đủ ví và đối tác liên quan');
      }

      // Roll back the current ledger row, never the snapshot held by the UI.
      final walletRollback =
          (persisted.type == 'LEND' || persisted.type == 'REPAY')
              ? persisted.amount
              : -persisted.amount;
      final walletReapply = (newTx.type == 'LEND' || newTx.type == 'REPAY')
          ? -newTx.amount
          : newTx.amount;
      final oldWalletRows = await (update(wallets)
            ..where((w) => w.id.equals(persisted.walletId)))
          .write(WalletsCompanion(
        balance: Value(oldWallet.balance + walletRollback),
        updatedAt: Value(DateTime.now()),
      ));
      final oldContactRows = await (update(debtContacts)
            ..where((c) => c.id.equals(persisted.contactId)))
          .write(DebtContactsCompanion(
        netBalance: Value(oldContact.netBalance - walletRollback),
        updatedAt: Value(DateTime.now()),
      ));

      // Reload after rollback: old and new IDs may refer to the same entity.
      final refreshedWallet = await (select(wallets)
            ..where((w) => w.id.equals(newTx.walletId)))
          .getSingle();
      final refreshedContact = await (select(debtContacts)
            ..where((c) => c.id.equals(newTx.contactId)))
          .getSingle();
      final newWalletRows = await (update(wallets)
            ..where((w) => w.id.equals(newTx.walletId)))
          .write(WalletsCompanion(
        balance: Value(refreshedWallet.balance + walletReapply),
        updatedAt: Value(DateTime.now()),
      ));
      final newContactRows = await (update(debtContacts)
            ..where((c) => c.id.equals(newTx.contactId)))
          .write(DebtContactsCompanion(
        netBalance: Value(refreshedContact.netBalance - walletReapply),
        updatedAt: Value(DateTime.now()),
      ));
      if (oldWalletRows != 1 ||
          oldContactRows != 1 ||
          newWalletRows != 1 ||
          newContactRows != 1) {
        throw StateError('Không thể cập nhật đủ hai phía của khoản nợ');
      }
      final updated = await (update(debtTransactions)
            ..where((t) => t.id.equals(persisted.id) & t.deletedAt.isNull()))
          .write(
        DebtTransactionsCompanion(
          contactId: Value(newTx.contactId),
          walletId: Value(newTx.walletId),
          type: Value(newTx.type),
          amount: Value(newTx.amount),
          date: Value(newTx.date),
          dueDate: Value(newTx.dueDate),
          note: Value(newTx.note),
          isSettled: Value(newTx.isSettled),
        ),
      );
      if (updated != 1) {
        throw StateError('Không thể hoàn tất cập nhật khoản nợ');
      }
    });
  }

  Future<void> deleteDebtTransaction(String txId) async {
    await softDeleteDebtTransaction(txId);
  }

  Future<void> deleteDebtTransactionWithSafetyCheck(String txId) async {
    final allTxs = await select(debtTransactions).get();
    final linkedChildren = allTxs.where((t) => t.note?.contains('#ref:$txId') == true && t.deletedAt == null).toList();
    if (linkedChildren.isNotEmpty) {
      throw StateError(
        'Khoản vay này đã có ${linkedChildren.length} giao dịch trả nợ đi kèm. Vui lòng xóa các giao dịch trả nợ trước khi xóa khoản vay gốc này.',
      );
    }

    await softDeleteDebtTransaction(txId);
  }

  Future<void> upsertDebtContact(DebtContactsCompanion contact) async {
    await into(debtContacts).insertOnConflictUpdate(contact);
  }

  Future<void> updateDebtContactMetadata({
    required String id,
    required String name,
    String? phone,
    String? avatarUrl,
  }) async {
    final updated = await (update(debtContacts)..where((c) => c.id.equals(id)))
        .write(DebtContactsCompanion(
      name: Value(name),
      phone: Value(phone),
      avatarUrl: Value(avatarUrl),
      updatedAt: Value(DateTime.now()),
    ));
    if (updated != 1) {
      throw StateError('Đối tác không còn tồn tại. Hãy mở lại danh sách.');
    }
  }

  // ==========================================
  // 🌟 PROJECT BUDGET DAOs & REPOSITORY METHODS
  // ==========================================

  Stream<List<ProjectBudget>> watchProjectBudgets() {
    return (select(projectBudgets)
      ..orderBy([(p) => OrderingTerm.desc(p.startDate)]))
        .watch();
  }

  Stream<List<ProjectBudget>> watchAllProjectBudgets() {
    return watchProjectBudgets();
  }

  Stream<List<Transaction>> watchTransactionsForProject(String projectId, String tag) {
    final cleanTag = tag.trim();
    return (select(transactions)
      ..where((t) {
        final isNotDeleted = t.deletedAt.isNull();
        final isNotSavings = t.goalId.isNull() &
            (t.envelopeType.equals('savings').not() |
                t.envelopeType.isNull());
        final matchesId = t.projectBudgetId.equals(projectId);
        final matchesTagNote = t.note.isNotNull() & t.note.like('%$cleanTag%');
        final matchesTagMerchant = t.merchant.isNotNull() & t.merchant.like('%$cleanTag%');
        return isNotDeleted &
            isNotSavings &
            (matchesId | matchesTagNote | matchesTagMerchant);
      })
      ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Future<double> calculateProjectSpent(String projectId, String tag) async {
    final cleanTag = tag.trim();
    final query = select(transactions)
      ..where((t) {
        final isNotDeleted = t.deletedAt.isNull();
        final isNotSavings = t.goalId.isNull() &
            (t.envelopeType.equals('savings').not() | t.envelopeType.isNull());
        final isExpense = t.type.equals(CategoryType.expense.index);
        final matchesId = t.projectBudgetId.equals(projectId);
        final matchesTagNote = t.note.isNotNull() & t.note.like('%$cleanTag%');
        final matchesTagMerchant = t.merchant.isNotNull() & t.merchant.like('%$cleanTag%');
        return isNotDeleted &
            isNotSavings &
            isExpense &
            (matchesId | matchesTagNote | matchesTagMerchant);
      });

    final txs = await query.get();
    return txs.fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  Future<double> calculateRecurringSpentForCategory({
    required String categoryId,
    required DateTime startDate,
    required DateTime endDate,
    bool isParentCategory = false,
  }) async {
    final activeProjects = await (select(projectBudgets)..where((p) => p.status.isNotValue('ARCHIVED'))).get();
    final activeTags = activeProjects.map((p) => p.tag.toLowerCase().trim()).toSet();

    List<String> targetCategoryIds = [categoryId];
    if (isParentCategory) {
      final subCategories = await (select(categories)..where((c) => c.parentId.equals(categoryId))).get();
      targetCategoryIds.addAll(subCategories.map((c) => c.id));
    }

    final txs = await (select(transactions)
      ..where((t) {
        final isNotDeleted = t.deletedAt.isNull();
        final isExpense = t.type.equals(CategoryType.expense.index);
        final inCategory = t.categoryId.isIn(targetCategoryIds);
        final isNotSavings = t.goalId.isNull() &
            (t.envelopeType.equals('savings').not() |
                t.envelopeType.isNull());
        final inRange = t.date.isBiggerOrEqualValue(startDate) & t.date.isSmallerOrEqualValue(endDate);
        return isNotDeleted &
            isNotSavings &
            isExpense &
            inCategory &
            inRange;
      }))
        .get();

    double totalSpent = 0.0;
    for (final tx in txs) {
      if (tx.projectBudgetId != null && tx.projectBudgetId!.isNotEmpty) continue;

      final noteLower = tx.note?.toLowerCase() ?? '';
      final merchantLower = tx.merchant?.toLowerCase() ?? '';
      final isLinkedToEvent = activeTags.any((tag) => noteLower.contains(tag) || merchantLower.contains(tag));
      if (isLinkedToEvent) continue;

      totalSpent += tx.amount;
    }

    return totalSpent;
  }

  Future<void> createProjectBudget({
    required String id,
    required String title,
    required String tag,
    String icon = '🌴',
    String colorHex = '#0EA5E9',
    required double targetAmount,
    required DateTime startDate,
    required DateTime endDate,
    String status = 'ACTIVE',
  }) async {
    await into(projectBudgets).insert(
      ProjectBudgetsCompanion(
        id: Value(id),
        title: Value(title),
        tag: Value(tag),
        icon: Value(icon),
        colorHex: Value(colorHex),
        targetAmount: Value(targetAmount),
        startDate: Value(startDate),
        endDate: Value(endDate),
        status: Value(status),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateProjectBudget({
    required String id,
    String? title,
    String? tag,
    String? icon,
    String? colorHex,
    double? targetAmount,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    await (update(projectBudgets)..where((p) => p.id.equals(id))).write(
      ProjectBudgetsCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        tag: tag != null ? Value(tag) : const Value.absent(),
        icon: icon != null ? Value(icon) : const Value.absent(),
        colorHex: colorHex != null ? Value(colorHex) : const Value.absent(),
        targetAmount: targetAmount != null ? Value(targetAmount) : const Value.absent(),
        startDate: startDate != null ? Value(startDate) : const Value.absent(),
        endDate: endDate != null ? Value(endDate) : const Value.absent(),
        status: status != null ? Value(status) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> upsertProjectBudget(ProjectBudgetsCompanion budget) async {
    await into(projectBudgets).insertOnConflictUpdate(budget);
  }

  Future<void> archiveProjectBudget(String id) async {
    await (update(projectBudgets)..where((p) => p.id.equals(id))).write(
      ProjectBudgetsCompanion(
        status: const Value('ARCHIVED'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteProjectBudget(String id) async {
    await transaction(() async {
      await (update(transactions)..where((t) => t.projectBudgetId.equals(id))).write(
        const TransactionsCompanion(projectBudgetId: Value(null)),
      );
      await (delete(projectBudgets)..where((p) => p.id.equals(id))).go();
    });
  }

  Future<void> deleteProjectBudgetSafely(String id) async {
    await deleteProjectBudget(id);
  }

  // ==========================================
  // 🌟 SAVINGS GOALS DAOs & REACTIVE STREAMS
  // ==========================================

  Stream<List<SavingsGoal>> watchAllSavingsGoals() {
    return (select(savingsGoals)
      ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
        .watch();
  }

  // ===========================================================================
  // 🌟 VAULT AUDIT LEDGER REACTIVE STREAMS (NHẬT KÝ TÍCH LŨY KÉT)
  // ===========================================================================

  /// Lắng nghe lịch sử nạp/rút tiền của MỘT HŨ CỤ THỂ (kèm thông tin ví đối ứng)
  Stream<List<VaultTransactionItem>> watchVaultTransactionsByGoal(String goalId) {
    final query = select(transactions).join([
      leftOuterJoin(savingsGoals, savingsGoals.id.equalsExp(transactions.goalId)),
      leftOuterJoin(wallets, wallets.id.equalsExp(transactions.walletId)),
    ])
      ..where(transactions.deletedAt.isNull() & transactions.goalId.equals(goalId))
      ..orderBy([OrderingTerm.desc(transactions.date), OrderingTerm.desc(transactions.createdAt)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final tx = row.readTable(transactions);
        final g = row.readTableOrNull(savingsGoals);
        final w = row.readTableOrNull(wallets);
        return VaultTransactionItem(
          transaction: tx,
          goal: g,
          wallet: w,
        );
      }).toList();
    });
  }

  /// Lắng nghe lịch sử nạp/rút tiền của TOÀN BỘ KÉT TIẾT KIỆM (kèm bộ lọc tùy chọn)
  /// filterType: 'all', 'deposit' (expense), 'withdrawal' (income)
  Stream<List<VaultTransactionItem>> watchAllVaultTransactions({String filterType = 'all'}) {
    final query = select(transactions).join([
      innerJoin(savingsGoals, savingsGoals.id.equalsExp(transactions.goalId)),
      leftOuterJoin(wallets, wallets.id.equalsExp(transactions.walletId)),
    ])
      ..where(transactions.deletedAt.isNull() & transactions.goalId.isNotNull());

    if (filterType == 'deposit') {
      query.where(transactions.type.equals(CategoryType.expense.index));
    } else if (filterType == 'withdrawal') {
      query.where(transactions.type.equals(CategoryType.income.index));
    }

    query.orderBy([OrderingTerm.desc(transactions.date), OrderingTerm.desc(transactions.createdAt)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final tx = row.readTable(transactions);
        final g = row.readTableOrNull(savingsGoals);
        final w = row.readTableOrNull(wallets);
        return VaultTransactionItem(
          transaction: tx,
          goal: g,
          wallet: w,
        );
      }).toList();
    });
  }

  // ===========================================================================
  // 🌟 GIAI ĐOẠN 3: ATOMIC MUTATION & TWO-WAY REVERSAL ENGINE CHO KÉT TIẾT KIỆM
  // ===========================================================================

  /// Nạp tiền vào hũ tích lũy (Atomic ACID):
  /// - Giảm số dư ví nguồn
  /// - Tăng số dư hũ mục tiêu
  /// - Ghi nhận dòng giao dịch gắn `goalId: goalId` và `envelopeType: 'savings'`
  Future<void> depositToGoal({
    required String goalId,
    required String walletId,
    required double amount,
    DateTime? date,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Số tiền nạp phải lớn hơn 0 ₫');
    }

    await transaction(() async {
      final wallet = await (select(wallets)..where((w) => w.id.equals(walletId))).getSingleOrNull();
      if (wallet == null) {
        throw StateError('Không tìm thấy ví nguồn với ID: $walletId');
      }
      if (wallet.balance < amount) {
        throw StateError('Số dư ví "${wallet.name}" không đủ để trích nạp vào hũ');
      }

      final goal = await (select(savingsGoals)..where((g) => g.id.equals(goalId))).getSingleOrNull();
      if (goal == null) {
        throw StateError('Không tìm thấy hũ tiết kiệm với ID: $goalId');
      }

      await (update(wallets)..where((w) => w.id.equals(walletId))).write(
        WalletsCompanion(
          balance: Value(wallet.balance - amount),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await (update(savingsGoals)..where((g) => g.id.equals(goalId))).write(
        SavingsGoalsCompanion(
          currentAmount: Value(goal.currentAmount + amount),
        ),
      );

      final cat = await (select(categories)..limit(1)).getSingleOrNull();
      final catId = cat?.id ?? 'cat_savings_deposit';
      final effectiveDate = date ?? DateTime.now();

      await into(transactions).insert(
        TransactionsCompanion(
          id: Value('tx_sav_dep_${DateTime.now().millisecondsSinceEpoch}'),
          walletId: Value(walletId),
          categoryId: Value(catId),
          goalId: Value(goalId),
          amount: Value(amount),
          type: const Value(CategoryType.expense),
          envelopeType: const Value('savings'),
          date: Value(effectiveDate),
          note: Value(note ?? 'Trích nạp Két Tiết Kiệm: ${goal.title}'),
          merchant: Value(goal.title),
          createdAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Rút tiền từ hũ về ví (Atomic ACID):
  /// - Giảm số dư hũ mục tiêu
  /// - Tăng số dư ví nhận tiền
  /// - Ghi nhận dòng giao dịch gắn `goalId: goalId` và `envelopeType: 'savings'`
  Future<void> withdrawFromGoal({
    required String goalId,
    required String walletId,
    required double amount,
    DateTime? date,
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Số tiền rút phải lớn hơn 0 ₫');
    }

    await transaction(() async {
      final goal = await (select(savingsGoals)..where((g) => g.id.equals(goalId))).getSingleOrNull();
      if (goal == null) {
        throw StateError('Không tìm thấy hũ tiết kiệm với ID: $goalId');
      }
      if (goal.currentAmount < amount) {
        throw StateError('Số dư trong hũ "${goal.title}" không đủ để rút');
      }

      final wallet = await (select(wallets)..where((w) => w.id.equals(walletId))).getSingleOrNull();
      if (wallet == null) {
        throw StateError('Không tìm thấy ví nhận tiền với ID: $walletId');
      }

      await (update(savingsGoals)..where((g) => g.id.equals(goalId))).write(
        SavingsGoalsCompanion(
          currentAmount: Value(goal.currentAmount - amount),
        ),
      );

      await (update(wallets)..where((w) => w.id.equals(walletId))).write(
        WalletsCompanion(
          balance: Value(wallet.balance + amount),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final cat = await (select(categories)..limit(1)).getSingleOrNull();
      final catId = cat?.id ?? 'cat_savings_withdraw';
      final effectiveDate = date ?? DateTime.now();

      await into(transactions).insert(
        TransactionsCompanion(
          id: Value('tx_sav_wth_${DateTime.now().millisecondsSinceEpoch}'),
          walletId: Value(walletId),
          categoryId: Value(catId),
          goalId: Value(goalId),
          amount: Value(amount),
          type: const Value(CategoryType.income),
          envelopeType: const Value('savings'),
          date: Value(effectiveDate),
          note: Value(note ?? 'Rút tiền từ Két Tiết Kiệm: ${goal.title}'),
          merchant: Value(goal.title),
          createdAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// 🌟 Cập nhật giao dịch nạp/rút trong két (Atomic Reversal Update)
  /// Xử lý hoàn trả chênh lệch số dư của ví cũ/mới và hũ tương ứng
  Future<void> updateVaultTransactionAtomically({
    required String transactionId,
    required String newWalletId,
    required double newAmount,
    required DateTime newDate,
    String? newNote,
  }) async {
    if (newAmount <= 0) {
      throw ArgumentError('Số tiền giao dịch phải lớn hơn 0 ₫');
    }

    await transaction(() async {
      final oldTx = await (select(transactions)..where((t) => t.id.equals(transactionId))).getSingleOrNull();
      if (oldTx == null || oldTx.goalId == null) {
        throw StateError('Không tìm thấy giao dịch dòng tiền két');
      }

      final goal = await (select(savingsGoals)..where((g) => g.id.equals(oldTx.goalId!))).getSingleOrNull();
      if (goal == null) {
        throw StateError('Không tìm thấy hũ tiết kiệm liên quan');
      }

      final oldWallet = await (select(wallets)..where((w) => w.id.equals(oldTx.walletId))).getSingleOrNull();
      if (oldWallet == null) {
        throw StateError('Không tìm thấy ví liên kết cũ');
      }

      final newWallet = await (select(wallets)..where((w) => w.id.equals(newWalletId))).getSingleOrNull();
      if (newWallet == null) {
        throw StateError('Không tìm thấy ví liên kết mới');
      }

      // 1. Hoàn tác hoàn toàn hiệu ứng cũ
      if (oldTx.type == CategoryType.expense) {
        // Lệnh nạp cũ: hoàn lại tiền vào ví cũ, trừ lại tiền khỏi hũ
        final rolledBackWalletBal = oldWallet.balance + oldTx.amount;
        final rolledBackGoalBal = math.max(0.0, goal.currentAmount - oldTx.amount);

        await (update(wallets)..where((w) => w.id.equals(oldWallet.id))).write(
          WalletsCompanion(balance: Value(rolledBackWalletBal), updatedAt: Value(DateTime.now())),
        );
        await (update(savingsGoals)..where((g) => g.id.equals(goal.id))).write(
          SavingsGoalsCompanion(currentAmount: Value(rolledBackGoalBal)),
        );
      } else if (oldTx.type == CategoryType.income) {
        // Lệnh rút cũ: trừ lại tiền khỏi ví cũ, cộng lại tiền vào hũ
        final rolledBackWalletBal = oldWallet.balance - oldTx.amount;
        final rolledBackGoalBal = goal.currentAmount + oldTx.amount;

        await (update(wallets)..where((w) => w.id.equals(oldWallet.id))).write(
          WalletsCompanion(balance: Value(rolledBackWalletBal), updatedAt: Value(DateTime.now())),
        );
        await (update(savingsGoals)..where((g) => g.id.equals(goal.id))).write(
          SavingsGoalsCompanion(currentAmount: Value(rolledBackGoalBal)),
        );
      }

      // 2. Tái nạp thông tin ví mới sau khi đã rollback (đặc biệt khi oldWallet == newWallet)
      final refreshedNewWallet = await (select(wallets)..where((w) => w.id.equals(newWalletId))).getSingleOrNull();
      final refreshedGoal = await (select(savingsGoals)..where((g) => g.id.equals(goal.id))).getSingleOrNull();

      if (refreshedNewWallet == null || refreshedGoal == null) {
        throw StateError('Lỗi đọc lại trạng thái sau khi hoàn tác số dư');
      }

      // 3. Áp dụng hiệu ứng mới
      if (oldTx.type == CategoryType.expense) {
        // Áp dụng lệnh nạp mới: ví mới trừ tiền, hũ cộng tiền
        if (refreshedNewWallet.balance < newAmount) {
          throw StateError('Số dư ví "${refreshedNewWallet.name}" không đủ để thực hiện nạp ${newAmount} ₫');
        }
        await (update(wallets)..where((w) => w.id.equals(newWalletId))).write(
          WalletsCompanion(balance: Value(refreshedNewWallet.balance - newAmount), updatedAt: Value(DateTime.now())),
        );
        await (update(savingsGoals)..where((g) => g.id.equals(goal.id))).write(
          SavingsGoalsCompanion(currentAmount: Value(refreshedGoal.currentAmount + newAmount)),
        );
      } else if (oldTx.type == CategoryType.income) {
        // Áp dụng lệnh rút mới: ví mới cộng tiền, hũ trừ tiền
        if (refreshedGoal.currentAmount < newAmount) {
          throw StateError('Số dư hũ "${refreshedGoal.title}" không đủ để rút ${newAmount} ₫');
        }
        await (update(wallets)..where((w) => w.id.equals(newWalletId))).write(
          WalletsCompanion(balance: Value(refreshedNewWallet.balance + newAmount), updatedAt: Value(DateTime.now())),
        );
        await (update(savingsGoals)..where((g) => g.id.equals(goal.id))).write(
          SavingsGoalsCompanion(currentAmount: Value(refreshedGoal.currentAmount - newAmount)),
        );
      }

      // 4. Cập nhật dòng transaction
      await (update(transactions)..where((t) => t.id.equals(transactionId))).write(
        TransactionsCompanion(
          walletId: Value(newWalletId),
          amount: Value(newAmount),
          date: Value(newDate),
          note: Value(newNote),
        ),
      );
    });
  }

  /// 🌟 Xóa bản ghi giao dịch nạp/rút trong két và khôi phục số dư đảo chiều nguyên tử
  Future<void> deleteVaultTransactionAtomically(String transactionId) async {
    await transaction(() async {
      final tx = await (select(transactions)
            ..where((t) => t.id.equals(transactionId)))
          .getSingleOrNull();
      if (tx == null || tx.goalId == null || tx.deletedAt != null) {
        throw const VaultTransactionDeletionException(
          'Giao dịch không còn khả dụng. Hãy mở lại lịch sử Két.',
        );
      }

      final goal = await (select(savingsGoals)
            ..where((g) => g.id.equals(tx.goalId!)))
          .getSingleOrNull();
      final wallet = await (select(wallets)
            ..where((w) => w.id.equals(tx.walletId)))
          .getSingleOrNull();
      if (goal == null || wallet == null) {
        throw const VaultTransactionDeletionException(
          'Không thể xóa vì không tìm thấy hũ hoặc ví liên kết.',
        );
      }
      if (tx.type != CategoryType.expense && tx.type != CategoryType.income) {
        throw const VaultTransactionDeletionException(
          'Loại giao dịch này chưa hỗ trợ hoàn tác trong Két.',
        );
      }

      final isDeposit = tx.type == CategoryType.expense;
      final goalDelta = isDeposit ? -tx.amount : tx.amount;
      final newGoalBalance = goal.currentAmount + goalDelta;
      // Same 0.001 monetary tolerance used by wallet balance reconciliation.
      const balanceTolerance = 0.001;
      if (isDeposit && newGoalBalance < -balanceTolerance) {
        throw const VaultTransactionDeletionException(
          'Hũ không còn đủ tiền để hoàn tác lần nạp này. '
          'Hãy nạp lại đủ số dư trước khi xóa.',
        );
      }

      // Only normalize a tiny negative floating-point remainder, never a deficit.
      final normalizedGoalBalance =
          isDeposit && newGoalBalance < 0 ? 0.0 : newGoalBalance;
      final goalUpdated = await (update(savingsGoals)
            ..where((g) => g.id.equals(goal.id)))
          .write(SavingsGoalsCompanion(
              currentAmount: Value(normalizedGoalBalance)));
      final walletUpdated = await (update(wallets)
            ..where((w) => w.id.equals(wallet.id)))
          .write(WalletsCompanion(
        balance: Value(wallet.balance - goalDelta),
        updatedAt: Value(DateTime.now()),
      ));
      if (goalUpdated != 1 || walletUpdated != 1) {
        throw StateError('Vault balance reversal did not update both sides');
      }
      // Xóa vĩnh viễn dòng transaction
      final removed = await (delete(transactions)
            ..where((t) => t.id.equals(transactionId)))
          .go();
      if (removed != 1) {
        throw StateError('Vault transaction deletion did not complete');
      }
    });
  }

  /// 🌟 XÓA HŨ TIẾT KIỆM KÈM GIẢI PHÁP ĐIỀU PHỐI DÒNG TIỀN NGUYÊN TỬ (Two-Way Resolution)
  /// - Nếu hũ = 0 ₫: Xóa luôn.
  /// - Nếu hũ > 0 ₫ và có refundWalletId: Hoàn trả số dư về ví và ghi transaction hoàn trả.
  /// - Nếu hũ > 0 ₫ và có transferToGoalId: Chuyển toàn bộ số dư sang hũ khác và ghi transaction điều chuyển.
  Future<void> deleteGoalWithBalanceResolution({
    required String goalId,
    String? refundWalletId,
    String? transferToGoalId,
  }) async {
    await transaction(() async {
      final goal = await (select(savingsGoals)..where((g) => g.id.equals(goalId))).getSingleOrNull();
      if (goal == null) return;

      final remaining = goal.currentAmount;

      if (remaining > 0) {
        if (refundWalletId != null) {
          // Lựa chọn 1: Hoàn tiền về ví
          final targetWallet = await (select(wallets)..where((w) => w.id.equals(refundWalletId))).getSingleOrNull();
          if (targetWallet == null) {
            throw StateError('Không tìm thấy ví nhận tiền hoàn trả');
          }

          await (update(wallets)..where((w) => w.id.equals(refundWalletId))).write(
            WalletsCompanion(
              balance: Value(targetWallet.balance + remaining),
              updatedAt: Value(DateTime.now()),
            ),
          );

          final cat = await (select(categories)..limit(1)).getSingleOrNull();
          final catId = cat?.id ?? 'cat_savings_refund';

          await into(transactions).insert(
            TransactionsCompanion(
              id: Value('tx_sav_close_refund_${DateTime.now().millisecondsSinceEpoch}'),
              walletId: Value(refundWalletId),
              categoryId: Value(catId),
              amount: Value(remaining),
              type: const Value(CategoryType.income),
              envelopeType: const Value('savings'),
              date: Value(DateTime.now()),
              note: Value('Tất toán hũ [${goal.title}]: Hoàn trả số dư về ví'),
              merchant: Value(goal.title),
              createdAt: Value(DateTime.now()),
            ),
          );
        } else if (transferToGoalId != null) {
          // Lựa chọn 2: Chuyển sang hũ khác
          final destGoal = await (select(savingsGoals)..where((g) => g.id.equals(transferToGoalId))).getSingleOrNull();
          if (destGoal == null) {
            throw StateError('Không tìm thấy hũ tiết kiệm nhận tiền');
          }

          await (update(savingsGoals)..where((g) => g.id.equals(transferToGoalId))).write(
            SavingsGoalsCompanion(
              currentAmount: Value(destGoal.currentAmount + remaining),
            ),
          );
        } else {
          throw StateError('Hũ vẫn còn số dư (${remaining} ₫). Bắt buộc chọn ví hoàn trả hoặc hũ chuyển tiếp.');
        }
      }

      // Xóa các giao dịch liên kết của hũ này trước khi xóa hũ
      await (delete(transactions)..where((t) => t.goalId.equals(goalId))).go();

      // Xóa bản ghi hũ
      await (delete(savingsGoals)..where((g) => g.id.equals(goalId))).go();
    });
  }

  Future<void> createSavingsGoal({
    required String id,
    required String title,
    String icon = '🐖',
    String colorHex = '#10B981',
    required double targetAmount,
    double initialAmount = 0.0,
    DateTime? targetDate,
  }) async {
    await into(savingsGoals).insert(
      SavingsGoalsCompanion(
        id: Value(id),
        title: Value(title),
        icon: Value(icon),
        colorHex: Value(colorHex),
        targetAmount: Value(targetAmount),
        currentAmount: Value(initialAmount),
        targetDate: Value(targetDate),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateSavingsGoal({
    required String id,
    String? title,
    String? icon,
    String? colorHex,
    double? targetAmount,
    DateTime? targetDate,
  }) async {
    await (update(savingsGoals)..where((g) => g.id.equals(id))).write(
      SavingsGoalsCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        icon: icon != null ? Value(icon) : const Value.absent(),
        colorHex: colorHex != null ? Value(colorHex) : const Value.absent(),
        targetAmount: targetAmount != null ? Value(targetAmount) : const Value.absent(),
        targetDate: targetDate != null ? Value(targetDate) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteSavingsGoal(String id, {String? refundWalletId}) async {
    await deleteGoalWithBalanceResolution(goalId: id, refundWalletId: refundWalletId);
  }
}

// Database Connection Helper
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pfm_local_vault.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

// --- RIVERPOD INJECTION PROVIDER ---
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final savingsGoalsStreamProvider = StreamProvider.autoDispose<List<SavingsGoal>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllSavingsGoals();
});

/// Stream đếm tổng số lượng bản ghi trong Thùng rác (Transactions + DebtTransactions)
final deletedTransactionsCountStreamProvider = StreamProvider.autoDispose<int>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchDeletedTransactionsCount();
});

/// 🌟 Stream lấy lịch sử dòng tiền theo từng Hũ tiết kiệm cụ thể
final vaultTransactionsByGoalStreamProvider =
StreamProvider.autoDispose.family<List<VaultTransactionItem>, String>((ref, goalId) {
  final db = ref.watch(databaseProvider);
  return db.watchVaultTransactionsByGoal(goalId);
});

/// 🌟 Stream lấy toàn bộ lịch sử dòng tiền của Két tiết kiệm (hỗ trợ filter: 'all', 'deposit', 'withdrawal')
final allVaultTransactionsStreamProvider =
StreamProvider.autoDispose.family<List<VaultTransactionItem>, String>((ref, filterType) {
  final db = ref.watch(databaseProvider);
  return db.watchAllVaultTransactions(filterType: filterType);
});
