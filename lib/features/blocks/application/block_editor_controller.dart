import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/failures/app_failure.dart';
import '../../../core/failures/error_mapper.dart';
import '../data/block_repository.dart';
import '../domain/block.dart';

/// حالة الحفظ الظاهرة في شريط المحرر.
enum EditorSaveStatus { idle, dirty, saving, saved, failed }

/// عقل محرّر الكتل: يحمل قائمة الكتل محليًا، يعدّلها فورًا (تجربة سلسة)،
/// ويحفظها في Supabase بعد توقف الكتابة (debounce) مع إمكانية الحفظ الفوري.
///
/// لماذا لا نستخدم مزوّد Riverpod مباشرة؟ لأن المحرر يحتاج حالة قصيرة العمر
/// مرتبطة بالشاشة (مؤقّت حفظ، كتل معلّقة، حالة تركيز) ولا يجب أن تبقى بعد
/// الخروج من الشاشة؛ ومع ذلك يبقى كل وصول لقاعدة البيانات عبر [BlockRepository]
/// في طبقة data (لا استعلامات في الواجهة).
class BlockEditorController extends ChangeNotifier {
  BlockEditorController({
    required BlockRepository repository,
    required this.pageId,
    this.autoSaveDelay = const Duration(milliseconds: 900),
  }) : _repository = repository;

  final BlockRepository _repository;
  final String pageId;
  final Duration autoSaveDelay;

  List<NoteBlock> _blocks = <NoteBlock>[];
  final Set<String> _pendingContentIds = <String>{};

  EditorSaveStatus _status = EditorSaveStatus.idle;
  AppFailure? _failure;
  DateTime? _lastSavedAt;
  Timer? _debounce;
  bool _attached = false;
  bool _disposed = false;
  bool _busy = false;

  /// الكتل الحالية مرتّبة (قائمة للقراءة فقط — لا تعدّلها مباشرة).
  List<NoteBlock> get blocks => _blocks;

  EditorSaveStatus get status => _status;

  AppFailure? get failure => _failure;

  DateTime? get lastSavedAt => _lastSavedAt;

  /// هل تعمل عملية تتطلّب انتظارًا (إضافة/حذف كتلة)؟
  bool get isBusy => _busy;

  bool get hasUnsavedChanges => _pendingContentIds.isNotEmpty;

  int get blockCount => _blocks.length;

  NoteBlock? blockById(String id) {
    for (final NoteBlock block in _blocks) {
      if (block.id == id) {
        return block;
      }
    }
    return null;
  }

  int indexOf(String id) =>
      _blocks.indexWhere((NoteBlock block) => block.id == id);

  // ── المزامنة مع مصدر البيانات ────────────────────────────────────────────

  /// يربط الكتل القادمة من `blocksProvider` بالمحرر.
  ///
  /// - أول استدعاء: يُثبّت القائمة.
  /// - بعد ذلك: يُحدَّث الهيكل فقط إن لم تكن هناك تعديلات معلّقة، حتى لا يبتلع
  ///   تحديث الخادم ما كتبه المستخدم.
  void attach(List<NoteBlock> serverBlocks, {bool force = false}) {
    if (_disposed) {
      return;
    }
    if (!_attached || force) {
      _blocks = List<NoteBlock>.of(serverBlocks);
      _attached = true;
      return;
    }
    if (hasUnsavedChanges || _status == EditorSaveStatus.saving) {
      return;
    }
    final bool sameShape = _blocks.length == serverBlocks.length &&
        _sameIds(_blocks, serverBlocks);
    if (sameShape) {
      return;
    }
    _blocks = List<NoteBlock>.of(serverBlocks);
  }

  static bool _sameIds(List<NoteBlock> a, List<NoteBlock> b) {
    for (int index = 0; index < a.length; index++) {
      if (a[index].id != b[index].id) {
        return false;
      }
    }
    return true;
  }

  // ── التعديلات ────────────────────────────────────────────────────────────

  /// تعديل محتوى كتلة (يُستدعى مع كل كتابة) — يُحدَّث محليًا فورًا ويُحفظ لاحقًا.
  void updateContent(String blockId, Map<String, dynamic> content) {
    final int index = indexOf(blockId);
    if (index < 0) {
      return;
    }
    _blocks = <NoteBlock>[
      for (int i = 0; i < _blocks.length; i++)
        i == index ? _blocks[i].copyWith(content: content) : _blocks[i],
    ];
    _pendingContentIds.add(blockId);
    _status = EditorSaveStatus.dirty;
    _failure = null;
    notifyListeners();
    _scheduleAutoSave();
  }

  /// تغيير نوع الكتلة مع محتوى افتراضي جديد للنوع.
  Future<void> changeType(String blockId, BlockType type) async {
    final int index = indexOf(blockId);
    if (index < 0) {
      return;
    }
    final Map<String, dynamic> content = type.defaultContent;
    _blocks = <NoteBlock>[
      for (int i = 0; i < _blocks.length; i++)
        i == index
            ? _blocks[i].copyWith(type: type, content: content)
            : _blocks[i],
    ];
    _pendingContentIds.add(blockId);
    _status = EditorSaveStatus.dirty;
    notifyListeners();
    await flush();
  }

  /// إضافة كتلة جديدة (بعد كتلة معيّنة أو في نهاية الصفحة).
  Future<NoteBlock?> addBlock(BlockType type, {String? afterBlockId}) async {
    if (_disposed) {
      return null;
    }
    _busy = true;
    _failure = null;
    notifyListeners();

    try {
      await flush();

      final double sortOrder;
      int insertIndex = _blocks.length;
      if (afterBlockId != null) {
        final int index = indexOf(afterBlockId);
        if (index >= 0) {
          final double current = _blocks[index].sortOrder;
          final double next = index + 1 < _blocks.length
              ? _blocks[index + 1].sortOrder
              : current + 2000;
          sortOrder = (current + next) / 2;
          insertIndex = index + 1;
        } else {
          sortOrder = BlockRepository.nextSortOrder(_blocks);
        }
      } else {
        sortOrder = BlockRepository.nextSortOrder(_blocks);
      }

      final NoteBlock created = await _repository.createBlock(
        pageId: pageId,
        type: type,
        sortOrder: sortOrder,
      );

      _blocks = <NoteBlock>[
        ..._blocks.sublist(0, insertIndex),
        created,
        ..._blocks.sublist(insertIndex),
      ];
      _status = EditorSaveStatus.saved;
      _lastSavedAt = DateTime.now();
      return created;
    } catch (error, stackTrace) {
      _failure = ErrorMapper.map(error, stackTrace);
      _status = EditorSaveStatus.failed;
      return null;
    } finally {
      _busy = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  /// تحريك كتلة خطوة لأعلى (بمبادلة الترتيب مع جارتها).
  Future<void> moveUp(String blockId) => _move(blockId, -1);

  /// تحريك كتلة خطوة لأسفل.
  Future<void> moveDown(String blockId) => _move(blockId, 1);

  Future<void> _move(String blockId, int direction) async {
    final int index = indexOf(blockId);
    if (index < 0) {
      return;
    }
    final int target = index + direction;
    if (target < 0 || target >= _blocks.length) {
      return;
    }

    final List<NoteBlock> previous = _blocks;
    final NoteBlock current = previous[index];
    final NoteBlock neighbour = previous[target];

    // تبديل موضعين محليًا (بمبادلة قيمة الترتيب) ثم إعادة الترتيب
    final List<NoteBlock> next = <NoteBlock>[...previous];
    next[index] = current.copyWith(sortOrder: neighbour.sortOrder);
    next[target] = neighbour.copyWith(sortOrder: current.sortOrder);
    next.sort(_byOrder);
    _blocks = next;
    _failure = null;
    notifyListeners();

    try {
      await _repository.swapSortOrders(current, neighbour);
      _status = EditorSaveStatus.saved;
      _lastSavedAt = DateTime.now();
    } catch (error, stackTrace) {
      _blocks = previous;
      _failure = ErrorMapper.map(error, stackTrace);
      _status = EditorSaveStatus.failed;
    } finally {
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  /// حذف كتلة (مع تراجع تلقائي عند فشل الخادم).
  Future<bool> deleteBlock(String blockId) async {
    final NoteBlock? block = blockById(blockId);
    if (block == null) {
      return false;
    }

    final List<NoteBlock> previous = _blocks;
    _blocks = _blocks
        .where((NoteBlock item) => item.id != blockId)
        .toList(growable: false);
    notifyListeners();

    try {
      await _repository.deleteBlock(blockId);
      _status = EditorSaveStatus.saved;
      _lastSavedAt = DateTime.now();
      return true;
    } catch (error, stackTrace) {
      _blocks = previous;
      _failure = ErrorMapper.map(error, stackTrace);
      _status = EditorSaveStatus.failed;
      return false;
    } finally {
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  static int _byOrder(NoteBlock a, NoteBlock b) {
    final int byOrder = a.sortOrder.compareTo(b.sortOrder);
    if (byOrder != 0) {
      return byOrder;
    }
    final DateTime aDate = a.createdAt ?? DateTime(1970);
    final DateTime bDate = b.createdAt ?? DateTime(1970);
    return aDate.compareTo(bDate);
  }

  // ── الحفظ ────────────────────────────────────────────────────────────────

  void _scheduleAutoSave() {
    _debounce?.cancel();
    _debounce = Timer(autoSaveDelay, () {
      unawaited(flush());
    });
  }

  /// حفظ كل التعديلات المعلّقة الآن.
  Future<void> flush() async {
    _debounce?.cancel();
    if (_pendingContentIds.isEmpty) {
      if (_status == EditorSaveStatus.dirty) {
        _status = EditorSaveStatus.saved;
        _lastSavedAt = DateTime.now();
        if (!_disposed) {
          notifyListeners();
        }
      }
      return;
    }

    final List<String> ids = _pendingContentIds.toList(growable: false);
    _pendingContentIds.clear();

    if (!_disposed) {
      _status = EditorSaveStatus.saving;
      notifyListeners();
    }

    try {
      for (final String id in ids) {
        final NoteBlock? block = blockById(id);
        if (block == null || !block.hasServerId) {
          continue;
        }
        await _repository.updateBlock(
          blockId: id,
          content: block.content,
          type: block.type,
        );
      }
      _status = EditorSaveStatus.saved;
      _lastSavedAt = DateTime.now();
      _failure = null;
    } catch (error, stackTrace) {
      // نُعيد العناصر إلى قائمة الانتظار حتى يستطيع المستخدم إعادة المحاولة.
      _pendingContentIds.addAll(ids);
      _failure = ErrorMapper.map(error, stackTrace);
      _status = EditorSaveStatus.failed;
    } finally {
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  /// إعادة المحاولة يدويًا بعد فشل الحفظ.
  Future<void> retry() => flush();

  @override
  void dispose() {
    _debounce?.cancel();
    _disposed = true;
    // لا ننتظر؛ الحفظ في الخلفية لا يحتاج الواجهة، والمُتحكّم يمنع الإشعار بعد الحذف.
    if (hasUnsavedChanges) {
      unawaited(_flushSilently());
    }
    super.dispose();
  }

  Future<void> _flushSilently() async {
    final List<String> ids = _pendingContentIds.toList(growable: false);
    _pendingContentIds.clear();
    for (final String id in ids) {
      final NoteBlock? block = blockById(id);
      if (block == null || !block.hasServerId) {
        continue;
      }
      try {
        await _repository.updateBlock(
          blockId: id,
          content: block.content,
          type: block.type,
        );
      } catch (_) {
        // لا شيء لفعله الآن — المستخدم غادر الشاشة.
      }
    }
  }
}
