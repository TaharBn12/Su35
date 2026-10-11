import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// سجلّ محرّرات النص الغني المفتوحة داخل شاشة التحرير.
///
/// السبب: كل كتلة نصية لها `QuillController` مستقل (حتى لا يتشارك المستخدمون
/// السجل نفسه)، وشريط الأدوات في الأسفل يجب أن يتحكم **بالكتلة المُركَّز عليها**
/// فقط. هذا السجل يربط بينهما ويُبلّغ الشاشة عند تغيّر التركيز.
class RichTextRegistry extends ChangeNotifier {
  final Map<String, QuillController> _controllers = <String, QuillController>{};
  final Map<String, FocusNode> _focusNodes = <String, FocusNode>{};
  final Map<String, VoidCallback> _focusListeners = <String, VoidCallback>{};

  String? _focusedBlockId;

  /// معرّف الكتلة المُركَّز عليها حاليًا.
  String? get focusedBlockId => _focusedBlockId;

  /// متحكّم الكتلة المُركَّز عليها (null إن لم تكن هناك كتلة نصية نشطة).
  QuillController? get activeController =>
      _focusedBlockId == null ? null : _controllers[_focusedBlockId];

  bool get hasActiveEditor => activeController != null;

  void register({
    required String blockId,
    required QuillController controller,
    required FocusNode focusNode,
  }) {
    _controllers[blockId] = controller;
    _focusNodes[blockId] = focusNode;

    void listener() {
      if (focusNode.hasFocus) {
        _setFocus(blockId);
      } else if (_focusedBlockId == blockId) {
        _setFocus(null);
      }
    }

    _focusListeners[blockId] = listener;
    focusNode.addListener(listener);
    if (focusNode.hasFocus) {
      _setFocus(blockId);
    }
  }

  void unregister(String blockId) {
    final VoidCallback? listener = _focusListeners.remove(blockId);
    if (listener != null) {
      _focusNodes[blockId]?.removeListener(listener);
    }
    _focusNodes.remove(blockId);
    _controllers.remove(blockId);
    if (_focusedBlockId == blockId) {
      _focusedBlockId = null;
      // لا نُبلّغ داخل dispose الخاص بالكتلة؛ نؤجّل للإطار التالي.
      scheduleMicrotask(notifyListeners);
    }
  }

  void _setFocus(String? blockId) {
    if (_focusedBlockId == blockId) {
      return;
    }
    _focusedBlockId = blockId;
    notifyListeners();
  }

  /// إخفاء شريط الأدوات (مثلًا عند الضغط على زر الإضافة).
  void clearFocus() {
    final String? id = _focusedBlockId;
    if (id != null) {
      _focusNodes[id]?.unfocus();
    }
    _setFocus(null);
  }

  @override
  void dispose() {
    for (final String blockId in _focusListeners.keys.toList(growable: false)) {
      unregister(blockId);
    }
    super.dispose();
  }
}
