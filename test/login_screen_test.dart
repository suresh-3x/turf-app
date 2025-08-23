import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:turfapp/screens/auth/login_screen.dart';
import 'package:turfapp/services/auth_service.dart';

void main() {
  group('LoginScreen Widget Tests', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
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
      expect(find.byType(TextField), findsNWidgets(2));
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

      await tester.enterText(
          find.byType(TextField).first, 'test@example.com');
      await tester.enterText(
          find.byType(TextField).last, 'password123');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      verify(mockAuthService.signIn(
          'test@example.com', 'password123')).called(1);
    });
  });
}

class MockAuthService extends Mock implements AuthService {
  @override
  Future<void> signIn(String email, String password) async {
    return super.noSuchMethod(
      Invocation.method(#signIn, [email, password]),
      returnValue: Future<void>.value(),
    );
  }
}