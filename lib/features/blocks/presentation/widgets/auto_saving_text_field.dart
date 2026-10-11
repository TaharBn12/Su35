import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDownEvent;
import 'package:flutter/material.dart';

/// حقل نص يحفظ بعد توقّف الكتابة (debounce) — يُستخدم في كل كتل النص البسيطة:
/// العنوان، الاقتباس، التنبيه، الكود، وخلايا الجدول.
///
/// المبدأ: النص يُبلَّغ للأب بعد 250 مللي ثانية من التوقّف، فلا تُثقل قاعدة
/// البيانات بكل ضغطة زر، ويتزامن الحقل مع تغييرات خارجية (إعادة تحميل/تراجع)
/// طالما ليس عليه تركيز.
class AutoSavingTextField extends StatefulWidget {
  const AutoSavingTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hintText,
    this.maxLines = 1,
    this.textStyle,
    this.monospace = false,
    this.textDirection,
    this.textCapitalization = TextCapitalization.sentences,
    this.filled = true,
    this.isDense = false,
    this.onSubmitted,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final int maxLines;
  final TextStyle? textStyle;

  /// خط ثابت العرض (للكود وخلايا الجداول الرقمية).
  final bool monospace;
  final TextDirection? textDirection;
  final TextCapitalization textCapitalization;

  /// خلفية خفيفة تُظهر حدود الحقل (تُطفأ داخل الجداول).
  final bool filled;
  final bool isDense;
  final VoidCallback? onSubmitted;

  @override
  State<AutoSavingTextField> createState() => _AutoSavingTextFieldState();
}

class _AutoSavingTextFieldState extends State<AutoSavingTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void didUpdateWidget(covariant AutoSavingTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus) {
      return; // لا نُزعج المستخدم أثناء الكتابة
    }
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  void _handleChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }
      widget.onChanged(text);
    });
  }

  void _flush() {
    _debounce?.cancel();
    if (_controller.text != widget.value) {
      widget.onChanged(_controller.text);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle baseStyle = widget.textStyle ??
        theme.textTheme.bodyLarge!.copyWith(height: 1.5);

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: widget.maxLines,
      style: widget.monospace
          ? baseStyle.copyWith(fontFamily: 'monospace', fontSize: (baseStyle.fontSize ?? 15) - 0.5)
          : baseStyle,
      textDirection: widget.textDirection,
      textCapitalization: widget.textCapitalization,
      onChanged: _handleChanged,
      onEditingComplete: _flush,
      onTapOutside: (PointerDownEvent event) => _focusNode.unfocus(),
      textInputAction:
          widget.maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
      decoration: InputDecoration(
        hintText: widget.hintText,
        isDense: widget.isDense,
        filled: widget.filled,
        fillColor: widget.filled
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : null,
        border: widget.filled ? null : InputBorder.none,
        contentPadding: widget.filled
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
            : EdgeInsets.zero,
      ),
    );
  }
}
