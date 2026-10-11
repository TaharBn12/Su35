import '../models/page.dart';

/// Result of one global full-text search hit.
class PageSearchResult {
  const PageSearchResult({
    required this.page,
    required this.rank,
    required this.snippet,
  });

  final NotePage page;

  /// Postgres `ts_rank` score (higher = better match).
  final double rank;

  /// Short excerpt around the match, highlighted with `<b>` tags by Postgres.
  final String snippet;
}

/// Contract for the pages collection (notebook pages + nested sub-pages).
abstract interface class PagesRepository {
  /// All non-archived pages of one notebook, ordered for a tree view.
  Future<List<NotePage>> fetchPages({required String notebookId});

  /// A single page by id (throws `AppFailure('error.notFound')` when missing).
  Future<NotePage> fetchPage(String pageId);

  /// Direct children of a page (used by the nested page tree).
  Future<List<NotePage>> fetchChildPages(String parentPageId);

  /// Recently updated pages across every notebook (home "recent" strip).
  Future<List<NotePage>> fetchRecentPages({int limit = 10});

  Future<NotePage> createPage({
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
    String? icon,
  });

  Future<NotePage> updatePage(
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
    int? position,

    /// Column names that must be written as SQL NULL (clearing a value).
    /// Without this, passing `null` means "leave untouched".
    Set<String> clearFields = const <String>{},
  });

  /// Moves a page to another parent (or to the notebook root when
  /// [newParentId] is null). The database rejects cycles.
  Future<void> movePage(String pageId, {String? newParentId});

  Future<void> deletePage(String pageId);

  /// Global full-text search powered by the `search_pages` SQL function and
  /// the `pages.search_vector` GIN index (Stage C wires this to the UI).
  Future<List<PageSearchResult>> searchPages({
    required String query,
    String? aircraftType,
    String? ataChapter,
    int limit = 30,
  });
}
