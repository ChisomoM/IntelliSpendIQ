import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:c_template_app/utils/utils.dart';

class PasswordField extends StatefulWidget {
  const PasswordField(
    this.controller, {
    super.key,
    this.obscureText = true,
    this.onCompleted,
    this.validator,
    this.hintText = 'Enter password',
    this.isLoading = false,
  });

  final TextEditingController controller;
  final bool obscureText;
  final void Function(String)? onCompleted;
  final String? Function(String?)? validator;
  final String hintText;
  final bool isLoading;

  @override
  PasswordFieldState createState() => PasswordFieldState();

  @override
  String toStringShort() => 'Password Field';
}

class PasswordFieldState extends State<PasswordField> {
  final focusNode = FocusNode();
  bool _showPassword = false;

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: focusNode,
      obscureText: widget.obscureText && !_showPassword,
      enabled: !widget.isLoading,
      decoration: InputDecoration(
        hintText: widget.hintText,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kAppCornerRadius),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: widget.isLoading
                    ? null
                    : () {
                        setState(() {
                          _showPassword = !_showPassword;
                        });
                      },
              )
            : null,
      ),
      style: GoogleFonts.lato(
        fontSize: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onFieldSubmitted: widget.onCompleted,
      validator: widget.validator,
      textInputAction: TextInputAction.done,
    );
  }
}
