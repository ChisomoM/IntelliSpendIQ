import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intellispendiq/core/time.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/wishlist_item.dart';
import 'package:intellispendiq/domain/models/wishlist_item_photo.dart';
import 'package:intellispendiq/wishlist/cubit/cubit.dart';

/// A wishlist item's card in the list: cover photo (or a placeholder),
/// name, estimated price, and a small status label.
class WishlistItemCard extends StatelessWidget {
  const WishlistItemCard({required this.item, this.coverPath, this.onTap, super.key});

  final WishlistItem item;

  /// The lowest-sort-order photo's path, if the item has any.
  final String? coverPath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.cardGap),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            _Cover(path: coverPath),
            const SizedBox(width: Space.x2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.rowTitle(color: colors.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusLabel(item.status),
                    style: AppTypography.metadata(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (item.estimatedPriceMinor != null)
              MoneyText(item.estimatedPriceMinor!, size: MoneySize.row),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(WishlistItemStatus status) => switch (status) {
  WishlistItemStatus.idea => 'Idea',
  WishlistItemStatus.saving => 'Saving toward it',
  WishlistItemStatus.purchased => 'Purchased',
};

class _Cover extends StatelessWidget {
  const _Cover({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const size = 48.0;

    if (path == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        alignment: Alignment.center,
        child: AppIcon(
          AppIcons.wishlist,
          size: size * 20 / 44,
          color: colors.onSurfaceVariant,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.3),
      child: Image.file(
        File(path!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          color: colors.surfaceContainerHigh,
          child: AppIcon(AppIcons.unknown, size: 20),
        ),
      ),
    );
  }
}

/// Picks an image from the camera or the gallery — the same two-option
/// sheet `_ReceiptField` uses for receipts — and returns its source path,
/// or null if the user backed out.
Future<String?> pickImagePath(BuildContext context) async {
  final source = await AppSheet.show<ImageSource>(
    context,
    isScrollControlled: false,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppListRow(
          leading: AppIcon(AppIcons.scanReceipt),
          title: const Text('Take photo'),
          onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
        ),
        AppListRow(
          leading: AppIcon(AppIcons.exportData),
          title: const Text('Choose from gallery'),
          onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
        ),
      ],
    ),
  );
  if (source == null) return null;

  if (source == ImageSource.camera) {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera);
    return photo?.path;
  }
  final result = await FilePicker.pickFiles(type: FileType.image);
  return result?.files.single.path;
}

/// The photo strip on an item's detail page: existing thumbnails plus an
/// "add" tile, capped at [maxPhotos].
class WishlistPhotoStrip extends StatelessWidget {
  const WishlistPhotoStrip({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    this.maxPhotos = 6,
    super.key,
  });

  final List<WishlistItemPhoto> photos;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final int maxPhotos;

  static const _size = 72.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: _size,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final photo in photos)
            Padding(
              padding: const EdgeInsets.only(right: Space.x1),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(photo.path),
                      width: _size,
                      height: _size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: _size,
                        height: _size,
                        color: colors.surfaceContainerHigh,
                        child: AppIcon(AppIcons.unknown, size: 20),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => onRemove(photo.id),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (photos.length < maxPhotos)
            GestureDetector(
              onTap: () async {
                final path = await pickImagePath(context);
                if (path != null) onAdd(path);
              },
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: AppIcon(AppIcons.add, size: 22, color: colors.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

/// Captures a new wishlist item: name, optional estimated price, and the
/// optional where-seen/URL/note fields.
class CreateWishlistItemSheet extends StatefulWidget {
  const CreateWishlistItemSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<WishlistCubit>();
    return AppSheet.show<void>(
      context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const CreateWishlistItemSheet(),
      ),
    );
  }

  @override
  State<CreateWishlistItemSheet> createState() =>
      _CreateWishlistItemSheetState();
}

class _CreateWishlistItemSheetState extends State<CreateWishlistItemSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _seenAtController = TextEditingController();
  final _urlController = TextEditingController();
  final _noteController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _seenAtController.dispose();
    _urlController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await context.read<WishlistCubit>().create(
      name: _nameController.text,
      estimatedPrice: _priceController.text,
      seenAt: _seenAtController.text,
      productUrl: _urlController.text,
      note: _noteController.text,
    );
    if (!mounted) return;
    final state = context.read<WishlistCubit>().state;
    if (state.status == WishlistStatus.invalid) {
      setState(() => _error = state.errorMessage);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Add to wishlist', style: AppTypography.sectionHeader()),
        const SizedBox(height: Space.x2),
        AppTextField(
          controller: _nameController,
          label: 'What do you want?',
          hint: 'New cooking pots',
          errorText: _error,
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
        ),
        const SizedBox(height: Space.x2),
        AmountField(
          controller: _priceController,
          label: 'Estimated price (optional)',
        ),
        const SizedBox(height: Space.x2),
        AppTextField(
          controller: _seenAtController,
          label: 'Where you saw it (optional)',
          hint: 'Shoprite, an online store…',
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: Space.x2),
        AppTextField(
          controller: _urlController,
          label: 'Product link (optional)',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: Space.x2),
        AppTextField(
          controller: _noteController,
          label: 'Notes (optional)',
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: Space.x3),
        AppButton.primary(label: 'Add to wishlist', onPressed: _save),
      ],
    );
  }
}

/// Turns the item into a funded savings goal.
class ConvertToGoalSheet extends StatefulWidget {
  const ConvertToGoalSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<WishlistItemDetailCubit>();
    return AppSheet.show<void>(
      context,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const ConvertToGoalSheet()),
    );
  }

  @override
  State<ConvertToGoalSheet> createState() => _ConvertToGoalSheetState();
}

class _ConvertToGoalSheetState extends State<ConvertToGoalSheet> {
  late final TextEditingController _targetController;
  DateTime? _targetDate;
  String? _accountId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = context.read<WishlistItemDetailCubit>().state;
    final estimated = state.item?.estimatedPriceMinor;
    _targetController = TextEditingController(
      text: estimated == null ? '' : (estimated / 100).toStringAsFixed(2),
    );
    _accountId = state.accounts.isEmpty ? null : state.accounts.first.id;
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (date == null) return;
    setState(() => _targetDate = date);
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await context.read<WishlistItemDetailCubit>().convertToGoal(
      targetAmount: _targetController.text,
      targetDate: _targetDate,
      defaultAccountId: _accountId,
    );
    if (!mounted) return;
    final state = context.read<WishlistItemDetailCubit>().state;
    if (state.status == WishlistItemDetailStatus.invalid) {
      setState(() => _error = state.errorMessage);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<WishlistItemDetailCubit>().state.accounts;
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Turn into a savings goal', style: AppTypography.sectionHeader()),
        const SizedBox(height: Space.x2),
        AmountField(
          controller: _targetController,
          label: 'Target amount',
          errorText: _error,
        ),
        const SizedBox(height: Space.x2),
        AppListRow(
          title: const Text('Target date (optional)'),
          subtitle: Text(
            _targetDate == null
                ? 'No date set'
                : Iso.formatDateDdMmYyyy(_targetDate!),
          ),
          trailing: AppIcon(
            AppIcons.chevronRight,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
          onTap: _pickDate,
        ),
        if (accounts.isNotEmpty) ...[
          const SizedBox(height: Space.x2),
          DropdownButtonFormField<String>(
            initialValue: _accountId,
            decoration: const InputDecoration(
              labelText: 'Contribute from (optional)',
            ),
            items: [
              for (final account in accounts)
                DropdownMenuItem(value: account.id, child: Text(account.name)),
            ],
            onChanged: (value) => setState(() => _accountId = value),
          ),
        ],
        const SizedBox(height: Space.x3),
        AppButton.primary(label: 'Create savings goal', onPressed: _save),
      ],
    );
  }
}

/// Buys the item: records a real expense, funded first by a linked goal
/// if there is one.
class ConvertToExpenseSheet extends StatefulWidget {
  const ConvertToExpenseSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<WishlistItemDetailCubit>();
    return AppSheet.show<void>(
      context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const ConvertToExpenseSheet(),
      ),
    );
  }

  @override
  State<ConvertToExpenseSheet> createState() => _ConvertToExpenseSheetState();
}

class _ConvertToExpenseSheetState extends State<ConvertToExpenseSheet> {
  late final TextEditingController _amountController;
  String? _accountId;
  String? _categoryId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = context.read<WishlistItemDetailCubit>().state;
    final price = state.item?.estimatedPriceMinor;
    _amountController = TextEditingController(
      text: price == null ? '' : (price / 100).toStringAsFixed(2),
    );
    _accountId = state.accounts.isEmpty ? null : state.accounts.first.id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_accountId == null) {
      setState(() => _error = 'Pick an account');
      return;
    }
    final navigator = Navigator.of(context);
    await context.read<WishlistItemDetailCubit>().convertToExpense(
      accountId: _accountId!,
      amount: _amountController.text,
      transactedAt: DateTime.now(),
      categoryId: _categoryId,
    );
    if (!mounted) return;
    final state = context.read<WishlistItemDetailCubit>().state;
    if (state.status == WishlistItemDetailStatus.invalid) {
      setState(() => _error = state.errorMessage);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WishlistItemDetailCubit>().state;
    final expenseCategories = state.categories
        .where((c) => c.type == CategoryType.expense)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('You bought it', style: AppTypography.sectionHeader()),
        const SizedBox(height: Space.x2),
        AmountField(
          controller: _amountController,
          label: 'Price paid',
          errorText: _error,
        ),
        const SizedBox(height: Space.x2),
        DropdownButtonFormField<String>(
          initialValue: _accountId,
          decoration: const InputDecoration(labelText: 'Paid from'),
          items: [
            for (final account in state.accounts)
              DropdownMenuItem(value: account.id, child: Text(account.name)),
          ],
          onChanged: (value) => setState(() => _accountId = value),
        ),
        if (expenseCategories.isNotEmpty) ...[
          const SizedBox(height: Space.x2),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Category (optional)'),
            items: [
              for (final category in expenseCategories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                ),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
          ),
        ],
        const SizedBox(height: Space.x3),
        AppButton.primary(label: 'Record purchase', onPressed: _save),
      ],
    );
  }
}

class NoWishlistItemsYet extends StatelessWidget {
  const NoWishlistItemsYet({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: AppIcons.wishlist,
      title: 'Nothing on your wishlist yet',
      message:
          'Keep track of things you want but haven\'t decided to buy or '
          'save for yet.',
      actionLabel: 'Add to wishlist',
      onAction: () => CreateWishlistItemSheet.show(context),
    );
  }
}
