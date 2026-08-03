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
    this.prefixText,
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
  final String? prefixText;
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
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      style: AppTypography.body(color: colors.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixStyle: prefixText == null
            ? null
            : AppTypography.body(color: colors.onSurfaceVariant),
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

/// Amount entry — same size and chrome as [AppTextField], with a `K`
/// prefix and a decimal keypad. No special display sizing.
class AmountField extends StatelessWidget {
  const AmountField({
    required this.controller,
    this.label = 'Amount',
    this.errorText,
    this.autofocus = false,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: label,
      prefixText: 'K ',
      errorText: errorText,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
      ],
      onChanged: onChanged,
    );
  }
}
