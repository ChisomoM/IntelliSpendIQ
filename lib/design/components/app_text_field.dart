import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intellispendiq/design/tokens/typography.dart';

/// A themed text field. `AppTheme.inputDecorationTheme` already carries
/// the border, focus ring and label colour; this widget standardises
/// the body text style and gives call sites one name to reach for
/// instead of hand-building `TextField` + `InputDecoration` per screen.
class AppTextField extends StatelessWidget {
  const AppTextField({
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppTypography.body(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        errorText: errorText,
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

/// A large, mono-styled field for entering an amount — the one field
/// on the entry sheet that should not look like every other field.
/// The keypad-driven redesign described in the redesign plan's Phase 4
/// is a separate, larger change; this is the field shell it will sit
/// behind.
class AmountField extends StatelessWidget {
  const AmountField({
    required this.controller,
    this.errorText,
    this.autofocus = false,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      autofocus: autofocus,
      textAlign: TextAlign.center,
      style: AppTypography.balanceDisplay(color: colors.onSurface),
      decoration: InputDecoration(
        prefixText: 'K',
        prefixStyle: AppTypography.balanceDisplay(color: colors.onSurfaceVariant),
        border: InputBorder.none,
        errorText: errorText,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
      ],
      onChanged: onChanged,
    );
  }
}
