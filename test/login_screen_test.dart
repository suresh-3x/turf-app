import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:turfapp/screens/auth/login_screen.dart';
import 'package:turfapp/services/auth_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('LoginScreen Widget Tests', () {
    late _FakeAuthService mockAuthService;

    setUp(() {
      mockAuthService = _FakeAuthService();
    });

    testWidgets('renders login form elements', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text('Login'), findsNWidgets(2)); // AppBar and button
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('calls signIn when form is submitted', 
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(mockAuthService.capturedEmail, 'test@example.com');
      expect(mockAuthService.capturedPassword, 'password123');
    });
  });
}

class _FakeAuthService implements AuthService {
  String? capturedEmail;
  String? capturedPassword;

  @override
  Future<void> signIn(String email, String password) async {
    capturedEmail = email;
    capturedPassword = password;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  User? get currentUser => null;
}
