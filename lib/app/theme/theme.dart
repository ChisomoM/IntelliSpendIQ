import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intellispendiq/app/theme/money_colors.dart';
import 'package:intellispendiq/app/theme/tokens.dart';
import 'package:intellispendiq/app/theme/typography.dart';

/// The app theme, built from fixed brand tokens.
///
/// Material 3 is on, but dynamic colour and Material You harmonisation
/// are deliberately **off** — the brand colours are fixed, and letting
/// the platform tint them would break the contrast guarantees each token
/// was chosen for.
///
/// The two brightnesses are not mirror images. Light mode gets a
/// hairline plus a very soft shadow; **dark mode is `elevation: 0`
/// everywhere** and expresses depth as surface lightness instead
/// (`night800` cards on a `night900` page, `night700` for sheets and
/// menus). A shadow on a near-black surface reads as dirt.
abstract final class AppTheme {
  static ThemeData get light => _build(_lightScheme, MoneyColors.light);

  static ThemeData get dark => _build(_darkScheme, MoneyColors.dark);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.violet600,
    onPrimary: AppColors.paper,
    primaryContainer: AppColors.violet100,
    onPrimaryContainer: AppColors.violet700,
    secondary: AppColors.violet700,
    onSecondary: AppColors.paper,
    secondaryContainer: AppColors.violet100,
    onSecondaryContainer: AppColors.violet700,
    tertiary: AppColors.inflowLight,
    onTertiary: AppColors.paper,
    error: AppColors.outflowLight,
    onError: AppColors.paper,
    errorContainer: Color(0xFFFCE9E7),
    onErrorContainer: AppColors.outflowLight,
    surface: AppColors.paper,
    onSurface: AppColors.ink900,
    surfaceContainerLowest: AppColors.paper,
    surfaceContainerLow: AppColors.ink050,
    surfaceContainer: AppColors.ink050,
    surfaceContainerHigh: AppColors.ink100,
    surfaceContainerHighest: AppColors.ink100,
    onSurfaceVariant: AppColors.ink400,
    outline: AppColors.ink300,
    outlineVariant: AppColors.ink200,
    inverseSurface: AppColors.ink900,
    onInverseSurface: AppColors.paper,
    inversePrimary: AppColors.violet300,
    shadow: AppColors.ink900,
    scrim: AppColors.ink900,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.cyan300,
    onPrimary: AppColors.ink900,
    primaryContainer: AppColors.night700,
    onPrimaryContainer: AppColors.cyan300,
    secondary: AppColors.violet300,
    onSecondary: AppColors.ink900,
    secondaryContainer: AppColors.night700,
    onSecondaryContainer: AppColors.violet300,
    tertiary: AppColors.inflowDark,
    onTertiary: AppColors.ink900,
    error: AppColors.outflowDark,
    onError: AppColors.ink900,
    errorContainer: Color(0xFF3B1D1B),
    onErrorContainer: AppColors.outflowDark,
    surface: AppColors.night900,
    onSurface: AppColors.nightText,
    surfaceContainerLowest: AppColors.night900,
    surfaceContainerLow: AppColors.night800,
    surfaceContainer: AppColors.night800,
    surfaceContainerHigh: AppColors.night700,
    surfaceContainerHighest: AppColors.night700,
    onSurfaceVariant: AppColors.nightText2,
    outline: AppColors.nightLineStrong,
    outlineVariant: AppColors.nightLine,
    inverseSurface: AppColors.nightText,
    onInverseSurface: AppColors.ink900,
    inversePrimary: AppColors.violet600,
    shadow: Color(0x00000000),
    scrim: Color(0xFF000000),
  );

  static ThemeData _build(ColorScheme scheme, MoneyColors money) {
    final isDark = scheme.brightness == Brightness.dark;
    final text = AppText.themeFor(scheme.onSurface, scheme.onSurfaceVariant);

    // In light mode the page sits a step below the cards so a white card
    // reads as raised without a shadow doing the work. In dark mode the
    // page is the darkest surface for the same reason, inverted.
    final pageBackground = isDark ? AppColors.night900 : AppColors.ink050;
    final cardBackground = isDark ? AppColors.night800 : AppColors.paper;
    final sheetBackground = isDark ? AppColors.night700 : AppColors.paper;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Off by construction: this is a `const ColorScheme`, not
      // `fromSeed`, so nothing is harmonised against a wallpaper.
      textTheme: text,
      fontFamily: AppFonts.sans,
      scaffoldBackgroundColor: pageBackground,
      canvasColor: pageBackground,
      dividerColor: scheme.outlineVariant,
      extensions: [money],

      appBarTheme: AppBarTheme(
        backgroundColor: pageBackground,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.screenTitle.copyWith(color: scheme.onSurface),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardThemeData(
        color: cardBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // Radius 18 rounded rectangle, not a circle.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: isDark ? 0 : 2,
        focusElevation: isDark ? 0 : 2,
        hoverElevation: isDark ? 0 : 2,
        highlightElevation: isDark ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.fab),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: AppText.button,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          textStyle: AppText.button,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.secondary,
          textStyle: AppText.button,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(48, 48),
        ),
      ),

      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.night800 : AppColors.paper,
        hintStyle: AppText.field.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: AppText.label.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: AppText.metadata.copyWith(color: scheme.onSurfaceVariant),
        errorStyle: AppText.metadata.copyWith(color: money.outflow),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
        border: _inputBorder(scheme.outline),
        enabledBorder: _inputBorder(scheme.outline),
        // 2px focus ring, in the link colour rather than the fill
        // colour, so focus never reads as a filled state.
        focusedBorder: _inputBorder(scheme.secondary, width: 2),
        errorBorder: _inputBorder(money.outflow),
        focusedErrorBorder: _inputBorder(money.outflow, width: 2),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: isDark ? AppColors.night700 : AppColors.violet100,
        side: BorderSide.none,
        labelStyle: AppText.label.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: AppText.label.copyWith(color: scheme.secondary),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        shape: const StadiumBorder(),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheetBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Radii.sheet),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: sheetBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppText.sectionHeader.copyWith(
          color: scheme.onSurface,
        ),
        contentTextStyle: AppText.body.copyWith(color: scheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sheet),
        ),
      ),

      // Snackbar is the undo surface: ink in light, the sheet surface in
      // dark, with the action always in violet.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.night700 : AppColors.ink900,
        contentTextStyle: AppText.body.copyWith(
          color: isDark ? AppColors.nightText : AppColors.paper,
        ),
        actionTextColor: AppColors.violet300,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.night800 : AppColors.paper,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppText.overline.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.secondary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.secondary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: AppText.rowTitle.copyWith(color: scheme.onSurface),
        subtitleTextStyle: AppText.metadata.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        minVerticalPadding: Space.md,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.secondary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          textStyle: AppText.label,
          selectedBackgroundColor: isDark
              ? AppColors.night700
              : AppColors.violet100,
          selectedForegroundColor: scheme.secondary,
          side: BorderSide(color: scheme.outline),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button),
          ),
        ),
      ),

      splashFactory: InkSparkle.splashFactory,
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.input),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
