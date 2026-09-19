import 'package:flutter/material.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';

/// Every top-level income source for the period, with its planned
/// amount, paid/unpaid status, and Actual vs Provisional totals.
///
/// Actual counts only what's been marked paid — the figure used
/// everywhere else money-in for this cycle is shown. Provisional adds
/// unpaid ("expected") envelopes on top, so the user can see both what
/// they have and what they're still expecting.
class IncomeSummaryCard extends StatelessWidget {
  const IncomeSummaryCard({
    required this.incomeCategories,
    required this.statusByCategory,
    required this.actualMinor,
    required this.provisionalMinor,
    required this.onTapRow,
    this.periodId,
    super.key,
  });

  /// Top-level income categories, including those without a plan yet.
  final List<Category> incomeCategories;

  /// Paid/unpaid status per category id. Absent means no envelope set
  /// yet for this category this period.
  final Map<String, IncomeStatus> statusByCategory;

  final int actualMinor;
  final int provisionalMinor;

  /// Called when a row (with a planned amount) is tapped, to toggle its
  /// paid/unpaid state.
  final void Function(Category category, IncomeStatus? current) onTapRow;

  /// Budget period to write planned amounts into when editing.
  final String? periodId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final money = Theme.of(context).extension<MoneyColors>()!;
    final planned = incomeCategories.where((c) => c.hasBudget).toList();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.x2,
              Space.x2,
              Space.x2,
              Space.x1,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: money.inflow.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(Radii.card),
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(
                    AppIcons.moneyIn,
                    size: 20,
                    color: money.inflow,
                  ),
                ),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Income', style: AppTypography.rowTitle()),
                      const SizedBox(height: 2),
                      Text(
                        'Money coming in this period',
                        style: AppTypography.metadata(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openEditor(context),
                  icon: AppIcon(AppIcons.add, size: 16, color: colors.primary),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          if (incomeCategories.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x2,
                0,
                Space.x2,
                Space.x2,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Salary, side hustle, or anything else you earn.',
                  style: AppTypography.metadata(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else ...[
            for (final category in incomeCategories)
              _IncomeSourceRow(
                category: category,
                periodId: periodId,
                status: statusByCategory[category.id],
                onTap: () =>
                    onTapRow(category, statusByCategory[category.id]),
              ),
            if (planned.isNotEmpty) ...[
              Divider(height: 1, color: colors.outlineVariant),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.x2,
                  Space.x2,
                  Space.x2,
                  Space.x2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Actual income',
                            style: AppTypography.rowTitle(
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        MoneyText.signed(actualMinor, isInflow: true),
                      ],
                    ),
                    if (provisionalMinor != actualMinor) ...[
                      const SizedBox(height: Space.x1),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Expected (incl. unpaid)',
                              style: AppTypography.metadata(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(
                            Money.display(provisionalMinor),
                            style: AppTypography.metadata(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _openEditor(BuildContext context) {
    Navigator.of(context).push<String?>(
      CategoryEditorPage.route(
        initialType: CategoryType.income,
        periodId: periodId,
      ),
    );
  }
}

class _IncomeSourceRow extends StatelessWidget {
  const _IncomeSourceRow({
    required this.category,
    required this.onTap,
    this.periodId,
    this.status,
  });

  final Category category;
  final String? periodId;
  final IncomeStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPaid = status == IncomeStatus.paid;

    return AppListRow(
      leading: CategoryAvatar(
        iconKey: category.icon,
        categoryId: category.id,
        colorName: category.color,
        size: 36,
      ),
      title: Text(category.name),
      subtitle: category.hasBudget
          ? Text(
              isPaid ? 'Paid' : 'Unpaid',
              style: AppTypography.metadata(
                color: isPaid ? colors.primary : colors.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (category.hasBudget)
            MoneyText(category.budgetedAmountMinor!, size: MoneySize.meta)
          else
            Text(
              'Set amount',
              style: AppTypography.metadata(color: colors.primary),
            ),
          const SizedBox(width: 4),
          AppIcon(
            AppIcons.chevronRight,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
        ],
      ),
      // Tapping a row with a planned amount toggles paid/unpaid; a row
      // with no amount yet opens the editor to set one first.
      onTap: category.hasBudget
          ? onTap
          : () => Navigator.of(context).push<String?>(
              CategoryEditorPage.route(existing: category, periodId: periodId),
            ),
      onLongPress: () => Navigator.of(context).push<String?>(
        CategoryEditorPage.route(existing: category, periodId: periodId),
      ),
    );
  }
}

/// Amount + date picked when marking an income envelope paid — may
/// differ from the envelope's planned figure (e.g. only part came in).
class MarkIncomePaidResult {
  const MarkIncomePaidResult({
    required this.amountMinor,
    required this.transactedAt,
  });

  final int amountMinor;
  final DateTime transactedAt;
}

/// Confirms (and lets the user adjust) the amount/date before marking an
/// income category paid. Returns null if the user cancels.
Future<MarkIncomePaidResult?> showMarkIncomePaidSheet(
  BuildContext context, {
  required Category category,
}) {
  return showModalBottomSheet<MarkIncomePaidResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _MarkIncomePaidSheet(category: category),
  );
}

class _MarkIncomePaidSheet extends StatefulWidget {
  const _MarkIncomePaidSheet({required this.category});

  final Category category;

  @override
  State<_MarkIncomePaidSheet> createState() => _MarkIncomePaidSheetState();
}

class _MarkIncomePaidSheetState extends State<_MarkIncomePaidSheet> {
  late final TextEditingController _amountController;
  DateTime _transactedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    final planned = widget.category.budgetedAmountMinor;
    _amountController = TextEditingController(
      text: planned == null ? '' : Money.display(planned),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.x2,
        Space.x2,
        Space.x2,
        MediaQuery.of(context).viewInsets.bottom + Space.x2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mark "${widget.category.name}" as paid',
            style: AppTypography.rowTitle(),
          ),
          const SizedBox(height: Space.x2),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(labelText: 'Amount received'),
          ),
          const SizedBox(height: Space.x2),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date received'),
            subtitle: Text(
              '${_transactedAt.year}-${_transactedAt.month.toString().padLeft(2, '0')}-${_transactedAt.day.toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.calendar_today, size: 18),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _transactedAt,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _transactedAt = picked);
            },
          ),
          const SizedBox(height: Space.x2),
          FilledButton(
            onPressed: () {
              final amountMinor = Money.tryParseToMinor(_amountController.text);
              if (amountMinor == null || amountMinor <= 0) return;
              Navigator.of(context).pop(
                MarkIncomePaidResult(
                  amountMinor: amountMinor,
                  transactedAt: _transactedAt,
                ),
              );
            },
            child: const Text('Mark as paid'),
          ),
        ],
      ),
    );
  }
}
