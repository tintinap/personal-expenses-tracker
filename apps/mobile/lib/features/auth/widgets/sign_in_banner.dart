import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

class SignInBanner extends ConsumerStatefulWidget {
  const SignInBanner({super.key});

  @override
  ConsumerState<SignInBanner> createState() => _SignInBannerState();
}

class _SignInBannerState extends ConsumerState<SignInBanner> {
  bool _isVisible = true;

  void _showAuthBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return const AuthBottomSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    if (authState.isAuthenticated || !_isVisible) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sign in to sync your data securely',
                    style: TextStyle(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showAuthBottomSheet(context, ref),
                    child: Text(
                      'Tap to connect',
                      style: TextStyle(
                        color: theme.colorScheme.tertiary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: theme.colorScheme.onTertiaryContainer),
              onPressed: () => setState(() => _isVisible = false),
            )
          ],
        ),
      ),
    );
  }
}

class AuthBottomSheet extends ConsumerWidget {
  const AuthBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sign In',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Back up your wallets safely to the cloud.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (authState.isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              FilledButton.icon(
                onPressed: () async {
                  await ref.read(authStateProvider.notifier).signInWithGoogle();
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Continue with Google'),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () async {
                  await ref.read(authStateProvider.notifier).signInWithApple();
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.apple),
                label: const Text('Continue with Apple'),
              ),
            ],
            if (authState.error != null) ...[
              const SizedBox(height: 16),
              Text(
                authState.error!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ]
          ],
        ),
      ),
    );
  }
}
