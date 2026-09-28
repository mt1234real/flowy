import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../core/animation/app_animation_policy.dart';
import '../../core/feedback/app_feedback.dart';
import '../../widgets/quick_entry_sheet.dart';
import '../../widgets/debt_transaction_detail_sheet.dart';
import '../../screens/contact_ledger_screen.dart';
import '../../screens/recycle_bin_screen.dart';
import '../insights/spending_insights_screen.dart';
import '../insights/insights_data.dart';

Future<bool> openNotification(
    BuildContext context, AppDatabase db, AppNotification item) async {
  Map<String, dynamic> payload;
  try {
    payload =
        Map<String, dynamic>.from(jsonDecode(item.payload ?? '{}') as Map);
  } catch (_) {
    return false;
  }
  if (!context.mounted) return false;
  final target = payload['target'];
  switch (target) {
    case 'quick_entry':
      final route =
          QuickEntrySheet.show(context, initialContextDate: DateTime.now());
      await db.markAsRead(item.id);
      await route;
      return true;
    case 'debt_detail':
      final id = payload['id'] as String?;
      final debt = id == null
          ? null
          : await (db.select(db.debtTransactions)
                ..where((d) => d.id.equals(id) & d.deletedAt.isNull()))
              .getSingleOrNull();
      if (!context.mounted) return false;
      if (debt != null) {
        final route = AppAnimationPolicy.showFluidSheet<void>(
            context: context,
            mode: FluidSheetMode.nestedScrollable,
            builder: (_, __) =>
                DebtTransactionDetailSheet(debtTransaction: debt));
        await db.markAsRead(item.id);
        await route;
        return true;
      }
      final contactId = payload['contactId'] as String?;
      final contact = contactId == null
          ? null
          : await (db.select(db.debtContacts)
                ..where((c) => c.id.equals(contactId)))
              .getSingleOrNull();
      if (!context.mounted) return false;
      if (contact == null) {
        AppFeedback.showInfo(context, 'Khoản vay này không còn trong sổ.');
        return false;
      }
      Navigator.of(context).push(PreservedMaterialPageRoute(
          builder: (_) => ContactLedgerScreen(contact: contact)));
    case 'budget_insights':
      final start = DateTime.tryParse(payload['start'] as String? ?? '');
      final end = DateTime.tryParse(payload['end'] as String? ?? '');
      var ids = (payload['categoryIds'] as List?)?.cast<String>().toSet();
      final categoryId = payload['id'] as String?;
      if (ids == null && categoryId != null) {
        final categories = await db.select(db.categories).get();
        ids = {categoryId};
        var changed = true;
        while (changed) {
          final before = ids.length;
          ids.addAll(categories
              .where((c) => ids!.contains(c.parentId))
              .map((c) => c.id));
          changed = ids.length != before;
        }
      }
      if (!context.mounted) return false;
      Navigator.of(context).push(PreservedMaterialPageRoute(
          builder: (_) => SpendingInsightsScreen(
                initialPeriod: start != null && end != null
                    ? InsightsPeriod.custom
                    : InsightsPeriod.cycle,
                customWindow: start != null && end != null
                    ? InsightsWindow(start, end)
                    : null,
                categoryIds: ids,
                detailCategoryId: payload['id'] as String?,
              )));
    case 'recycle_bin':
      Navigator.of(context).push(
          PreservedMaterialPageRoute(builder: (_) => const RecycleBinScreen()));
    default:
      AppFeedback.showInfo(context, 'Thông báo này chưa có nội dung để mở.');
      return false;
  }
  await db.markAsRead(item.id);
  return true;
}
