import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/data/repositories/wishlist_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/wishlist/cubit/cubit.dart';
import 'package:intellispendiq/wishlist/view/create_wishlist_item_page.dart';
import 'package:intellispendiq/wishlist/view/wishlist_item_detail_page.dart';
import 'package:intellispendiq/wishlist/widgets/widgets.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const WishlistPage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          WishlistCubit(context.read<WishlistRepository>())..loadUnawaited(),
      child: const WishlistView(),
    );
  }
}

class WishlistView extends StatelessWidget {
  const WishlistView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist'),
        actions: [
          IconButton(
            icon: AppIcon(AppIcons.add, size: 22),
            tooltip: 'Add to wishlist',
            onPressed: () => Navigator.of(
              context,
            ).push<void>(CreateWishlistItemPage.route()),
          ),
          const SizedBox(width: Space.x1),
        ],
      ),
      body: BlocBuilder<WishlistCubit, WishlistState>(
        builder: (context, state) {
          if (state.isEmpty) {
            return NoWishlistItemsYet(
              onAction: () => Navigator.of(
                context,
              ).push<void>(CreateWishlistItemPage.route()),
            );
          }
          if (state.status == WishlistStatus.initial ||
              state.status == WishlistStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final filtered = state.filtered;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x1,
              Space.gutter,
              Space.x4,
            ),
            children: [
              _FilterChips(
                selected: state.filter,
                onChanged: context.read<WishlistCubit>().filterChanged,
              ),
              const SizedBox(height: Space.x2),
              for (final item in filtered)
                WishlistItemCard(
                  item: item,
                  coverPath: state.covers[item.id],
                  onTap: () => Navigator.of(
                    context,
                  ).push<void>(WishlistItemDetailPage.route(itemId: item.id)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onChanged});

  final WishlistFilter selected;
  final ValueChanged<WishlistFilter> onChanged;

  static const _labels = {
    WishlistFilter.all: 'All',
    WishlistFilter.idea: 'Ideas',
    WishlistFilter.saving: 'Saving',
    WishlistFilter.purchased: 'Purchased',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in WishlistFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: Space.x1),
              child: ChoiceChip(
                label: Text(_labels[filter]!),
                selected: selected == filter,
                onSelected: (_) => onChanged(filter),
              ),
            ),
        ],
      ),
    );
  }
}
