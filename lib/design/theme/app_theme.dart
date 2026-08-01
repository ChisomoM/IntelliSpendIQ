import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intellispendiq/design/theme/capture_colors.dart';
import 'package:intellispendiq/design/theme/money_colors.dart';
import 'package:intellispendiq/design/tokens/colors.dart';
import 'package:intellispendiq/design/tokens/radii.dart';
import 'package:intellispendiq/design/tokens/typography.dart';

/// Light and dark [ThemeData], built from the token files rather than
/// `ColorScheme.fromSeed` — the brand guide restricts specific roles
/// (cyan on dark surfaces only, violet at most twice a screen) that a
/// generated scheme can't express.
///
/// `useMaterial3` is on; dynamic colour / Material You harmonisation is
/// deliberately never enabled — brand colours are fixed regardless of
/// device wallpaper.
abstract final class AppTheme {
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.violet600,
    onPrimary: AppColors.paper,
    secondary: AppColors.violet700,
    onSecondary: AppColors.paper,
    error: AppColors.outflow,
    onError: AppColors.paper,
    surface: AppColors.paper,
    onSurface: AppColors.ink900,
    surfaceContainerLow: AppColors.ink050,
    surfaceContainerHigh: AppColors.ink100,
    onSurfaceVariant: AppColors.ink400,
    outline: AppColors.ink300,
    outlineVariant: AppColors.ink200,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.cyan300,
    onPrimary: AppColors.ink900,
    secondary: AppColors.violet300,
    onSecondary: AppColors.ink900,
    error: AppColors.outflowD,
    onError: AppColors.ink900,
    surface: AppColors.night900,
    onSurface: AppColors.nightText,
    surfaceContainerLow: AppColors.night800,
    surfaceContainerHigh: AppColors.night700,
    onSurfaceVariant: AppColors.nightText2,
    outline: AppColors.nightLine,
    outlineVariant: AppColors.nightLine,
  );

  static ThemeData get light => _build(_lightScheme, [MoneyColors.light, CaptureColors.light]);

  static ThemeData get dark => _build(_darkScheme, [MoneyColors.dark, CaptureColors.dark]);

  static ThemeData _build(
    ColorScheme scheme,
    List<ThemeExtension<dynamic>> extensions,
  ) {
    final isDark = scheme.brightness == Brightness.dark;

    // Baseline for anything not explicitly styled through
    // AppTypography (dialogs, default widgets); the roles actually
    // used across the app are overridden below with the exact scale.
    final materialDefaults = ThemeData(
      brightness: scheme.brightness,
      useMaterial3: true,
    ).textTheme;
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      materialDefaults,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    final textTheme = baseTextTheme.copyWith(
      titleLarge: AppTypography.screenTitle(color: scheme.onSurface),
      titleMedium: AppTypography.sectionHeader(color: scheme.onSurface),
      titleSmall: AppTypography.rowTitle(color: scheme.onSurface),
      bodyLarge: AppTypography.body(color: scheme.onSurface),
      bodyMedium: AppTypography.body(color: scheme.onSurface),
      // The 13px floor: nothing in the app should render metadata
      // smaller than this, and bodySmall is what most screens reach
      // for when they want "small text".
      bodySmall: AppTypography.metadata(color: scheme.onSurfaceVariant),
      labelMedium: AppTypography.metadata(color: scheme.onSurfaceVariant),
      labelSmall: AppTypography.metadata(color: scheme.onSurfaceVariant),
      // Both of these are used exclusively for large money figures
      // today — see docs/REDESIGN_PLAN.md §1.1. Phase 3+ replaces the
      // call sites with MoneyText directly; this keeps them correct
      // (mono, tabular) in the meantime.
      headlineMedium: AppTypography.balanceDisplay(color: scheme.onSurface),
      headlineSmall: AppTypography.balanceDisplay(color: scheme.onSurface),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      // The page plane sits *below* the cards, so cards can be white
      // and still read as lifted. Previously both were white and the
      // border was the only thing separating them.
      scaffoldBackgroundColor: isDark
          ? scheme.surface
          : scheme.surfaceContainerLow,
      textTheme: textTheme,
      extensions: extensions,
      splashFactory: InkSparkle.splashFactory,
      // Elevation is surface lightness in dark mode, never a shadow —
      // every card and app bar below sets elevation: 0 accordingly.
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTypography.screenTitle(color: scheme.onSurface),
      ),
      // No outline in light mode: the 1px border drew a hard rectangle
      // around every group and made a scroll read as a stack of boxes.
      // AppCard carries the shadow; dark mode keeps a hairline because
      // a shadow on near-black does nothing.
      cardTheme: CardThemeData(
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.cardRadius,
          side: isDark
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLow,
        selectedColor: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.12),
        labelStyle: AppTypography.metadata(color: scheme.onSurface),
        secondaryLabelStyle: AppTypography.metadata(color: scheme.primary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        showCheckmark: false,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainerLow : scheme.surface,
        border: OutlineInputBorder(
          borderRadius: Radii.inputRadius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.inputRadius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.inputRadius,
          borderSide: BorderSide(color: scheme.secondary, width: 2),
        ),
        hintStyle: AppTypography.body(color: scheme.onSurfaceVariant),
        labelStyle: AppTypography.body(color: scheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          textStyle: AppTypography.rowTitle(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outline),
          textStyle: AppTypography.rowTitle(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: AppTypography.rowTitle(),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: Radii.fabShape,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? scheme.surfaceContainerLow : scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.secondary.withValues(alpha: isDark ? 0.24 : 0.12),
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.metadata(color: scheme.onSurface),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheetRadius),
      ),
      // Per the guide's component table: ink900 fill / white label in
      // light mode, night700 fill / nightText label in dark — the
      // snackbar surface is always dark chrome regardless of theme, so
      // it is spelled out here rather than derived from `scheme`.
      // violet300 as the action colour is the guide's one explicit
      // carve-out to the "never on a light surface" rule, because this
      // surface itself is dark even in light mode.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.night700 : AppColors.ink900,
        contentTextStyle: AppTypography.body(
          color: isDark ? AppColors.nightText : AppColors.paper,
        ),
        actionTextColor: AppColors.violet300,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: Radii.cardRadius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: Radii.cardRadius),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
    );
  }
}
