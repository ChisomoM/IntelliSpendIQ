import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/app/app_services.dart';
import 'package:intellispendiq/senders/senders.dart';

import '../../support/test_harness.dart';

void main() {
  late AppServices services;

  Future<CustomSendersCubit> cubitWith() async {
    services = await createTestServices();
    addTearDown(services.dispose);
    final cubit = CustomSendersCubit(services.customSenders, services.registry);
    await cubit.load();
    await Future<void>.delayed(Duration.zero);
    return cubit;
  }

  group('CustomSendersCubit', () {
    test('starts empty', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);

      expect(cubit.state.senders, isEmpty);
    });

    test(
      'add() persists a sender and routes it in the live registry',
      () async {
        final cubit = await cubitWith();
        addTearDown(cubit.close);

        await cubit.add(providerKey: 'stan_chart', senderId: 'StanChartZM');
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.senders, hasLength(1));
        expect(cubit.state.senders.single.providerKey, 'stan_chart');
        expect(cubit.state.senders.single.senderId, 'stanchartzm');
        expect(
          services.registry.findBySender('StanChartZM')?.key,
          'stan_chart',
        );
      },
    );

    test('add() rejects an empty sender id', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);

      await cubit.add(providerKey: 'stan_chart', senderId: '   ');

      expect(cubit.state.status, CustomSendersStatus.invalid);
      expect(cubit.state.senders, isEmpty);
    });

    test('delete() removes it from storage and the live registry', () async {
      final cubit = await cubitWith();
      addTearDown(cubit.close);
      await cubit.add(providerKey: 'airtel_money', senderId: '90210');
      await Future<void>.delayed(Duration.zero);
      final sender = cubit.state.senders.single;

      await cubit.delete(sender);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.senders, isEmpty);
      expect(services.registry.findBySender('90210'), isNull);
    });
  });
}
