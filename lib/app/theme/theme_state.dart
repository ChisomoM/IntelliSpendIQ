part of 'theme_cubit.dart';

/// {@template theme}
/// ThemeState description
/// {@endtemplate}
class ThemeState extends Equatable {
  /// {@macro theme}
  const ThemeState({this.mode = ThemeMode.system, this.isDark = false});

  final ThemeMode mode;
  final bool isDark;

  @override
  List<Object> get props => [mode, isDark];

  /// Creates a copy of the current ThemeState with property changes
  ThemeState copyWith({ThemeMode? mode, bool? isDark}) {
    return ThemeState(
      mode: mode ?? this.mode,
      isDark: isDark ?? this.isDark,
    );
  }
}
