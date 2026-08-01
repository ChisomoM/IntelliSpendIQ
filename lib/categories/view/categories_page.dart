import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/categories/cubit/cubit.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
import 'package:intellispendiq/design/design.dart';
import 'package:intellispendiq/domain/models/category.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const CategoriesPage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          CategoriesCubit(context.read<CategoryRepository>())..loadUnawaited(),
      child: const CategoriesView(),
    );
  }
}

class CategoriesView extends StatelessWidget {
  const CategoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: AppIcon(AppIcons.add, size: 22),
            tooltip: 'Add category',
            onPressed: () => Navigator.of(
              context,
            ).push<String?>(CategoryEditorPage.route()),
          ),
          const SizedBox(width: Space.x1),
        ],
      ),
      body: BlocBuilder<CategoriesCubit, CategoriesState>(
        builder: (context, state) {
          if (state.isEmpty) return const NoCategoriesYet();
          if (state.status == CategoriesStatus.initial ||
              state.status == CategoriesStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final topLevel = state.topLevel;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x1,
              Space.gutter,
              Space.x4,
            ),
            children: [
              for (final parent in topLevel)
                CategoryTile(
                  category: parent,
                  childCount: state.childrenOf(parent.id).length,
                  onTap: () => Navigator.of(context).push<void>(
                    CategoryChildrenPage.route(
                      parent: parent,
                      cubit: context.read<CategoriesCubit>(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Subcategories under a single parent — opened by tapping a top-level
/// category on [CategoriesPage].
class CategoryChildrenPage extends StatelessWidget {
  const CategoryChildrenPage({required this.parent, super.key});

  final Category parent;

  static Route<void> route({
    required Category parent,
    required CategoriesCubit cubit,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: CategoryChildrenPage(parent: parent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CategoriesCubit, CategoriesState>(
      listener: (context, state) {
        if (!state.categories.any((c) => c.id == parent.id)) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final current =
            state.categories.where((c) => c.id == parent.id).firstOrNull ??
            parent;
        final children = state.childrenOf(parent.id);
        void addSubcategory() {
          Navigator.of(context).push<String?>(
            CategoryEditorPage.route(
              parentId: current.id,
              initialType: current.type,
              lockParent: true,
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(current.name),
            actions: [
              IconButton(
                icon: AppIcon(AppIcons.edit, size: 22),
                tooltip: 'Edit category',
                onPressed: () => Navigator.of(context).push<String?>(
                  CategoryEditorPage.route(existing: current),
                ),
              ),
              IconButton(
                icon: AppIcon(AppIcons.add, size: 22),
                tooltip: 'Add subcategory',
                onPressed: addSubcategory,
              ),
              const SizedBox(width: Space.x1),
            ],
          ),
          body: children.isEmpty
              ? EmptyState(
                  icon: AppIcons.budgets,
                  title: 'No subcategories under ${current.name}',
                  message:
                      'Add a subcategory to break this category down further.',
                  actionLabel: 'Add subcategory',
                  onAction: addSubcategory,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.x1,
                    Space.gutter,
                    Space.x1,
                  ),
                  children: [
                    for (final child in children) CategoryTile(category: child),
                    _AddSubcategoryRow(onTap: addSubcategory),
                  ],
                ),
        );
      },
    );
  }
}

/// Full-width dashed-feeling "add" row that closes the subcategory list —
/// same shape as [AddCategoryCard] on the Budgets screen, kept local
/// here to avoid a cross-module dependency for one small widget.
class _AddSubcategoryRow extends StatelessWidget {
  const _AddSubcategoryRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: Radii.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: Radii.cardRadius,
            border: Border.all(color: colors.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(AppIcons.add, size: 18, color: colors.primary),
              const SizedBox(width: Space.x1),
              Text(
                'Add subcategory',
                style: AppTypography.rowTitle(color: colors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
