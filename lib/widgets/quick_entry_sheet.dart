// ==============================================================================
// File: lib/widgets/quick_entry_sheet.dart
// Architecture: Ergonomic Quick-Entry Sheet with Fluid Sheet Engine & Chromatic Precision
// Stack: flutter_riverpod, drift, intl, flutter/services.dart
// Features:
// 1. Phân Tầng Dual-Level Segmented Tabs:
//    - Tầng 1 (Chế độ gốc): height 42px, 3 tabs [Khoản chi | Khoản thu | Vay / Nợ].
//    - Tầng 2 (Bản chất nợ): height 34px, 4 tabs [Cho vay | Thu nợ | Đi vay | Trả nợ],
//      nền màu đặc, chữ in đậm màu trắng tinh khiết nổi bật.
// 2. Amount Header Cluster & Smooth Numeric Jump (32sp):
//    - Chữ số 32sp font monospace, nhảy số 140ms trượt dọc vi mô 2px qua AnimatedSwitcher.
//    - Màu sắc số tiền đồng bộ 100% với màu sắc ngữ nghĩa của sub-tab.
// 3. Ergonomic Inputs (Height 46px):
//    - Ô đối tác và ô ghi chú mở rộng lên 46px tạo không gian bấm thoải mái.
//    - Dropdown ví cố định tối thiểu 110px, bo góc 14px mềm mại.
// 4. Modal Chọn Ví Chuẩn Fluid Sheet Engine:
//    - Mở qua AppAnimationPolicy.showFluidSheet(mode: FluidSheetMode.fixed, enableBlur: false).
//    - Toàn bộ bề mặt kéo hạ 1:1, đàn hồi snap-back và quẹt đóng dứt khoát, triệt tiêu blur kép.
// 5. Numpad Chromatic Tuning & Elastic Press Feedback:
//    - Phím nén 0.93x trong 60ms kèm HapticFeedback.selectionClick().
//    - Cột phím shortcut (+50k, +100k, +200k) nền xám trung tính, chữ đổi theo màu tab.
// 6. Disabled Action Button Guardrail:
//    - Nút Lưu/Xác nhận cao 50px ở đáy; khi số tiền = 0 tự động hạ 40% opacity và chặn bấm.
// 7. Fluid Sheet Engine & In-Memory Draft Retention:
//    - Khóa private constructor QuickEntrySheet._ và mở qua launcher tĩnh QuickEntrySheet.show(...).
//    - Đồng bộ draft liên tục qua quickEntryDraftProvider trong RAM; nút "✕" reset trắng sạch.
// ==============================================================================

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../data/database.dart';
import '../services/cloud_backup_service.dart';
import '../theme/app_theme.dart';
import 'category_tree_modal.dart';
import 'overrun_resolution_sheet.dart';
import 'sliding_segmented_bar.dart';

// =============================================================================
// 🌟 IN-MEMORY DRAFT RETENTION MODEL & TOP-LEVEL STATE PROVIDER
// =============================================================================

class QuickEntryDraft {
  final String expression;
  final String note;
  final Category? category;
  final Wallet? wallet;
  final CategoryType type;
  final DateTime date;
  final String debtActionType;
  final DebtContact? debtContact;
  final DateTime? debtDueDate;

  const QuickEntryDraft({
    required this.expression,
    required this.note,
    this.category,
    this.wallet,
    this.type = CategoryType.expense,
    required this.date,
    this.debtActionType = 'LEND',
    this.debtContact,
    this.debtDueDate,
  });

  bool get hasData => (expression != '0' && expression.isNotEmpty) || note.trim().isNotEmpty;
}

final quickEntryDraftProvider = StateProvider<QuickEntryDraft?>((ref) => null);

final quickEntryWalletsStreamProvider = StreamProvider.autoDispose<List<Wallet>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.wallets)
    ..where((w) => w.isArchived.equals(false))
    ..orderBy([(w) => drift.OrderingTerm.asc(w.sortOrder), (w) => drift.OrderingTerm.asc(w.createdAt)]))
      .watch();
});

final quickEntryDebtContactsStreamProvider = StreamProvider.autoDispose<List<DebtContact>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllDebtContacts();
});

// =============================================================================
// 🌟 PHÍM SỐ NUMPAD ĐÀN HỒI (ELASTIC NUMPAD KEY WITH 0.93X PRESS FEEDBACK)
// =============================================================================

class _NumpadKey extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color textColor;
  final Color bgColor;
  final bool isMonospace;

  const _NumpadKey({
    super.key,
    required this.label,
    required this.onTap,
    required this.textColor,
    required this.bgColor,
    this.isMonospace = true,
  });

  @override
  State<_NumpadKey> createState() => _NumpadKeyState();
}

class _NumpadKeyState extends State<_NumpadKey> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 60),
      reverseDuration: const Duration(milliseconds: 80),
      debugLabel: 'NumpadKey.${widget.label}',
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: widget.bgColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse(),
          onTapCancel: () => _controller.reverse(),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          child: Container(
            height: 42,
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: widget.label.startsWith('+') ? 12.5 : 16,
                fontWeight: FontWeight.bold,
                fontFamily: widget.isMonospace ? 'monospace' : null,
                color: widget.textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 🌟 QUICK ENTRY SHEET CHÍNH
// =============================================================================

class QuickEntrySheet extends ConsumerStatefulWidget {
  final Transaction? initialTransaction;
  final DateTime? initialContextDate;
  final DebtContact? prefilledDebtContact;
  final double? prefilledAmount;
  final String? prefilledDebtType;
  final double? prefilledDailySafe;
  final ScrollController scrollController;

  const QuickEntrySheet._({
    super.key,
    this.initialTransaction,
    this.initialContextDate,
    this.prefilledDebtContact,
    this.prefilledAmount,
    this.prefilledDebtType,
    this.prefilledDailySafe,
    required this.scrollController,
  });

  static Future<void> show(
      BuildContext context, {
        Transaction? initialTransaction,
        DateTime? initialContextDate,
        DebtContact? prefilledDebtContact,
        double? prefilledAmount,
        String? prefilledDebtType,
        double? prefilledDailySafe,
      }) {
    HapticFeedback.selectionClick();
    return AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.scrollable,
      useRootNavigator: true,
      isDismissible: true,
      builder: (sheetContext, scrollController) => QuickEntrySheet._(
        initialTransaction: initialTransaction,
        initialContextDate: initialContextDate,
        prefilledDebtContact: prefilledDebtContact,
        prefilledAmount: prefilledAmount,
        prefilledDebtType: prefilledDebtType,
        prefilledDailySafe: prefilledDailySafe,
        scrollController: scrollController!,
      ),
    );
  }

  @override
  ConsumerState<QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends ConsumerState<QuickEntrySheet> with TickerProviderStateMixin {
  late CategoryType _activeTab;
  late String _expression;
  late final TextEditingController _noteController;
  late final TextEditingController _contactSearchController;
  late DateTime _selectedDate;

  Category? _selectedCategory;
  Wallet? _selectedWallet;
  bool _isSubmitting = false;

  String _debtActionType = 'LEND';
  DebtContact? _selectedDebtContact;
  DateTime? _debtDueDate;
  bool _isSearchingContact = false;

  bool _isAmortized = false;

  final AppValidationFeedbackController _categoryFeedback =
  AppValidationFeedbackController();
  final AppValidationFeedbackController _debtContactFeedback =
  AppValidationFeedbackController();

  late final AnimationController _colorMorphController;
  late Animation<Color?> _colorMorphAnimation;
  Color _prevActiveColor = AppTokens.expense;

  late final AnimationController _walletIconTiltController;
  late final Animation<double> _walletIconTiltAnimation;

  late final AnimationController _headShakeController;
  late final Animation<double> _headShakeAnimation;
  bool _hasTriggeredOverrunShake = false;

  late final AnimationController _morphButtonController;
  late final AnimationController _checkIconController;
  late final Animation<double> _morphWidthAnimation;
  late final Animation<double> _checkScaleAnimation;
  bool _isSuccessMorphed = false;

  bool get _isEditMode => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.initialTransaction;

    _contactSearchController = TextEditingController();

    if (tx != null) {
      _activeTab = tx.type;
      _expression = tx.amount.toStringAsFixed(0);
      _noteController = TextEditingController(text: tx.note ?? tx.merchant ?? '');
      _selectedDate = tx.date;
      _isAmortized = tx.note?.contains('#amortized') ?? false;
      _loadInitialEntities(tx);
    } else if (widget.prefilledDebtContact != null) {
      _activeTab = CategoryType.debt;
      _selectedDebtContact = widget.prefilledDebtContact;
      _debtActionType = widget.prefilledDebtType ?? 'LEND';
      _expression = widget.prefilledAmount != null && widget.prefilledAmount! > 0
          ? widget.prefilledAmount!.toStringAsFixed(0)
          : '0';
      _noteController = TextEditingController();
      _selectedDate = widget.initialContextDate ?? DateTime.now();
    } else {
      final draft = ref.read(quickEntryDraftProvider);
      if (draft != null && draft.hasData) {
        _activeTab = draft.type;
        _expression = draft.expression;
        _noteController = TextEditingController(text: draft.note);
        _selectedCategory = draft.category;
        _selectedWallet = draft.wallet;
        _selectedDate = draft.date;
        _debtActionType = draft.debtActionType;
        _selectedDebtContact = draft.debtContact;
        _debtDueDate = draft.debtDueDate;
        _isAmortized = draft.note.contains('#amortized');
      } else {
        _activeTab = CategoryType.expense;
        _expression = widget.prefilledAmount != null && widget.prefilledAmount! > 0
            ? widget.prefilledAmount!.toStringAsFixed(0)
            : '0';
        _noteController = TextEditingController();

        final ctxDate = widget.initialContextDate;
        if (ctxDate != null) {
          final now = DateTime.now();
          if (ctxDate.year != now.year || ctxDate.month != now.month) {
            _selectedDate = ctxDate;
          } else {
            _selectedDate = now;
          }
        } else {
          _selectedDate = DateTime.now();
        }
      }
    }

    _noteController.addListener(_syncDraft);

    final initialColor = _resolveCurrentSemanticColor();
    _prevActiveColor = initialColor;

    _colorMorphController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      debugLabel: 'QuickEntry.ColorMorph',
    );
    _colorMorphAnimation = ColorTween(begin: initialColor, end: initialColor).animate(
      CurvedAnimation(parent: _colorMorphController, curve: Curves.easeOut),
    );

    _walletIconTiltController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      debugLabel: 'QuickEntry.WalletTilt',
    );
    _walletIconTiltAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.21), weight: 45),
      TweenSequenceItem(tween: Tween<double>(begin: 0.21, end: 0.0), weight: 55),
    ]).animate(CurvedAnimation(parent: _walletIconTiltController, curve: Curves.easeOutBack));

    _headShakeController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      debugLabel: 'QuickEntry.HeadShake',
    );
    _headShakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: -4.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: -4.0, end: 4.0), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 4.0, end: -2.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: -2.0, end: 0.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _headShakeController, curve: Curves.easeInOutSine));

    _morphButtonController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      debugLabel: 'QuickEntry.MorphButton',
    );
    _morphWidthAnimation = CurvedAnimation(
      parent: _morphButtonController,
      curve: Curves.easeInOutCubic,
    );

    _checkIconController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      debugLabel: 'QuickEntry.CheckIcon',
    );
    _checkScaleAnimation = CurvedAnimation(
      parent: _checkIconController,
      curve: Curves.elasticOut,
    );
  }

  Future<void> _loadInitialEntities(Transaction tx) async {
    final db = ref.read(databaseProvider);

    final cats = await (db.select(db.categories)..where((c) => c.id.equals(tx.categoryId))).get();
    if (cats.isNotEmpty && mounted) {
      setState(() => _selectedCategory = cats.first);
    }

    final wallets = await (db.select(db.wallets)..where((w) => w.id.equals(tx.walletId))).get();
    if (wallets.isNotEmpty && mounted) {
      setState(() => _selectedWallet = wallets.first);
    }
  }

  void _syncDraft() {
    if (_isEditMode || _isSubmitting || widget.prefilledDebtContact != null) return;

    final draft = QuickEntryDraft(
      expression: _expression,
      note: _noteController.text,
      category: _selectedCategory,
      wallet: _selectedWallet,
      type: _activeTab,
      date: _selectedDate,
      debtActionType: _debtActionType,
      debtContact: _selectedDebtContact,
      debtDueDate: _debtDueDate,
    );

    if (draft.hasData) {
      ref.read(quickEntryDraftProvider.notifier).state = draft;
    } else {
      ref.read(quickEntryDraftProvider.notifier).state = null;
    }
  }

  @override
  void dispose() {
    _noteController.removeListener(_syncDraft);
    _colorMorphController.dispose();
    _walletIconTiltController.dispose();
    _headShakeController.dispose();
    _morphButtonController.dispose();
    _checkIconController.dispose();
    _categoryFeedback.dispose();
    _debtContactFeedback.dispose();
    _noteController.dispose();
    _contactSearchController.dispose();
    super.dispose();
  }

  Color _resolveCurrentSemanticColor() {
    if (_activeTab == CategoryType.debt) {
      return _resolveDebtColor(_debtActionType);
    }
    return _activeTab == CategoryType.expense ? AppTokens.expense : AppTokens.income;
  }

  void _switchTab(CategoryType newTab) {
    if (_activeTab == newTab) return;
    setState(() {
      _activeTab = newTab;
      _selectedCategory = null;
    });
    _categoryFeedback.clear();
    _debtContactFeedback.clear();
    _animateSemanticColor();
    _checkOverrunCondition(_evaluateExpression());
    _syncDraft();
  }

  void _animateSemanticColor() {
    final Color oldC = _colorMorphAnimation.value ?? _prevActiveColor;
    final Color newC = _resolveCurrentSemanticColor();

    _prevActiveColor = oldC;

    _colorMorphAnimation = ColorTween(begin: oldC, end: newC).animate(
      CurvedAnimation(parent: _colorMorphController, curve: Curves.easeOut),
    );
    _colorMorphController.forward(from: 0.0);
  }

  String _formatCurrency(double amount, [String currency = '₫']) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: currency, decimalDigits: 0);
    return formatter.format(amount);
  }

  double _evaluateExpression() {
    try {
      final sanitized = _expression.replaceAll('×', '*').replaceAll('÷', '/');
      final List<String> tokens = [];
      String currentNumber = '';

      for (int i = 0; i < sanitized.length; i++) {
        final char = sanitized[i];
        if ('+-*/'.contains(char)) {
          if (currentNumber.isNotEmpty) {
            tokens.add(currentNumber);
            currentNumber = '';
          }
          tokens.add(char);
        } else {
          currentNumber += char;
        }
      }
      if (currentNumber.isNotEmpty) tokens.add(currentNumber);
      if (tokens.isEmpty) return 0.0;

      final List<String> pass1 = [];
      int idx = 0;
      while (idx < tokens.length) {
        if (tokens[idx] == '*' || tokens[idx] == '/') {
          final op = tokens[idx];
          final prevNum = double.parse(pass1.removeLast());
          final nextNum = double.parse(tokens[idx + 1]);
          final res = op == '*' ? prevNum * nextNum : (nextNum != 0 ? prevNum / nextNum : 0.0);
          pass1.add(res.toString());
          idx += 2;
        } else {
          pass1.add(tokens[idx]);
          idx++;
        }
      }

      double total = double.parse(pass1[0]);
      idx = 1;
      while (idx < pass1.length) {
        final op = pass1[idx];
        final nextNum = double.parse(pass1[idx + 1]);
        if (op == '+') total += nextNum;
        if (op == '-') total -= nextNum;
        idx += 2;
      }
      return total < 0 ? 0.0 : total;
    } catch (_) {
      return 0.0;
    }
  }

  void _checkOverrunCondition(double calculatedAmount) {
    final double dailySafeLimit = widget.prefilledDailySafe ?? 150000.0;
    final bool isOver = _activeTab == CategoryType.expense &&
        dailySafeLimit > 0 &&
        calculatedAmount > dailySafeLimit;

    if (isOver && !_hasTriggeredOverrunShake) {
      _hasTriggeredOverrunShake = true;
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 90), () {
        if (mounted) HapticFeedback.mediumImpact();
      });
      _headShakeController.forward(from: 0.0);
    } else if (!isOver && _hasTriggeredOverrunShake) {
      _hasTriggeredOverrunShake = false;
    }
  }

  void _resetDraftAndInputs() {
    HapticFeedback.selectionClick();
    setState(() {
      _expression = '0';
      _noteController.clear();
      _isAmortized = false;
    });
    ref.read(quickEntryDraftProvider.notifier).state = null;
    _checkOverrunCondition(0.0);
  }

  void _onNumpadPress(String key) {
    setState(() {
      if (key == 'C') {
        _expression = '0';
      } else if (key == '⌫') {
        if (_expression.length > 1) {
          _expression = _expression.substring(0, _expression.length - 1);
        } else {
          _expression = '0';
        }
      } else if (key == '000') {
        if (_expression != '0' && _expression.length <= 10) {
          _expression += '000';
        }
      } else if (key == '+50k') {
        final current = _evaluateExpression();
        _expression = (current + 50000).toStringAsFixed(0);
      } else if (key == '+100k') {
        final current = _evaluateExpression();
        _expression = (current + 100000).toStringAsFixed(0);
      } else if (key == '+200k') {
        final current = _evaluateExpression();
        _expression = (current + 200000).toStringAsFixed(0);
      } else {
        if (_expression == '0') {
          _expression = key;
        } else if (_expression.length <= 11) {
          _expression += key;
        }
      }
    });

    _checkOverrunCondition(_evaluateExpression());
    _syncDraft();
  }

  Future<void> _openCategoryModal() async {
    HapticFeedback.selectionClick();
    final chosen = await CategoryTreeModal.show(
      context,
      initialType: _activeTab,
      selectedCategoryId: _selectedCategory?.id,
      // Quick Entry now accepts both parent and child categories.
      // CategoryTreeModal already separates selection from expand/collapse:
      // tapping the parent selects it, while "Chi tiết" expands its children.
      allowSelectParent: true,
    );
    if (chosen != null && mounted) {
      setState(() => _selectedCategory = chosen);
      _categoryFeedback.clear();
      _syncDraft();
    }
  }

  Future<void> _handleWalletPickerTap(List<Wallet> wallets, bool isDark, AppAccentPreset accent) async {
    HapticFeedback.selectionClick();
    await _walletIconTiltController.forward(from: 0.0);
    if (!mounted) return;
    _openWalletPickerModal(wallets, isDark, accent);
  }

  // ===========================================================================
  // 🌟 MODAL CHỌN VÍ: FLUID SHEET MODE FIXED (VUỐT KÉO 1:1, KHÔNG BLUR)
  // ===========================================================================
  void _openWalletPickerModal(List<Wallet> wallets, bool isDark, AppAccentPreset accent) {
    HapticFeedback.selectionClick();

    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.fixed,
      enableBlur: false,
      useRootNavigator: true,
      isDismissible: true,
      builder: (sheetContext, _) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151C28) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                width: 1,
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Chọn nguồn tiền / Ví thanh toán',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                        ),
                        onPressed: () {
                          if (sheetContext.mounted && Navigator.of(sheetContext).canPop()) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  ...wallets.map((w) {
                    final isSelected = (_selectedWallet?.id ?? wallets.first.id) == w.id;
                    final walletColor = _parseColor(w.color);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedWallet = w);
                          _syncDraft();
                          if (sheetContext.mounted && Navigator.of(sheetContext).canPop()) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? walletColor.withValues(alpha: 0.12)
                                : (isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? walletColor
                                  : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: walletColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _resolveWalletIcon(w.type),
                                  color: walletColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          w.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                          ),
                                        ),
                                        if (w.isDefault) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: accent.primary.withValues(alpha: 0.16),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Mặc định',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: accent.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      'Số dư: ${_formatCurrency(w.balance)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: walletColor,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openMiniCalendarModal(bool isDark, AppAccentPreset accent) {
    HapticFeedback.selectionClick();
    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      useRootNavigator: true,
      builder: (_, __) => _MiniCalendarSheet(
        initialDate: _selectedDate,
        isExpense: _activeTab == CategoryType.expense,
        isDark: isDark,
        accent: accent,
        onDateSelected: (newDate) {
          setState(() {
            final now = DateTime.now();
            _selectedDate = DateTime(
              newDate.year,
              newDate.month,
              newDate.day,
              now.hour,
              now.minute,
              now.second,
            );
          });
          _syncDraft();
        },
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initialDate = _debtDueDate ?? now.add(const Duration(days: 7));

    final picked = await AppAnimationPolicy.showPreservedDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return DatePickerDialog(
          initialDate: initialDate,
          firstDate: DateTime(now.year, now.month, now.day),
          lastDate: DateTime(now.year + 5, now.month, now.day),
        );
      },
    );

    if (picked != null && mounted) {
      HapticFeedback.selectionClick();
      setState(() => _debtDueDate = picked);
      _syncDraft();
    }
  }

  Future<void> _createContactOnTheFly(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final db = ref.read(databaseProvider);
    final newId = 'contact_${DateTime.now().millisecondsSinceEpoch}';

    await db.upsertDebtContact(
      DebtContactsCompanion(
        id: drift.Value(newId),
        name: drift.Value(trimmed),
        netBalance: const drift.Value(0.0),
        createdAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );

    HapticFeedback.mediumImpact();

    if (!mounted) return;
    setState(() {
      _selectedDebtContact = DebtContact(
        id: newId,
        name: trimmed,
        netBalance: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _contactSearchController.clear();
      _isSearchingContact = false;
    });
    _debtContactFeedback.clear();
    _syncDraft();
  }

  IconData _resolveWalletIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bank':
        return Icons.credit_card_rounded;
      case 'ewallet':
        return Icons.phone_android_rounded;
      case 'credit':
        return Icons.credit_card_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'cash':
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  Future<void> _confirmDeleteTransaction() async {
    final confirmed = await AppAnimationPolicy.showPreservedDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa giao dịch này? Số dư ví sẽ được hoàn lại tương ứng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('HỦY BỎ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTokens.expense),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('XÓA', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final db = ref.read(databaseProvider);
      await db.deleteTransactionWithBalanceReversal(widget.initialTransaction!.id);
      HapticFeedback.mediumImpact();

      ref.read(cloudBackupServiceProvider).notifyDataChanged();

      if (!mounted) return;

      AppFeedback.showSuccess(
        context,
        'Đã xóa giao dịch thành công',
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _playSuccessMorphAnimation() async {
    setState(() => _isSuccessMorphed = true);
    await _morphButtonController.forward(from: 0.0);

    HapticFeedback.mediumImpact();
    await _checkIconController.forward(from: 0.0);

    await Future.delayed(const Duration(milliseconds: 250));
  }

  Future<void> _submitTransaction() async {
    if (_isSubmitting || _isSuccessMorphed) return;

    final double amount = _evaluateExpression();
    if (amount <= 0) return;

    final db = ref.read(databaseProvider);
    final activeWallets = await (db.select(db.wallets)..where((w) => w.isArchived.equals(false))).get();
    if (activeWallets.isEmpty) {
      if (!mounted) return;
      AppFeedback.showInfo(
        context,
        'Chưa có nguồn tiền khả dụng nào!',
      );
      return;
    }

    final targetWalletId = _selectedWallet?.id ??
        activeWallets.firstWhere((w) => w.isDefault, orElse: () => activeWallets.first).id;

    if (_activeTab == CategoryType.debt) {
      if (_selectedDebtContact == null) {
        _debtContactFeedback.reject();
        return;
      }

      _debtContactFeedback.clear();
      setState(() => _isSubmitting = true);

      try {
        if (_isEditMode) {
          // Standard transactions and debt transactions live in different
          // physical tables. Use the DB atomic bridge; never soft-delete the
          // original row in UI code and never expose a half-finished mutation.
          await db.convertTransactionToDebtAtomically(
            transactionId: widget.initialTransaction!.id,
            contactId: _selectedDebtContact!.id,
            walletId: targetWalletId,
            debtType: _debtActionType,
            amount: amount,
            date: _selectedDate,
            dueDate: _debtDueDate,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
        } else {
          final txId = 'debt_tx_${DateTime.now().millisecondsSinceEpoch}';
          await db.createDebtTransaction(
            id: txId,
            contactId: _selectedDebtContact!.id,
            walletId: targetWalletId,
            type: _debtActionType,
            amount: amount,
            date: _selectedDate,
            dueDate: _debtDueDate,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
        }

        ref.read(quickEntryDraftProvider.notifier).state = null;
        ref.read(cloudBackupServiceProvider).notifyDataChanged();

        await _playSuccessMorphAnimation();
        if (!mounted) return;

        String actionDesc = '';
        switch (_debtActionType) {
          case 'LEND':
            actionDesc = 'cho ${_selectedDebtContact!.name} vay';
            break;
          case 'COLLECT':
            actionDesc = 'thu nợ từ ${_selectedDebtContact!.name}';
            break;
          case 'BORROW':
            actionDesc = 'vay từ ${_selectedDebtContact!.name}';
            break;
          case 'REPAY':
            actionDesc = 'trả nợ cho ${_selectedDebtContact!.name}';
            break;
        }

        AppFeedback.showSuccess(
          context,
          _isEditMode
              ? 'Đã chuyển giao dịch sang Vay / Nợ: ${_formatCurrency(amount)}'
              : 'Đã ghi nhận $actionDesc: ${_formatCurrency(amount)}',
        );
        Navigator.of(context).pop();
      } catch (e, st) {
        debugPrint('QuickEntry debt mutation failed: $e\n$st');
        if (!mounted) return;
        AppFeedback.showError(
          context,
          _isEditMode
              ? 'Không thể thay đổi loại giao dịch. Vui lòng thử lại.'
              : 'Không thể lưu giao dịch vay / nợ. Vui lòng thử lại.',
        );
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
      return;
    }

    // Expense / income always require an explicit compatible category.
    // Never silently pick the first category or create a fallback behind the
    // user's back when the tab changed.
    final selectedCategory = _selectedCategory;
    if (selectedCategory == null || selectedCategory.type != _activeTab) {
      _categoryFeedback.reject();
      return;
    }
    _categoryFeedback.clear();

    setState(() => _isSubmitting = true);

    try {
      final catId = selectedCategory.id;
      final noteString = _noteController.text.trim();
      final finalNote = _isAmortized
          ? (noteString.isEmpty
          ? '#amortized'
          : (noteString.contains('#amortized')
          ? noteString
          : '$noteString #amortized'))
          : (noteString.isEmpty
          ? null
          : noteString.replaceAll('#amortized', '').trim());

      if (_isEditMode) {
        final oldTx = widget.initialTransaction!;
        await db.updateTransactionAtomically(
          transactionId: oldTx.id,
          walletId: targetWalletId,
          categoryId: catId,
          amount: amount,
          type: _activeTab,
          envelopeType: oldTx.envelopeType ?? 'needs',
          date: _selectedDate,
          note: finalNote,
          merchant: oldTx.merchant,
        );
      } else {
        final newTx = TransactionsCompanion(
          id: drift.Value('tx_${DateTime.now().millisecondsSinceEpoch}'),
          walletId: drift.Value(targetWalletId),
          categoryId: drift.Value(catId),
          amount: drift.Value(amount),
          type: drift.Value(_activeTab),
          envelopeType: const drift.Value('needs'),
          date: drift.Value(_selectedDate),
          note: drift.Value(finalNote),
        );

        await db.insertTransactionWithBalanceUpdate(newTx);
      }

      ref.read(quickEntryDraftProvider.notifier).state = null;
      ref.read(cloudBackupServiceProvider).notifyDataChanged();

      final double? dailySafe = widget.prefilledDailySafe;
      final bool triggersOverrun = _activeTab == CategoryType.expense &&
          !_isAmortized &&
          dailySafe != null &&
          dailySafe > 0 &&
          (amount > dailySafe);

      await _playSuccessMorphAnimation();

      if (!mounted) return;

      if (triggersOverrun) {
        final double over = amount - dailySafe;

        await AppAnimationPolicy.showFluidSheet(
          context: context,
          mode: FluidSheetMode.scrollable,
          useRootNavigator: true,
          builder: (_, scrollController) => OverrunResolutionSheet(
            overAmount: over,
            originalDailySafe: dailySafe,
            daysRemaining: 15,
            freeBudgetRemaining: 2000000,
            scrollController: scrollController,
          ),
        );

        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        AppFeedback.showSuccess(
          context,
          _isEditMode
              ? 'Đã cập nhật giao dịch!'
              : 'Đã ghi chép: ${_formatCurrency(amount)}',
        );
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      debugPrint('QuickEntry standard transaction mutation failed: $e\n$st');
      if (!mounted) return;
      AppFeedback.showError(
        context,
        _isEditMode
            ? 'Không thể thay đổi loại giao dịch. Vui lòng thử lại.'
            : 'Không thể lưu giao dịch. Vui lòng thử lại.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Color _resolveDebtColor(String actionType) {
    switch (actionType) {
      case 'LEND':
        return const Color(0xFF10B981);
      case 'COLLECT':
        return const Color(0xFF0EA5E9);
      case 'BORROW':
        return const Color(0xFFF59E0B);
      case 'REPAY':
        return const Color(0xFFF43F5E);
      default:
        return const Color(0xFF10B981);
    }
  }

  String _formatDateChipLabel(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) {
      return '📅 Hôm nay, ${DateFormat('dd/MM').format(date)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
    if (isYesterday) {
      return '📅 Hôm qua, ${DateFormat('dd/MM').format(date)}';
    }
    final dayBefore = now.subtract(const Duration(days: 2));
    final isDayBefore = date.year == dayBefore.year && date.month == dayBefore.month && date.day == dayBefore.day;
    if (isDayBefore) {
      return '📅 Hôm kia, ${DateFormat('dd/MM').format(date)}';
    }
    return '📅 ${DateFormat('dd/MM/yyyy').format(date)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final walletsAsync = ref.watch(quickEntryWalletsStreamProvider);
    final debtContactsAsync = ref.watch(quickEntryDebtContactsStreamProvider);

    final double calculatedAmount = _evaluateExpression();
    final double dailySafeLimit = widget.prefilledDailySafe ?? 150000.0;
    final bool isLargeSpend = _activeTab == CategoryType.expense &&
        dailySafeLimit > 0 &&
        calculatedAmount > dailySafeLimit;

    final now = DateTime.now();

    final isSelectedYesterday = _selectedDate.year == now.subtract(const Duration(days: 1)).year &&
        _selectedDate.month == now.subtract(const Duration(days: 1)).month &&
        _selectedDate.day == now.subtract(const Duration(days: 1)).day;

    final isSelectedDayBefore = _selectedDate.year == now.subtract(const Duration(days: 2)).year &&
        _selectedDate.month == now.subtract(const Duration(days: 2)).month &&
        _selectedDate.day == now.subtract(const Duration(days: 2)).day;

    final bool hasDraftData = _expression != '0' || _noteController.text.trim().isNotEmpty;
    final bool canSubmit = calculatedAmount > 0 && !_isSubmitting;
    final bool requiredSelectionReady = _activeTab == CategoryType.debt
        ? _selectedDebtContact != null
        : _selectedCategory != null && _selectedCategory!.type == _activeTab;

    return AppFeedbackDismissRegion(
      child: AnimatedBuilder(
        animation: _colorMorphAnimation,
        builder: (context, _) {
          final Color currentSemanticColor = _colorMorphAnimation.value ?? _resolveCurrentSemanticColor();

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.92,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppTokens.darkBg : AppTokens.lightBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // ===============================================================
                // 🌟 NỬA TRÊN: CUỘN ĐƯỢC VÀ ĐIỀU PHỐI VỚI FLUID SHEET ENGINE
                // ===============================================================
                Expanded(
                  child: SingleChildScrollView(
                    controller: widget.scrollController,
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white24 : Colors.black26,
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                            ),
                          ),
                        ),

                        if (_isEditMode)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 2, 12, 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.edit_note_rounded, size: 20, color: accent.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Chỉnh sửa giao dịch',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppTokens.expense, size: 22),
                                  onPressed: _confirmDeleteTransaction,
                                ),
                              ],
                            ),
                          ),

                        // ===============================================================
                        // 🌟 TẦNG 1: 3 TAB CHÍNH (HEIGHT 42PX, BO GÓC 12PX)
                        // ===============================================================
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SlidingSegmentedBar<CategoryType>(
                            height: 42,
                            fontSize: 12,
                            selectedValue: _activeTab,
                            onValueChanged: _switchTab,
                            items: [
                              SlidingSegmentedItem<CategoryType>(
                                value: CategoryType.expense,
                                label: 'Khoản chi',
                                activeColor: AppTokens.expense,
                                activeBackgroundColor: AppTokens.expense.withValues(alpha: 0.18),
                              ),
                              SlidingSegmentedItem<CategoryType>(
                                value: CategoryType.income,
                                label: 'Khoản thu',
                                activeColor: AppTokens.income,
                                activeBackgroundColor: AppTokens.income.withValues(alpha: 0.18),
                              ),
                              SlidingSegmentedItem<CategoryType>(
                                value: CategoryType.debt,
                                label: 'Vay / Nợ',
                                activeColor: const Color(0xFF10B981),
                                activeBackgroundColor: const Color(0xFF10B981).withValues(alpha: 0.18),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ===============================================================
                        // 🌟 TẦNG 2: 4 SUB-TAB CÔNG NỢ (HEIGHT 34PX, SOLID BG, CHỮ TRẮNG)
                        // ===============================================================
                        if (_activeTab == CategoryType.debt) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: SlidingSegmentedBar<String>(
                              height: 34,
                              fontSize: 11,
                              selectedValue: _debtActionType,
                              onValueChanged: (newAction) {
                                setState(() => _debtActionType = newAction);
                                _animateSemanticColor();
                                _syncDraft();
                              },
                              items: const [
                                SlidingSegmentedItem<String>(
                                  value: 'LEND',
                                  label: 'Cho vay (+)',
                                  activeColor: Color(0xFF10B981),
                                  activeBackgroundColor: Color(0xFF10B981),
                                ),
                                SlidingSegmentedItem<String>(
                                  value: 'COLLECT',
                                  label: 'Thu nợ (-)',
                                  activeColor: Color(0xFF0EA5E9),
                                  activeBackgroundColor: Color(0xFF0EA5E9),
                                ),
                                SlidingSegmentedItem<String>(
                                  value: 'BORROW',
                                  label: 'Đi vay (-)',
                                  activeColor: Color(0xFFF59E0B),
                                  activeBackgroundColor: Color(0xFFF59E0B),
                                ),
                                SlidingSegmentedItem<String>(
                                  value: 'REPAY',
                                  label: 'Trả nợ (+)',
                                  activeColor: Color(0xFFF43F5E),
                                  activeBackgroundColor: Color(0xFFF43F5E),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // ===============================================================
                        // 🌟 KHỐI HIỂN THỊ SỐ TIỀN: 32SP & NHẢY SỐ TRƯỢT DỌC 140MS
                        // ===============================================================
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _activeTab == CategoryType.debt ? 'Số tiền vay nợ' : 'Số tiền',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                    ),
                                  ),
                                  if (hasDraftData) ...[
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: _resetDraftAndInputs,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white12 : Colors.black12,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 140),
                                switchInCurve: Curves.easeOutQuad,
                                switchOutCurve: Curves.easeInQuad,
                                transitionBuilder: (child, animation) {
                                  return SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, 0.08),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: FadeTransition(opacity: animation, child: child),
                                  );
                                },
                                child: Text(
                                  _formatCurrency(calculatedAmount),
                                  key: ValueKey<String>(_expression),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                    letterSpacing: -0.5,
                                    color: currentSemanticColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (isLargeSpend)
                          AnimatedBuilder(
                            animation: _headShakeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_headShakeAnimation.value, 0),
                                child: child,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('⚠️', style: TextStyle(fontSize: 14)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Khoản này vượt mức chi hôm nay (${_formatCurrency(dailySafeLimit)}). Bạn có muốn dàn đều cho các ngày tới?',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              setState(() => _isAmortized = true);
                                              _syncDraft();
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                              decoration: BoxDecoration(
                                                color: _isAmortized ? const Color(0xFF10B981) : (isDark ? AppTokens.darkCard : Colors.white),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: _isAmortized ? const Color(0xFF10B981) : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '✓ Có, dàn đều',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: _isAmortized ? Colors.white : (isDark ? AppTokens.darkText : AppTokens.lightText),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              setState(() => _isAmortized = false);
                                              _syncDraft();
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                              decoration: BoxDecoration(
                                                color: !_isAmortized ? const Color(0xFFF59E0B) : (isDark ? AppTokens.darkCard : Colors.white),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: !_isAmortized ? const Color(0xFFF59E0B) : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'Không, tính hôm nay',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: !_isAmortized ? Colors.white : (isDark ? AppTokens.darkText : AppTokens.lightText),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        const Divider(height: 14),

                        // ===============================================================
                        // 🌟 CỤM INPUT: ĐỐI TÁC, DANH MỤC, GHI CHÚ & VÍ (CHIỀU CAO 46PX)
                        // ===============================================================
                        if (_activeTab != CategoryType.debt)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: AppValidationFeedback(
                              controller: _categoryFeedback,
                              builder: (context, visual) {
                                final restingBorder = _selectedCategory != null
                                    ? currentSemanticColor.withValues(alpha: 0.5)
                                    : (isDark
                                    ? AppTokens.darkBorder
                                    : AppTokens.lightBorder);

                                return InkWell(
                                  onTap: _openCategoryModal,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    height: 46,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTokens.darkCard : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: visual.borderColor(restingBorder),
                                        width: visual.isInvalid ? 1.4 : 1.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: currentSemanticColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.folder_open_rounded,
                                            size: 16,
                                            color: currentSemanticColor,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Danh mục giao dịch',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isDark
                                                      ? AppTokens.darkMuted
                                                      : AppTokens.lightMuted,
                                                ),
                                              ),
                                              Text(
                                                _selectedCategory != null
                                                    ? _selectedCategory!.name
                                                    : 'Chọn danh mục 2 cấp...',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: _selectedCategory != null
                                                      ? (isDark
                                                      ? AppTokens.darkText
                                                      : AppTokens.lightText)
                                                      : (isDark
                                                      ? AppTokens.darkMuted
                                                      : AppTokens.lightMuted),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 20,
                                          color: isDark
                                              ? AppTokens.darkMuted
                                              : AppTokens.lightMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                        if (_activeTab == CategoryType.debt)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: AppValidationFeedback(
                              controller: _debtContactFeedback,
                              builder: (context, visual) {
                                final restingBorder = isDark
                                    ? AppTokens.darkBorder
                                    : AppTokens.lightBorder;
                                final validationBorder =
                                visual.borderColor(restingBorder);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_selectedDebtContact != null)
                                      Container(
                                        height: 46,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: currentSemanticColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: visual.borderColor(
                                              currentSemanticColor.withValues(alpha: 0.4),
                                            ),
                                            width: visual.isInvalid ? 1.8 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: currentSemanticColor.withValues(alpha: 0.25),
                                              child: Icon(Icons.person_rounded, size: 16, color: currentSemanticColor),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _selectedDebtContact!.name,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w800,
                                                      color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                                    ),
                                                  ),
                                                  Text(
                                                    _selectedDebtContact!.netBalance > 0
                                                        ? 'Đang nợ bạn: ${_formatCurrency(_selectedDebtContact!.netBalance)}'
                                                        : (_selectedDebtContact!.netBalance < 0
                                                        ? 'Bạn đang nợ: ${_formatCurrency(_selectedDebtContact!.netBalance.abs())}'
                                                        : 'Đã tất toán sòng phẳng (0 ₫)'),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: _selectedDebtContact!.netBalance > 0
                                                          ? const Color(0xFF10B981)
                                                          : (_selectedDebtContact!.netBalance < 0
                                                          ? AppTokens.expense
                                                          : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                _debtContactFeedback.clear();
                                                setState(() => _selectedDebtContact = null);
                                                _syncDraft();
                                              },
                                              borderRadius: BorderRadius.circular(8),
                                              child: Padding(
                                                padding: const EdgeInsets.all(4.0),
                                                child: Icon(Icons.close_rounded, size: 16, color: currentSemanticColor),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      SizedBox(
                                        height: 46,
                                        child: TextField(
                                          controller: _contactSearchController,
                                          onChanged: (text) {
                                            setState(
                                                  () => _isSearchingContact =
                                                  text.trim().isNotEmpty,
                                            );
                                          },
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Nhập tên người vay / nợ (vd: Nam, Hải Anh)...',
                                            hintStyle: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                            ),
                                            prefixIcon: Icon(Icons.person_outline_rounded, size: 18, color: currentSemanticColor),
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide(
                                                color: validationBorder,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide(
                                                color: validationBorder,
                                                width: visual.isInvalid ? 1.8 : 1.0,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              borderSide: BorderSide(
                                                color: visual.isInvalid
                                                    ? AppTokens.expense
                                                    : currentSemanticColor,
                                                width: 1.8,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    if (_isSearchingContact && _selectedDebtContact == null)
                                      debtContactsAsync.when(
                                        data: (contacts) {
                                          final query = _contactSearchController.text.trim().toLowerCase();
                                          final matched = contacts.where((c) => c.name.toLowerCase().contains(query)).toList();
                                          final isExactMatch = matched.any((c) => c.name.toLowerCase() == query);

                                          return Container(
                                            margin: const EdgeInsets.only(top: 6),
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: isDark ? AppTokens.darkCard : Colors.white,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.08),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ...matched.map((c) {
                                                  return ListTile(
                                                    dense: true,
                                                    visualDensity: VisualDensity.compact,
                                                    leading: const Icon(Icons.account_circle_outlined, size: 20),
                                                    title: Text(
                                                      c.name,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                        color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                                      ),
                                                    ),
                                                    subtitle: Text(
                                                      c.netBalance != 0
                                                          ? 'Dư nợ: ${_formatCurrency(c.netBalance)}'
                                                          : 'Đã tất toán',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                                      ),
                                                    ),
                                                    onTap: () {
                                                      HapticFeedback.selectionClick();
                                                      setState(() {
                                                        _selectedDebtContact = c;
                                                        _contactSearchController.clear();
                                                        _isSearchingContact = false;
                                                      });
                                                      _debtContactFeedback.clear();
                                                      _syncDraft();
                                                    },
                                                  );
                                                }),
                                                if (!isExactMatch && _contactSearchController.text.trim().isNotEmpty)
                                                  InkWell(
                                                    onTap: () => _createContactOnTheFly(_contactSearchController.text),
                                                    borderRadius: BorderRadius.circular(10),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.person_add_alt_1_rounded, size: 18, color: currentSemanticColor),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              '+ Thêm mới "${_contactSearchController.text.trim()}" vào danh bạ nợ',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w800,
                                                                color: currentSemanticColor,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                        loading: () => const SizedBox(),
                                        error: (_, __) => const SizedBox(),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 8),

                        // Hàng Ghi chú & Dropdown Ví (Chiều cao 46px, minWidth 110px)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 46,
                                  child: TextField(
                                    controller: _noteController,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _activeTab == CategoryType.debt
                                          ? 'Ghi chú (vd: Ăn trưa hộ, Mượn tiền mặt...)'
                                          : 'Ghi chú / Cửa hàng...',
                                      hintStyle: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                      ),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              walletsAsync.when(
                                data: (wallets) {
                                  if (wallets.isEmpty) return const SizedBox();

                                  _selectedWallet ??= wallets.firstWhere(
                                        (w) => w.isDefault,
                                    orElse: () => wallets.first,
                                  );

                                  return InkWell(
                                    onTap: () => _handleWalletPickerTap(wallets, isDark, accent),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      height: 46,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      constraints: const BoxConstraints(minWidth: 110, maxWidth: 140),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTokens.darkCard : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.02),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          AnimatedBuilder(
                                            animation: _walletIconTiltAnimation,
                                            builder: (context, child) {
                                              return Transform.rotate(
                                                angle: _walletIconTiltAnimation.value,
                                                child: child,
                                              );
                                            },
                                            child: Icon(
                                              _resolveWalletIcon(_selectedWallet!.type),
                                              size: 15,
                                              color: _parseColor(_selectedWallet!.color),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              _selectedWallet!.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.arrow_drop_down_rounded,
                                            size: 18,
                                            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                loading: () => const SizedBox(),
                                error: (_, __) => const SizedBox(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),

                        if (_activeTab == CategoryType.debt)
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                            color: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
                            child: Row(
                              children: [
                                Text(
                                  'Hạn trả:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      children: [
                                        _buildDueDateChip('Không hẹn', _debtDueDate == null, () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _debtDueDate = null);
                                          _syncDraft();
                                        }, isDark, currentSemanticColor),
                                        const SizedBox(width: 6),
                                        _buildDueDateChip(
                                          '7 ngày',
                                          _debtDueDate != null && _debtDueDate!.difference(now).inDays == 7,
                                              () {
                                            HapticFeedback.selectionClick();
                                            setState(() => _debtDueDate = now.add(const Duration(days: 7)));
                                            _syncDraft();
                                          },
                                          isDark,
                                          currentSemanticColor,
                                        ),
                                        const SizedBox(width: 6),
                                        _buildDueDateChip(
                                          '1 tháng',
                                          _debtDueDate != null &&
                                              _debtDueDate!.difference(now).inDays >= 28 &&
                                              _debtDueDate!.difference(now).inDays <= 31,
                                              () {
                                            HapticFeedback.selectionClick();
                                            setState(() => _debtDueDate = now.add(const Duration(days: 30)));
                                            _syncDraft();
                                          },
                                          isDark,
                                          currentSemanticColor,
                                        ),
                                        const SizedBox(width: 6),
                                        _buildDueDateChip(
                                          _debtDueDate != null ? DateFormat('dd/MM').format(_debtDueDate!) : '📅 Chọn ngày',
                                          _debtDueDate != null,
                                          _pickDueDate,
                                          isDark,
                                          currentSemanticColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Hàng Chip Ngày
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
                            border: Border(
                              top: BorderSide(
                                color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => _openMiniCalendarModal(isDark, accent),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: currentSemanticColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: currentSemanticColor.withValues(alpha: 0.4),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatDateChipLabel(_selectedDate),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: currentSemanticColor,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: currentSemanticColor),
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        final y = now.subtract(const Duration(days: 1));
                                        _selectedDate = DateTime(y.year, y.month, y.day, now.hour, now.minute);
                                      });
                                      _syncDraft();
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      height: 32,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSelectedYesterday
                                            ? currentSemanticColor.withValues(alpha: 0.14)
                                            : (isDark ? AppTokens.darkCard : Colors.white),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelectedYesterday
                                              ? currentSemanticColor
                                              : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Text(
                                        'Hôm qua',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelectedYesterday ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelectedYesterday
                                              ? currentSemanticColor
                                              : (isDark ? AppTokens.darkText : AppTokens.lightText),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        final d = now.subtract(const Duration(days: 2));
                                        _selectedDate = DateTime(d.year, d.month, d.day, now.hour, now.minute);
                                      });
                                      _syncDraft();
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      height: 32,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSelectedDayBefore
                                            ? currentSemanticColor.withValues(alpha: 0.14)
                                            : (isDark ? AppTokens.darkCard : Colors.white),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelectedDayBefore
                                              ? currentSemanticColor
                                              : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Text(
                                        'Hôm kia',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelectedDayBefore ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelectedDayBefore
                                              ? currentSemanticColor
                                              : (isDark ? AppTokens.darkText : AppTokens.lightText),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // ===============================================================
                // 🌟 VÙNG CỐ ĐỊNH PHÍA DƯỚI: NUMPAD VÀ NÚT LƯU 50PX
                // ===============================================================
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTokens.darkCard : AppTokens.lightCard,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildChromaticNumpad(isDark, currentSemanticColor),
                        const SizedBox(height: 8),

                        Center(
                          child: AnimatedBuilder(
                            animation: _morphWidthAnimation,
                            builder: (context, child) {
                              final double fullWidth = MediaQuery.of(context).size.width - 24;
                              final double currentWidth = _isSuccessMorphed
                                  ? fullWidth - (fullWidth - 50.0) * _morphWidthAnimation.value
                                  : fullWidth;

                              return SizedBox(
                                width: currentWidth,
                                height: 50,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 140),
                                  opacity: canSubmit
                                      ? (requiredSelectionReady ? 1.0 : 0.58)
                                      : 0.40,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: currentSemanticColor,
                                      foregroundColor: Colors.white,
                                      elevation: canSubmit ? 2 : 0,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          _isSuccessMorphed
                                              ? 16.0 + (9.0 * _morphWidthAnimation.value)
                                              : 16.0,
                                        ),
                                      ),
                                    ),
                                    onPressed: canSubmit ? _submitTransaction : null,
                                    child: _isSuccessMorphed
                                        ? ScaleTransition(
                                      scale: _checkScaleAnimation,
                                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
                                    )
                                        : (_isSubmitting
                                        ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor: AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                        : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                        child: Text(
                                          _activeTab == CategoryType.debt
                                              ? '✓ XÁC NHẬN GIAO DỊCH VAY NỢ'
                                              : (_isAmortized
                                              ? '✓ LƯU & DÀN ĐỀU CẢ KỲ'
                                              : (_isEditMode ? '✓ CẬP NHẬT GIAO DỊCH' : 'LƯU GIAO DỊCH')),
                                          maxLines: 1,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    )),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDueDateChip(String label, bool isSelected, VoidCallback onTap, bool isDark, Color debtColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? debtColor.withValues(alpha: 0.14)
              : (isDark ? AppTokens.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? debtColor
                : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? debtColor
                : (isDark ? AppTokens.darkText : AppTokens.lightText),
          ),
        ),
      ),
    );
  }

  Widget _buildChromaticNumpad(bool isDark, Color currentSemanticColor) {
    final rows = [
      ['7', '8', '9', '+50k'],
      ['4', '5', '6', '+100k'],
      ['1', '2', '3', '+200k'],
      ['C', '0', '000', '⌫'],
    ];

    final Color normalKeyBg = isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle;
    final Color shortcutKeyBg = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9);
    final Color normalKeyText = isDark ? AppTokens.darkText : AppTokens.lightText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            children: row.map((key) {
              Color keyBg = normalKeyBg;
              Color keyText = normalKeyText;
              bool isMonospace = true;

              if (key.startsWith('+')) {
                keyBg = shortcutKeyBg;
                keyText = currentSemanticColor;
                isMonospace = false;
              } else if (key == 'C') {
                final bool hasInput = _expression != '0';
                keyBg = hasInput ? AppTokens.expense.withValues(alpha: 0.12) : normalKeyBg;
                keyText = hasInput ? AppTokens.expense : (isDark ? Colors.white30 : Colors.black26);
              } else if (key == '⌫') {
                keyBg = normalKeyBg;
                keyText = isDark ? Colors.white70 : Colors.black87;
              }

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                  child: _NumpadKey(
                    label: key,
                    bgColor: keyBg,
                    textColor: keyText,
                    isMonospace: isMonospace,
                    onTap: () => _onNumpadPress(key),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

// ==============================================================================
// MODAL LỊCH MINI (_MiniCalendarSheet)
// ==============================================================================

class _MiniCalendarSheet extends StatefulWidget {
  final DateTime initialDate;
  final bool isExpense;
  final bool isDark;
  final AppAccentPreset accent;
  final ValueChanged<DateTime> onDateSelected;

  const _MiniCalendarSheet({
    required this.initialDate,
    required this.isExpense,
    required this.isDark,
    required this.accent,
    required this.onDateSelected,
  });

  @override
  State<_MiniCalendarSheet> createState() => _MiniCalendarSheetState();
}

class _MiniCalendarSheetState extends State<_MiniCalendarSheet> {
  late DateTime _displayedMonth;
  late DateTime _currentPickedDate;

  @override
  void initState() {
    super.initState();
    _currentPickedDate = widget.initialDate;
    _displayedMonth = DateTime(widget.initialDate.year, widget.initialDate.month, 1);
  }

  void _shiftMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday;
    final leadingEmptyCount = (firstWeekday - 1) % 7;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF151C28) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: widget.isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 28),
                    onPressed: () => _shiftMonth(-1),
                  ),
                  Text(
                    'Tháng ${DateFormat('MM / yyyy').format(_displayedMonth)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: widget.isDark ? AppTokens.darkText : AppTokens.lightText,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 28),
                    onPressed: () => _shiftMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'].map((w) {
                  final isWeekend = w == 'T7' || w == 'CN';
                  return Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isWeekend
                              ? (widget.isDark ? Colors.amber.shade300 : Colors.amber.shade800)
                              : (widget.isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1.0,
                ),
                itemCount: leadingEmptyCount + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < leadingEmptyCount) {
                    return const SizedBox();
                  }

                  final dayNumber = index - leadingEmptyCount + 1;
                  final cellDate = DateTime(_displayedMonth.year, _displayedMonth.month, dayNumber);

                  final isFutureDate = cellDate.isAfter(today);
                  final isDisabled = widget.isExpense && isFutureDate;

                  final isSelected = cellDate.year == _currentPickedDate.year &&
                      cellDate.month == _currentPickedDate.month &&
                      cellDate.day == _currentPickedDate.day;

                  final isToday = cellDate.year == today.year &&
                      cellDate.month == today.month &&
                      cellDate.day == today.day;

                  return InkWell(
                    onTap: isDisabled
                        ? null
                        : () {
                      HapticFeedback.selectionClick();
                      setState(() => _currentPickedDate = cellDate);
                      widget.onDateSelected(cellDate);
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? widget.accent.primary
                            : (isToday
                            ? widget.accent.primary.withValues(alpha: 0.15)
                            : Colors.transparent),
                        borderRadius: BorderRadius.circular(12),
                        border: isToday && !isSelected
                            ? Border.all(color: widget.accent.primary, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDisabled
                                ? (widget.isDark ? Colors.white24 : Colors.black26)
                                : (isSelected
                                ? Colors.white
                                : (widget.isDark ? AppTokens.darkText : AppTokens.lightText)),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    widget.onDateSelected(today);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.today_rounded, size: 16),
                  label: const Text(
                    'Hôm nay',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.accent.primary,
                    side: BorderSide(color: widget.accent.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}