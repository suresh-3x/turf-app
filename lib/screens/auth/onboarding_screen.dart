import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../utils/constants.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.sports_soccer, size: 88, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(appName, textAlign: TextAlign.center, style: theme.textTheme.displaySmall),
              const SizedBox(height: 12),
              Text(
                'Book turfs, courts and game zones near you — or list your own '
                'and take bookings.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              const _Feature(icon: Icons.search, text: 'Find places to play nearby'),
              const _Feature(
                icon: Icons.event_available,
                text: 'See free slots and book in seconds',
              ),
              const _Feature(
                icon: Icons.storefront,
                text: 'Own a venue? Manage slots and bookings',
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.push('/signup'),
                child: const Text('Create an account'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/login'),
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
