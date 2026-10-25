import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intellispendiq/categories/categories.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/shopping/widgets/shopping_category_picker.dart';

/// The quick-add strip pinned above the keyboard: a name, a price and
/// optionally a category. Anything added here is an impulse buy.
class AddItemBar extends StatefulWidget {
  const AddItemBar({
    required this.categoriesById,
    required this.onAdd,
    required this.onPickCategory,
    super.key,
  });

  final Map<String, Category> categoriesById;

  /// Returns an error message for the price field, or null on success.
  final Future<String?> Function({
    required String name,
    required String price,
    required String? categoryId,
  })
  onAdd;

  /// Opens the category sheet; null means it was dismissed.
  final Future<CategoryPick?> Function(String? selectedId) onPickCategory;

  @override
  State<AddItemBar> createState() => _AddItemBarState();
}

class _AddItemBarState extends State<AddItemBar> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _nameFocus = FocusNode();
  String? _categoryId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await widget.onAdd(
      name: _name.text,
      price: _price.text,
      categoryId: _categoryId,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) {
      _name.clear();
      _price.clear();
      _nameFocus.requestFocus();
    }
  }

  Future<void> _pickCategory() async {
    final picked = await widget.onPickCategory(_categoryId);
    if (picked == null || !mounted) return;
    setState(() => _categoryId = picked.categoryId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = _categoryId == null
        ? null
        : widget.categoriesById[_categoryId];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.x1,
          Space.gutter,
          Space.x1,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _name,
                    focusNode: _nameFocus,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Add something not on your list',
                    ),
                  ),
                ),
                const SizedBox(width: Space.x1),
                SizedBox(
                  width: 104,
                  child: TextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                    ],
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixText: 'K ',
                      hintText: 'Price',
                      errorText: _error,
                      errorMaxLines: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  tooltip: 'Add to cart',
                  onPressed: _busy ? null : _add,
                  icon: AppIcon(AppIcons.add, color: colors.onPrimary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: CategoryChipButton(
                category: selected,
                placeholder: 'Category (optional)',
                onTap: _pickCategory,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
