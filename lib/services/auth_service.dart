import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import 'supabase_providers.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(supabaseClientProvider)),
);

/// Emits the signed-in user's ID on every sign-in / sign-out.
final _userIdChangesProvider = StreamProvider<String?>(
  (ref) => ref.watch(authServiceProvider).userIdChanges,
);

/// ID of the signed-in user, or null. Only changes when the user changes.
final currentUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authServiceProvider);
  final changes = ref.watch(_userIdChangesProvider);
  // Before the first event, fall back to the restored session (if any).
  return changes.hasValue ? changes.value : auth.currentUserId;
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

  /// The signed-in user's ID, or null.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Emits the user ID (or null) whenever the user signs in or out.
  Stream<String?> get userIdChanges =>
      _client.auth.onAuthStateChange.map((s) => s.session?.user.id).distinct();

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
    final id = currentUserId;
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
