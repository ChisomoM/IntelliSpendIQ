import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/transactions/cubit/cubit.dart';
import 'package:intl/intl.dart';

/// Category, account, and date-range filters for the Activity list.
/// Search and money in/out have their own controls above the list —
/// this sheet is for the filters that need more room.
class TransactionFilterSheet extends StatelessWidget {
  const TransactionFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<TransactionsCubit>();
    return AppSheet.show<void>(
      context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const TransactionFilterSheet(),
      ),
    );
  }

  static final _dateFormat = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionsCubit, TransactionsState>(
      builder: (context, state) {
        final cubit = context.read<TransactionsCubit>();
        final colors = Theme.of(context).colorScheme;
        final hasRange = state.dateFrom != null && state.dateTo != null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Filter', style: AppTypography.sectionHeader()),
                ),
                if (state.hasFilters)
                  TextButton(
                    onPressed: () {
                      cubit.clearFilters();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Clear all'),
                  ),
              ],
            ),
            const SizedBox(height: Space.x2),
            DropdownButtonFormField<String>(
              initialValue: state.categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(child: Text('All categories')),
                for (final category in state.categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.displayName),
                  ),
              ],
              onChanged: cubit.categoryFilterChanged,
            ),
            const SizedBox(height: Space.x2),
            DropdownButtonFormField<String>(
              initialValue: state.accountId,
              decoration: const InputDecoration(labelText: 'Account'),
              items: [
                const DropdownMenuItem(child: Text('All accounts')),
                for (final account in state.accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  ),
              ],
              onChanged: cubit.accountFilterChanged,
            ),
            const SizedBox(height: Space.x2),
            AppListRow(
              leading: AppIcon(AppIcons.calendar),
              title: const Text('Date range'),
              subtitle: Text(
                hasRange
                    ? '${_dateFormat.format(state.dateFrom!)} – '
                          '${_dateFormat.format(state.dateTo!)}'
                    : 'Any time',
              ),
              trailing: hasRange
                  ? IconButton(
                      icon: AppIcon(AppIcons.close, size: 20),
                      tooltip: 'Clear date range',
                      onPressed: cubit.dateRangeChanged,
                    )
                  : AppIcon(
                      AppIcons.chevronRight,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
              onTap: () => _pickDateRange(context, cubit, state),
            ),
            const SizedBox(height: Space.x2),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickDateRange(
    BuildContext context,
    TransactionsCubit cubit,
    TransactionsState state,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: state.dateFrom == null || state.dateTo == null
          ? null
          : DateTimeRange(start: state.dateFrom!, end: state.dateTo!),
    );
    if (picked == null) return;
    cubit.dateRangeChanged(from: picked.start, to: picked.end);
  }
}
