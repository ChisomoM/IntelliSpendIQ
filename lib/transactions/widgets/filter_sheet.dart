import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/transactions/cubit/cubit.dart';
import 'package:intl/intl.dart';

/// Category, account, and date-range filters for the Activity list.
/// Search text has its own always-visible field above the list —
/// this sheet is for the filters that need more room.
class TransactionFilterSheet extends StatelessWidget {
  const TransactionFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<TransactionsCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const TransactionFilterSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy');

    return BlocBuilder<TransactionsCubit, TransactionsState>(
      builder: (context, state) {
        final cubit = context.read<TransactionsCubit>();

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filter',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (state.hasFilters)
                    TextButton(
                      onPressed: cubit.clearFilters,
                      child: const Text('Clear all'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range_outlined),
                title: const Text('Date range'),
                subtitle: Text(
                  state.dateFrom == null || state.dateTo == null
                      ? 'Any time'
                      : '${dateFormat.format(state.dateFrom!)} – '
                            '${dateFormat.format(state.dateTo!)}',
                ),
                trailing: state.dateFrom == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: cubit.dateRangeChanged,
                      ),
                onTap: () => _pickDateRange(context, cubit, state),
              ),
            ],
          ),
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
