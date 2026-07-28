part of 'main_cubit.dart';

/// {@template main}
/// MainState description
/// {@endtemplate}
class MainState extends Equatable {
  /// {@macro main}
  const MainState({
    this.message = 'Default Value',
    this.currentIndex = 0,
    this.status = CurrentStatus.initial,
  });

  /// A description for message
  final String message;
  final int currentIndex;
  final CurrentStatus status;

  @override
  List<Object> get props => [message, currentIndex, status];

  /// Creates a copy of the current MainState with property changes
  MainState copyWith({
    String? message,
    int? currentIndex,
    CurrentStatus? status,
  }) {
    return MainState(
      message: message ?? this.message,
      currentIndex: currentIndex ?? this.currentIndex,
      status: status ?? this.status,
    );
  }
}
