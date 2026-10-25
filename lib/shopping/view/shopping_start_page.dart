import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/shopping_trip_repository.dart';
import 'package:intellispendiq/data/repositories/transaction_repository.dart';
import 'package:intellispendiq/data/repositories/wishlist_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/transaction.dart';
import 'package:intellispendiq/domain/models/wishlist_item.dart';
import 'package:intellispendiq/domain/services/category_envelope_service.dart';
import 'package:intellispendiq/domain/services/shopping_trip_calculator.dart';
import 'package:intellispendiq/shopping/cubit/cubit.dart';
import 'package:intellispendiq/shopping/widgets/widgets.dart';

/// "What are you buying today?" The planned expenses due this period
/// and the wishlist, ticked to become a trip.
class ShoppingStartView extends StatelessWidget {
  const ShoppingStartView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ShoppingStartCubit(
        trips: context.read<ShoppingTripRepository>(),
        transactions: context.read<TransactionRepository>(),
        wishlist: context.read<WishlistRepository>(),
        categories: context.read<CategoryRepository>(),
        budgetPeriods: context.read<BudgetPeriodRepository>(),
        envelopes: context.read<CategoryEnvelopeService>(),
      )..loadUnawaited(),
      child: const _StartBody(),
    );
  }
}

class _StartBody extends StatelessWidget {
  const _StartBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start a shopping trip')),
      body: BlocConsumer<ShoppingStartCubit, ShoppingStartState>(
        listenWhen: (previous, current) =>
            current.status == ShoppingStartStatus.failed &&
            previous.status != ShoppingStartStatus.failed,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Something went wrong'),
            ),
          );
        },
        builder: (context, state) {
          if (!state.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.planned.isEmpty && state.wishlist.isEmpty) {
            return const EmptyState(
              icon: AppIcons.cart,
              title: 'Nothing planned yet',
              message:
                  'Record an expense as unpaid, or add something to your '
                  'wishlist, and it will show up here to shop for.',
            );
          }
          return Column(
            children: [
              Expanded(child: _PickList(state: state)),
              _StartBar(state: state),
            ],
          );
        },
      ),
    );
  }
}

class _PickList extends StatelessWidget {
  const _PickList({required this.state});

  final ShoppingStartState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShoppingStartCubit>();
    final groups = state.plannedByCategory;

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.x3),
      children: [
        if (state.planned.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: SectionHeader(
              title: 'Planned',
              subtitle: 'Tick what you are buying today',
              action:
                  state.selectedTransactionIds.length == state.planned.length
                  ? 'Clear'
                  : 'Select all',
              onActionTap: cubit.toggleAll,
            ),
          ),
        for (final entry in groups.entries)
          _CategoryGroup(
            categoryId: entry.key,
            category: entry.key == null
                ? null
                : state.categoriesById[entry.key],
            envelope: entry.key == null ? null : state.envelopes[entry.key],
            transactions: entry.value,
            selected: state.selectedTransactionIds,
          ),
        if (state.wishlist.isNotEmpty) ...[
          const SizedBox(height: Space.x2),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.gutter),
            child: SectionHeader(
              title: 'Wishlist',
              subtitle: 'Things you want, if the price is right',
            ),
          ),
          for (final item in state.wishlist)
            _WishlistRow(
              item: item,
              choice: state.wishlistChoices[item.id],
              categoriesById: state.categoriesById,
            ),
        ],
      ],
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.categoryId,
    required this.category,
    required this.envelope,
    required this.transactions,
    required this.selected,
  });

  final String? categoryId;
  final Category? category;
  final CategoryEnvelope? envelope;
  final List<Transaction> transactions;
  final Set<String> selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cubit = context.read<ShoppingStartCubit>();
    final allTicked = transactions.every((tx) => selected.contains(tx.id));
    final room = envelope?.envelopeMinor == null
        ? null
        : envelope!.envelopeMinor! - envelope!.spentMinor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => cubit.toggleCategory(categoryId),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.gutter,
              vertical: Space.x1,
            ),
            child: Row(
              children: [
                if (category != null)
                  CategoryAvatar(
                    iconKey: category!.icon,
                    categoryId: category!.id,
                    colorName: category!.color,
                    size: 32,
                  )
                else
                  AppIcon(AppIcons.unknown, color: colors.onSurfaceVariant),
                const SizedBox(width: Space.x1 + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category?.displayName ?? 'No category',
                        style: AppTypography.rowTitle(color: colors.onSurface),
                      ),
                      Text(
                        room == null
                            ? 'No budget this period'
                            : room < 0
                            ? '${Money.display(-room)} over already'
                            : '${Money.display(room)} left this period',
                        style: AppTypography.metadata(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  allTicked ? 'Clear' : 'All',
                  style: AppTypography.rowTitle(color: colors.primary),
                ),
              ],
            ),
          ),
        ),
        for (final tx in transactions)
          AppListRow(
            leading: Checkbox(
              value: selected.contains(tx.id),
              onChanged: (_) => cubit.toggleTransaction(tx.id),
            ),
            title: Text(tx.merchant ?? tx.description ?? 'Planned item'),
            trailing: MoneyText(tx.amountMinor),
            onTap: () => cubit.toggleTransaction(tx.id),
          ),
      ],
    );
  }
}

class _WishlistRow extends StatelessWidget {
  const _WishlistRow({
    required this.item,
    required this.choice,
    required this.categoriesById,
  });

  final WishlistItem item;
  final WishlistChoice? choice;
  final Map<String, Category> categoriesById;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShoppingStartCubit>();
    final colors = Theme.of(context).colorScheme;
    final ticked = choice != null;
    final price = choice?.priceMinor ?? item.estimatedPriceMinor;
    final category = choice?.categoryId == null
        ? null
        : categoriesById[choice!.categoryId];

    return Column(
      children: [
        AppListRow(
          leading: Checkbox(
            value: ticked,
            onChanged: (_) => cubit.toggleWishlist(item.id),
          ),
          title: Text(item.name),
          subtitle: item.seenAt == null ? null : Text('Seen at ${item.seenAt}'),
          trailing: price == null
              ? Text(
                  'No price',
                  style: AppTypography.metadata(color: colors.onSurfaceVariant),
                )
              : MoneyText(price),
          onTap: () => cubit.toggleWishlist(item.id),
        ),
        if (ticked)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.x6 + Space.x2,
              0,
              Space.gutter,
              Space.x1,
            ),
            child: Row(
              children: [
                CategoryChipButton(
                  category: category,
                  placeholder: 'Pick a category',
                  onTap: () async {
                    final picked = await pickShoppingCategory(
                      context,
                      categories: categoriesById.values,
                      selectedId: choice?.categoryId,
                    );
                    if (picked == null) return;
                    cubit.setWishlistCategory(item.id, picked.categoryId);
                  },
                ),
                const SizedBox(width: Space.x1),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('wish-price-${item.id}'),
                    initialValue: price == null
                        ? ''
                        : (price / 100).toStringAsFixed(2),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixText: 'K ',
                      hintText: 'Price',
                    ),
                    onChanged: (value) =>
                        cubit.setWishlistPrice(item.id, value),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StartBar extends StatelessWidget {
  const _StartBar({required this.state});

  final ShoppingStartState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final preview = state.preview;
    final hasBudget = preview.lines.any((l) => l.onList && l.hasBudget);
    final planned = preview.toBuyMinor;

    return Material(
      color: colors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Space.gutter),
          child: Row(
            children: [
              Expanded(
                child: state.selectedCount == 0
                    ? Text(
                        'Pick at least one item',
                        style: AppTypography.body(
                          color: colors.onSurfaceVariant,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasBudget
                                ? 'Trip budget ${Money.display(preview.budgetMinor)}'
                                : 'No budget set for these',
                            style: AppTypography.rowTitle(
                              color: colors.onSurface,
                            ),
                          ),
                          Text(
                            '${state.selectedCount} '
                            '${state.selectedCount == 1 ? 'item' : 'items'} · '
                            '${Money.display(planned)} planned',
                            style: AppTypography.metadata(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: Space.x2),
              FilledButton(
                onPressed: state.canStart
                    ? context.read<ShoppingStartCubit>().start
                    : null,
                child: Text(
                  state.status == ShoppingStartStatus.starting
                      ? 'Starting'
                      : 'Start shopping',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
