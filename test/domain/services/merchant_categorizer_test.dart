import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/domain/services/merchant_categorizer.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;
  late MerchantCategorizer categorizer;

  setUp(() async {
    services = await createTestServices();
    categorizer = services.merchantCategorizer;
  });
  tearDown(() async => services.dispose());

  group('keyword rules', () {
    test('matches airtime/data merchants', () async {
      final categoryId = await categorizer.categorize(
        merchant: 'Airtel Airtime Bundle',
      );
      final category = (await services.categories.getAll()).firstWhere(
        (c) => c.id == categoryId,
      );
      expect(category.name, 'Airtime/Data');
    });

    test('matches shopping merchants', () async {
      final categoryId = await categorizer.categorize(merchant: 'Shoprite Mukuba');
      final category = (await services.categories.getAll()).firstWhere(
        (c) => c.id == categoryId,
      );
      expect(category.name, 'Shopping');
    });

    test('matches food merchants', () async {
      final categoryId = await categorizer.categorize(
        merchant: 'Hungry Lion Cairo Road',
      );
      final category = (await services.categories.getAll()).firstWhere(
        (c) => c.id == categoryId,
      );
      expect(category.name, 'Food');
    });

    test('matches transport/fuel merchants', () async {
      final categoryId = await categorizer.categorize(
        merchant: 'Puma Energy Fuel Station',
      );
      final category = (await services.categories.getAll()).firstWhere(
        (c) => c.id == categoryId,
      );
      expect(category.name, 'Transport');
    });

    test('falls through to the message body when the merchant is blank', () async {
      final categoryId = await categorizer.categorize(
        merchant: null,
        messageBody: 'You bought a data bundle for K50',
      );
      final category = (await services.categories.getAll()).firstWhere(
        (c) => c.id == categoryId,
      );
      expect(category.name, 'Airtime/Data');
    });

    test('returns null when nothing matches', () async {
      final categoryId = await categorizer.categorize(
        merchant: 'Some Unrelated Business',
      );
      expect(categoryId, isNull);
    });
  });

  group('learned rules', () {
    test('a correction is remembered for the same merchant', () async {
      final shopping = await services.categories.byName('Shopping');
      await categorizer.learnFrom(
        merchant: 'City Deli',
        categoryId: shopping!.id,
      );

      final categoryId = await categorizer.categorize(merchant: 'City Deli');

      expect(categoryId, shopping.id);
    });

    test('a learned rule outranks the keyword table', () async {
      // "Corner Cafe" would otherwise match the Food keyword rule.
      final shopping = await services.categories.byName('Shopping');
      await categorizer.learnFrom(
        merchant: 'Corner Cafe',
        categoryId: shopping!.id,
      );

      final categoryId = await categorizer.categorize(merchant: 'Corner Cafe');

      expect(categoryId, shopping.id);
    });

    test('a later correction overwrites an earlier one', () async {
      final shopping = await services.categories.byName('Shopping');
      final transport = await services.categories.byName('Transport');
      await categorizer.learnFrom(
        merchant: 'Corner Cafe',
        categoryId: shopping!.id,
      );
      await categorizer.learnFrom(
        merchant: 'Corner Cafe',
        categoryId: transport!.id,
      );

      final categoryId = await categorizer.categorize(merchant: 'Corner Cafe');

      expect(categoryId, transport.id);
    });

    test('merchant matching ignores case and punctuation', () async {
      final shopping = await services.categories.byName('Shopping');
      await categorizer.learnFrom(
        merchant: 'Corner Cafe!',
        categoryId: shopping!.id,
      );

      final categoryId = await categorizer.categorize(
        merchant: '  corner   cafe  ',
      );

      expect(categoryId, shopping.id);
    });
  });
}
