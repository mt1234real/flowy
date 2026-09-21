// ==============================================================================
// File: lib/data/database_seeder.dart
// Architecture: Cold-Start Local Database Seeder
// Stack: drift, sqlite3_flutter_libs
// Features: 3 Default Wallets, 2-Tier Hierarchy, Active Cycle Transactions & Budget
// ==============================================================================

import 'package:drift/drift.dart';
import 'database.dart';

class DatabaseSeeder {
  static Future<void> seedInitialData(AppDatabase db) async {
    // 1. Kiểm tra xem DB đã có dữ liệu ví hoặc danh mục hay chưa
    final existingWallets = await db.select(db.wallets).get();
    if (existingWallets.isNotEmpty) {
      // Đã có dữ liệu từ trước, bỏ qua seeder
      return;
    }

    await db.transaction(() async {
      // =======================================================================
      // A. SEED 3 VÍ MẶC ĐỊNH
      // =======================================================================
      const walletCashId = 'wallet-cash-01';
      const walletTcbId = 'wallet-tcb-02';
      const walletMomoId = 'wallet-momo-03';

      await db.into(db.wallets).insert(
        WalletsCompanion.insert(
          id: walletCashId,
          name: 'Ví Tiền Mặt',
          type: 'cash',
          balance: const Value(2450000.0),
          currency: const Value('VND'),
          icon: const Value('Banknote'),
          color: const Value('#10B981'),
        ),
      );

      await db.into(db.wallets).insert(
        WalletsCompanion.insert(
          id: walletTcbId,
          name: 'Techcombank',
          type: 'bank',
          balance: const Value(38600000.0),
          currency: const Value('VND'),
          icon: const Value('CreditCard'),
          color: const Value('#EF4444'),
        ),
      );

      await db.into(db.wallets).insert(
        WalletsCompanion.insert(
          id: walletMomoId,
          name: 'Ví MoMo',
          type: 'ewallet',
          balance: const Value(1850000.0),
          currency: const Value('VND'),
          icon: const Value('Smartphone'),
          color: const Value('#EC4899'),
        ),
      );

      // =======================================================================
      // B. SEED DANH MỤC 2 CẤP (2-TIER HIERARCHY TREE)
      // =======================================================================

      // --- Parent Group 1: Needs (Thiết yếu) ---
      const pNeedsId = 'cat-parent-needs';
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: pNeedsId,
          name: 'Needs (Thiết yếu)',
          type: CategoryType.expense,
          icon: const Value('ShoppingBag'),
          color: const Value('#3B82F6'),
          sortOrder: const Value(1),
          isSystem: const Value(true),
        ),
      );

      const cFoodId = 'cat-sub-food';
      const cRentId = 'cat-sub-rent';
      const cGroceriesId = 'cat-sub-groceries';
      const cFuelId = 'cat-sub-fuel';

      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: cFoodId,
          parentId: const Value(pNeedsId),
          name: 'Ăn uống hàng ngày',
          type: CategoryType.expense,
          icon: const Value('Utensils'),
          color: const Value('#3B82F6'),
          budgetLimit: const Value(4500000.0),
          sortOrder: const Value(1),
        ),
      );

      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: cRentId,
          parentId: const Value(pNeedsId),
          name: 'Tiền trọ / Nhà ở',
          type: CategoryType.expense,
          icon: const Value('Home'),
          color: const Value('#6366F1'),
          budgetLimit: const Value(6000000.0),
          sortOrder: const Value(2),
        ),
      );

      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: cGroceriesId,
          parentId: const Value(pNeedsId),
          name: 'Siêu thị & Nhu yếu phẩm',
          type: CategoryType.expense,
          icon: const Value('ShoppingCart'),
          color: const Value('#06B6D4'),
          budgetLimit: const Value(3000000.0),
          sortOrder: const Value(3),
        ),
      );

      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: cFuelId,
          parentId: const Value(pNeedsId),
          name: 'Xăng xe & Di chuyển',
          type: CategoryType.expense,
          icon: const Value('Fuel'),
          color: const Value('#0EA5E9'),
          budgetLimit: const Value(1500000.0),
          sortOrder: const Value(4),
        ),
      );

      // --- Parent Group 2: Wants (Mong muốn) ---
      const pWantsId = 'cat-parent-wants';
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: pWantsId,
          name: 'Wants (Mong muốn)',
          type: CategoryType.expense,
          icon: const Value('Smile'),
          color: const Value('#F59E0B'),
          sortOrder: const Value(2),
          isSystem: const Value(true),
        ),
      );

      const cCoffeeId = 'cat-sub-coffee';
      const cShoppingId = 'cat-sub-shopping';

      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: cCoffeeId,
          parentId: const Value(pWantsId),
          name: 'Cà phê & Gặp gỡ',
          type: CategoryType.expense,
          icon: const Value('Coffee'),
          color: const Value('#F59E0B'),
          budgetLimit: const Value(1800000.0),
          sortOrder: const Value(1),
        ),
      );

      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: cShoppingId,
          parentId: const Value(pWantsId),
          name: 'Mua sắm cá nhân',
          type: CategoryType.expense,
          icon: const Value('Gift'),
          color: const Value('#EC4899'),
          budgetLimit: const Value(2200000.0),
          sortOrder: const Value(2),
        ),
      );

      // --- Parent Group 3: Bills (Hóa đơn) ---
      const pBillsId = 'cat-parent-bills';
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: pBillsId,
          name: 'Bills (Hóa đơn)',
          type: CategoryType.expense,
          icon: const Value('Receipt'),
          color: const Value('#8B5CF6'),
          sortOrder: const Value(3),
          isSystem: const Value(true),
        ),
      );

      const cUtilitiesId = 'cat-sub-utilities';
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: cUtilitiesId,
          parentId: const Value(pBillsId),
          name: 'Điện, Nước & Internet',
          type: CategoryType.expense,
          icon: const Value('Zap'),
          color: const Value('#8B5CF6'),
          budgetLimit: const Value(1500000.0),
          sortOrder: const Value(1),
        ),
      );

      // --- Parent Group 4: Income (Thu nhập) ---
      const pIncomeId = 'cat-parent-income';
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: pIncomeId,
          name: 'Thu nhập chính',
          type: CategoryType.income,
          icon: const Value('TrendingUp'),
          color: const Value('#10B981'),
          sortOrder: const Value(4),
          isSystem: const Value(true),
        ),
      );

      const cSalaryId = 'cat-sub-salary';
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: cSalaryId,
          parentId: const Value(pIncomeId),
          name: 'Lương & Thưởng cố định',
          type: CategoryType.income,
          icon: const Value('DollarSign'),
          color: const Value('#10B981'),
          sortOrder: const Value(1),
        ),
      );

      // =======================================================================
      // C. SEED GIAO DỊCH BAN ĐẦU TRONG CHU KỲ (2026-08-10 ĐẾN 2026-09-09)
      // =======================================================================
      final sampleTxs = [
        TransactionsCompanion.insert(
          id: 'tx-init-01',
          walletId: walletTcbId,
          categoryId: cSalaryId,
          amount: 32000000.0,
          type: CategoryType.income,
          envelopeType: const Value('savings'),
          date: DateTime(2026, 8, 10, 8, 30),
          note: const Value('Nhận lương tháng 08 công ty'),
          merchant: const Value('Công ty Tech Solution'),
        ),
        TransactionsCompanion.insert(
          id: 'tx-init-02',
          walletId: walletTcbId,
          categoryId: cRentId,
          amount: 5500000.0,
          type: CategoryType.expense,
          envelopeType: const Value('needs'),
          date: DateTime(2026, 8, 11, 10, 0),
          note: const Value('Tiền thuê căn hộ tháng 08 - 09'),
          merchant: const Value('Chủ nhà Thảo Điền'),
        ),
        TransactionsCompanion.insert(
          id: 'tx-init-03',
          walletId: walletMomoId,
          categoryId: cGroceriesId,
          amount: 685000.0,
          type: CategoryType.expense,
          envelopeType: const Value('needs'),
          date: DateTime(2026, 8, 25, 18, 45),
          note: const Value('Mua thực phẩm & rau củ tuần 4'),
          merchant: const Value('Siêu thị Co.opmart'),
          isAiParsed: const Value(true),
        ),
        TransactionsCompanion.insert(
          id: 'tx-init-04',
          walletId: walletMomoId,
          categoryId: cCoffeeId,
          amount: 115000.0,
          type: CategoryType.expense,
          envelopeType: const Value('wants'),
          date: DateTime(2026, 9, 8, 9, 15),
          note: const Value('Phin sữa đá & Bánh mì que'),
          merchant: const Value('Highlands Coffee'),
          isAiParsed: const Value(true),
        ),
        TransactionsCompanion.insert(
          id: 'tx-init-05',
          walletId: walletCashId,
          categoryId: cFuelId,
          amount: 120000.0,
          type: CategoryType.expense,
          envelopeType: const Value('needs'),
          date: DateTime(2026, 9, 9, 7, 50),
          note: const Value('Đổ xăng đầy bình A95'),
          merchant: const Value('Cây xăng Petrolimex Số 14'),
        ),
      ];

      for (final tx in sampleTxs) {
        await db.into(db.transactions).insert(tx);
      }

      // =======================================================================
      // D. SEED CHU KỲ NGÂN SÁCH HOẠT ĐỘNG (20.500.000 đ)
      // =======================================================================
      await db.into(db.budgets).insert(
        BudgetsCompanion.insert(
          id: 'budget-cycle-current',
          categoryId: pNeedsId,
          amount: 20500000.0,
          cycleStartDay: const Value(10), // Bắt đầu ngày 10 hàng tháng
          periodMonth: DateTime(2026, 8, 10),
        ),
      );
    });
  }
}