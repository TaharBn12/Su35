import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../../l10n/l10n.dart';
import '../../application/rich_text_registry.dart';
import '../../domain/block_content.dart';

/// محرّر النص الغني لكتلة «نص» (Quill).
///
/// كل كتلة نصية لها `QuillController` و`FocusNode` مستقلّان، ويُسجَّلان في
/// [RichTextRegistry] حتى يعرف شريط الأدوات في أسفل الشاشة أي كتلة يتحكّم بها.
/// الكتابة تُبلَّغ للأب بعد توقّف قصير (debounce) لتقليل إعادة البناء، والحفظ
/// النهائي مسؤولية [BlockEditorController].
class RichTextBlockField extends StatefulWidget {
  const RichTextBlockField({
    super.key,
    required this.blockId,
    required this.data,
    required this.registry,
    required this.onChanged,
    this.hint,
    this.autofocus = false,
  });

  final String blockId;
  final RichTextData data;
  final RichTextRegistry registry;

  /// يُستدعى بمحتوى جاهز للحفظ: `{'delta': [...], 'text': '...'}`
  final ValueChanged<Map<String, dynamic>> onChanged;
  final String? hint;
  final bool autofocus;

  @override
  State<RichTextBlockField> createState() => _RichTextBlockFieldState();
}

class _RichTextBlockFieldState extends State<RichTextBlockField> {
  late Document _document = _buildDocument(widget.data);
  late final QuillController _controller = QuillController(
    document: _document,
    selection: const TextSelection.collapsed(offset: 0),
  );
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  late String _lastEncoded = _encode(_document.toDelta().toJson());

  static Document _buildDocument(RichTextData data) {
    final List<dynamic> delta =
        data.delta.isEmpty ? <dynamic>[<String, dynamic>{'insert': '\n'}] : data.delta;
    try {
      return Document.fromJson(delta);
    } catch (_) {
      // محتوى تالف: نبدأ بسطر فارغ بدل الانهيار.
      return Document.fromJson(<dynamic>[<String, dynamic>{'insert': '\n'}]);
    }
  }

  static String _encode(List<dynamic> delta) {
    try {
      return jsonEncode(delta);
    } catch (_) {
      return delta.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    widget.registry.register(
      blockId: widget.blockId,
      controller: _controller,
      focusNode: _focusNode,
    );
  }

  @override
  void didUpdateWidget(covariant RichTextBlockField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // تحديث خارجي (تغيير نوع/إعادة تحميل) لا يحدث أثناء الكتابة داخل هذه الكتلة
    if (identical(oldWidget.data, widget.data) || _focusNode.hasFocus) {
      return;
    }
    final String incoming = _encode(widget.data.delta);
    if (incoming == _lastEncoded) {
      return;
    }
    _controller.removeListener(_onControllerChanged);
    final Document document = _buildDocument(widget.data);
    setState(() {
      _document = document;
    });
    _controller.document = document;
    _lastEncoded = incoming;
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    final String encoded = _encode(_controller.document.toDelta().toJson());
    if (encoded == _lastEncoded) {
      return; // تغيّر تحديد فقط (حركة المؤشر) — لا داعي للإبلاغ
    }
    _lastEncoded = encoded;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _emit);
  }

  void _emit() {
    if (!mounted) {
      return;
    }
    final List<dynamic> delta =
        _controller.document.toDelta().toJson();
    final String plainText = _controller.document.toPlainText();
    widget.onChanged(<String, dynamic>{
      'delta': delta,
      'text': plainText,
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.registry.unregister(widget.blockId);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QuillEditor.basic(
      controller: _controller,
      focusNode: _focusNode,
      config: QuillEditorConfig(
        placeholder: widget.hint ?? context.l10n.blockTextHint,
        autoFocus: widget.autofocus,
        expands: false,
        // القائمة الخارجية هي التي تُمرَّر، فلا نُنشئ مُمرِّرًا داخليًا لكل كتلة.
        scrollable: false,
        minHeight: 46,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        textCapitalization: TextCapitalization.sentences,
        // لا نُغلق التركيز عند اللمس خارج الكتلة: المستخدم ينتقل باللمس على كتلة أخرى.
        onTapOutsideEnabled: false,
      ),
    );
  }
}
