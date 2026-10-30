import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Labelled text field with validation, used on every form.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.validator,
    this.keyboardType,
    this.obscure = false,
    this.maxLength,
    this.digitsOnly = false,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.serverError,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscure;
  final int? maxLength;
  final bool digitsOnly;
  final bool enabled;
  final TextInputAction textInputAction;

  /// Error text coming from the server for this field (shown until the user edits it).
  final String? serverError;
  final ValueChanged<String>? onChanged;

  /// Called when the user presses Enter / the keyboard's "done" key. Give it to the LAST field of a form so Enter
  /// submits the form just like the button does.
  final VoidCallback? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      maxLength: widget.maxLength,
      onChanged: widget.onChanged,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      inputFormatters: [if (widget.digitsOnly) FilteringTextInputFormatter.digitsOnly],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (v) => widget.validator?.call(v) ?? widget.serverError,
      decoration: InputDecoration(
        labelText: widget.label,
        counterText: '',
        prefixIcon: widget.icon == null ? null : Icon(widget.icon),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}
