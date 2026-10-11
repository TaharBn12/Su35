import '../models/notebook.dart';

/// Contract for the notebooks collection.
///
/// `watch*` methods return a `Future` (not a `Stream`) on purpose: Stage D
/// swaps the implementation for a Drift-backed one that reads the local cache
/// first and reconciles with Supabase afterwards, without changing any UI code.
abstract interface class NotebooksRepository {
  Future<List<Notebook>> fetchNotebooks();

  Future<Notebook> createNotebook({
    required String name,
    String? icon,
    String? color,
    String? description,
  });

  Future<Notebook> renameNotebook(String notebookId, String name);

  Future<void> updateNotebook(
    String notebookId, {
    String? name,
    String? icon,
    String? color,
    String? description,
    bool? isArchived,
    int? position,
  });

  Future<void> deleteNotebook(String notebookId);
}
