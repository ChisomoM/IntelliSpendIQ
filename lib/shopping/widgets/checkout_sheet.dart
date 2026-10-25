import 'package:flutter/material.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/account.dart';
import 'package:intellispendiq/domain/models/shopping_trip.dart';
import 'package:intellispendiq/shopping/cubit/cubit.dart';

/// The last look before the cart becomes real expenses. Pops with the
/// chosen account's id when confirmed.
class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({required this.state, super.key});

  final ShoppingTripState state;

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  String? _accountId;

  @override
  void initState() {
    super.initState();
    final accounts = widget.state.accounts;
    if (accounts.isNotEmpty) {
      _accountId =
          (accounts.where((a) => a.isDefault).firstOrNull ?? accounts.first).id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = widget.state;
    final cart = state.items.where((i) => i.inCart).toList();
    final planned = cart.where((i) => i.kind == ShoppingItemKind.planned);
    final created = cart.where((i) => i.kind != ShoppingItemKind.planned);
    final staying = state.items.where((i) => i.isPlanned && !i.inCart);
    final summary = state.summary;
    final needsAccount = created.isNotEmpty;

    final over = summary.overLines;
    final overText = over.isEmpty
        ? null
        : over
              .map(
                (l) =>
                    '${state.categoryName(l.categoryId)} by '
                    '${Money.display(l.overByMinor)}',
              )
              .join(', ');

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Check out'),
          Row(
            children: [
              Text(
                Money.display(summary.cartTotalMinor),
                style: AppTypography.sectionHeader(color: colors.onSurface),
              ),
              const SizedBox(width: Space.x1),
              Text(
                '${cart.length} ${cart.length == 1 ? 'item' : 'items'}',
                style: AppTypography.metadata(color: colors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: Space.x2),
          _Line(
            count: planned.length,
            text:
                'planned ${planned.length == 1 ? 'expense' : 'expenses'} '
                'marked as paid',
          ),
          _Line(
            count: created.length,
            text:
                'new ${created.length == 1 ? 'expense' : 'expenses'}'
                '${summary.impulseMinor > 0 ? ' (${Money.display(summary.impulseMinor)} impulse)' : ''}',
          ),
          _Line(
            count: staying.length,
            text:
                'planned ${staying.length == 1 ? 'item stays' : 'items stay'} '
                'planned',
          ),
          if (overText != null) ...[
            const SizedBox(height: Space.x1),
            Text(
              'Over budget in $overText.',
              style: AppTypography.body(
                color: Theme.of(context).extension<MoneyColors>()!.outflow,
              ),
            ),
          ],
          const SizedBox(height: Space.x2),
          if (needsAccount && state.accounts.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Paid from'),
              items: [
                for (final Account a in state.accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (value) => setState(() => _accountId = value),
            )
          else
            Text(
              'Planned expenses keep the account they were planned on.',
              style: AppTypography.metadata(color: colors.onSurfaceVariant),
            ),
          const SizedBox(height: Space.x2),
          AppButton.primary(
            label: 'Confirm and check out',
            onPressed: _accountId == null
                ? null
                : () => Navigator.of(context).pop(_accountId),
          ),
          const SizedBox(height: Space.x1),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.count, required this.text});

  final int count;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$count',
              style: AppTypography.rowAmount(color: colors.onSurface),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
