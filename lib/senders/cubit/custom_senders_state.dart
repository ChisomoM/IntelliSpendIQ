part of 'custom_senders_cubit.dart';

enum CustomSendersStatus { initial, loading, loaded, invalid }

class CustomSendersState extends Equatable {
  const CustomSendersState({
    this.status = CustomSendersStatus.initial,
    this.senders = const [],
    this.errorMessage,
  });

  final CustomSendersStatus status;
  final List<CustomSender> senders;
  final String? errorMessage;

  bool get isEmpty => status == CustomSendersStatus.loaded && senders.isEmpty;

  CustomSendersState copyWith({
    CustomSendersStatus? status,
    List<CustomSender>? senders,
    String? errorMessage,
  }) {
    return CustomSendersState(
      status: status ?? this.status,
      senders: senders ?? this.senders,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, senders, errorMessage];
}
