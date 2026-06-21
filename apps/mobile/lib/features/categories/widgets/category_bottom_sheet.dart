import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../core/database/database.dart';
import '../../../core/presentation/category_visuals.dart';
import '../../../core/providers/database_providers.dart';
import '../category_icon_picker_data.dart';
import '../../shared/providers/shared_providers.dart';

/// Bottom sheet for creating or editing a category / sub-category.
///
/// Usage:
///   - Top-level: `CategoryBottomSheet.show(context)`
///   - Sub-category: `CategoryBottomSheet.show(context, parentId: 'xxx', parentColor: '#F44336', parentName: 'Subscriptions')`
///   - Edit: `CategoryBottomSheet.show(context, category: existingCat, parentColor: '#F44336')`
class CategoryBottomSheet extends ConsumerStatefulWidget {
  final CategoryData? initialCategory;
  final String? parentId;
  final String? parentName;
  /// Parent's colourHex — inherited by sub-categories
  final String? parentColor;
  /// Parent's iconCodePoint — used as the default icon for new sub-categories
  /// (and as a fallback when editing a sub-category whose icon is unset).
  final int? parentIconCodePoint;

  const CategoryBottomSheet({
    super.key,
    this.initialCategory,
    this.parentId,
    this.parentName,
    this.parentColor,
    this.parentIconCodePoint,
  });

  static Future<void> show(BuildContext context, {
    CategoryData? category,
    String? parentId,
    String? parentName,
    String? parentColor,
    int? parentIconCodePoint,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CategoryBottomSheet(
        initialCategory: category,
        parentId: parentId,
        parentName: parentName,
        parentColor: parentColor,
        parentIconCodePoint: parentIconCodePoint,
      ),
    );
  }

  @override
  ConsumerState<CategoryBottomSheet> createState() => _CategoryBottomSheetState();
}

class _CategoryBottomSheetState extends ConsumerState<CategoryBottomSheet> {
  final _nameController = TextEditingController();
  String _selectedColor = '#378ADD';
  late int _selectedIconCode;

  static const _colorOptions = [
    '#378ADD', '#4CAF50', '#FF7043', '#E91E8C',
    '#9C27B0', '#009688', '#FFC107', '#FF8F00',
    '#F44336', '#455A64', '#4FC3F7', '#9E9E9E',
    '#00BCD4', '#8BC34A', '#FF5722', '#795548',
  ];

  bool get _isEditing => widget.initialCategory != null;
  bool get _isSubCategory =>
      widget.parentId != null || (widget.initialCategory?.parentId != null);

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _nameController.text = widget.initialCategory!.name;
      _selectedColor = widget.initialCategory!.colourHex;
      _selectedIconCode = widget.initialCategory!.iconCodePoint;
    } else {
      _selectedIconCode = widget.parentIconCodePoint ?? _resolveParentIconCode() ?? Icons.category.codePoint;
    }
    if (widget.initialCategory == null && widget.parentColor != null) {
      // Sub-category inherits parent color by default
      _selectedColor = widget.parentColor!;
    }
  }

  int? _resolveParentIconCode() {
    final parentId = widget.parentId ?? widget.initialCategory?.parentId;
    if (parentId == null) return null;
    final all = ref.read(categoryListProvider).valueOrNull ?? [];
    return all.where((c) => c.id == parentId).firstOrNull?.iconCodePoint;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildIconPicker(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Icon', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kCategoryIconChoices.map((icon) {
            final code = icon.codePoint;
            final selected = code == _selectedIconCode;
            final previewColour = _parseHex(_selectedColor);
            return InkWell(
              onTap: () => setState(() => _selectedIconCode = code),
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? theme.colorScheme.primary : Colors.transparent,
                    width: selected ? 2.5 : 1,
                  ),
                  color: previewColour.withValues(alpha: selected ? 0.28 : 0.12),
                ),
                child: Icon(icon, color: previewColour, size: 22),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _parseHex(String hexColor) {
    return parseHexColour(hexColor);
  }

  void _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final dao = ref.read(categoryDaoProvider);
    final db = ref.read(databaseProvider);
    final now = DateTime.now();

    if (_isEditing) {
      final cat = widget.initialCategory!;
      await (db.update(db.categories)..where((c) => c.id.equals(cat.id))).write(
        CategoriesCompanion(
          name: Value(name),
          colourHex: Value(_selectedColor),
          iconCodePoint: Value(_selectedIconCode),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
      await db.addToSyncQueue(
        id: const Uuid().v4(),
        recordType: 'category',
        recordId: cat.id,
        operation: 'update',
        payload: '{}',
      );
    } else {
      final allCategories = ref.read(categoryListProvider).valueOrNull ?? [];
      final maxSort = allCategories.isEmpty
          ? 0
          : allCategories.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b);
      final newId = const Uuid().v4();

      await dao.insertCategory(CategoriesCompanion.insert(
        id: newId,
        name: name,
        colourHex: _selectedColor,
        iconCodePoint: Value(_selectedIconCode),
        sortOrder: maxSort + 1,
        parentId: Value(widget.parentId),
        syncStatus: const Value('pending'),
      ));
      await db.addToSyncQueue(
        id: const Uuid().v4(),
        recordType: 'category',
        recordId: newId,
        operation: 'insert',
        payload: '{}',
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    // Sub-category: just name field + small color swatch (read-only)
    if (_isSubCategory) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                categoryGlyphAvatar(
                  colour: _parseHex(_selectedColor),
                  iconCodePoint: _selectedIconCode,
                  radius: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit sub-category' : 'New sub-category',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (widget.parentName != null)
                  Flexible(
                    child: Text(
                      'Under: ${widget.parentName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildIconPicker(theme),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save' : 'Add'),
            ),
          ],
        ),
      );
    }

    // Top-level category: name + color picker
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit Category' : 'New Category',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _buildIconPicker(theme),
            const SizedBox(height: 16),
            Text('Color', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorOptions.map((hex) {
                final isSelected = hex == _selectedColor;
                final color = _parseHex(hex);
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                          : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save Changes' : 'Create Category'),
            ),
          ],
        ),
      ),
    );
  }
}
