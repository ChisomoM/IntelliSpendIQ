import 'package:flutter/material.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/account.dart';
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
    required this.receivedByCategory,
    required this.actualMinor,
    required this.provisionalMinor,
    required this.onTapRow,
    required this.onRemoveFromCycle,
    this.periodId,
    super.key,
  });

  /// Top-level income categories, including those without a plan yet.
  final List<Category> incomeCategories;

  /// Paid/unpaid status per category id. Absent means nothing planned and
  /// nothing received yet for this category this period.
  final Map<String, IncomeStatus> statusByCategory;

  /// Money that has arrived this period per category id (including its
  /// sub categories), from the transactions.
  final Map<String, int> receivedByCategory;

  final int actualMinor;
  final int provisionalMinor;

  /// Called when a row (with a planned amount) is tapped, to toggle its
  /// paid/unpaid state.
  final void Function(Category category, IncomeStatus? current) onTapRow;

  /// Called when the user asks to remove a row's amount from this cycle
  /// only.
  final void Function(Category category, IncomeStatus? current)
  onRemoveFromCycle;

  /// Budget period to write planned amounts into when editing.
  final String? periodId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final money = Theme.of(context).extension<MoneyColors>()!;
    final planned = incomeCategories.where((c) => c.hasBudget).toList();
    final hasAny = planned.isNotEmpty || actualMinor > 0;

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
                receivedMinor: receivedByCategory[category.id] ?? 0,
                onTap: () => onTapRow(category, statusByCategory[category.id]),
                onRemove: () =>
                    onRemoveFromCycle(category, statusByCategory[category.id]),
              ),
            if (hasAny) ...[
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
    required this.onRemove,
    this.receivedMinor = 0,
    this.periodId,
    this.status,
  });

  final Category category;
  final String? periodId;
  final IncomeStatus? status;

  /// Money that has arrived for this source this period.
  final int receivedMinor;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPaid = status == IncomeStatus.paid;
    final hasPlan = category.hasBudget;
    final hasReceived = receivedMinor > 0;

    final String? subtitle;
    if (isPaid) {
      subtitle = hasPlan ? 'Paid' : 'Received';
    } else if (hasReceived) {
      subtitle = 'Part paid · ${Money.display(receivedMinor)} received';
    } else {
      subtitle = hasPlan ? 'Unpaid' : null;
    }

    return AppListRow(
      leading: CategoryAvatar(
        iconKey: category.icon,
        categoryId: category.id,
        colorName: category.color,
        size: 36,
      ),
      title: Text(category.name),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: AppTypography.metadata(
                color: isPaid ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPlan)
            MoneyText(category.budgetedAmountMinor!, size: MoneySize.meta)
          else if (hasReceived)
            MoneyText(receivedMinor, size: MoneySize.meta)
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
      // Money still to come: tapping records it. Once the source has been
      // received in full there is nothing to tick off, so tapping offers
      // the other things you can do with it instead. A source with no
      // amount and nothing received opens the editor to set one first.
      onTap: isPaid
          ? () => _showActions(context)
          : (hasPlan || hasReceived)
          ? onTap
          : () => _edit(context),
      // A source with an amount or money received offers its actions; one
      // with neither goes straight to the editor, as before.
      onLongPress: (hasPlan || hasReceived)
          ? () => _showActions(context)
          : () => _edit(context),
    );
  }

  void _edit(BuildContext context) {
    Navigator.of(context).push<String?>(
      CategoryEditorPage.route(existing: category, periodId: periodId),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final choice = await showModalBottomSheet<_IncomeAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(category.name),
              subtitle: const Text('This cycle'),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: Text(
                status == IncomeStatus.paid
                    ? 'Record more money received'
                    : 'Record money received',
              ),
              onTap: () => Navigator.of(sheetContext).pop(_IncomeAction.record),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit income source'),
              onTap: () => Navigator.of(sheetContext).pop(_IncomeAction.edit),
            ),
            if (category.hasBudget)
              ListTile(
                leading: Icon(
                  Icons.remove_circle_outline,
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
                title: const Text('Remove planned amount from this cycle'),
                subtitle: const Text('Other cycles are not affected'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_IncomeAction.remove),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case _IncomeAction.record:
        onTap();
      case _IncomeAction.edit:
        _edit(context);
      case _IncomeAction.remove:
        onRemove();
      case null:
        break;
    }
  }
}

enum _IncomeAction { record, edit, remove }

/// What the user decided when removing an income source from a cycle.
class RemoveIncomeResult {
  const RemoveIncomeResult({required this.deleteReceivedTransaction});

  /// Only ever true for a source that had been marked paid.
  final bool deleteReceivedTransaction;
}

/// Confirms removing [category] from the cycle being viewed. For a source
/// that was marked paid, also asks whether to delete the money-received
/// transaction that marking it paid created; it is kept unless the user
/// turns that on. Returns null if the user cancels.
Future<RemoveIncomeResult?> showRemoveIncomeDialog(
  BuildContext context, {
  required Category category,
  required int amountMinor,
  required bool isPaid,
}) {
  var deleteReceived = false;
  return showDialog<RemoveIncomeResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Remove from this cycle?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This takes the planned ${Money.display(amountMinor)} for '
              '"${category.name}" out of this cycle only. The income source '
              'and your other cycles are not changed.',
            ),
            if (isPaid) ...[
              const SizedBox(height: Space.x2),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Also delete the money received'),
                subtitle: const Text(
                  'Removes the transaction recorded when you marked it paid. '
                  'Left off, it stays in your activity, your account '
                  "balance and this cycle's income.",
                ),
                value: deleteReceived,
                onChanged: (value) => setState(() => deleteReceived = value),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              RemoveIncomeResult(deleteReceivedTransaction: deleteReceived),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    ),
  );
}

/// Amount + date + account picked when marking an income envelope paid
/// — the amount may differ from the envelope's planned figure (e.g.
/// only part came in), and the account is wherever it actually landed.
class MarkIncomePaidResult {
  const MarkIncomePaidResult({
    required this.amountMinor,
    required this.transactedAt,
    required this.accountId,
  });

  final int amountMinor;
  final DateTime transactedAt;
  final String accountId;
}

/// Confirms (and lets the user adjust) the amount/date/account before
/// marking an income category paid. Returns null if the user cancels.
Future<MarkIncomePaidResult?> showMarkIncomePaidSheet(
  BuildContext context, {
  required Category category,
  required List<Account> accounts,
  required String defaultAccountId,
  int? suggestedAmountMinor,
}) {
  return showModalBottomSheet<MarkIncomePaidResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _MarkIncomePaidSheet(
      category: category,
      accounts: accounts,
      defaultAccountId: defaultAccountId,
      suggestedAmountMinor: suggestedAmountMinor,
    ),
  );
}

class _MarkIncomePaidSheet extends StatefulWidget {
  const _MarkIncomePaidSheet({
    required this.category,
    required this.accounts,
    required this.defaultAccountId,
    this.suggestedAmountMinor,
  });

  final Category category;
  final List<Account> accounts;
  final String defaultAccountId;

  /// What to fill in first, such as what is still to come; the planned
  /// amount when null.
  final int? suggestedAmountMinor;

  @override
  State<_MarkIncomePaidSheet> createState() => _MarkIncomePaidSheetState();
}

class _MarkIncomePaidSheetState extends State<_MarkIncomePaidSheet> {
  late final TextEditingController _amountController;
  DateTime _transactedAt = DateTime.now();
  late String _accountId;

  @override
  void initState() {
    super.initState();
    final suggested =
        widget.suggestedAmountMinor ?? widget.category.budgetedAmountMinor;
    _amountController = TextEditingController(
      text: suggested == null ? '' : Money.display(suggested),
    );
    _accountId = widget.defaultAccountId;
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
          DropdownButtonFormField<String>(
            initialValue: _accountId,
            decoration: const InputDecoration(labelText: 'Received into'),
            items: [
              for (final account in widget.accounts)
                DropdownMenuItem(value: account.id, child: Text(account.name)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _accountId = value);
            },
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
                  accountId: _accountId,
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
