part of 'splash_cubit.dart';

class SplashState extends Equatable {
  const SplashState({required this.isLoading});

  factory SplashState.loading() => const SplashState(isLoading: true);
  factory SplashState.loaded() => const SplashState(isLoading: false);
  final bool isLoading;

  @override
  List<Object?> get props => [isLoading];
}
