import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/data/repositories/transfer_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/transactions/cubit/activity_entry.dart';
import 'package:intellispendiq/transactions/cubit/cubit.dart';
import 'package:intellispendiq/transactions/view/transaction_entry_page.dart';
import 'package:intellispendiq/transactions/widgets/widgets.dart';
import 'package:intl/intl.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TransactionsCubit(
        transactions: context.read<TransactionRepository>(),
        categories: context.read<CategoryRepository>(),
        accounts: context.read<AccountRepository>(),
        transfers: context.read<TransferRepository>(),
      )..subscribeUnawaited(),
      child: const TransactionsView(),
    );
  }
}

class TransactionsView extends StatefulWidget {
  const TransactionsView({super.key});

  @override
  State<TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<TransactionsView> {
  late final TextEditingController _searchController;

  /// Search is collapsed by default. It used to be permanently mounted,
  /// costing ~72dp above the fold on a screen whose whole job is the
  /// list beneath it.
  bool _searchOpen = false;

  /// Clears the bottom nav bar and the docked FAB.
  static const _bottomInset = 96.0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<TransactionsCubit>().state.query,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (!_searchOpen) {
      _searchController.clear();
      context.read<TransactionsCubit>().queryChanged('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransactionsCubit>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            icon: AppIcon(_searchOpen ? AppIcons.close : AppIcons.search),
            tooltip: _searchOpen ? 'Close search' : 'Search',
            onPressed: _toggleSearch,
          ),
          BlocBuilder<TransactionsCubit, TransactionsState>(
            buildWhen: (previous, current) =>
                previous.hasSheetFilters != current.hasSheetFilters,
            builder: (context, state) {
              return IconButton(
                icon: Badge(
                  isLabelVisible: state.hasSheetFilters,
                  child: AppIcon(AppIcons.filter),
                ),
                tooltip: 'Filter',
                onPressed: () => TransactionFilterSheet.show(context),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                0,
                Space.gutter,
                Space.x1,
              ),
              child: BlocBuilder<TransactionsCubit, TransactionsState>(
                buildWhen: (previous, current) =>
                    previous.query != current.query,
                builder: (context, state) {
                  if (_searchController.text != state.query) {
                    _searchController.text = state.query;
                  }
                  return AppTextField(
                    controller: _searchController,
                    hint: 'Search merchant or note',
                    autofocus: true,
                    prefixIcon: AppIcon(AppIcons.search, size: 20),
                    onChanged: cubit.queryChanged,
                  );
                },
              ),
            ),
          const _DirectionFilterRow(),
          Expanded(
            child: BlocBuilder<TransactionsCubit, TransactionsState>(
              builder: (context, state) {
                if (state.status == TransactionsStatus.initial) {
                  return const Padding(
                    padding: EdgeInsets.all(Space.gutter),
                    child: LoadingSkeletonList(rowCount: 6),
                  );
                }
                if (state.isEmpty && !state.hasFilters) {
                  return NoTransactionsYet(
                    onAddTransaction: () => Navigator.of(
                      context,
                    ).push<void>(TransactionEntryPage.route()),
                  );
                }
                if (state.isEmpty) {
                  return EmptyState(
                    icon: AppIcons.search,
                    title: 'Nothing matches',
                    message: 'Try a different search, or clear the filters.',
                    actionLabel: 'Clear filters',
                    onAction: cubit.clearFilters,
                  );
                }

                final groups = state.dayGroups;
                final categoriesById = state.categoriesById;
                final accountNames = {
                  for (final account in state.accounts)
                    account.id: account.name,
                };

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: _bottomInset),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DayHeader(group: group),
                        for (final entry in group.entries)
                          _entryRow(
                            context,
                            entry,
                            categoriesById: categoriesById,
                            accountNames: accountNames,
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryRow(
    BuildContext context,
    ActivityEntry entry, {
    required Map<String, Category> categoriesById,
    required Map<String, String> accountNames,
  }) {
    return switch (entry) {
      TransactionEntry(:final transaction) => Dismissible(
        key: ValueKey(transaction.id),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Theme.of(context).colorScheme.errorContainer,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: Space.x3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppIcon(
                AppIcons.delete,
                size: 20,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: Space.x1),
              // Colour alone never carries a destructive action.
              Text(
                'Delete',
                style: AppTypography.rowTitle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
        confirmDismiss: (_) => _confirmDelete(context, transaction),
        onDismissed: (_) =>
            context.read<TransactionsCubit>().delete(transaction.id),
        child: TransactionTile(
          transaction: transaction,
          category: categoriesById[transaction.categoryId],
        ),
      ),
      TransferEntry(:final transfer) => TransferTile(
        key: ValueKey(transfer.id),
        transfer: transfer,
        fromAccountName: accountNames[transfer.fromAccountId] ?? 'Unknown',
        toAccountName: accountNames[transfer.toAccountId] ?? 'Unknown',
      ),
    };
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    Transaction transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text(
          transaction.merchant?.isNotEmpty ?? false
              ? 'This removes the entry for "${transaction.merchant}". '
                    'This cannot be undone.'
              : 'This removes the entry. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

/// All / Money in / Money out. Visible rather than buried in the sheet,
/// because it is the filter people reach for most and its state is
/// legible at a glance this way.
class _DirectionFilterRow extends StatelessWidget {
  const _DirectionFilterRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionsCubit, TransactionsState>(
      buildWhen: (previous, current) =>
          previous.direction != current.direction,
      builder: (context, state) {
        final cubit = context.read<TransactionsCubit>();

        return SizedBox(
          height: Space.x6,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: state.direction == null,
                onSelected: (_) => cubit.directionFilterChanged(null),
              ),
              const SizedBox(width: Space.x1),
              ChoiceChip(
                label: const Text('Money in'),
                selected: state.direction == TxDirection.credit,
                onSelected: (selected) => cubit.directionFilterChanged(
                  selected ? TxDirection.credit : null,
                ),
              ),
              const SizedBox(width: Space.x1),
              ChoiceChip(
                label: const Text('Money out'),
                selected: state.direction == TxDirection.debit,
                onSelected: (selected) => cubit.directionFilterChanged(
                  selected ? TxDirection.debit : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Day label on the left, the day's net movement on the right.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.group});

  final ActivityDayGroup group;

  static final _dayFormat = DateFormat('EEEE, d MMM');
  static final _dayWithYearFormat = DateFormat('d MMM yyyy');

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(group.day).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (group.day.year != now.year) {
      return _dayWithYearFormat.format(group.day);
    }
    return _dayFormat.format(group.day);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.x2,
        Space.gutter,
        Space.x1,
      ),
      child: Row(
        children: [
          Expanded(
            // Metadata rather than the 11px chip style: that one is
            // reserved for tracked uppercase overlines, and a day
            // label reads as a phrase.
            child: Text(
              _label,
              style: AppTypography.metadata(
                color: colors.onSurfaceVariant,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (group.netMinor != 0)
            MoneyText.signed(
              group.netMinor.abs(),
              isInflow: group.netMinor > 0,
              size: MoneySize.meta,
            ),
        ],
      ),
    );
  }
}
