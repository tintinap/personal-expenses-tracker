import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/currency_helper.dart';
import '../../export/providers/export_provider.dart';
import '../../shared/providers/shared_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'Account'),
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: const Text('Sign In'),
            subtitle: const Text('Sync data across devices'),
            onTap: () {
              // TODO: Auth flow
            },
          ),
          const Divider(),
          _buildSectionHeader(context, 'Preferences'),
          ListTile(
            leading: const Icon(Icons.monetization_on),
            title: const Text('Base Currency'),
            subtitle: Text(_currencyDisplayName(baseCurrency)),
            trailing: Text(
              baseCurrency,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => _showCurrencyPicker(context, ref, baseCurrency),
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Theme'),
            trailing: Text(
              _themeLabel(themeMode),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => _showThemePicker(context, ref, themeMode),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Data & Automation'),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/categories'),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: const Text('Google Sheets Sync'),
            subtitle: const Text('Not connected'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Google Sheets connect flow
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_view),
            title: const Text('Export to Excel'),
            onTap: () {
              ref.read(exportProvider).exportToExcel();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Generating Excel export...')),
              );
            },
          ),
          const Divider(),
          _buildSectionHeader(context, 'About'),
          const ListTile(
            title: Text('Version'),
            trailing: Text('1.0.0 (v3.0)'),
            onTap: null,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  String _currencyDisplayName(String code) {
    return CurrencyCode.fromCode(code)?.name ?? code;
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  Future<void> _showCurrencyPicker(
    BuildContext context,
    WidgetRef ref,
    String selected,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text('Base currency', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: CurrencyCode.values.map((c) {
                    final isSelected = c.code == selected;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          c.symbol,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(c.name),
                      subtitle: Text(c.code),
                      trailing: isSelected
                          ? Icon(
                              Icons.check,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.of(ctx).pop(c.code),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null && picked != selected) {
      await ref.read(baseCurrencyProvider.notifier).set(picked);
    }
  }

  Future<void> _showThemePicker(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text('Theme', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...ThemeMode.values.map((mode) {
                final isSelected = mode == current;
                return ListTile(
                  leading: Icon(_themeIcon(mode)),
                  title: Text(_themeLabel(mode)),
                  trailing: isSelected
                      ? Icon(
                          Icons.check,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(mode),
                );
              }),
            ],
          ),
        );
      },
    );

    if (picked != null && picked != current) {
      await ref.read(themeModeProvider.notifier).set(picked);
    }
  }

  IconData _themeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }
}
