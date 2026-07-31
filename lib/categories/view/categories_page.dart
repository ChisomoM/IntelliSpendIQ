import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/categories/cubit/cubit.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';
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
            icon: const Icon(Icons.add),
            tooltip: 'Add category',
            onPressed: () => Navigator.of(
              context,
            ).push<String?>(CategoryEditorPage.route()),
          ),
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
          return ListView.separated(
            itemCount: topLevel.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final parent = topLevel[index];
              final children = state.childrenOf(parent.id);
              return CategoryTile(
                category: parent,
                childCount: children.length,
                onTap: () => Navigator.of(context).push<void>(
                  CategoryChildrenPage.route(
                    parent: parent,
                    cubit: context.read<CategoriesCubit>(),
                  ),
                ),
              );
            },
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
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit category',
                onPressed: () => Navigator.of(context).push<String?>(
                  CategoryEditorPage.route(existing: current),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add subcategory',
                onPressed: addSubcategory,
              ),
            ],
          ),
          body: children.isEmpty
              ? _NoSubcategoriesYet(parent: current, onAdd: addSubcategory)
              : ListView.separated(
                  itemCount: children.length + 1,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == children.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add subcategory'),
                          onPressed: addSubcategory,
                        ),
                      );
                    }
                    return CategoryTile(category: children[index]);
                  },
                ),
        );
      },
    );
  }
}

class _NoSubcategoriesYet extends StatelessWidget {
  const _NoSubcategoriesYet({required this.parent, required this.onAdd});

  final Category parent;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.subdirectory_arrow_right, size: 48),
            const SizedBox(height: 16),
            Text(
              'No subcategories under ${parent.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a subcategory to break this category down further.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAdd, child: const Text('Add subcategory')),
          ],
        ),
      ),
    );
  }
}
