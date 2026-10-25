import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/categories/categories.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/shopping_trip_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/shopping_trip.dart';
import 'package:intellispendiq/domain/services/category_envelope_service.dart';
import 'package:intellispendiq/shopping/cubit/cubit.dart';
import 'package:intellispendiq/shopping/view/shopping_start_page.dart';
import 'package:intellispendiq/shopping/widgets/widgets.dart';

/// The Shopping Day Assistant. With no trip open it is the start
/// screen; with one open it is the live cart; after checkout it is the
/// result.
class ShoppingPage extends StatelessWidget {
  const ShoppingPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const ShoppingPage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ShoppingTripCubit(
        trips: context.read<ShoppingTripRepository>(),
        categories: context.read<CategoryRepository>(),
        budgetPeriods: context.read<BudgetPeriodRepository>(),
        envelopes: context.read<CategoryEnvelopeService>(),
        accounts: context.read<AccountRepository>(),
      )..loadUnawaited(),
      child: const ShoppingView(),
    );
  }
}

class ShoppingView extends StatelessWidget {
  const ShoppingView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShoppingTripCubit, ShoppingTripState>(
      buildWhen: (previous, current) => previous.status != current.status,
      builder: (context, state) {
        return switch (state.status) {
          ShoppingTripViewStatus.initial => Scaffold(
            appBar: AppBar(title: const Text('Shopping')),
            body: const Center(child: CircularProgressIndicator()),
          ),
          ShoppingTripViewStatus.none => const ShoppingStartView(),
          ShoppingTripViewStatus.active ||
          ShoppingTripViewStatus.checkingOut => const _TripBody(),
          ShoppingTripViewStatus.done => const _DoneBody(),
        };
      },
    );
  }
}

class _TripBody extends StatelessWidget {
  const _TripBody();

  Future<void> _afford(BuildContext context) {
    final cubit = context.read<ShoppingTripCubit>();
    return AppSheet.show<void>(
      context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const AffordSheet(),
      ),
    );
  }

  Future<void> _checkout(BuildContext context) async {
    final cubit = context.read<ShoppingTripCubit>();
    final accountId = await AppSheet.show<String>(
      context,
      builder: (_) => CheckoutSheet(state: cubit.state),
    );
    if (accountId == null) return;
    await cubit.checkout(accountId);
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final cubit = context.read<ShoppingTripCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this trip?'),
        content: const Text(
          'Nothing is recorded. Your planned items stay exactly as they '
          'were.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep shopping'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel trip'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await cubit.cancelTrip();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping trip'),
        actions: [
          PopupMenuButton<String>(
            icon: const AppIcon(AppIcons.more),
            onSelected: (value) {
              if (value == 'cancel') unawaited(_confirmCancel(context));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'cancel', child: Text('Cancel trip')),
            ],
          ),
        ],
      ),
      body: BlocBuilder<ShoppingTripCubit, ShoppingTripState>(
        builder: (context, state) {
          final cubit = context.read<ShoppingTripCubit>();
          return Column(
            children: [
              Expanded(child: _TripList(state: state)),
              const TripAlertBanner(),
              AddItemBar(
                categoriesById: state.categoriesById,
                onAdd: cubit.addImpulse,
                onPickCategory: (selectedId) => pickShoppingCategory(
                  context,
                  categories: state.categoriesById.values,
                  selectedId: selectedId,
                  onAddCategory: () async {
                    await Navigator.of(context).push<void>(
                      CategoriesPage.route(),
                    );
                    await cubit.refreshCategories();
                  },
                ),
              ),
              _BottomActions(
                state: state,
                onAfford: () => _afford(context),
                onCheckout: () => _checkout(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  const _TripList({required this.state});

  final ShoppingTripState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShoppingTripCubit>();
    final toBuy = state.toBuy;
    final inCart = state.inCart;

    Future<void> remove(
      Future<Future<void> Function()> action,
      String message,
    ) async {
      final undo = await action;
      if (!context.mounted) return;
      showUndoSnackBar(context, message: message, onUndo: undo);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.x2),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.x1,
            Space.gutter,
            0,
          ),
          child: TripHeroCard(
            summary: state.summary,
            categoryName: state.categoryName,
          ),
        ),
        if (state.summary.lines.isNotEmpty) ...[
          const SizedBox(height: Space.x2),
          Padding(
            padding: const EdgeInsets.only(left: Space.gutter),
            child: CategoryStrip(
              lines: state.summary.lines,
              categoriesById: state.categoriesById,
              selectedKey: state.categoryFilter,
              onSelected: cubit.filterChanged,
            ),
          ),
        ],
        if (toBuy.isNotEmpty) ...[
          const SizedBox(height: Space.x1),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.gutter),
            child: SectionHeader(title: 'To buy'),
          ),
          for (final item in toBuy)
            ToBuyTile(
              item: item,
              category: item.categoryId == null
                  ? null
                  : state.categoriesById[item.categoryId],
              onToggle: () => cubit.toggleInCart(item),
              onEdit: () => _edit(context, item),
              onRemove: () => remove(
                cubit.removeFromTrip(item),
                '${item.name} dropped from the trip',
              ),
            ),
        ],
        const SizedBox(height: Space.x1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: SectionHeader(
            title: 'In your cart',
            subtitle: inCart.isEmpty
                ? 'Tap an item above, or add something below'
                : null,
          ),
        ),
        for (final item in inCart)
          CartTile(
            item: item,
            category: item.categoryId == null
                ? null
                : state.categoriesById[item.categoryId],
            onPriceSubmitted: (raw) => cubit.setPrice(item, raw),
            onQuantityChanged: (q) => cubit.setQuantity(item, q),
            onEdit: () => _edit(context, item),
            onRemove: () => remove(
              cubit.removeFromCart(item),
              item.isImpulse ? '${item.name} removed' : '${item.name} put back',
            ),
          ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, ShoppingTripItem item) {
    final cubit = context.read<ShoppingTripCubit>();
    return AppSheet.show<void>(
      context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _EditItemSheet(item: item),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.state,
    required this.onAfford,
    required this.onCheckout,
  });

  final ShoppingTripState state;
  final VoidCallback onAfford;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final busy = state.status == ShoppingTripViewStatus.checkingOut;

    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.x1,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onAfford,
                  child: const Text('Can I afford…'),
                ),
              ),
              const SizedBox(width: Space.x1),
              Expanded(
                child: FilledButton(
                  onPressed: state.cartCount == 0 || busy ? null : onCheckout,
                  child: Text(
                    state.cartCount == 0
                        ? 'Check out'
                        : 'Check out ${Money.display(state.summary.cartTotalMinor)}',
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

/// Everything about one line in one place: name, price, quantity and
/// category, plus dropping it from the trip.
class _EditItemSheet extends StatefulWidget {
  const _EditItemSheet({required this.item});

  final ShoppingTripItem item;

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late int _quantity;
  late String? _categoryId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item.name);
    _price = TextEditingController(
      text: item.unitPriceMinor > 0
          ? (item.unitPriceMinor / 100).toStringAsFixed(2)
          : '',
    );
    _quantity = item.quantity;
    _categoryId = item.categoryId;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cubit = context.read<ShoppingTripCubit>();
    final item = widget.item;
    final error = await cubit.setPrice(item, _price.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    await cubit.setName(item, _name.text);
    await cubit.setQuantity(item, _quantity);
    await cubit.setCategory(item, _categoryId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShoppingTripCubit>();
    final state = cubit.state;
    final colors = Theme.of(context).colorScheme;
    final category = _categoryId == null
        ? null
        : state.categoriesById[_categoryId];

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Edit item'),
          AppTextField(
            controller: _name,
            label: 'Name',
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: Space.x2),
          AmountField(
            controller: _price,
            label: 'Price each',
            errorText: _error,
            autofocus: widget.item.unitPriceMinor <= 0,
          ),
          const SizedBox(height: Space.x1),
          Row(
            children: [
              Text(
                'Quantity',
                style: AppTypography.rowTitle(color: colors.onSurface),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'One fewer',
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Text(
                '$_quantity',
                style: AppTypography.rowAmount(color: colors.onSurface),
              ),
              IconButton(
                tooltip: 'One more',
                onPressed: () => setState(() => _quantity++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: CategoryChipButton(
              category: category,
              placeholder: 'Pick a category',
              onTap: () async {
                final picked = await pickShoppingCategory(
                  context,
                  categories: state.categoriesById.values,
                  selectedId: _categoryId,
                );
                if (picked == null) return;
                setState(() => _categoryId = picked.categoryId);
              },
            ),
          ),
          const SizedBox(height: Space.x2),
          AppButton.primary(label: 'Save', onPressed: _save),
          const SizedBox(height: Space.x1),
          AppButton.tertiary(
            label: 'Remove from trip',
            onPressed: () async {
              final item = widget.item;
              final undo = await cubit.removeFromTrip(item);
              if (!context.mounted) return;
              Navigator.of(context).pop();
              showUndoSnackBar(
                context,
                message: '${item.name} dropped from the trip',
                onUndo: undo,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// After checkout: what was written, and anything that could not be.
class _DoneBody extends StatelessWidget {
  const _DoneBody();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = context.read<ShoppingTripCubit>().state;
    final result = state.result!;
    final impulsePercent = result.totalMinor == 0
        ? 0
        : (result.impulseMinor / result.totalMinor * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip done'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.gutter),
        children: [
          HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SPENT TODAY',
                  style: AppTypography.chipOverline(
                    color: AppColors.nightText2,
                  ),
                ),
                const SizedBox(height: Space.x1),
                MoneyText(
                  result.totalMinor,
                  size: MoneySize.display,
                  color: AppColors.nightText,
                ),
                const SizedBox(height: Space.x1),
                Text(
                  result.impulseMinor == 0
                      ? 'Nothing unplanned. Everything was on your list.'
                      : '${Money.display(result.impulseMinor)} was impulse '
                            '($impulsePercent% of the trip)',
                  style: AppTypography.metadata(color: AppColors.nightText2),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.x2),
          Text(
            '${result.flipped.length} planned '
            '${result.flipped.length == 1 ? 'expense' : 'expenses'} marked '
            'as paid, ${result.created.length} new '
            '${result.created.length == 1 ? 'expense' : 'expenses'} recorded.',
            style: AppTypography.body(color: colors.onSurface),
          ),
          if (result.skipped.isNotEmpty) ...[
            const SizedBox(height: Space.x2),
            const SectionHeader(
              title: 'Not recorded',
              subtitle: 'These could not be written, so nothing was changed',
            ),
            for (final skipped in result.skipped)
              AppListRow(
                title: Text(skipped.item.name),
                subtitle: Text(switch (skipped.reason) {
                  SkipReason.changedElsewhere =>
                    'Changed or paid somewhere else during the trip',
                  SkipReason.wishlistGone =>
                    'Deleted or already bought on your wishlist',
                  SkipReason.noPrice => 'No price was entered',
                }),
              ),
          ],
          const SizedBox(height: Space.x3),
          AppButton.primary(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
