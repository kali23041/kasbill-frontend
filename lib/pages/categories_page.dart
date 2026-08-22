import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../components/ratnex_page_scaffold.dart';
import '../services/shop_categories_service.dart';
import '../theme/ratnex_theme.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _service = ShopCategoriesService();

  Future<void> _openAddSheet(Set<String> addedKeys) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RatnexColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _AddCategorySheet(
        addedKeys: addedKeys,
        onAdd: ({required name, required isCustom, suggestionKey}) async {
          await _service.addCategory(
            name: name,
            isCustom: isCustom,
            suggestionKey: suggestionKey,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('d MMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: RatnexColors.surface,
      floatingActionButton: StreamBuilder<List<ShopCategory>>(
        stream: _service.watchCategories(),
        builder: (context, snap) {
          final added = snap.data ?? const <ShopCategory>[];
          final addedKeys = {
            for (final c in added)
              if (c.suggestionKey != null) c.suggestionKey!,
            for (final c in added)
              JewelleryCategorySuggestions.keyFor(c.name),
          };
          return FloatingActionButton.extended(
            onPressed: () => _openAddSheet(addedKeys),
            backgroundColor: RatnexColors.ink,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text(
              'Add category',
              style: RatnexTheme.label(
                size: 13,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            right: -40,
            height: 260,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 0.95,
                    colors: [
                      RatnexColors.goldSoft.withValues(alpha: 0.55),
                      RatnexColors.surface.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 14, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        color: RatnexColors.ink,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Categories',
                              style: RatnexTheme.brand(size: 26),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Item categories  ·  $today',
                              style: RatnexTheme.label(size: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<ShopCategory>>(
                    stream: _service.watchCategories(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Could not load: ${snap.error}',
                              style: RatnexTheme.label(
                                size: 13,
                                color: RatnexColors.muted,
                              ),
                            ),
                          ),
                        );
                      }
                      if (!snap.hasData) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: RatnexColors.gold,
                          ),
                        );
                      }

                      final added = snap.data!;
                      if (added.isEmpty) {
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(14, 20, 14, 100),
                          children: [
                            RatnexPanel(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.category_outlined,
                                      size: 32,
                                      color: RatnexColors.gold,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No categories yet',
                                      style: RatnexTheme.label(
                                        size: 15,
                                        weight: FontWeight.w700,
                                        color: RatnexColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tap + Add category to choose from suggestions or create a custom one.',
                                      textAlign: TextAlign.center,
                                      style: RatnexTheme.label(
                                        size: 13,
                                        color: RatnexColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
                        children: [
                          const RatnexSectionLabel(text: 'Your categories'),
                          const SizedBox(height: 8),
                          RatnexPanel(
                            child: Column(
                              children: [
                                for (var i = 0; i < added.length; i++) ...[
                                  if (i > 0)
                                    Divider(
                                      height: 1,
                                      indent: 12,
                                      endIndent: 12,
                                      color: RatnexColors.hairline,
                                    ),
                                  _CategoryRow(
                                    category: added[i],
                                    onDelete: () =>
                                        _service.deleteCategory(added[i].id),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddCategorySheet extends StatefulWidget {
  final Set<String> addedKeys;
  final Future<void> Function({
    required String name,
    required bool isCustom,
    String? suggestionKey,
  }) onAdd;

  const _AddCategorySheet({
    required this.addedKeys,
    required this.onAdd,
  });

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  late Set<String> _addedKeys;
  final _customCtrl = TextEditingController();
  bool _savingCustom = false;
  String? _busySuggestion;

  @override
  void initState() {
    super.initState();
    _addedKeys = {...widget.addedKeys};
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _addSuggestion(String name) async {
    final key = JewelleryCategorySuggestions.keyFor(name);
    if (_addedKeys.contains(key)) return;

    setState(() => _busySuggestion = name);
    try {
      await widget.onAdd(
        name: name,
        isCustom: false,
        suggestionKey: key,
      );
      if (!mounted) return;
      setState(() {
        _addedKeys.add(key);
        _busySuggestion = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added “$name”')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busySuggestion = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _addCustom() async {
    final name = _customCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a category name')),
      );
      return;
    }

    setState(() => _savingCustom = true);
    try {
      await widget.onAdd(name: name, isCustom: true, suggestionKey: null);
      if (!mounted) return;
      final key = JewelleryCategorySuggestions.keyFor(name);
      setState(() {
        _addedKeys.add(key);
        _savingCustom = false;
      });
      _customCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added “$name”')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingCustom = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: RatnexColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add category',
                      style: RatnexTheme.label(
                        size: 18,
                        weight: FontWeight.w700,
                        color: RatnexColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: RatnexColors.muted,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customCtrl,
                      textCapitalization: TextCapitalization.words,
                      style: RatnexTheme.label(
                        size: 14,
                        weight: FontWeight.w600,
                        color: RatnexColors.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Custom category name',
                        isDense: true,
                        filled: true,
                        fillColor: RatnexColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: RatnexColors.hairline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: RatnexColors.hairline),
                        ),
                      ),
                      onSubmitted: (_) => _addCustom(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _savingCustom ? null : _addCustom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RatnexColors.ink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _savingCustom ? '…' : 'Add',
                        style: RatnexTheme.label(
                          size: 13,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Suggested',
                style: RatnexTheme.label(
                  size: 11,
                  weight: FontWeight.w600,
                  color: RatnexColors.muted,
                ).copyWith(letterSpacing: 0.4),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in JewelleryCategorySuggestions.all)
                      _SuggestionChip(
                        label: name,
                        alreadyAdded: _addedKeys.contains(
                          JewelleryCategorySuggestions.keyFor(name),
                        ),
                        busy: _busySuggestion == name,
                        onTap: () => _addSuggestion(name),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final ShopCategory category;
  final VoidCallback onDelete;

  const _CategoryRow({
    required this.category,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: RatnexColors.goldSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              category.isCustom
                  ? Icons.edit_outlined
                  : Icons.category_outlined,
              size: 18,
              color: RatnexColors.gold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: RatnexTheme.label(
                    size: 13,
                    weight: FontWeight.w700,
                    color: RatnexColors.ink,
                  ),
                ),
                Text(
                  category.isCustom ? 'Custom' : 'Suggested',
                  style: RatnexTheme.label(size: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            color: RatnexColors.muted,
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final bool alreadyAdded;
  final bool busy;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.alreadyAdded,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = alreadyAdded;
    return Material(
      color: selected ? RatnexColors.ink : RatnexColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: selected || busy ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? RatnexColors.ink : RatnexColors.hairline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: RatnexColors.gold,
                  ),
                )
              else if (selected)
                const Icon(Icons.check, size: 14, color: Colors.white)
              else
                Icon(Icons.add, size: 14, color: RatnexColors.ink),
              const SizedBox(width: 6),
              Text(
                label,
                style: RatnexTheme.label(
                  size: 12,
                  weight: FontWeight.w600,
                  color: selected ? Colors.white : RatnexColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
