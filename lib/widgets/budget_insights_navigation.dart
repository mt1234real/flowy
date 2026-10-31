import 'package:flutter/material.dart';
import '../core/animation/flowy_navigation_motion.dart';
import '../data/database.dart';
import '../features/insights/insights_data.dart';
import '../features/insights/spending_insights_screen.dart';
import '../services/budget_spending.dart';

/// Uses fiscal calendar labels (end exclusive), matching InsightsWindow.
SpendingInsightsScreen budgetInsightsScreen(
    BudgetSpending b, BudgetSpendingOverview overview,
    {required bool isVisible}) {
  final ids = <String>{b.budget.categoryId};
  bool added;
  do {
    added = false;
    for (final c in overview.source.categories) {
      if (ids.contains(c.parentId) && ids.add(c.id)) added = true;
    }
  } while (added);
  return SpendingInsightsScreen(
      initialPeriod: InsightsPeriod.custom,
      anchor: b.start,
      customWindow: InsightsWindow(b.start, b.end),
      initialType: CategoryType.expense,
      title: b.name,
      detailCategoryId: b.budget.categoryId,
      categoryIds: ids,
      leaf: true,
      revealAmounts: isVisible,
      budgetScopeId: b.budget.id);
}

Future<void> openBudgetInsights(
    BuildContext context, BudgetSpending b, BudgetSpendingOverview overview,
    {required bool isVisible}) {
  if (ModalRoute.of(context)?.isCurrent == false) return Future.value();
  return Navigator.of(context).push(flowyReferenceRoute<void>(
      builder: (_) => budgetInsightsScreen(b, overview, isVisible: isVisible)));
}
