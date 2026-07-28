part of 'home_cubit.dart';

enum HomeStatus {
  initial,
  loading,
  success,
  failure,
}

/// {@template home}
/// HomeState description
/// {@endtemplate}
class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
  });

  final HomeStatus status;

  @override
  List<Object> get props => [status];

  HomeState copyWith({
    HomeStatus? status,
  }) {
    return HomeState(
      status: status ?? this.status,
    );
  }
}
