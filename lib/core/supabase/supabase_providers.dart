import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// عميل Supabase المُهيَّأ في `main()` عبر `Supabase.initialize`.
/// يبقى في مزوّد واحد ليُبنى عليه كل شيء وليسهل استبداله في الاختبارات.
final Provider<SupabaseClient> supabaseClientProvider =
    Provider<SupabaseClient>((Ref ref) => Supabase.instance.client);
