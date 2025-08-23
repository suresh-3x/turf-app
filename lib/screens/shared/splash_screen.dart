import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('SplashScreen builds');
    ref.listen<AsyncValue<AuthState?>>(authStateProvider, (previous, next) {
      print('SplashScreen: authStateProvider emitted: $next');
      next.when(
        data: (state) {
          print('SplashScreen: Auth session: ${state?.session}');
          if (state?.session != null) {
            print('SplashScreen: Navigating to /home');
            context.go('/home');
          } else {
            print('SplashScreen: Navigating to /onboarding');
            context.go('/onboarding');
          }
        },
        loading: () => print('SplashScreen: authStateProvider loading'),
        error: (e, st) => print('SplashScreen: authStateProvider error: $e'),
      );
    });

    Future.delayed(const Duration(seconds: 10), () {
      print('SplashScreen: Timeout reached, still waiting for auth state...');
    });

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
} 