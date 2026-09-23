import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/data/repositories/wishlist_repository.dart';
import 'package:intellispendiq/domain/models/wishlist_item.dart';
import 'package:intellispendiq/wishlist/cubit/cubit.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;
  late WishlistRepository wishlistRepository;
  late Directory tempDocumentsDir;

  setUp(() async {
    services = await createTestServices();
    tempDocumentsDir = await Directory.systemTemp.createTemp(
      'wishlist_cubit_test_',
    );
    // The default `services.wishlist` resolves photo storage through
    // the real `path_provider` plugin, unavailable in a plain unit
    // test — build one against the same repositories but pointed at
    // the system temp dir instead, same seam `backup_service_test.dart`
    // uses for its own temp-directory override.
    wishlistRepository = WishlistRepository(
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

  group('WishlistCubit.create', () {
    test('creates the item and attaches every staged photo', () async {
      final source1 = File('${tempDocumentsDir.path}/one.jpg')
        ..writeAsBytesSync([1]);
      final source2 = File('${tempDocumentsDir.path}/two.jpg')
        ..writeAsBytesSync([2]);

      final cubit = WishlistCubit(wishlistRepository);
      addTearDown(cubit.close);
      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      await cubit.create(
        name: 'New Cooking Pots',
        estimatedPrice: '1500',
        photoPaths: [source1.path, source2.path],
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, WishlistStatus.loaded);
      expect(cubit.state.items, hasLength(1));
      final item = cubit.state.items.single;
      expect(item.name, 'New Cooking Pots');
      expect(item.estimatedPriceMinor, 150000);

      final photos = await wishlistRepository.watchPhotos(item.id).first;
      expect(photos, hasLength(2));
      expect(photos.every((p) => File(p.path).existsSync()), isTrue);
    });

    test('creating with no photos leaves the item with none', () async {
      final cubit = WishlistCubit(wishlistRepository);
      addTearDown(cubit.close);
      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      await cubit.create(name: 'New Cooking Pots');
      await Future<void>.delayed(Duration.zero);

      final item = cubit.state.items.single;
      expect(await wishlistRepository.watchPhotos(item.id).first, isEmpty);
      expect(item.status, WishlistItemStatus.idea);
    });
  });
}
