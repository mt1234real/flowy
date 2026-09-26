import 'dart:math' as math;
import 'package:drift/drift.dart';
import 'database.dart';

class DemoDataSummary {
  final bool alreadyExists;
  final int transactions, categories, wallets, budgets, debts, goals;
  const DemoDataSummary(
      {required this.alreadyExists,
      required this.transactions,
      required this.categories,
      required this.wallets,
      required this.budgets,
      required this.debts,
      required this.goals});
}

/// Opt-in, additive demo data. All financial mutations use the production DAOs.
/// The entire fixture commits once, or rolls back including all balance changes.
class DemoDataSeeder {
  static const prefix = 'flowy_demo_v1_';
  static String id(String key) => '$prefix$key';
  static Future<DemoDataSummary>? _inFlight;
  static final _categories = <(String, String, String?, String, String)>[
    ('food', 'Ăn uống', null, 'Restaurant', '#10B981'),
    ('groceries', 'Đi chợ & siêu thị', 'food', 'ShoppingCart', '#10B981'),
    ('lunch', 'Ăn trưa văn phòng', 'food', 'Restaurant', '#34D399'),
    ('coffee', 'Cà phê', 'food', 'Coffee', '#059669'),
    ('dining', 'Ăn ngoài cuối tuần', 'food', 'Restaurant', '#047857'),
    ('home', 'Nhà ở & hóa đơn', null, 'Home', '#F59E0B'),
    ('rent', 'Tiền thuê nhà', 'home', 'Home', '#F59E0B'),
    ('utilities', 'Điện & nước', 'home', 'Bolt', '#FBBF24'),
    ('internet', 'Internet & điện thoại', 'home', 'Wifi', '#D97706'),
    ('transport', 'Di chuyển', null, 'DirectionsCar', '#0EA5E9'),
    ('fuel', 'Xăng xe', 'transport', 'LocalGasStation', '#0EA5E9'),
    ('ride', 'Xe công nghệ', 'transport', 'DirectionsCar', '#38BDF8'),
    ('shopping', 'Mua sắm', null, 'ShoppingBag', '#F43F5E'),
    ('clothes', 'Quần áo', 'shopping', 'ShoppingBag', '#FB7185'),
    ('tech', 'Đồ công nghệ', 'shopping', 'Laptop', '#E11D48'),
    ('health', 'Sức khỏe', null, 'HealthAndSafety', '#8B5CF6'),
    ('medicine', 'Khám bệnh & thuốc', 'health', 'MedicalServices', '#8B5CF6'),
    ('gym', 'Thể thao', 'health', 'FitnessCenter', '#A78BFA'),
    ('leisure', 'Giải trí & du lịch', null, 'Movie', '#EC4899'),
    ('movies', 'Phim & âm nhạc', 'leisure', 'Movie', '#EC4899'),
    ('travel', 'Du lịch', 'leisure', 'Flight', '#DB2777'),
    ('learning', 'Học tập', null, 'School', '#6366F1'),
    ('books', 'Sách & khóa học', 'learning', 'School', '#6366F1'),
    ('family', 'Gia đình & quà tặng', null, 'Favorite', '#14B8A6'),
    ('gifts', 'Quà & hiếu hỉ', 'family', 'CardGiftcard', '#14B8A6'),
    ('pets', 'Chăm sóc thú cưng', null, 'Pets', '#78716C'),
    ('savingsmove', 'Nạp quỹ tiết kiệm', null, 'Savings', '#6366F1'),
    ('savingsreturn', 'Rút quỹ tiết kiệm', null, 'Savings', '#22C55E'),
    ('income', 'Thu nhập', null, 'Payments', '#22C55E'),
    ('salary', 'Lương công ty', 'income', 'Work', '#22C55E'),
    ('freelance', 'Dự án ngoài giờ', 'income', 'Laptop', '#16A34A'),
    ('interest', 'Lãi tiết kiệm & hoàn tiền', 'income', 'Savings', '#15803D'),
  ];
  static List<Map<String, dynamic>> get schemes {
    Map<String, dynamic> make(String key, String name, List<String> groups,
            String? Function(String) mapping) =>
        {
          'id': id('scheme_$key'),
          'name': name,
          'preset': key != 'custom',
          'groups': [
            for (var i = 0; i < groups.length; i++)
              {
                'id': 'g$i',
                'name': groups[i],
                'color': [0xFF10B981, 0xFFF59E0B, 0xFF6366F1][i]
              }
          ],
          'assignments': {
            for (final c in _categories)
              if (mapping(c.$1) != null) id('cat_${c.$1}'): mapping(c.$1)
          },
        };
    const needs = {
      'food',
      'groceries',
      'lunch',
      'home',
      'rent',
      'utilities',
      'internet',
      'transport',
      'fuel',
      'ride',
      'health',
      'medicine',
      'family'
    };
    const fixed = {'rent', 'internet', 'gym', 'movies'};
    return [
      make(
          'needs',
          'Thiết yếu / Tùy ý · Mẫu',
          ['Thiết yếu', 'Tùy ý'],
          (key) => [
                'income',
                'salary',
                'freelance',
                'interest',
                'pets',
                'savingsmove',
                'savingsreturn'
              ].contains(key)
                  ? null
                  : needs.contains(key)
                      ? 'g0'
                      : 'g1'),
      make(
          'fixed',
          'Cố định / Linh hoạt · Mẫu',
          ['Cố định', 'Linh hoạt'],
          (key) => [
                'income',
                'salary',
                'freelance',
                'interest',
                'savingsreturn',
                'savingsmove'
              ].contains(key)
                  ? null
                  : fixed.contains(key)
                      ? 'g0'
                      : 'g1'),
      make(
          'custom',
          'Sinh hoạt / Trải nghiệm / Phát triển · Mẫu',
          ['Sinh hoạt', 'Trải nghiệm', 'Phát triển'],
          (key) => needs.contains(key)
              ? 'g0'
              : ['leisure', 'movies', 'travel', 'coffee', 'dining']
                      .contains(key)
                  ? 'g1'
                  : ['learning', 'books', 'gym'].contains(key)
                      ? 'g2'
                      : null),
    ];
  }

  static Future<DemoDataSummary> seed(AppDatabase db,
      {required int Function(DateTime) cycleDay}) async {
    final running = _inFlight;
    if (running != null) return running;
    final operation = _seed(db, cycleDay);
    _inFlight = operation;
    try {
      return await operation;
    } finally {
      _inFlight = null;
    }
  }

  static Future<DemoDataSummary> _summary(AppDatabase db, bool exists) async {
    final wallets = await (db.select(db.wallets)
          ..where((w) => w.id.like('$prefix%')))
        .get();
    final categories = await (db.select(db.categories)
          ..where((c) => c.id.like('$prefix%')))
        .get();
    final tx = await (db.select(db.transactions)
          ..where((t) => t.walletId.like('$prefix%')))
        .get();
    final budgets = await (db.select(db.budgets)
          ..where((b) => b.categoryId.like('$prefix%')))
        .get();
    final debts = await (db.select(db.debtTransactions)
          ..where((d) => d.walletId.like('$prefix%')))
        .get();
    final goals = await (db.select(db.savingsGoals)
          ..where((g) => g.id.like('$prefix%')))
        .get();
    return DemoDataSummary(
        alreadyExists: exists,
        transactions: tx.length,
        categories: categories.length,
        wallets: wallets.length,
        budgets: budgets.length,
        debts: debts.length,
        goals: goals.length);
  }

  static Future<DemoDataSummary> _seed(
      AppDatabase db, int Function(DateTime) cycleDay) async {
    return db.transaction(() async {
      final marker = await (db.select(db.categories)
            ..where((c) => c.id.equals(id('cat_food'))))
          .getSingleOrNull();
      if (marker != null) return _summary(db, true);
      final now = DateTime.now();
      final first = DateTime(now.year, now.month - 12, 1);
      final random = math.Random(24092026);
      final openings = <String, double>{
        'bank': 15000000,
        'cash': 2000000,
        'momo': 500000,
        'credit': 0,
        'reserve': 20000000,
        'old': 0
      };
      final hasDefault = await (db.select(db.wallets)
            ..where((w) => w.isDefault.equals(true)))
          .get();
      final walletSpecs = [
        ('bank', 'Techcombank · Mẫu', 'bank', '#0EA5E9'),
        ('cash', 'Tiền mặt · Mẫu', 'cash', '#10B981'),
        ('momo', 'MoMo · Mẫu', 'ewallet', '#EC4899'),
        ('credit', 'Visa mua sắm · Mẫu', 'credit', '#6366F1'),
        ('reserve', 'Quỹ dự phòng · Mẫu', 'savings', '#F59E0B'),
        ('old', 'Ví du lịch cũ · Mẫu', 'cash', '#94A3B8'),
      ];
      for (var i = 0; i < walletSpecs.length; i++) {
        final w = walletSpecs[i];
        await db.into(db.wallets).insert(WalletsCompanion.insert(
            id: id('wallet_${w.$1}'),
            name: w.$2,
            type: w.$3,
            balance: Value(openings[w.$1]!),
            color: Value(w.$4),
            icon: Value(w.$1 == 'cash' ? 'Wallet' : 'CreditCard'),
            isDefault: Value(hasDefault.isEmpty && i == 0),
            isArchived: Value(w.$1 == 'old'),
            isExcludedFromTotal: Value(w.$1 == 'reserve'),
            sortOrder: Value(100 + i),
            creditLimit: Value(w.$1 == 'credit' ? 30000000 : null),
            statementDay: Value(w.$1 == 'credit' ? 20 : null),
            paymentDueDay: Value(w.$1 == 'credit' ? 5 : null),
            createdAt: Value(first),
            updatedAt: Value(now)));
      }
      for (var i = 0; i < _categories.length; i++) {
        final c = _categories[i];
        await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: id('cat_${c.$1}'),
            name: c.$2,
            parentId: Value(c.$3 == null ? null : id('cat_${c.$3}')),
            type: ['income', 'salary', 'freelance', 'interest', 'savingsreturn']
                    .contains(c.$1)
                ? CategoryType.income
                : CategoryType.expense,
            icon: Value(c.$4),
            color: Value(c.$5),
            sortOrder: Value(100 + i),
            createdAt: Value(first)));
      }
      final projects = [
        (
          'trip',
          'Đà Nẵng cuối tuần · Mẫu',
          7000000.0,
          DateTime(now.year, now.month - 2, 12),
          DateTime(now.year, now.month - 2, 15),
          'ARCHIVED'
        ),
        (
          'desk',
          'Góc làm việc tại nhà · Mẫu',
          5000000.0,
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0),
          'ACTIVE'
        ),
        (
          'holiday',
          'Kỳ nghỉ gia đình · Mẫu',
          18000000.0,
          DateTime(now.year, now.month + 2, 10),
          DateTime(now.year, now.month + 2, 15),
          'UPCOMING'
        ),
      ];
      for (final p in projects) {
        await db.into(db.projectBudgets).insert(ProjectBudgetsCompanion.insert(
            id: id('project_${p.$1}'),
            title: p.$2,
            tag: '#demo_${p.$1}',
            targetAmount: p.$3,
            startDate: p.$4,
            endDate: p.$5,
            status: Value(p.$6),
            icon: Value(p.$1 == 'desk' ? '💻' : '🌴'),
            createdAt: Value(first),
            updatedAt: Value(now)));
      }
      var serial = 0;
      Future<String> tx(String category, String wallet, double amount,
          DateTime date, String note,
          {bool income = false,
          String? project,
          bool ai = false,
          bool cycleStart = false}) async {
        final txId = id('tx_${serial++}');
        await db.insertTransactionWithBalanceUpdate(
            TransactionsCompanion.insert(
                id: txId,
                walletId: id('wallet_$wallet'),
                categoryId: id('cat_$category'),
                amount: amount,
                type: income ? CategoryType.income : CategoryType.expense,
                date: date.isAfter(now) ? now : date,
                note: Value(note),
                merchant: Value(note.split(' · ').first),
                envelopeType: Value([
                  'rent',
                  'utilities',
                  'internet',
                  'groceries',
                  'lunch',
                  'fuel',
                  'medicine'
                ].contains(category)
                    ? 'needs'
                    : 'wants'),
                projectBudgetId:
                    Value(project == null ? null : id('project_$project')),
                isAiParsed: Value(ai),
                rawReceiptText: Value(ai
                    ? 'Hóa đơn mẫu: $note — ${amount.toStringAsFixed(0)} VND'
                    : null),
                isCycleStart: Value(cycleStart),
                createdAt: Value(date.isAfter(now) ? now : date)));
        return txId;
      }

      Future<void> transfer(String from, String to, double amount,
          DateTime date, String note) async {
        // Production transfer IDs use milliseconds; separate seed calls explicitly.
        await Future<void>.delayed(const Duration(milliseconds: 2));
        await db.executeInternalTransfer(
            fromWalletId: id('wallet_$from'),
            toWalletId: id('wallet_$to'),
            amount: amount,
            date: date.isAfter(now) ? now : date,
            note: note);
      }

      const budgetAmounts = {
        'food': 4500000.0,
        'home': 7800000.0,
        'transport': 1200000.0,
        'shopping': 1500000.0,
        'health': 900000.0,
        'leisure': 1600000.0,
        'learning': 800000.0,
        'family': 1000000.0
      };
      for (var offset = 0; offset <= 12; offset++) {
        final month = DateTime(first.year, first.month + offset);
        final days = DateTime(month.year, month.month + 1, 0).day;
        final lastDay =
            month.year == now.year && month.month == now.month ? now.day : days;
        final payDay = cycleDay(month).clamp(1, days);
        for (final budget in budgetAmounts.entries) {
          await db.into(db.budgets).insert(BudgetsCompanion.insert(
              id: 'b_${month.year}-${month.month.toString().padLeft(2, '0')}_${id('cat_${budget.key}')}',
              categoryId: id('cat_${budget.key}'),
              amount: budget.value,
              cycleStartDay: Value(payDay),
              periodMonth: month,
              createdAt: Value(month)));
        }
        for (var day = 1; day <= lastDay; day++) {
          final date = DateTime(month.year, month.month, day, 12, 15);
          if (day == 1) {
            final credit = await (db.select(db.wallets)
                  ..where((w) => w.id.equals(id('wallet_credit'))))
                .getSingle();
            if (credit.balance < 0) {
              await transfer(
                  'bank',
                  'credit',
                  -credit.balance,
                  DateTime(month.year, month.month, 1, 8),
                  'Thanh toán dư nợ Visa tháng trước');
            }
            await transfer(
                'bank',
                'cash',
                1500000,
                DateTime(month.year, month.month, 1, 9),
                'Rút tiền mặt sinh hoạt');
            await transfer('bank', 'momo', 700000,
                DateTime(month.year, month.month, 1, 9, 15), 'Nạp ví MoMo');
          }
          if (day == payDay) {
            await tx(
                'salary',
                'bank',
                28000000 + (offset >= 6 ? 2000000 : 0),
                DateTime(month.year, month.month, day, 8),
                'Lương tháng ${month.month}/${month.year}',
                income: true,
                cycleStart: true);
          }
          if (day == 3) {
            await tx('rent', 'bank', 6500000, date,
                'Thuê căn hộ tháng ${month.month}');
          }
          if (day == 8) {
            await tx('utilities', 'bank', 600000 + random.nextInt(350) * 1000.0,
                date, 'Điện nước sinh hoạt');
          }
          if (day == 12) {
            await tx('internet', 'bank', 320000, date,
                'Internet cáp quang và gói di động');
          }
          if (day == 15) {
            await tx('gym', 'bank', 450000, date, 'Gia hạn phòng tập');
          }
          if (day == 18) {
            await tx(
                'freelance',
                'bank',
                2500000 + random.nextInt(5) * 500000.0,
                date,
                'Thiết kế website ngoài giờ',
                income: true);
          }
          if (day == 22) {
            await tx('movies', 'credit', 129000, date, 'Gói phim trực tuyến');
          }
          if (day == 25) {
            await tx('interest', 'bank', 65000 + random.nextInt(50) * 1000.0,
                date, 'Lãi tài khoản và hoàn tiền thẻ',
                income: true);
          }
          if (date.weekday <= 5) {
            await tx(
                'lunch',
                day.isEven ? 'cash' : 'bank',
                35000 + random.nextInt(31) * 1000.0,
                date,
                ['Cơm văn phòng', 'Bún bò', 'Phở gà'][day % 3]);
            if (day % 3 == 0) {
              await tx(
                  'coffee',
                  'momo',
                  35000 + random.nextInt(21) * 1000.0,
                  DateTime(month.year, month.month, day, 8, 30),
                  'Cà phê trước giờ làm');
            }
          } else {
            await tx(
                'groceries',
                'credit',
                220000 + random.nextInt(211) * 1000.0,
                date,
                'Siêu thị cuối tuần',
                ai: day % 2 == 0);
            if (date.weekday == 7) {
              await tx('dining', 'bank', 180000 + random.nextInt(241) * 1000.0,
                  date, 'Ăn tối cùng bạn bè');
            }
          }
          if (day % 7 == 0) {
            await tx('fuel', 'cash', 120000, date, 'Đổ xăng xe máy');
          }
          if (day % 9 == 0) {
            await tx('ride', 'momo', 45000 + random.nextInt(51) * 1000.0, date,
                'Xe công nghệ ngày mưa');
          }
          if (day == 16) {
            await tx('books', 'bank', 150000 + random.nextInt(6) * 50000.0,
                date, 'Sách và khóa học kỹ năng');
          }
          if (day == 20 && offset % 2 == 0) {
            await tx('clothes', 'credit', 450000 + random.nextInt(5) * 100000.0,
                date, 'Mua quần áo đi làm');
          }
          if (day == 21 && offset % 3 == 0) {
            await tx('medicine', 'bank', 380000, date, 'Khám răng định kỳ');
          }
          if (day == 24 && offset % 2 == 1) {
            await tx('gifts', 'bank', 700000, date, 'Quà sinh nhật người thân');
          }
          if (day == 19) {
            await tx('pets', 'momo', 180000, date, 'Thức ăn cho mèo');
          }
        }
      }
      await tx(
          'travel',
          'bank',
          7200000,
          DateTime(now.year, now.month - 2, 12, 10),
          'Vé máy bay và khách sạn Đà Nẵng',
          project: 'trip');
      await tx(
          'tech',
          'credit',
          3200000,
          DateTime(now.year, now.month, math.min(now.day, 5), 14),
          'Màn hình làm việc 27 inch',
          project: 'desk');
      await tx('tech', 'bank', 1200000, now.subtract(const Duration(days: 1)),
          'Bàn phím và giá đỡ laptop',
          project: 'desk');
      // A recent surge, a no-budget category and soft-deleted records for reports/bin.
      final deleted = await tx(
          'clothes',
          'bank',
          890000,
          now.subtract(const Duration(days: 2)),
          'Đơn hàng nhập trùng · mẫu thùng rác');
      await db.softDeleteTransaction(deleted);
      final deletedIncome = await tx(
          'freelance',
          'bank',
          2000000,
          now.subtract(const Duration(days: 3)),
          'Khoản thu nhập nhầm · mẫu thùng rác',
          income: true);
      await db.softDeleteTransaction(deletedIncome);
      final contacts = [
        ('minh', 'Minh · Đồng nghiệp'),
        ('lan', 'Lan · Bạn thân'),
        ('anh', 'Anh trai'),
        ('hoa', 'Hoa · Đã tất toán')
      ];
      for (final c in contacts) {
        await db.into(db.debtContacts).insert(DebtContactsCompanion.insert(
            id: id('contact_${c.$1}'),
            name: '${c.$2} · Mẫu',
            createdAt: Value(first),
            updatedAt: Value(now)));
      }
      Future<void> debt(
          String key, String contact, String type, double amount, int daysAgo,
          {int? due}) async {
        await db.createDebtTransaction(
            id: id('debt_$key'),
            contactId: id('contact_$contact'),
            walletId: id('wallet_bank'),
            type: type,
            amount: amount,
            date: now.subtract(Duration(days: daysAgo)),
            dueDate: due == null ? null : now.add(Duration(days: due)),
            note: '${{
              'LEND': 'Cho mượn tiền',
              'COLLECT': 'Nhận lại một phần tiền cho mượn',
              'BORROW': 'Mượn tiền người thân',
              'REPAY': 'Trả một phần tiền đã mượn'
            }[type]} · Mẫu');
      }

      await debt('minh_lend', 'minh', 'LEND', 2500000, 25, due: -3);
      await debt('minh_collect', 'minh', 'COLLECT', 1000000, 6);
      await debt('lan_lend', 'lan', 'LEND', 1800000, 5, due: 14);
      await debt('anh_borrow', 'anh', 'BORROW', 5000000, 40, due: 10);
      await debt('anh_repay', 'anh', 'REPAY', 2000000, 12);
      await debt('hoa_lend', 'hoa', 'LEND', 800000, 20, due: -10);
      await debt('hoa_collect', 'hoa', 'COLLECT', 800000, 11);
      await (db.update(db.debtTransactions)
            ..where((d) => d.contactId.equals(id('contact_hoa'))))
          .write(const DebtTransactionsCompanion(isSettled: Value(true)));
      await debt('deleted', 'lan', 'LEND', 500000, 2);
      await db.softDeleteDebtTransaction(id('debt_deleted'));
      final goals = [
        ('emergency', 'Quỹ khẩn cấp', 60000000.0, 18000000.0, 'emergency', 180),
        ('holiday', 'Du lịch Nhật Bản', 45000000.0, 12000000.0, 'travel', 240),
        ('laptop', 'Laptop mới', 30000000.0, 27000000.0, 'laptop', 45),
        ('course', 'Khóa học ngoại ngữ', 6000000.0, 6000000.0, 'education', 30),
        ('bike', 'Xe máy mới', 65000000.0, 0.0, 'motorbike', 365),
      ];
      Future<void> dateSavingsEntry(
          String note, DateTime date, bool income) async {
        final entry = await (db.select(db.transactions)
              ..where((t) =>
                  t.walletId.equals(id('wallet_bank')) & t.note.equals(note)))
            .getSingle();
        await db.updateTransactionAtomically(
            transactionId: entry.id,
            walletId: entry.walletId,
            categoryId: id(income ? 'cat_savingsreturn' : 'cat_savingsmove'),
            amount: entry.amount,
            type: income ? CategoryType.income : CategoryType.expense,
            date: date,
            note: entry.note,
            merchant: entry.merchant,
            envelopeType: 'savings');
      }

      var goalIndex = 0;
      for (final g in goals) {
        await db.createSavingsGoal(
            id: id('goal_${g.$1}'),
            title: '${g.$2} · Mẫu',
            icon: g.$5,
            colorHex: '#6366F1',
            targetAmount: g.$3,
            targetDate: now.add(Duration(days: g.$6)));
        if (g.$4 > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
          await db.depositToGoal(
              goalId: id('goal_${g.$1}'),
              walletId: id('wallet_bank'),
              amount: g.$4);
          await dateSavingsEntry('Trích nạp Két Tiết Kiệm: ${g.$2} · Mẫu',
              now.subtract(Duration(days: 120 - goalIndex * 25)), false);
        }
        goalIndex++;
      }
      await db.withdrawFromGoal(
          goalId: id('goal_emergency'),
          walletId: id('wallet_bank'),
          amount: 500000);
      await dateSavingsEntry('Rút tiền từ Két Tiết Kiệm: Quỹ khẩn cấp · Mẫu',
          now.subtract(const Duration(days: 10)), true);
      await _verifyBalances(db, openings);
      for (final goal in goals) {
        final persisted = await (db.select(db.savingsGoals)
              ..where((g) => g.id.equals(id('goal_${goal.$1}'))))
            .getSingle();
        final expected = goal.$4 - (goal.$1 == 'emergency' ? 500000 : 0);
        if ((persisted.currentAmount - expected).abs() > .01) {
          throw StateError('Demo savings reconciliation failed');
        }
      }
      return _summary(db, false);
    });
  }

  static Future<void> _verifyBalances(
      AppDatabase db, Map<String, double> openings) async {
    final txs = await (db.select(db.transactions)
          ..where((t) => t.walletId.like('$prefix%') & t.deletedAt.isNull()))
        .get();
    final debts = await (db.select(db.debtTransactions)
          ..where((d) => d.walletId.like('$prefix%') & d.deletedAt.isNull()))
        .get();
    final expected = {
      for (final entry in openings.entries)
        id('wallet_${entry.key}'): entry.value
    };
    final contactExpected = <String, double>{};
    for (final tx in txs) {
      final delta = tx.type == CategoryType.income
          ? tx.amount
          : tx.type == CategoryType.expense || tx.type == CategoryType.transfer
              ? -tx.amount
              : 0.0;
      expected[tx.walletId] = expected[tx.walletId]! + delta;
      if (tx.type == CategoryType.transfer && tx.toWalletId != null) {
        expected[tx.toWalletId!] = expected[tx.toWalletId!]! + tx.amount;
      }
    }
    for (final debt in debts) {
      final outgoing = debt.type == 'LEND' || debt.type == 'REPAY';
      expected[debt.walletId] =
          expected[debt.walletId]! + (outgoing ? -debt.amount : debt.amount);
      contactExpected[debt.contactId] = (contactExpected[debt.contactId] ?? 0) +
          (outgoing ? debt.amount : -debt.amount);
    }
    for (final entry in expected.entries) {
      final wallet = await (db.select(db.wallets)
            ..where((w) => w.id.equals(entry.key)))
          .getSingle();
      if ((wallet.balance - entry.value).abs() > .01) {
        throw StateError('Demo wallet reconciliation failed');
      }
    }
    for (final entry in contactExpected.entries) {
      final contact = await (db.select(db.debtContacts)
            ..where((c) => c.id.equals(entry.key)))
          .getSingle();
      if ((contact.netBalance - entry.value).abs() > .01) {
        throw StateError('Demo contact reconciliation failed');
      }
    }
  }
}
