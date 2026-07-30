import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/categories/cubit/cubit.dart';
import 'package:intellispendiq/domain/models/category.dart';

class CategoryTile extends StatelessWidget {
  const CategoryTile({required this.category, super.key});

  final Category category;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: category.icon == null
            ? const Icon(Icons.label_outline)
            : Text(category.icon!),
      ),
      title: Text(category.name),
      subtitle: category.isSystem ? const Text('Default category') : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename',
            onPressed: () =>
                CategoryEditorSheet.show(context, existing: category),
          ),
          if (!category.isSystem)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<CategoriesCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this category?'),
        content: Text(
          'Transactions already in "${category.name}" keep their history, '
          'but you will not be able to pick it for new ones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.delete(category.id);
  }
}

/// Adds or renames a category. Renaming works for system categories
/// too — only deletion is restricted for those.
class CategoryEditorSheet extends StatefulWidget {
  const CategoryEditorSheet({this.existing, super.key});

  final Category? existing;

  static Future<void> show(BuildContext context, {Category? existing}) {
    final cubit = context.read<CategoriesCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: CategoryEditorSheet(existing: existing),
      ),
    );
  }

  @override
  State<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<CategoryEditorSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _iconController = TextEditingController(
    text: widget.existing?.icon ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final cubit = context.read<CategoriesCubit>();
    final existing = widget.existing;
    if (existing == null) {
      await cubit.add(name: _nameController.text, icon: _iconController.text);
    } else {
      await cubit.rename(
        existing.id,
        name: _nameController.text,
        icon: _iconController.text,
      );
    }
    if (!mounted) return;
    final state = context.read<CategoriesCubit>().state;
    if (state.status == CategoriesStatus.invalid) {
      setState(() => _error = state.errorMessage);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEditing ? 'Rename category' : 'Add category',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Category name',
              errorText: _error,
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _iconController,
            decoration: const InputDecoration(
              labelText: 'Icon (optional)',
              hintText: 'Paste an emoji, e.g. 🎮',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text(isEditing ? 'Save' : 'Add category'),
          ),
        ],
      ),
    );
  }
}

class NoCategoriesYet extends StatelessWidget {
  const NoCategoriesYet({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.label_outline, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No categories yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a category for spending that does not fit the defaults.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => CategoryEditorSheet.show(context),
              child: const Text('Add category'),
            ),
          ],
        ),
      ),
    );
  }
}
