import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Supabase client. Overridden in tests.
final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
