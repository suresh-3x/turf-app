import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

/// Shown while the signed-in user's profile loads. The router moves on from
/// here automatically; this only needs to handle the failure cases.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);

    Widget body;
    if (profile.hasError ||
        (profile.hasValue && profile.value == null && ref.watch(currentUserIdProvider) != null)) {
      final message = profile.hasError
          ? friendlyError(profile.error!)
          : "We couldn't find your profile. Try again, or sign out and sign up again.";
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.invalidate(currentProfileProvider),
            child: const Text('Try again'),
          ),
          TextButton(
            onPressed: () => ref.read(authServiceProvider).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      );
    } else {
      body = const CircularProgressIndicator();
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_soccer, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(appName, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 32),
              body,
            ],
          ),
        ),
      ),
    );
  }
}
