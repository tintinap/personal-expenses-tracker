import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/presentation/category_visuals.dart';
import '../../../core/providers/database_providers.dart';
import '../../shared/providers/shared_providers.dart';
import '../widgets/category_bottom_sheet.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  // Tracks which parent IDs have their sub-categories expanded
  final Set<String> _expandedParents = {};

  Color _parseHex(String hexColor) {
    return parseHexColour(hexColor);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CategoryData category) async {
    final dao = ref.read(categoryDaoProvider);
    final expenseCount = await dao.countAssociatedExpenses(category.id);

    if (!context.mounted) return;

    if (expenseCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Cannot delete: $expenseCount transactions use this category.'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
      return;
    }

    if (category.parentId == null) {
      final childCount = await dao.countSubCategories(category.id);
      if (!context.mounted) return;
      if (childCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Cannot delete: $childCount sub-categories exist. Remove them first.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
        return;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${category.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () { dao.deleteCategory(category.id); Navigator.pop(ctx); },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryListProvider);
    final dao = ref.read(categoryDaoProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('No categories found.'));
          }

          final parents = categories.where((c) => c.parentId == null).toList();
          final childrenMap = <String, List<CategoryData>>{};
          for (final cat in categories) {
            if (cat.parentId != null) {
              childrenMap.putIfAbsent(cat.parentId!, () => []).add(cat);
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: parents.length,
            itemBuilder: (context, index) {
              final parent = parents[index];
              final children = childrenMap[parent.id] ?? [];
              final isExpanded = _expandedParents.contains(parent.id);
              final parentColor = _parseHex(parent.colourHex);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Parent tile ──
                    ListTile(
                      leading: categoryGlyphAvatar(
                        colour: parentColor,
                        iconCodePoint: parent.iconCodePoint,
                        radius: 18,
                      ),
                      title: Text(
                        parent.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: parent.isHidden ? TextDecoration.lineThrough : null,
                          color: parent.isHidden ? Colors.grey : null,
                        ),
                      ),
                      subtitle: children.isNotEmpty
                          ? Text(
                              '${children.length} sub-categor${children.length == 1 ? 'y' : 'ies'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Toggle expand/collapse if has children
                          if (children.isNotEmpty)
                            IconButton(
                              icon: AnimatedRotation(
                                turns: isExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(Icons.keyboard_arrow_down, size: 20),
                              ),
                              onPressed: () => setState(() {
                                if (isExpanded) {
                                  _expandedParents.remove(parent.id);
                                } else {
                                  _expandedParents.add(parent.id);
                                }
                              }),
                            ),
                          // If NO children yet, show "+" button next to the eye icon
                          if (children.isEmpty)
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () => CategoryBottomSheet.show(
                                context,
                                parentId: parent.id,
                                parentName: parent.name,
                                parentColor: parent.colourHex,
                                parentIconCodePoint: parent.iconCodePoint,
                              ),
                            ),
                          IconButton(
                            icon: Icon(
                              parent.isHidden ? Icons.visibility_off : Icons.visibility,
                              size: 18,
                            ),
                            onPressed: () => dao.toggleHidden(parent.id, !parent.isHidden),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _confirmDelete(context, ref, parent),
                          ),
                        ],
                      ),
                      onTap: () => CategoryBottomSheet.show(context, category: parent),
                    ),

                    // ── Sub-categories (collapsed by default) ──
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 200),
                      crossFadeState: isExpanded
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: Column(
                        children: [
                          ...children.map((child) => Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: ListTile(
                              dense: true,
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.subdirectory_arrow_right,
                                      size: 14, color: Colors.grey[400]),
                                  const SizedBox(width: 6),
                                  categoryGlyphAvatar(
                                    colour: _parseHex(child.colourHex),
                                    iconCodePoint: child.iconCodePoint,
                                    radius: 10,
                                  ),
                                ],
                              ),
                              title: Text(
                                child.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  decoration: child.isHidden ? TextDecoration.lineThrough : null,
                                  color: child.isHidden ? Colors.grey : null,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      child.isHidden ? Icons.visibility_off : Icons.visibility,
                                      size: 16,
                                    ),
                                    onPressed: () => dao.toggleHidden(child.id, !child.isHidden),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    onPressed: () => _confirmDelete(context, ref, child),
                                  ),
                                ],
                              ),
                              onTap: () => CategoryBottomSheet.show(
                                context,
                                category: child,
                                parentColor: parent.colourHex,
                                parentName: parent.name,
                                parentIconCodePoint: parent.iconCodePoint,
                              ),
                            ),
                          )),
                          // "+ Add sub-category" inline button
                          Padding(
                            padding: const EdgeInsets.only(left: 32, bottom: 6),
                            child: TextButton.icon(
                              onPressed: () => CategoryBottomSheet.show(
                                context,
                                parentId: parent.id,
                                parentName: parent.name,
                                parentColor: parent.colourHex,
                                parentIconCodePoint: parent.iconCodePoint,
                              ),
                              icon: Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
                              label: Text(
                                'Add sub-category',
                                style: TextStyle(fontSize: 13, color: theme.colorScheme.primary),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                minimumSize: const Size(0, 32),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // When collapsed, empty box (since '+' is now in trailing actions)
                      secondChild: const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => CategoryBottomSheet.show(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
