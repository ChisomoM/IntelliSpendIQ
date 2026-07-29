import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intellispendiq/data/repositories/app_lock_repository.dart';

/// Obscured numeric PIN input.
///
/// Deliberately a real [TextField] rather than a custom keypad: it gets
/// the platform's secure input handling, accessibility, and hardware
/// keyboard support for free.
class PinEntryField extends StatefulWidget {
  const PinEntryField({
    required this.value,
    required this.onChanged,
    required this.onSubmitted,
    this.enabled = true,
    this.autofocus = true,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final bool enabled;
  final bool autofocus;

  @override
  State<PinEntryField> createState() => _PinEntryFieldState();
}

class _PinEntryFieldState extends State<PinEntryField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(PinEntryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The cubit clears the PIN after every attempt; mirror that here
    // without stomping on the caret while the user is mid-type.
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      obscureText: true,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      textAlign: TextAlign.center,
      maxLength: AppLockRepository.maxPinLength,
      style: const TextStyle(fontSize: 28, letterSpacing: 12),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        counterText: '',
        hintText: '••••',
        hintStyle: TextStyle(letterSpacing: 12),
      ),
      onChanged: widget.onChanged,
      onSubmitted: (_) => widget.onSubmitted(),
    );
  }
}
