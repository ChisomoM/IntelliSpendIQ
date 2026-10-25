import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/domain/models/budget_period.dart';
import 'package:intellispendiq/domain/services/shopping_trip_calculator.dart';

/// Each top-level expense category's envelope for a period and what has
/// been spent against it, subcategories rolled up into their parent and
/// planned (unpaid) transactions left out. It mirrors the figures
/// `BudgetsCubit` puts on the Budgets screen, so a shopping trip never
/// disagrees with them.
class CategoryEnvelopeService {
  CategoryEnvelopeService({
    required CategoryRepository categories,
    required BudgetPeriodRepository budgetPeriods,
    required TransactionRepository transactions,
  }) : _categories = categories,
       _budgetPeriods = budgetPeriods,
       _transactions = transactions;

  final CategoryRepository _categories;
  final BudgetPeriodRepository _budgetPeriods;
  final TransactionRepository _transactions;

  Future<Map<String, CategoryEnvelope>> forPeriod(BudgetPeriod period) async {
    final categories = (await _categories.getAll())
        .where((c) => c.isExpense)
        .toList();
    final envelopes = {
      for (final b in await _budgetPeriods.categoryBudgetsFor(period.id))
        b.categoryId: b.amountMinor,
    };

    final direct = <String, int>{};
    for (final category in categories) {
      direct[category.id] = await _transactions.spentForCategoryInRange(
        category.id,
        from: period.startAt,
        to: period.endAt,
      );
    }

    return {
      for (final category in categories)
        if (category.parentId == null)
          category.id: CategoryEnvelope(
            categoryId: category.id,
            envelopeMinor: envelopes[category.id],
            spentMinor:
                (direct[category.id] ?? 0) +
                categories
                    .where((c) => c.parentId == category.id)
                    .fold<int>(0, (sum, c) => sum + (direct[c.id] ?? 0)),
          ),
    };
  }
}
