import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Provider;

final authServiceProvider = Provider((ref) => AuthService());

final authStateProvider = StreamProvider<AuthState>((ref) {
  print('authStateProvider: stream started');
  final stream = ref.watch(authServiceProvider).onAuthStateChange;
  stream.listen(
    (event) => print('authStateProvider: stream event: $event'),
    onError: (e) => print('authStateProvider: stream error: $e'),
    onDone: () => print('authStateProvider: stream done'),
  );
  return stream;
});

class AuthService {
  final _supabase = Supabase.instance.client;

  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  Future<void> signUp(String email, String password) async {
    try {
      await _supabase.auth.signUp(email: email, password: password);
    } on AuthException catch (e) {
      // TODO: Handle exceptions
      print(e.message);
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      // TODO: Handle exceptions
      print(e.message);
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;
} 