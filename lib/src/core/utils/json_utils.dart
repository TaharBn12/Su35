/// Small helpers to read Supabase (PostgREST) JSON rows defensively.
///
/// PostgREST returns JSON where types can shift (e.g. an `int` arriving as a
/// `String`, or a timestamp without a timezone). These helpers make the models
/// crash-proof without sprinkling `as` casts everywhere.
library;

String asString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

String? asNullableString(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool asBool(Object? value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().toLowerCase();
  if (text == 'true' || text == 't' || text == '1') return true;
  if (text == 'false' || text == 'f' || text == '0') return false;
  return fallback;
}

int asInt(Object? value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

int? asNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? asNullableDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

DateTime asDateTime(Object? value, {DateTime? fallback}) {
  return asNullableDateTime(value) ?? fallback ?? DateTime.now();
}

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, v) => MapEntry(key.toString(), v));
  return <String, dynamic>{};
}

Map<String, dynamic>? asNullableMap(Object? value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, v) => MapEntry(key.toString(), v));
  return null;
}

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map<dynamic, dynamic>>()
      .map((row) => row.map((key, v) => MapEntry(key.toString(), v)))
      .toList(growable: false);
}
