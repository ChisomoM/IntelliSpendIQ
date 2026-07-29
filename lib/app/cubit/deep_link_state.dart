part of 'deep_link_cubit.dart';

class DeepLinkState extends Equatable {
  const DeepLinkState({this.pending});

  /// The destination awaiting navigation, or null when there is
  /// nothing outstanding.
  final DeepLink? pending;

  bool get hasPending => pending != null;

  @override
  List<Object?> get props => [pending];
}
