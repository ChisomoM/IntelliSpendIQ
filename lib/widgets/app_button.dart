import 'package:flutter/material.dart';
import 'package:c_template_app/app/theme/theme.dart';

enum ButtonType { filled, elevated, outlined, text }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.text,
    super.key,
    this.loading = false,
    this.showTrailingIcon = false,
    this.icon = Icons.arrow_forward,
    this.loadingText = 'Loading...',
    this.onPressed,
    this.type = ButtonType.filled,
  });

  final bool loading;
  final bool showTrailingIcon;
  final String text;
  final String loadingText;
  final IconData icon;
  final VoidCallback? onPressed;
  final ButtonType type;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!loading) ...[
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Ubuntu',
              fontSize: 16,
            ),
          ),
        ],
        if (showTrailingIcon) const Spacer(),
        if (loading)
          const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2.5),
          )
        else ...[
          if (showTrailingIcon) Icon(icon),
        ],
      ],
    );
    switch (type) {
      case ButtonType.filled:
        return FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: buttonSize,
            shape: buttonShape,
          ),
          onPressed: loading ? null : onPressed,
          child: child,
        );
      case ButtonType.elevated:
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: buttonSize,
            shape: buttonShape,
          ),
          onPressed: loading ? null : onPressed,
          child: child,
        );
      case ButtonType.outlined:
        return OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: buttonSize,
            shape: buttonShape,
          ),
          onPressed: loading ? null : onPressed,
          child: child,
        );
      case ButtonType.text:
        return TextButton(
          style: TextButton.styleFrom(
            minimumSize: buttonSize,
            shape: buttonShape,
          ),
          onPressed: loading ? null : onPressed,
          child: child,
        );
    }
  }
}
