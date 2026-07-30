import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intellispendiq/data/repositories/custom_sender_repository.dart';
import 'package:intellispendiq/domain/models/custom_sender.dart';
import 'package:intellispendiq/domain/parsers/parser_registry.dart';

part 'custom_senders_state.dart';

/// Lets the user teach the SMS capture pipeline a sender ID it doesn't
/// already recognize — e.g. a bank's alert shortcode — by routing it
/// to an existing provider parser. Kept in sync with the live
/// [ParserRegistry] as well as persisted, so a sender added mid-session
/// starts being recognized immediately, not just after restart.
class CustomSendersCubit extends Cubit<CustomSendersState> {
  CustomSendersCubit(this._senders, this._registry)
    : super(const CustomSendersState());

  final CustomSenderRepository _senders;
  final ParserRegistry _registry;
  StreamSubscription<List<CustomSender>>? _subscription;

  void loadUnawaited() => unawaited(load());

  Future<void> load() async {
    emit(state.copyWith(status: CustomSendersStatus.loading));
    await _subscription?.cancel();
    _subscription = _senders.watchAll().listen(
      (rows) => emit(
        state.copyWith(status: CustomSendersStatus.loaded, senders: rows),
      ),
    );
  }

  Future<void> add({
    required String providerKey,
    required String senderId,
  }) async {
    final trimmed = senderId.trim();
    if (trimmed.isEmpty) {
      emit(
        state.copyWith(
          status: CustomSendersStatus.invalid,
          errorMessage: 'Enter the sender ID from the SMS',
        ),
      );
      return;
    }
    await _senders.add(providerKey: providerKey, senderId: trimmed);
    _registry.addCustomSender(providerKey, trimmed);
  }

  Future<void> delete(CustomSender sender) async {
    await _senders.delete(sender.id);
    _registry.removeCustomSender(sender.senderId);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
