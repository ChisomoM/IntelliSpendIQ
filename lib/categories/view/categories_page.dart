import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intellispendiq/categories/cubit/cubit.dart';
import 'package:intellispendiq/categories/widgets/widgets.dart';
import 'package:intellispendiq/data/repositories/category_repository.dart';

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
            onPressed: () => CategoryEditorSheet.show(context),
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
          return ListView.builder(
            itemCount: topLevel.length,
            itemBuilder: (context, index) {
              final parent = topLevel[index];
              final children = state.childrenOf(parent.id);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  CategoryTile(category: parent),
                  for (final child in children)
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: CategoryTile(category: child),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add subcategory'),
                      onPressed: () => CategoryEditorSheet.show(
                        context,
                        parentId: parent.id,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
