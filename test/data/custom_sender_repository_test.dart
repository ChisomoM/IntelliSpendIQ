import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';

import '../support/test_harness.dart';

void main() {
  late AppServices services;

  setUp(() async => services = await createTestServices());
  tearDown(() async => services.dispose());

  group('CustomSenderRepository', () {
    test('add() normalizes the sender id before storing it', () async {
      final sender = await services.customSenders.add(
        providerKey: 'stan_chart',
        senderId: '+260 StanChart-ZM',
      );

      expect(sender.senderId, '260stanchartzm');
      final all = await services.customSenders.getAll();
      expect(all, hasLength(1));
      expect(all.single.senderId, '260stanchartzm');
    });

    test(
      'add() reactivates a previously deleted sender for the same id',
      () async {
        final first = await services.customSenders.add(
          providerKey: 'airtel_money',
          senderId: '90210',
        );
        await services.customSenders.delete(first.id);

        final second = await services.customSenders.add(
          providerKey: 'stan_chart',
          senderId: '90210',
        );

        expect(second.id, first.id);
        expect(second.providerKey, 'stan_chart');
        final all = await services.customSenders.getAll();
        expect(all, hasLength(1));
      },
    );

    test('delete() removes it from getAll()', () async {
      final sender = await services.customSenders.add(
        providerKey: 'airtel_money',
        senderId: '90210',
      );

      await services.customSenders.delete(sender.id);

      expect(await services.customSenders.getAll(), isEmpty);
    });
  });
}
