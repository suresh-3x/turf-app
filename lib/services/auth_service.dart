import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import 'supabase_providers.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(supabaseClientProvider)),
);

/// Auth events (sign in, sign out, token refresh).
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authServiceProvider).onAuthStateChange,
);

/// ID of the signed-in user, or null. Only changes when the user changes.
final currentUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authServiceProvider);
  final fromStream = ref.watch(authStateProvider.select((s) => s.valueOrNull?.session?.user.id));
  return fromStream ?? auth.currentUser?.id;
});

/// Profile row of the signed-in user (name, role...).
final currentProfileProvider = FutureProvider<AppUser?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(authServiceProvider).fetchProfile(userId);
});

class SignUpResult {
  const SignUpResult({required this.needsEmailConfirmation});
  final bool needsEmailConfirmation;
}

class AuthService {
  AuthService(this._client);
  final SupabaseClient _client;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
  User? get currentUser => _client.auth.currentUser;

  /// Throws [AuthException] with a readable message on failure.
  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// The profile row is created by a database trigger from [data].
  Future<SignUpResult> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
  }) async {
    final res = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'name': name.trim(),
        'role': role.name,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    );
    return SignUpResult(needsEmailConfirmation: res.session == null);
  }

  Future<void> sendPasswordReset(String email) => _client.auth.resetPasswordForEmail(email.trim());

  Future<void> signOut() => _client.auth.signOut();

  Future<AppUser?> fetchProfile(String userId) async {
    final row = await _client.from('users').select().eq('id', userId).maybeSingle();
    return row == null ? null : AppUser.fromJson(row);
  }

  Future<void> updateProfile({required String name, String? phone}) async {
    final id = currentUser?.id;
    if (id == null) throw const AuthException('You are not signed in.');
    await _client
        .from('users')
        .update({
          'name': name.trim(),
          'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
        })
        .eq('id', id);
  }
}
