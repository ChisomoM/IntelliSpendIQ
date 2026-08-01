import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/categories/cubit/cubit.dart';
import 'package:intellispendiq/core/money.dart';
import 'package:intellispendiq/data/repositories/budget_period_repository.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/domain/models/category.dart';
import 'package:intellispendiq/domain/models/enums.dart';

class CategoryTile extends StatelessWidget {
  const CategoryTile({
    required this.category,
    this.onTap,
    this.childCount,
    super.key,
  });

  final Category category;

  /// Opens this category's detail (e.g. its subcategories). When set, a
  /// chevron is shown to signal the row is tappable.
  final VoidCallback? onTap;

  /// When non-null, appended to the subtitle as "N subcategories".
  final int? childCount;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (category.isSystem) 'Default category',
      if (category.hasBudget)
        '${category.isIncome ? 'Planned' : 'Budget'}: ${Money.format(category.budgetedAmountMinor!)}',
      if (childCount != null && childCount! > 0)
        '$childCount subcategor${childCount == 1 ? 'y' : 'ies'}',
    ];

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: category.icon == null
            ? const Icon(Icons.label_outline)
            : Text(category.icon!),
      ),
      title: Text(category.name),
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => Navigator.of(
              context,
            ).push<String?>(CategoryEditorPage.route(existing: category)),
          ),
          if (!category.isSystem)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context),
            ),
          if (onTap != null) const Icon(Icons.chevron_right),
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

/// Adds or renames a category — its type, icon, optional parent, and
/// its standing budget all together, since a category is the budget
/// line for it. Renaming works for system categories too — only
/// deletion is restricted for those.
///
/// Pushed as a full page (not a bottom sheet reusing the caller's
/// cubit), so it builds its own [CategoriesCubit] from the repository
/// — the same pattern every other full-page editor in the app uses,
/// since a pushed route sits outside the caller's provider subtree.
class CategoryEditorPage extends StatelessWidget {
  const CategoryEditorPage({
    this.existing,
    this.parentId,
    this.initialType,
    this.periodId,
    this.lockParent = false,
    super.key,
  });

  final Category? existing;

  /// Preselects a parent when adding a new subcategory directly under
  /// it. Ignored when [existing] is set — its own current parent wins.
  final String? parentId;

  /// The parent's type, when [lockParent] is set — the caller already
  /// has the parent Category in hand, so this is passed through
  /// rather than re-looked-up from a cubit that may not have loaded
  /// yet.
  final CategoryType? initialType;

  /// Budget period to write the planned/budget amount into.
  final String? periodId;

  /// True when opened as "add subcategory" — the parent (and its
  /// type) are fixed rather than pickable.
  final bool lockParent;

  /// Resolves with the created or edited category's id when saved, or
  /// null if the user backed out — lets a caller (like the expense
  /// form's quick "add category" action) select what was just made.
  static Route<String?> route({
    Category? existing,
    String? parentId,
    CategoryType? initialType,
    String? periodId,
    bool lockParent = false,
  }) {
    return MaterialPageRoute<String?>(
      builder: (_) => CategoryEditorPage(
        existing: existing,
        parentId: parentId,
        initialType: initialType,
        periodId: periodId,
        lockParent: lockParent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CategoriesCubit(
        context.read<CategoryRepository>(),
        budgetPeriods: context.read<BudgetPeriodRepository>(),
        periodId: periodId,
      )..loadUnawaited(),
      child: _CategoryEditorView(
        existing: existing,
        parentId: parentId,
        initialType: initialType,
        lockParent: lockParent,
      ),
    );
  }
}

class _CategoryEditorView extends StatefulWidget {
  const _CategoryEditorView({
    this.existing,
    this.parentId,
    this.initialType,
    this.lockParent = false,
  });

  final Category? existing;
  final String? parentId;
  final CategoryType? initialType;
  final bool lockParent;

  @override
  State<_CategoryEditorView> createState() => _CategoryEditorViewState();
}

class _CategoryEditorViewState extends State<_CategoryEditorView> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _iconController = TextEditingController(
    text: widget.existing?.icon ?? '',
  );
  late final TextEditingController _budgetController = TextEditingController(
    text: widget.existing?.budgetedAmountMinor == null
        ? ''
        : (widget.existing!.budgetedAmountMinor! / 100).toStringAsFixed(2),
  );
  late String? _parentId = widget.existing?.parentId ?? widget.parentId;
  late CategoryType _type =
      widget.existing?.type ?? widget.initialType ?? CategoryType.expense;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final cubit = context.read<CategoriesCubit>();
    final existing = widget.existing;
    String? savedId = existing?.id;
    if (existing == null) {
      final created = await cubit.add(
        name: _nameController.text,
        icon: _iconController.text,
        parentId: _parentId,
        type: _type,
        budgetedAmount: _budgetController.text,
      );
      savedId = created?.id;
    } else {
      await cubit.rename(
        existing.id,
        name: _nameController.text,
        icon: _iconController.text,
        parentId: _parentId,
        type: _type,
        budgetedAmount: _budgetController.text,
      );
    }
    if (!mounted) return;
    final state = context.read<CategoriesCubit>().state;
    if (state.status == CategoriesStatus.invalid) {
      setState(() => _error = state.errorMessage);
      return;
    }
    navigator.pop(savedId);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? (_type == CategoryType.income
                    ? 'Edit income source'
                    : 'Edit category')
              : (_type == CategoryType.income
                    ? 'Add income source'
                    : 'Add category'),
        ),
        actions: [
          TextButton(onPressed: _save, child: const Text('SAVE')),
        ],
      ),
      body: BlocBuilder<CategoriesCubit, CategoriesState>(
        builder: (context, state) {
          // A category can't be its own parent, and only top-level
          // categories are offered as parents — one level of nesting
          // keeps the picker simple and matches how the list renders.
          final parentOptions = state.topLevel
              .where((c) => c.id != widget.existing?.id)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!widget.lockParent) ...[
                Text(
                  'Category type',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<CategoryType>(
                  segments: const [
                    ButtonSegment(
                      value: CategoryType.expense,
                      label: Text('Expense'),
                    ),
                    ButtonSegment(
                      value: CategoryType.income,
                      label: Text('Income'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (values) =>
                      setState(() => _type = values.first),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
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
              const SizedBox(height: 16),
              TextField(
                controller: _budgetController,
                decoration: InputDecoration(
                  labelText: _type == CategoryType.income
                      ? 'Planned amount for this period'
                      : 'Budgeted amount (optional)',
                  hintText: _type == CategoryType.income
                      ? 'e.g. monthly salary'
                      : null,
                  prefixText: 'K',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                ],
              ),
              if (!widget.lockParent && parentOptions.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: parentOptions.any((c) => c.id == _parentId)
                      ? _parentId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Parent category (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(child: Text('None — top level')),
                    for (final parent in parentOptions)
                      DropdownMenuItem(
                        value: parent.id,
                        child: Text(parent.displayName),
                      ),
                  ],
                  onChanged: (value) => setState(() => _parentId = value),
                ),
              ],
            ],
          );
        },
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
              onPressed: () => Navigator.of(
                context,
              ).push<String?>(CategoryEditorPage.route()),
              child: const Text('Add category'),
            ),
          ],
        ),
      ),
    );
  }
}
