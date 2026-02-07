// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:turfapp/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:turfapp/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthService implements AuthService {
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  User? get currentUser => null;
}

void main() {
  testWidgets('TurfApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame with provider overrides to avoid real Supabase.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => const Stream<AuthState>.empty()),
          authServiceProvider.overrideWithValue(_FakeAuthService()),
        ],
        child: const TurfApp(),
      ),
    );

    // Simple smoke check that app renders without exceptions.
    // Allow timers to complete
    await tester.pump(const Duration(seconds: 11));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
