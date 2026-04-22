import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../export/providers/export_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Account Section
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
            trailing: const Text('AUD'),
            onTap: () {
              // TODO: Base currency picker
            },
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Theme'),
            trailing: const Text('System'),
            onTap: () {
              // TODO: Theme picker
            },
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
          ListTile(
            title: const Text('Version'),
            trailing: const Text('1.0.0 (v3.1)'),
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
}
