import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:c_template_app/app/theme/theme.dart';
import 'package:c_template_app/utils/utils.dart';

export 'package:flutter_bloc/flutter_bloc.dart';

export 'color_schemes.g.dart';
export 'theme_cubit.dart';

/// {@template app_theme}
/// The Default App [ThemeData].
/// {@endtemplate}
class AppTheme {
  /// {@macro app_theme}
  const AppTheme();

  /// Default `ThemeData` for App UI.
  ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: _textTheme,
      colorScheme: _colorScheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      filledButtonTheme: _filledButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      bottomSheetTheme: _bottomSheetTheme,
    );
  }

  // TextTheme get _textTheme {
  // return GoogleFonts.manropeTextTheme(
  // ThemeData(brightness: Brightness.light).textTheme,
  // );
  // }
  TextTheme get _textTheme {
    return GoogleFonts.ubuntuTextTheme(
      ThemeData(brightness: Brightness.light).textTheme,
    );
  }

  ColorScheme get _colorScheme => lightColorScheme;

  FilledButtonThemeData get _filledButtonTheme {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kAppCornerRadius),
        ),
      ),
    );
  }

  OutlinedButtonThemeData get _outlinedButtonTheme {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kAppCornerRadius),
        ),
      ),
    );
  }

  ElevatedButtonThemeData get _elevatedButtonTheme {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kAppCornerRadius),
        ),
      ),
    );
  }

  BottomSheetThemeData get _bottomSheetTheme {
    return BottomSheetThemeData(surfaceTintColor: lightColorScheme.surface);
  }
}

/// {@template app_dark_theme}
/// Dark Mode App [ThemeData].
/// {@endtemplate}
class AppDarkTheme extends AppTheme {
  /// {@macro app_dark_theme}
  const AppDarkTheme();

  @override
  ColorScheme get _colorScheme => darkColorScheme;

  @override
  TextTheme get _textTheme {
    return GoogleFonts.manropeTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );
  }

  @override
  BottomSheetThemeData get _bottomSheetTheme {
    return BottomSheetThemeData(surfaceTintColor: darkColorScheme.surface);
  }
}

InputDecoration kTextFieldDecoration = InputDecoration(
  isDense: false,
  hintText: 'Required',
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(
      color: Theme.of(navKey.currentContext!).dividerColor,
    ),
  ),
  filled: true,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(
      color: Theme.of(navKey.currentContext!).dividerColor,
    ),
  ),
  fillColor: Theme.of(navKey.currentContext!).colorScheme.onPrimary,
  focusedBorder: OutlineInputBorder(
    borderSide: BorderSide(
      color: Theme.of(navKey.currentContext!).dividerColor,
    ),
  ),
  hintStyle: TextStyle(
    fontSize: 14, // Change font size
    fontWeight: FontWeight.w400, // Adjust weight
    fontStyle: FontStyle.italic, // Change style to italic
    color: Theme.of(
      navKey.currentContext!,
    ).colorScheme.secondary.withValues(alpha: 0.5),
  ),
  contentPadding: const EdgeInsets.only(top: 16, left: 8),
  prefixIconConstraints: const BoxConstraints(minHeight: 50),
);

final buttonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(14),
);
const buttonSize = Size.fromHeight(50);
