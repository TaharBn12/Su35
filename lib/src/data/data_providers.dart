import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_failure.dart';
import '../features/auth/providers/auth_providers.dart';
import 'models/notebook.dart';
import 'models/page.dart';
import 'models/page_block.dart';
import 'repositories/blocks_repository.dart';
import 'repositories/notebooks_repository.dart';
import 'repositories/pages_repository.dart';
import 'repositories/supabase_blocks_repository.dart';
import 'repositories/supabase_notebooks_repository.dart';
import 'repositories/supabase_pages_repository.dart';
import 'supabase_providers.dart';

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

final notebooksRepositoryProvider = Provider<NotebooksRepository>((ref) {
  return SupabaseNotebooksRepository(ref.watch(supabaseClientProvider));
});

final pagesRepositoryProvider = Provider<PagesRepository>((ref) {
  return SupabasePagesRepository(ref.watch(supabaseClientProvider));
});

final blocksRepositoryProvider = Provider<BlocksRepository>((ref) {
  return SupabaseBlocksRepository(ref.watch(supabaseClientProvider));
});

// ---------------------------------------------------------------------------
// Read providers
// ---------------------------------------------------------------------------

/// All notebooks of the signed-in user.
///
/// `autoDispose` + watching [currentUserIdProvider] means the list is dropped
/// and re-fetched automatically on sign-out/sign-in.
final notebooksProvider =
    AsyncNotifierProvider.autoDispose<NotebooksNotifier, List<Notebook>>(
  NotebooksNotifier.new,
);

class NotebooksNotifier extends AsyncNotifier<List<Notebook>> {
  @override
  Future<List<Notebook>> build() async {
    // Re-fetch whenever the user changes (also handles sign-out -> null).
    ref.watch(currentUserIdProvider);
    final repository = ref.watch(notebooksRepositoryProvider);
    try {
      return await repository.fetchNotebooks();
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  /// Pull-to-refresh that keeps the previous list visible while reloading.
  Future<void> reload() async {
    state = const AsyncLoading().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(notebooksRepositoryProvider).fetchNotebooks(),
    );
  }

  /// Applies a local change immediately (optimistic) without a full refetch.
  void applyLocally(List<Notebook> next) => state = AsyncData(next);
}

/// Pages of one notebook (top-level pages + all nested pages, flat list).
final notebookPagesProvider = AsyncNotifierProvider.autoDispose
    .family<NotebookPagesNotifier, List<NotePage>, String>(
  (notebookId) => NotebookPagesNotifier(notebookId),
);

class NotebookPagesNotifier extends AsyncNotifier<List<NotePage>> {
  NotebookPagesNotifier(this.notebookId);

  /// The notebook this notifier was created for (Riverpod 3 passes family
  /// arguments through the notifier constructor).
  final String notebookId;

  @override
  Future<List<NotePage>> build() async {
    ref.watch(currentUserIdProvider);
    final repository = ref.watch(pagesRepositoryProvider);
    try {
      return await repository.fetchPages(notebookId: notebookId);
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref
          .read(pagesRepositoryProvider)
          .fetchPages(notebookId: notebookId),
    );
  }

  void applyLocally(List<NotePage> next) => state = AsyncData(next);
}

/// A single page.
final pageProvider =
    AsyncNotifierProvider.autoDispose.family<PageNotifier, NotePage, String>(
  (pageId) => PageNotifier(pageId),
);

class PageNotifier extends AsyncNotifier<NotePage> {
  PageNotifier(this.pageId);

  final String pageId;

  @override
  Future<NotePage> build() async {
    ref.watch(currentUserIdProvider);
    final repository = ref.watch(pagesRepositoryProvider);
    try {
      return await repository.fetchPage(pageId);
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  void applyLocally(NotePage next) => state = AsyncData(next);
}

/// Content blocks of one page, ordered by `position`.
final pageBlocksProvider = AsyncNotifierProvider.autoDispose
    .family<PageBlocksNotifier, List<PageBlock>, String>(
  (pageId) => PageBlocksNotifier(pageId),
);

class PageBlocksNotifier extends AsyncNotifier<List<PageBlock>> {
  PageBlocksNotifier(this.pageId);

  final String pageId;

  @override
  Future<List<PageBlock>> build() async {
    ref.watch(currentUserIdProvider);
    final repository = ref.watch(blocksRepositoryProvider);
    try {
      return await repository.fetchBlocks(pageId);
    } catch (error) {
      throw toAppFailure(error);
    }
  }
}

// ---------------------------------------------------------------------------
// Write providers (mutations) - shared by notebooks & pages screens
// ---------------------------------------------------------------------------

/// The write operation currently in flight for [CollectionMutations].
enum BusyOp { create, rename, delete, move }

/// Tracks which row is busy so exactly one button/list tile shows a spinner.
class CollectionBusyState {
  const CollectionBusyState({this.op, this.id});

  final BusyOp? op;
  final String? id;

  static const CollectionBusyState idle = CollectionBusyState();

  bool get isIdle => op == null;

  bool isBusy(String? id, BusyOp op) =>
      this.op == op && (id == null || this.id == id || this.id == null);

  @override
  bool operator ==(Object other) =>
      other is CollectionBusyState && other.op == op && other.id == id;

  @override
  int get hashCode => Object.hash(op, id);

  @override
  String toString() => 'CollectionBusyState($op, $id)';
}

/// One notifier that performs every notebook/page write, invalidates the right
/// read providers afterwards and exposes an `AppFailure` for the UI to show in
/// a SnackBar.
final collectionMutationsProvider =
    AsyncNotifierProvider<CollectionMutations, CollectionBusyState>(
  CollectionMutations.new,
);

class CollectionMutations extends AsyncNotifier<CollectionBusyState> {
  @override
  CollectionBusyState build() => CollectionBusyState.idle;

  /// The last failure, so screens can show a SnackBar after `await`.
  AppFailure? lastFailure;

  Future<T?> _run<T>(
    BusyOp op,
    Future<T> Function() action, {
    String? id,
  }) async {
    lastFailure = null;
    state = AsyncData(CollectionBusyState(op: op, id: id));
    try {
      final result = await action();
      state = const AsyncData(CollectionBusyState.idle);
      return result;
    } catch (error) {
      final failure = toAppFailure(error);
      lastFailure = failure;
      state = AsyncError(failure, StackTrace.current);
      // Return to idle so the UI is usable again, but keep `lastFailure`.
      state = const AsyncData(CollectionBusyState.idle);
      return null;
    }
  }

  // --- Notebooks -----------------------------------------------------------

  Future<Notebook?> createNotebook({
    required String name,
    String? icon,
    String? color,
    String? description,
  }) {
    return _run<Notebook>(
      BusyOp.create,
      () => ref.read(notebooksRepositoryProvider).createNotebook(
            name: name,
            icon: icon,
            color: color,
            description: description,
          ),
    ).then(_afterNotebookChange);
  }

  Future<Notebook?> renameNotebook(String notebookId, String name) {
    return _run<Notebook>(
      BusyOp.rename,
      () => ref
          .read(notebooksRepositoryProvider)
          .renameNotebook(notebookId, name),
      id: notebookId,
    ).then(_afterNotebookChange);
  }

  /// Full metadata update (name + icon + colour + description).
  Future<Notebook?> updateNotebookMeta(
    String notebookId, {
    String? name,
    String? icon,
    String? color,
    String? description,
    bool? isArchived,
    int? position,
  }) {
    return _run<Notebook>(
      BusyOp.rename,
      () => ref.read(notebooksRepositoryProvider).updateNotebook(
            notebookId,
            name: name,
            icon: icon,
            color: color,
            description: description,
            isArchived: isArchived,
            position: position,
          ),
      id: notebookId,
    ).then(_afterNotebookChange);
  }

  Future<bool> deleteNotebook(String notebookId) async {
    await _run<void>(
      BusyOp.delete,
      () => ref.read(notebooksRepositoryProvider).deleteNotebook(notebookId),
      id: notebookId,
    );
    if (lastFailure != null) return false;
    ref.invalidate(notebooksProvider);
    return true;
  }

  Future<Notebook?> _afterNotebookChange(Future<Notebook?> future) async {
    final result = await future;
    if (lastFailure == null) ref.invalidate(notebooksProvider);
    return result;
  }

  // --- Pages ---------------------------------------------------------------

  Future<NotePage?> createPage({
    required String notebookId,
    required String title,
    String? parentPageId,
    String? templateKey,
    String? aircraftType,
    String? registration,
    String? ataChapter,
    String? airportIcao,
    String? departureIcao,
    String? arrivalIcao,
    DateTime? flightDate,
  }) async {
    final created = await _run<NotePage>(
      BusyOp.create,
      () => ref.read(pagesRepositoryProvider).createPage(
            notebookId: notebookId,
            title: title,
            parentPageId: parentPageId,
            templateKey: templateKey,
            aircraftType: aircraftType,
            registration: registration,
            ataChapter: ataChapter,
            airportIcao: airportIcao,
            departureIcao: departureIcao,
            arrivalIcao: arrivalIcao,
            flightDate: flightDate,
          ),
      id: notebookId,
    );
    if (lastFailure == null) {
      ref.invalidate(notebookPagesProvider(notebookId));
      if (parentPageId != null) ref.invalidate(pageProvider(parentPageId));
    }
    return created;
  }

  Future<NotePage?> updatePage(
    String pageId, {
    String? title,
    String? icon,
    String? summary,
    String? aircraftType,
    String? registration,
    String? ataChapter,
    String? airportIcao,
    String? departureIcao,
    String? arrivalIcao,
    DateTime? flightDate,
    bool? isFavorite,
    bool? isArchived,
    bool clearNulls = false,
  }) async {
    const clearable = <String>[
      'aircraft_type',
      'registration',
      'ata_chapter',
      'airport_icao',
      'departure_icao',
      'arrival_icao',
      'flight_date',
    ];
    final updated = await _run<NotePage>(
      BusyOp.rename,
      () => ref.read(pagesRepositoryProvider).updatePage(
            pageId,
            title: title,
            icon: icon,
            summary: summary,
            aircraftType: aircraftType,
            registration: registration,
            ataChapter: ataChapter,
            airportIcao: airportIcao,
            departureIcao: departureIcao,
            arrivalIcao: arrivalIcao,
            flightDate: flightDate,
            isFavorite: isFavorite,
            isArchived: isArchived,
            clearFields: clearNulls ? clearable.toSet() : const <String>{},
          ),
      id: pageId,
    );
    if (lastFailure == null) await _invalidatePageCaches(updated);
    return updated;
  }

  Future<bool> deletePage(String pageId, {required String notebookId}) async {
    await _run<void>(
      BusyOp.delete,
      () => ref.read(pagesRepositoryProvider).deletePage(pageId),
      id: pageId,
    );
    if (lastFailure != null) return false;
    ref.invalidate(notebookPagesProvider(notebookId));
    ref.invalidate(pageProvider(pageId));
    ref.invalidate(notebooksProvider);
    return true;
  }

  Future<void> _invalidatePageCaches(NotePage? page) async {
    if (page == null) return;
    ref.invalidate(pageProvider(page.id));
    ref.invalidate(notebookPagesProvider(page.notebookId));
    if (page.parentPageId != null) {
      ref.invalidate(pageProvider(page.parentPageId!));
    }
  }
}
