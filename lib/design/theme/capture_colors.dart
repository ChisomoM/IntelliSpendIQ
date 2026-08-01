import 'package:flutter/material.dart';
import 'package:intellispendiq/design/tokens/colors.dart';

/// Where a transaction came from — SMS, voice, or typed by hand.
enum CaptureSource { sms, voice, manual }

/// Fill, label and dot colour for one [CaptureSource]'s chip.
class SourceChipColors {
  const SourceChipColors({
    required this.fill,
    required this.label,
    required this.dot,
  });

  final Color fill;
  final Color label;
  final Color dot;
}

/// Colours for the capture & confidence system (brand guide §5) — the
/// part of the design language specific to this app rather than a
/// generic Material role.
///
/// The guide gives light-mode chip colours per source and states that
/// in dark mode "chips become `night700` fill with `violet300` label"
/// — one rule for all three sources. Dot colours are not specified for
/// dark mode; the values below extrapolate from the light-mode
/// relationship between each source's dot and its label.
class CaptureColors extends ThemeExtension<CaptureColors> {
  const CaptureColors({
    required this.sms,
    required this.voice,
    required this.manual,
    required this.uncertainField,
  });

  static const light = CaptureColors(
    sms: SourceChipColors(
      fill: AppColors.ink100,
      label: AppColors.ink700,
      dot: AppColors.ink500,
    ),
    voice: SourceChipColors(
      fill: AppColors.violet100,
      label: AppColors.violet700,
      dot: AppColors.violet600,
    ),
    manual: SourceChipColors(
      fill: AppColors.ink100,
      label: AppColors.ink700,
      dot: AppColors.ink300,
    ),
    uncertainField: AppColors.review,
  );

  static const dark = CaptureColors(
    sms: SourceChipColors(
      fill: AppColors.night700,
      label: AppColors.violet300,
      dot: AppColors.nightText2,
    ),
    voice: SourceChipColors(
      fill: AppColors.night700,
      label: AppColors.violet300,
      dot: AppColors.violet300,
    ),
    manual: SourceChipColors(
      fill: AppColors.night700,
      label: AppColors.violet300,
      dot: AppColors.nightLine,
    ),
    uncertainField: AppColors.reviewD,
  );

  final SourceChipColors sms;
  final SourceChipColors voice;
  final SourceChipColors manual;

  /// Dotted-underline colour for a field the app guessed. Kept
  /// separate from [MoneyColors.review] so a future chip-only palette
  /// change can't accidentally move this too.
  final Color uncertainField;

  SourceChipColors forSource(CaptureSource source) => switch (source) {
    CaptureSource.sms => sms,
    CaptureSource.voice => voice,
    CaptureSource.manual => manual,
  };

  @override
  CaptureColors copyWith({
    SourceChipColors? sms,
    SourceChipColors? voice,
    SourceChipColors? manual,
    Color? uncertainField,
  }) {
    return CaptureColors(
      sms: sms ?? this.sms,
      voice: voice ?? this.voice,
      manual: manual ?? this.manual,
      uncertainField: uncertainField ?? this.uncertainField,
    );
  }

  @override
  CaptureColors lerp(ThemeExtension<CaptureColors>? other, double t) {
    if (other is! CaptureColors) return this;
    Color dot(Color a, Color b) => Color.lerp(a, b, t)!;
    SourceChipColors lerpChip(SourceChipColors a, SourceChipColors b) =>
        SourceChipColors(
          fill: dot(a.fill, b.fill),
          label: dot(a.label, b.label),
          dot: dot(a.dot, b.dot),
        );
    return CaptureColors(
      sms: lerpChip(sms, other.sms),
      voice: lerpChip(voice, other.voice),
      manual: lerpChip(manual, other.manual),
      uncertainField: dot(uncertainField, other.uncertainField),
    );
  }
}
