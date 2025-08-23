import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:turfapp/services/auth_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('User Profile Placeholder'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
                // After signing out, you might want to navigate to the login screen
                // For now, we'll just pop the profile screen.
                // The auth state listener should handle the redirection.
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
} 