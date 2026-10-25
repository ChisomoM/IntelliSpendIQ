import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/shopping_trip.dart';

String _editable(int minor) => (minor / 100).toStringAsFixed(2);

Widget _swipeBackground(BuildContext context, String label) {
  final money = Theme.of(context).extension<MoneyColors>()!;
  return Container(
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.symmetric(horizontal: Space.x3),
    color: money.outflow.withValues(alpha: 0.12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.rowTitle(color: money.outflow)),
        const SizedBox(width: Space.x1),
        AppIcon(AppIcons.delete, size: 20, color: money.outflow),
      ],
    ),
  );
}

/// A planned or wishlist line that is still on the shelf. Tapping puts
/// it in the cart; swiping drops it from the trip.
class ToBuyTile extends StatelessWidget {
  const ToBuyTile({
    required this.item,
    required this.category,
    required this.onToggle,
    required this.onEdit,
    required this.onRemove,
    super.key,
  });

  final ShoppingTripItem item;
  final Category? category;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final needsPrice = item.unitPriceMinor <= 0;
    final origin = item.kind == ShoppingItemKind.wishlist
        ? 'Wishlist'
        : 'Planned';

    return Dismissible(
      key: ValueKey('tobuy-${item.id}'),
      direction: DismissDirection.endToStart,
      background: _swipeBackground(context, 'Drop from trip'),
      onDismissed: (_) => onRemove(),
      child: AppListRow(
        leading: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.outline, width: 2),
          ),
        ),
        title: Text(item.name),
        subtitle: Text(
          [
            if (needsPrice)
              'No price yet'
            else
              '$origin ${Money.display(item.unitPriceMinor)}',
            if (item.quantity > 1) 'x${item.quantity}',
            category?.displayName ?? 'No category',
          ].join(' · '),
        ),
        trailing: needsPrice
            ? Text(
                'Add price',
                style: AppTypography.rowTitle(color: colors.primary),
              )
            : MoneyText(item.lineTotalMinor),
        onTap: needsPrice ? onEdit : onToggle,
        onLongPress: onEdit,
      ),
    );
  }
}

/// A line in the cart. The price is editable in place, and the
/// quantity steps up and down without opening anything, because the
/// shelf tag is rarely what the plan said.
class CartTile extends StatelessWidget {
  const CartTile({
    required this.item,
    required this.category,
    required this.onPriceSubmitted,
    required this.onQuantityChanged,
    required this.onEdit,
    required this.onRemove,
    super.key,
  });

  final ShoppingTripItem item;
  final Category? category;

  /// Returns an error message to show against the field, or null.
  final Future<String?> Function(String raw) onPriceSubmitted;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('cart-${item.id}'),
      direction: DismissDirection.endToStart,
      background: _swipeBackground(
        context,
        item.isImpulse ? 'Remove' : 'Put back',
      ),
      onDismissed: (_) => onRemove(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.gutter,
          vertical: Space.x1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onEdit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.rowTitle(
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (item.isImpulse) ...[
                                _ImpulseTag(),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  category?.displayName ?? 'No category',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.metadata(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Space.x1),
                MoneyText(item.lineTotalMinor),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: _InlinePriceField(
                    item: item,
                    onSubmitted: onPriceSubmitted,
                  ),
                ),
                const Spacer(),
                _QuantityStepper(
                  quantity: item.quantity,
                  onChanged: onQuantityChanged,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Divider(height: 1, color: colors.outlineVariant),
          ],
        ),
      ),
    );
  }
}

class _ImpulseTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final review = Theme.of(context).extension<CaptureColors>()!.uncertainField;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: review.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('IMPULSE', style: AppTypography.chipOverline(color: review)),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'One fewer',
          icon: Icon(Icons.remove, color: colors.onSurface),
          onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: AppTypography.rowAmount(color: colors.onSurface),
          ),
        ),
        IconButton(
          tooltip: 'One more',
          icon: Icon(Icons.add, color: colors.onSurface),
          onPressed: () => onChanged(quantity + 1),
        ),
      ],
    );
  }
}

class _InlinePriceField extends StatefulWidget {
  const _InlinePriceField({required this.item, required this.onSubmitted});

  final ShoppingTripItem item;
  final Future<String?> Function(String raw) onSubmitted;

  @override
  State<_InlinePriceField> createState() => _InlinePriceFieldState();
}

class _InlinePriceFieldState extends State<_InlinePriceField> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _editable(widget.item.unitPriceMinor),
    );
    _focus.addListener(() {
      if (!_focus.hasFocus) unawaited(_commit());
    });
  }

  @override
  void didUpdateWidget(_InlinePriceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.unitPriceMinor != widget.item.unitPriceMinor &&
        !_focus.hasFocus) {
      _controller.text = _editable(widget.item.unitPriceMinor);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    final raw = _controller.text;
    if (Money.tryParseToMinor(raw) == widget.item.unitPriceMinor) {
      if (_error != null) setState(() => _error = null);
      return;
    }
    final error = await widget.onSubmitted(raw);
    if (!mounted) return;
    setState(() => _error = error);
    if (error != null) {
      _controller.text = _editable(widget.item.unitPriceMinor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
      onSubmitted: (_) => _commit(),
      onTap: () => _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      ),
      decoration: InputDecoration(
        isDense: true,
        labelText: 'Price each',
        prefixText: 'K ',
        errorText: _error,
      ),
    );
  }
}
