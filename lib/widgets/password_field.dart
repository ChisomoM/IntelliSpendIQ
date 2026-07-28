import 'package:flutter/material.dart';
import 'package:c_template_app/app/theme/theme.dart';

class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.onChanged,
    super.key,
    this.label = 'Password',
    this.error,
  });

  final String label;
  final String? error;
  final void Function(String?)? onChanged;

  @override
  State<PasswordField> createState() => PasswordFieldState();
}

class PasswordFieldState extends State<PasswordField> {
  bool _hidePassword = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      onChanged: widget.onChanged,
      keyboardType: TextInputType.visiblePassword,
      obscureText: _hidePassword,
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          return null;
        }
        return widget.error ?? 'Password is required';
      },
      decoration: kTextFieldDecoration.copyWith(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        suffixIconConstraints: const BoxConstraints(
          minHeight: 24,
          minWidth: 24,
        ),
        suffixIcon: IconButton(
          splashRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: Icon(
            _hidePassword ? Icons.visibility : Icons.visibility_off,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _hidePassword = !_hidePassword;
            });
          },
        ),
      ),
    );
  }
}
