import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/categories/categories.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;

  Future<CategoriesCubit> cubitWith() async {
    services = await createTestServices();
    addTearDown(services.dispose);
    final cubit = CategoriesCubit(services.categories);
    await cubit.load();
    await Future<void>.delayed(Duration.zero);
    return cubit;
  }

  group('CategoriesCubit', () {
    test('loads the ten seeded categories', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);

      expect(cubit.state.status, CategoriesStatus.loaded);
      expect(cubit.state.categories, hasLength(10));
    });

    test('add() creates a new category', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);

      await cubit.add(name: 'Pets', icon: '🐕');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.categories, hasLength(11));
      expect(cubit.state.categories.map((c) => c.name), contains('Pets'));
    });

    test('add() rejects an empty name', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);

      await cubit.add(name: '   ');

      expect(cubit.state.status, CategoriesStatus.invalid);
      expect(cubit.state.categories, hasLength(10));
    });

    test('rename() updates name and icon', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.add(name: 'Pets', icon: '🐕');
      await Future<void>.delayed(Duration.zero);
      final pets = cubit.state.categories.firstWhere((c) => c.name == 'Pets');

      await cubit.rename(pets.id, name: 'Pet care', icon: '🐈');
      await Future<void>.delayed(Duration.zero);

      final updated = cubit.state.categories.firstWhere((c) => c.id == pets.id);
      expect(updated.name, 'Pet care');
      expect(updated.icon, '🐈');
    });

    test('delete() removes a custom category', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.add(name: 'Pets');
      await Future<void>.delayed(Duration.zero);
      final pets = cubit.state.categories.firstWhere((c) => c.name == 'Pets');

      await cubit.delete(pets.id);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.categories, hasLength(10));
    });

    test('delete() refuses a system category', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      final food = cubit.state.categories.firstWhere((c) => c.name == 'Food');

      await cubit.delete(food.id);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, CategoriesStatus.invalid);
      expect(cubit.state.categories, hasLength(10));
    });

    test('add() nests a subcategory under a parent', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      final food = cubit.state.categories.firstWhere((c) => c.name == 'Food');

      await cubit.add(name: 'Groceries', parentId: food.id);
      await Future<void>.delayed(Duration.zero);

      final groceries = cubit.state.categories.firstWhere(
        (c) => c.name == 'Groceries',
      );
      expect(groceries.parentId, food.id);
      expect(cubit.state.childrenOf(food.id).map((c) => c.name), [
        'Groceries',
      ]);
      expect(
        cubit.state.topLevel.map((c) => c.name),
        isNot(contains('Groceries')),
      );
    });

    test('rename() can move a category out from under its parent', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      final food = cubit.state.categories.firstWhere((c) => c.name == 'Food');
      await cubit.add(name: 'Groceries', parentId: food.id);
      await Future<void>.delayed(Duration.zero);
      final groceries = cubit.state.categories.firstWhere(
        (c) => c.name == 'Groceries',
      );

      await cubit.rename(groceries.id, name: 'Groceries');
      await Future<void>.delayed(Duration.zero);

      final updated = cubit.state.categories.firstWhere(
        (c) => c.id == groceries.id,
      );
      expect(updated.parentId, isNull);
    });

    test('add() refuses a subcategory under a subcategory', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      final food = cubit.state.categories.firstWhere((c) => c.name == 'Food');
      await cubit.add(name: 'Groceries', parentId: food.id);
      await Future<void>.delayed(Duration.zero);
      final groceries = cubit.state.categories.firstWhere(
        (c) => c.name == 'Groceries',
      );

      final created = await cubit.add(
        name: 'Fresh produce',
        parentId: groceries.id,
      );
      await Future<void>.delayed(Duration.zero);

      expect(created, isNull);
      expect(cubit.state.status, CategoriesStatus.invalid);
      expect(
        cubit.state.categories.map((c) => c.name),
        isNot(contains('Fresh produce')),
      );
    });

    test(
      'add() refuses a subcategory budget beyond what the parent has left',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        final food = cubit.state.categories.firstWhere(
          (c) => c.name == 'Food',
        );
        await cubit.rename(food.id, name: 'Food', budgetedAmount: '1000');
        await Future<void>.delayed(Duration.zero);

        final created = await cubit.add(
          name: 'Takeaways',
          parentId: food.id,
          budgetedAmount: '1200',
        );
        await Future<void>.delayed(Duration.zero);

        expect(created, isNull);
        expect(cubit.state.status, CategoriesStatus.invalid);
        expect(
          cubit.state.categories.map((c) => c.name),
          isNot(contains('Takeaways')),
        );
      },
    );

    test(
      'add() allows subcategory budgets that stay within the parent',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);
        final food = cubit.state.categories.firstWhere(
          (c) => c.name == 'Food',
        );
        await cubit.rename(food.id, name: 'Food', budgetedAmount: '1000');
        await Future<void>.delayed(Duration.zero);

        await cubit.add(
          name: 'Takeaways',
          parentId: food.id,
          budgetedAmount: '600',
        );
        await Future<void>.delayed(Duration.zero);
        // A second subcategory eating into what's left is fine...
        await cubit.add(
          name: 'Groceries',
          parentId: food.id,
          budgetedAmount: '400',
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, isNot(CategoriesStatus.invalid));
        expect(
          cubit.state.categories.map((c) => c.name),
          containsAll(['Takeaways', 'Groceries']),
        );

        // ...but a third subcategory that would push the total over the
        // parent's budget is refused.
        final overBudget = await cubit.add(
          name: 'Snacks',
          parentId: food.id,
          budgetedAmount: '1',
        );
        await Future<void>.delayed(Duration.zero);

        expect(overBudget, isNull);
        expect(cubit.state.status, CategoriesStatus.invalid);
      },
    );
  });
}
