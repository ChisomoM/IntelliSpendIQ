import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/services/shopping_trip_calculator.dart';
import 'package:intellispendiq/shopping/cubit/cubit.dart';
import 'package:intellispendiq/shopping/widgets/shopping_category_picker.dart';

/// "Can I afford this?" Type a price, pick a category, read the
/// answer. It is plain arithmetic on the trip as it stands, so it
/// works offline and always agrees with the numbers on the page.
class AffordSheet extends StatefulWidget {
  const AffordSheet({super.key});

  @override
  State<AffordSheet> createState() => _AffordSheetState();
}

class _AffordSheetState extends State<AffordSheet> {
  final _price = TextEditingController();
  int _quantity = 1;
  String? _categoryId;
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickCategory(ShoppingTripState state) async {
    final picked = await pickShoppingCategory(
      context,
      categories: state.categoriesById.values,
      selectedId: _categoryId,
    );
    if (picked == null || !mounted) return;
    setState(() => _categoryId = picked.categoryId);
  }

  Future<void> _addToCart() async {
    final error = await context.read<ShoppingTripCubit>().addImpulse(
      name: '',
      price: _price.text,
      quantity: _quantity,
      categoryId: _categoryId,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cubit = context.read<ShoppingTripCubit>();

    return BlocBuilder<ShoppingTripCubit, ShoppingTripState>(
      builder: (context, state) {
        final answer = cubit.canAfford(
          price: _price.text,
          quantity: _quantity,
          categoryId: _categoryId,
        );
        final category = _categoryId == null
            ? null
            : state.categoriesById[_categoryId];
        final listLines = state.summary.lines
            .where((l) => l.onList && l.hasBudget)
            .toList();

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(title: 'Can I afford this?'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _price,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                      ],
                      onChanged: (_) => setState(() => _error = null),
                      decoration: InputDecoration(
                        labelText: 'Price each',
                        prefixText: 'K ',
                        errorText: _error,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.x1),
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
              const SizedBox(height: Space.x1),
              Align(
                alignment: Alignment.centerLeft,
                child: CategoryChipButton(
                  category: category,
                  placeholder: 'Pick a category',
                  onTap: () => _pickCategory(state),
                ),
              ),
              const SizedBox(height: Space.x2),
              if (answer == null)
                Text(
                  'Enter a price to check it against your budget.',
                  style: AppTypography.body(color: colors.onSurfaceVariant),
                )
              else
                _AnswerCard(
                  answer: answer,
                  categoryName: state.categoryName(answer.categoryId),
                  hasCategory: _categoryId != null,
                  cartTotalMinor: state.summary.cartTotalMinor,
                ),
              const SizedBox(height: Space.x2),
              if (answer != null)
                AppButton.primary(label: 'Add to cart', onPressed: _addToCart),
              if (listLines.isNotEmpty) ...[
                const SizedBox(height: Space.x2),
                const SectionHeader(title: 'What can I still afford?'),
                for (final line in listLines)
                  _AffordLine(
                    line: line,
                    category: state.categoriesById[line.categoryId],
                    name: state.categoryName(line.categoryId),
                  ),
              ],
              const SizedBox(height: Space.x1),
            ],
          ),
        );
      },
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.answer,
    required this.categoryName,
    required this.hasCategory,
    required this.cartTotalMinor,
  });

  final AffordAnswer answer;
  final String categoryName;
  final bool hasCategory;
  final int cartTotalMinor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final money = Theme.of(context).extension<MoneyColors>()!;

    final (headline, detail, tone) = switch (answer.verdict) {
      AffordVerdict.yes => (
        'Yes',
        '$categoryName would have '
            '${Money.display(answer.leftAfterMinor!)} left.',
        money.inflow,
      ),
      AffordVerdict.tight => (
        'Yes, but it is tight',
        '$categoryName would have ${Money.display(answer.leftAfterMinor!)} '
            'left, which leaves what you still plan to buy '
            '${Money.display(answer.shortForListMinor)} short.',
        colors.onSurface,
      ),
      AffordVerdict.no => (
        'No',
        'That puts $categoryName ${Money.display(answer.overByMinor)} over '
            'its budget.',
        money.outflow,
      ),
      AffordVerdict.noBudget => (
        hasCategory ? 'No budget to check against' : 'Pick a category',
        hasCategory
            ? '$categoryName has no budget this period, so nothing stops '
                  'this one.'
            : 'Choose a category and I will check it against its budget.',
        colors.onSurface,
      ),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: AppTypography.sectionHeader(color: tone)),
          const SizedBox(height: 4),
          Text(detail, style: AppTypography.body(color: colors.onSurface)),
          const SizedBox(height: Space.x1),
          Text(
            'Your cart would be '
            '${Money.display(cartTotalMinor + answer.totalMinor)}.',
            style: AppTypography.metadata(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _AffordLine extends StatelessWidget {
  const _AffordLine({
    required this.line,
    required this.category,
    required this.name,
  });

  final TripCategoryLine line;
  final Category? category;
  final String name;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      leading: category == null
          ? null
          : CategoryAvatar(
              iconKey: category!.icon,
              categoryId: category!.id,
              colorName: category!.color,
              size: 32,
            ),
      title: Text(name),
      subtitle: Text(
        line.toBuyMinor > 0
            ? '${Money.display(line.toBuyMinor)} still to buy'
            : 'Nothing else planned',
      ),
      trailing: _trailing(context),
    );
  }

  Widget _trailing(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final money = Theme.of(context).extension<MoneyColors>()!;
    if (line.isOver) {
      return Text(
        '${Money.display(line.overByMinor)} over',
        style: AppTypography.rowTitle(color: money.outflow),
      );
    }
    final free = line.freeMinor ?? 0;
    if (free < 0) {
      return Text(
        '${Money.display(-free)} short for list',
        style: AppTypography.rowTitle(color: colors.onSurface),
      );
    }
    return Text(
      '${Money.display(free)} free',
      style: AppTypography.rowTitle(color: colors.onSurface),
    );
  }
}
