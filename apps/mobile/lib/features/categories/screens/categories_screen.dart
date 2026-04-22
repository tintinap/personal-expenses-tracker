import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';
import '../../shared/providers/shared_providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Color _parseHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, CategoryData category) {
    final controller = TextEditingController(text: category.name);
    final dao = ref.read(categoryDaoProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != category.name) {
                (dao.db.update(dao.db.categories)
                      ..where((c) => c.id.equals(category.id)))
                    .write(CategoriesCompanion(
                  name: Value(newName),
                  updatedAt: Value(DateTime.now()),
                  syncStatus: const Value('pending'),
                ));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CategoryData category) async {
    final dao = ref.read(categoryDaoProvider);
    final count = await dao.countAssociatedExpenses(category.id);
    
    if (!context.mounted) return;

    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete: $count transactions use this category. Reassign them first.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              dao.deleteCategory(category.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryListProvider);
    final dao = ref.read(categoryDaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('No categories found.'));
          }

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              Color catColor = Colors.grey;
              try {
                catColor = _parseHex(cat.colourHex);
              } catch (_) {}

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: catColor,
                  radius: 16,
                ),
                title: Text(
                  cat.name,
                  style: TextStyle(
                    decoration: cat.isHidden ? TextDecoration.lineThrough : null,
                    color: cat.isHidden ? Colors.grey : null,
                  ),
                ),
                subtitle: cat.isHidden ? const Text('Hidden from lists') : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(cat.isHidden ? Icons.visibility_off : Icons.visibility),
                      tooltip: cat.isHidden ? 'Show category' : 'Hide category',
                      onPressed: () {
                        dao.toggleHidden(cat.id, !cat.isHidden);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context, ref, cat),
                    ),
                  ],
                ),
                onTap: () => _showEditDialog(context, ref, cat),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Open Add Category sheet
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
