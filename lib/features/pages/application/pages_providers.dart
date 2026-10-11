import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../notebooks/application/notebooks_controller.dart';
import '../../notebooks/domain/notebook.dart';
import '../data/page_repository.dart';
import '../domain/note_page.dart';

final Provider<PageRepository> pageRepositoryProvider = Provider<PageRepository>(
  (Ref ref) => PageRepository(ref.watch(supabaseClientProvider)),
);

/// صفحات دفتر معيّن (مسطّحة) — تُبنى الشجرة في الواجهة عبر [PageTree].
///
/// استخدمنا FutureProvider.family هنا لأن القائمة مرتبطة بمعرّف الدفتر،
/// ولا حاجة لحالة محلية دائمة؛ وبعد كل تعديل نُبطل المزوّد بحسب الحاجة.
final notebookPagesProvider = FutureProvider.family<List<NotePage>, String>(
  (Ref ref, String notebookId) =>
      ref.watch(pageRepositoryProvider).fetchPages(notebookId),
  retry: (int retryCount, Object error) => null,
);

/// صفحة واحدة بالمعرّف.
final pageProvider = FutureProvider.family<NotePage, String>(
  (Ref ref, String pageId) =>
      ref.watch(pageRepositoryProvider).fetchPage(pageId),
  retry: (int retryCount, Object error) => null,
);

/// عمليات التعديل على الصفحات + إبطال المزوّدات المتأثرة + تحديث العدّادات.
final Provider<PageActions> pageActionsProvider = Provider<PageActions>(
  (Ref ref) => PageActions(ref),
);

class PageActions {
  PageActions(this._ref);

  final Ref _ref;

  PageRepository get _repository => _ref.read(pageRepositoryProvider);

  Future<NotePage> createPage({
    required String notebookId,
    required String title,
    String? parentPageId,
    String? icon,
    String? summary,
    String? templateKey,
    String? aircraftType,
    String? tailNumber,
    String? ataChapter,
    String? airportIcao,
    DateTime? flightDate,
    bool isFavorite = false,
  }) async {
    final NotePage created = await _repository.createPage(
      notebookId: notebookId,
      title: title,
      parentPageId: parentPageId,
      icon: icon,
      summary: summary,
      templateKey: templateKey,
      aircraftType: aircraftType,
      tailNumber: tailNumber,
      ataChapter: ataChapter,
      airportIcao: airportIcao,
      flightDate: flightDate,
      isFavorite: isFavorite,
      sortOrder: _nextSortOrder(notebookId, parentPageId),
    );

    _invalidatePages(notebookId);
    _bumpNotebookCounter(notebookId, 1);
    return created;
  }

  Future<NotePage> updatePage({
    required NotePage page,
    required String title,
    String? icon,
    String? summary,
    String? aircraftType,
    String? tailNumber,
    String? ataChapter,
    String? airportIcao,
    DateTime? flightDate,
    bool? isFavorite,
    bool? isArchived,
  }) async {
    final NotePage updated = await _repository.updatePage(
      pageId: page.id,
      title: title,
      icon: icon,
      summary: summary,
      aircraftType: aircraftType,
      tailNumber: tailNumber,
      ataChapter: ataChapter,
      airportIcao: airportIcao,
      flightDate: flightDate,
      isFavorite: isFavorite,
      isArchived: isArchived,
    );

    _invalidatePages(page.notebookId);
    return updated;
  }

  Future<NotePage> toggleFavorite(NotePage page) async {
    final NotePage updated =
        await _repository.setFavorite(page.id, !page.isFavorite);
    _invalidatePages(page.notebookId);
    return updated;
  }

  /// حذف الصفحة مع كل صفحاتها الفرعية، وتصحيح عدّاد الدفتر.
  Future<void> deletePage(NotePage page) async {
    final List<NotePage>? siblings =
        _ref.read(notebookPagesProvider(page.notebookId)).value;
    int affected = 1;
    if (siblings != null) {
      affected += PageTree.descendantsOf(siblings, page.id).length;
    }

    await _repository.deletePage(page.id);
    _invalidatePages(page.notebookId);
    _bumpNotebookCounter(page.notebookId, -affected);
  }

  void _invalidatePages(String notebookId) {
    _ref.invalidate(notebookPagesProvider(notebookId));
  }

  void _bumpNotebookCounter(String notebookId, int delta) {
    final NotebooksController controller =
        _ref.read(notebooksControllerProvider.notifier);

    int? current;
    for (final Notebook notebook in controller.currentList) {
      if (notebook.id == notebookId) {
        current = notebook.pagesCount;
        break;
      }
    }
    if (current == null) {
      return;
    }

    final int next = current + delta;
    controller.patchPagesCount(notebookId, next < 0 ? 0 : next);
  }

  /// ترتيب الصفحة الجديدة: آخر ترتيب بين أشقائها + 100.
  int _nextSortOrder(String notebookId, String? parentPageId) {
    final List<NotePage>? pages =
        _ref.read(notebookPagesProvider(notebookId)).value;
    if (pages == null) {
      return 100;
    }
    final List<NotePage> siblings =
        PageTree.childrenOf(pages, parentPageId);
    if (siblings.isEmpty) {
      return 100;
    }
    int maxOrder = 0;
    for (final NotePage page in siblings) {
      if (page.sortOrder > maxOrder) {
        maxOrder = page.sortOrder;
      }
    }
    return maxOrder + 100;
  }
}
