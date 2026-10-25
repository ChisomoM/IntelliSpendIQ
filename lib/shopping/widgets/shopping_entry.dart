import 'package:flutter/material.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/design/design.dart';

/// Home's reminder that a trip is open, in the same slot and shape as
/// the Review banner. Tapping resumes it.
class ShoppingResumeBanner extends StatelessWidget {
  const ShoppingResumeBanner({
    required this.cartCount,
    required this.cartTotalMinor,
    required this.onTap,
    super.key,
  });

  final int cartCount;
  final int cartTotalMinor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.primary.withValues(alpha: 0.08),
      borderRadius: Radii.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.cardPadding),
          child: Row(
            children: [
              AppIcon(AppIcons.cart, color: colors.primary),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shopping trip in progress',
                      style: AppTypography.rowTitle(color: colors.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cartCount == 0
                          ? 'Nothing in the cart yet'
                          : '${Money.display(cartTotalMinor)} in cart · '
                                '$cartCount ${cartCount == 1 ? 'item' : 'items'}',
                      style: AppTypography.metadata(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.x1),
              AppIcon(
                AppIcons.chevronRight,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
