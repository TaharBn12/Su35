import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/notebook_repository.dart';
import '../domain/notebook.dart';

final Provider<NotebookRepository> notebookRepositoryProvider =
    Provider<NotebookRepository>(
  (Ref ref) => NotebookRepository(ref.watch(supabaseClientProvider)),
);

/// قائمة دفاتر المستخدم مع تحديثات تفاؤلية (Optimistic) بعد كل إضافة/تعديل/حذف.
///
/// ملاحظة: تم تعطيل إعادة المحاولة التلقائية في Riverpod 3 (`retry`) لأن
/// إعادة المحاولة اليدوية أوضح للمستخدم وأقل استهلاكًا للشبكة.
final AsyncNotifierProvider<NotebooksController, List<Notebook>>
    notebooksControllerProvider =
    AsyncNotifierProvider<NotebooksController, List<Notebook>>(
  NotebooksController.new,
  retry: (int retryCount, Object error) => null,
);

class NotebooksController extends AsyncNotifier<List<Notebook>> {
  NotebookRepository get _repository => ref.read(notebookRepositoryProvider);

  @override
  Future<List<Notebook>> build() {
    return ref.watch(notebookRepositoryProvider).fetchNotebooks();
  }

  /// إعادة تحميل كاملة (سحب للتحديث أو زر إعادة المحاولة).
  Future<void> reload() async {
    state = const AsyncLoading<List<Notebook>>();
    state = await AsyncValue.guard<List<Notebook>>(
      () => ref.read(notebookRepositoryProvider).fetchNotebooks(),
    );
  }

  Future<Notebook> create({
    required String title,
    String? description,
    String? icon,
    String? color,
    String? aircraftType,
    bool isFavorite = false,
  }) async {
    final Notebook created = await _repository.createNotebook(
      title: title,
      description: description,
      icon: icon,
      color: color,
      aircraftType: aircraftType,
      isFavorite: isFavorite,
      sortOrder: _nextSortOrder(),
    );
    _applyLocal(<Notebook>[...currentList, created]);
    return created;
  }

  Future<void> update(Notebook notebook) async {
    final Notebook updated = await _repository.updateNotebook(
      id: notebook.id,
      title: notebook.title,
      description: notebook.description ?? '',
      icon: notebook.displayIcon,
      color: notebook.color,
      aircraftType: notebook.aircraftType ?? '',
      isFavorite: notebook.isFavorite,
      isArchived: notebook.isArchived,
      sortOrder: notebook.sortOrder,
    );
    _applyLocal(
      currentList
          .map((Notebook item) =>
              item.id == updated.id
                  ? updated.copyWith(
                      pagesCount: item.pagesCount,
                      lastPageUpdate: item.lastPageUpdate,
                    )
                  : item)
          .toList(growable: false),
    );
  }

  Future<void> toggleFavorite(Notebook notebook) async {
    // تحديث محلي فوري ثم تثبيت النتيجة من الخادم
    _applyLocal(
      currentList
          .map((Notebook item) => item.id == notebook.id
              ? item.copyWith(isFavorite: !item.isFavorite)
              : item)
          .toList(growable: false),
    );
    try {
      await _repository.updateNotebook(
        id: notebook.id,
        isFavorite: !notebook.isFavorite,
      );
    } catch (error) {
      _applyLocal(
        currentList
            .map((Notebook item) => item.id == notebook.id
                ? item.copyWith(isFavorite: notebook.isFavorite)
                : item)
            .toList(growable: false),
      );
      rethrow;
    }
  }

  Future<void> setArchived(Notebook notebook, bool isArchived) async {
    await _repository.updateNotebook(
      id: notebook.id,
      isArchived: isArchived,
    );
    _applyLocal(
      currentList
          .map((Notebook item) => item.id == notebook.id
              ? item.copyWith(isArchived: isArchived)
              : item)
          .toList(growable: false),
    );
  }

  Future<void> delete(String notebookId) async {
    final List<Notebook> previous = currentList;
    _applyLocal(
      previous
          .where((Notebook item) => item.id != notebookId)
          .toList(growable: false),
    );
    try {
      await _repository.deleteNotebook(notebookId);
    } catch (error) {
      _applyLocal(previous);
      rethrow;
    }
  }

  /// تحديث عدد الصفحات محليًا بعد إضافة/حذف صفحة (بدون رحلة شبكة إضافية).
  void patchPagesCount(String notebookId, int pagesCount) {
    _applyLocal(
      currentList
          .map((Notebook item) => item.id == notebookId
              ? item.copyWith(pagesCount: pagesCount)
              : item)
          .toList(growable: false),
    );
  }

  List<Notebook> get currentList => state.value ?? const <Notebook>[];

  int _nextSortOrder() {
    if (currentList.isEmpty) {
      return 100;
    }
    int maxOrder = 0;
    for (final Notebook notebook in currentList) {
      if (notebook.sortOrder > maxOrder) {
        maxOrder = notebook.sortOrder;
      }
    }
    return maxOrder + 100;
  }

  void _applyLocal(List<Notebook> notebooks) {
    final List<Notebook> sorted = <Notebook>[...notebooks]..sort(_compare);
    state = AsyncData<List<Notebook>>(sorted);
  }

  /// نفس ترتيب الاستعلام في SQL: المثبّتة → ترتيب المستخدم → الأحدث تعديلًا.
  static int _compare(Notebook a, Notebook b) {
    if (a.isFavorite != b.isFavorite) {
      return a.isFavorite ? -1 : 1;
    }
    if (a.sortOrder != b.sortOrder) {
      return a.sortOrder.compareTo(b.sortOrder);
    }
    final DateTime aDate = a.updatedAt ?? a.createdAt ?? DateTime(1970);
    final DateTime bDate = b.updatedAt ?? b.createdAt ?? DateTime(1970);
    return bDate.compareTo(aDate);
  }
}

/// الدفاتر النشطة (غير المؤرشفة).
final Provider<List<Notebook>> activeNotebooksProvider =
    Provider<List<Notebook>>((Ref ref) {
  final List<Notebook> all =
      ref.watch(notebooksControllerProvider).value ?? const <Notebook>[];
  return all.where((Notebook notebook) => !notebook.isArchived).toList();
});

final Provider<List<Notebook>> archivedNotebooksProvider =
    Provider<List<Notebook>>((Ref ref) {
  final List<Notebook> all =
      ref.watch(notebooksControllerProvider).value ?? const <Notebook>[];
  return all.where((Notebook notebook) => notebook.isArchived).toList();
});

/// دفتر واحد بالمعرّف (من القائمة المحمّلة) — يُستخدم في شاشة الصفحات.
final notebookByIdProvider = Provider.family<Notebook?, String>(
  (Ref ref, String notebookId) {
    final List<Notebook> all =
        ref.watch(notebooksControllerProvider).value ?? const <Notebook>[];
    for (final Notebook notebook in all) {
      if (notebook.id == notebookId) {
        return notebook;
      }
    }
    return null;
  },
);
