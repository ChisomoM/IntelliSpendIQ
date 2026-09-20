import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/data/repositories/wishlist_repository.dart';
import 'package:intellispendiq/domain/models/enums.dart';
import 'package:intellispendiq/domain/models/wishlist_item.dart';

import '../support/test_harness.dart';

void main() {
  late AppServices services;
  late WishlistRepository wishlist;
  late String accountId;
  late Directory tempDocumentsDir;

  setUp(() async {
    services = await createTestServices();
    accountId = (await services.accounts.getDefault()).id;
    tempDocumentsDir = await Directory.systemTemp.createTemp(
      'wishlist_test_',
    );
    wishlist = WishlistRepository(
      services.db,
      userId: services.userId,
      transactions: services.transactions,
      savingsGoals: services.savingsGoals,
      budgetPeriods: services.budgetPeriods,
      documentsDirectory: () async => tempDocumentsDir,
    );
  });
  tearDown(() async {
    await services.dispose();
    await tempDocumentsDir.delete(recursive: true);
  });

  group('create', () {
    test('starts as an idea with no price required', () async {
      final item = await wishlist.create(name: 'New Cooking Pots');

      expect(item.status, WishlistItemStatus.idea);
      expect(item.estimatedPriceMinor, isNull);

      final all = await wishlist.watchAll().first;
      expect(all, hasLength(1));
      expect(all.single.name, 'New Cooking Pots');
    });

    test('keeps optional fields', () async {
      final item = await wishlist.create(
        name: 'New Cooking Pots',
        estimatedPriceMinor: 150000,
        seenAt: 'Shoprite',
        productUrl: 'https://example.com/pots',
        note: 'I like this particular set.',
      );

      expect(item.estimatedPriceMinor, 150000);
      expect(item.seenAt, 'Shoprite');
      expect(item.productUrl, 'https://example.com/pots');
      expect(item.note, 'I like this particular set.');
    });
  });

  group('photos', () {
    late File sourceImage;

    setUp(() async {
      sourceImage = File('${tempDocumentsDir.path}/source.jpg')
        ..writeAsBytesSync([1, 2, 3]);
    });

    test('addPhoto copies the file into app-local storage', () async {
      final item = await wishlist.create(name: 'New Cooking Pots');

      final photo = await wishlist.addPhoto(item.id, sourceImage.path);

      expect(photo.wishlistItemId, item.id);
      expect(File(photo.path).existsSync(), isTrue);
      expect(photo.path, isNot(sourceImage.path));

      final photos = await wishlist.watchPhotos(item.id).first;
      expect(photos, hasLength(1));
      expect(photos.single.id, photo.id);
    });

    test('multiple photos keep increasing sort order', () async {
      final item = await wishlist.create(name: 'New Cooking Pots');

      final first = await wishlist.addPhoto(item.id, sourceImage.path);
      final second = await wishlist.addPhoto(item.id, sourceImage.path);

      expect(second.sortOrder, greaterThan(first.sortOrder));
      final photos = await wishlist.watchPhotos(item.id).first;
      expect(photos, hasLength(2));
    });

    test('removePhoto deletes the row and the file', () async {
      final item = await wishlist.create(name: 'New Cooking Pots');
      final photo = await wishlist.addPhoto(item.id, sourceImage.path);

      await wishlist.removePhoto(photo.id);

      expect(await wishlist.watchPhotos(item.id).first, isEmpty);
      expect(File(photo.path).existsSync(), isFalse);
    });

    test('watchCovers reports each item\'s lowest-sort-order photo',
        () async {
      final item = await wishlist.create(name: 'New Cooking Pots');
      final first = await wishlist.addPhoto(item.id, sourceImage.path);
      await wishlist.addPhoto(item.id, sourceImage.path);

      final covers = await wishlist.watchCovers().first;

      expect(covers[item.id], first.path);
    });
  });

  group('convertToGoal', () {
    test('funds the item without deleting it — status becomes saving',
        () async {
      final item = await wishlist.create(
        name: 'New Cooking Pots',
        estimatedPriceMinor: 150000,
      );

      final goal = await wishlist.convertToGoal(
        item.id,
        targetMinor: 150000,
        targetDate: DateTime(2026, 12, 1),
      );

      expect(goal.name, 'New Cooking Pots');
      expect(goal.targetMinor, 150000);

      final updated = (await wishlist.watchAll().first).single;
      expect(updated.linkedGoalId, goal.id);
      expect(updated.status, WishlistItemStatus.saving);
    });
  });

  group('convertToExpense', () {
    test('direct purchase (no goal) records a real expense and marks it '
        'purchased', () async {
      final item = await wishlist.create(
        name: 'New Cooking Pots',
        estimatedPriceMinor: 150000,
      );

      final tx = await wishlist.convertToExpense(
        item.id,
        accountId: accountId,
        amountMinor: 135000,
        transactedAt: DateTime(2026, 9, 1),
      );

      expect(tx.amountMinor, 135000);
      expect(tx.metadata['linkedWishlistItemId'], item.id);

      final updated = (await wishlist.watchAll().first).single;
      expect(updated.status, WishlistItemStatus.purchased);
      expect(updated.actualPriceMinor, 135000);
      expect(updated.linkedTransactionId, tx.id);
    });

    test('purchase via a linked goal routes through spend() and releases '
        'the saved amount', () async {
      final item = await wishlist.create(
        name: 'New Cooking Pots',
        estimatedPriceMinor: 150000,
      );
      final goal = await wishlist.convertToGoal(item.id, targetMinor: 150000);
      await services.savingsGoals.contribute(
        goalId: goal.id,
        accountId: accountId,
        amountMinor: 150000,
        transactedAt: DateTime(2026, 8, 1),
      );

      final tx = await wishlist.convertToExpense(
        item.id,
        accountId: accountId,
        amountMinor: 135000,
        transactedAt: DateTime(2026, 9, 1),
      );

      expect(tx.amountMinor, 135000);
      final saved = await services.savingsGoals.watchSaved().first;
      expect(
        saved[goal.id],
        15000,
        reason: 'only 1350 of the 1500 saved was needed for the purchase',
      );

      final updated = (await wishlist.watchAll().first).single;
      expect(updated.status, WishlistItemStatus.purchased);
      expect(updated.linkedTransactionId, tx.id);
    });
  });

  group('delete', () {
    test('soft-deletes the item and removes its photo files', () async {
      final item = await wishlist.create(name: 'New Cooking Pots');
      final source = File('${tempDocumentsDir.path}/source2.jpg')
        ..writeAsBytesSync([4, 5, 6]);
      final photo = await wishlist.addPhoto(item.id, source.path);

      await wishlist.delete(item.id);

      expect(await wishlist.watchAll().first, isEmpty);
      expect(await wishlist.watchPhotos(item.id).first, isEmpty);
      expect(File(photo.path).existsSync(), isFalse);
    });

    test('never touches a linked goal — it stands on its own', () async {
      final item = await wishlist.create(name: 'New Cooking Pots');
      final goal = await wishlist.convertToGoal(item.id, targetMinor: 150000);

      await wishlist.delete(item.id);

      final goals = await services.savingsGoals.watchAll().first;
      expect(goals, hasLength(1));
      expect(goals.single.id, goal.id);
    });
  });
}
