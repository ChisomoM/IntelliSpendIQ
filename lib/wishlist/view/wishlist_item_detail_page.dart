import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/account_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/data/repositories/wishlist_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/wishlist_item.dart';
import 'package:intellispendiq/wishlist/cubit/cubit.dart';
import 'package:intellispendiq/wishlist/widgets/widgets.dart';

class WishlistItemDetailPage extends StatelessWidget {
  const WishlistItemDetailPage({required this.itemId, super.key});

  final String itemId;

  static Route<void> route({required String itemId}) {
    return MaterialPageRoute<void>(
      builder: (_) => WishlistItemDetailPage(itemId: itemId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WishlistItemDetailCubit(
        wishlist: context.read<WishlistRepository>(),
        accounts: context.read<AccountRepository>(),
        categories: context.read<CategoryRepository>(),
        itemId: itemId,
      )..loadUnawaited(),
      child: const WishlistItemDetailView(),
    );
  }
}

class WishlistItemDetailView extends StatelessWidget {
  const WishlistItemDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WishlistItemDetailCubit, WishlistItemDetailState>(
      builder: (context, state) {
        if (state.status == WishlistItemDetailStatus.notFound) {
          return const Scaffold(body: Center(child: Text('Item not found')));
        }
        final item = state.item;
        if (item == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final colors = Theme.of(context).colorScheme;
        final cubit = context.read<WishlistItemDetailCubit>();

        return Scaffold(
          appBar: AppBar(
            title: Text(item.name),
            actions: [
              IconButton(
                icon: AppIcon(AppIcons.delete, size: 20),
                tooltip: 'Remove',
                onPressed: () => _confirmDelete(context),
              ),
              const SizedBox(width: Space.x1),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x1,
              Space.gutter,
              Space.x4,
            ),
            children: [
              WishlistPhotoStrip(
                photos: state.photos,
                onAdd: cubit.addPhoto,
                onRemove: cubit.removePhoto,
              ),
              const SizedBox(height: Space.sectionGap),
              if (item.estimatedPriceMinor != null)
                _InfoRow(
                  label: item.status == WishlistItemStatus.purchased
                      ? 'Estimated price'
                      : 'Estimated price',
                  value: Money.display(item.estimatedPriceMinor!),
                ),
              if (item.actualPriceMinor != null)
                _InfoRow(
                  label: 'Paid',
                  value: Money.display(item.actualPriceMinor!),
                ),
              if (item.seenAt != null && item.seenAt!.isNotEmpty)
                _InfoRow(label: 'Where you saw it', value: item.seenAt!),
              if (item.productUrl != null && item.productUrl!.isNotEmpty)
                _InfoRow(label: 'Link', value: item.productUrl!),
              if (item.note != null && item.note!.isNotEmpty)
                _InfoRow(label: 'Notes', value: item.note!),
              const SizedBox(height: Space.sectionGap),
              if (item.status != WishlistItemStatus.purchased) ...[
                if (item.status == WishlistItemStatus.idea)
                  AppButton.primary(
                    label: 'Turn into a savings goal',
                    onPressed: () => ConvertToGoalSheet.show(context),
                  ),
                const SizedBox(height: Space.x1),
                AppButton.secondary(
                  label: 'I bought it',
                  onPressed: () => ConvertToExpenseSheet.show(context),
                ),
              ] else
                Text(
                  'Purchased',
                  style: AppTypography.sectionHeader(color: colors.onSurface),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<WishlistItemDetailCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from wishlist?'),
        content: const Text(
          'Its photos will be deleted. A linked savings goal, if any, is '
          'left untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      final navigator = Navigator.of(context);
      await cubit.delete();
      navigator.pop();
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.chipOverline(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(value, style: AppTypography.body(color: colors.onSurface)),
        ],
      ),
    );
  }
}
