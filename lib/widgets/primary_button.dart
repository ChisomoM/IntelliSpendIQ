import 'package:flutter/material.dart';
import 'package:c_template_app/widgets/loader.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.text,
    this.margin = EdgeInsets.zero,
    this.isLoading = false,
    this.onPressed,
    this.buttonStyle,
    super.key,
  });

  final String text;
  final dynamic Function()? onPressed;
  final ButtonStyle? buttonStyle;
  final bool isLoading;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: FilledButton(
        style:
            buttonStyle ??
            FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading ? const Loader() : Text(text),
      ),
    );
  }
}
