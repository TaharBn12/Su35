import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/utils/validators.dart';

/// A labelled text field with built-in translation of validator keys.
///
/// `validator` returns a *translation key* (see [Validators]) or `null`; this
/// widget resolves it against the active language so forms stay localizable.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.label,
    super.key,
    this.controller,
    this.hint,
    this.initialValue,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.keyboardType,
    this.maxLength,
    this.maxLines = 1,
    this.prefixIcon,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.validatorKey,
    this.onChanged,
    this.onSubmitted,
    this.textDirection,
    this.suffix,
    this.autofillHints,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? initialValue;
  final bool obscure;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int maxLines;
  final IconData? prefixIcon;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  /// `String? Function(String? value)` returning a translation key or null.
  final String? Function(String? value)? validatorKey;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Force LTR for emails/codes even when the app is in Arabic (RTL).
  final TextDirection? textDirection;
  final Widget? suffix;
  final Iterable<String>? autofillHints;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscure;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return TextFormField(
      controller: widget.controller,
      initialValue: widget.controller == null ? widget.initialValue : null,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      obscureText: widget.obscure && _obscured,
      textInputAction: widget.textInputAction,
      keyboardType: widget.keyboardType ??
          (widget.obscure ? TextInputType.visiblePassword : TextInputType.text),
      maxLength: widget.maxLength,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      textDirection: widget.textDirection,
      style: Theme.of(context).textTheme.bodyLarge,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validatorKey == null
          ? null
          : (value) {
              final key = widget.validatorKey!(value);
              if (key == null) return null;
              return t.get(key);
            },
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(widget.prefixIcon, size: 20),
        suffixIcon: _buildSuffix(),
        counterText: '',
      ),
    );
  }

  Widget? _buildSuffix() {
    if (widget.obscure) {
      return IconButton(
        tooltip: _obscured ? 'Show' : 'Hide',
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
        ),
      );
    }
    return widget.suffix;
  }
}
