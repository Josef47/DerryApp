import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/shopping_item_model.dart';
import '../../providers/shopping_provider.dart';

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _userId = '';
  bool _isHM = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      _userId = prefs.getString(AppConstants.prefUserId) ?? '';
      _isHM = prefs.getBool(AppConstants.prefIsHousemaster) ?? false;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alışveriş'),
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        actions: [
          IconButton(
            icon: const Icon(Icons.credit_card_rounded),
            tooltip: 'Sadakat Kartları',
            onPressed: () => context.push('/shopping/loyalty-cards'),
          ),
          if (_isHM)
            IconButton(
              icon: const Icon(Icons.category_rounded),
              tooltip: 'Kategoriler',
              onPressed: () => _showCategoryManager(context),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Liste'),
            Tab(text: 'Arşiv'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemDialog(context),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Ürün Ekle'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ActiveListView(userId: _userId),
          _ArchiveView(),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddItemSheet(userId: _userId),
    );
  }

  void _showCategoryManager(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryManagerSheet(userId: _userId),
    );
  }
}

class _ActiveListView extends ConsumerWidget {
  final String userId;
  const _ActiveListView({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(activeShoppingItemsProvider);
    final categoriesAsync = ref.watch(shoppingCategoriesProvider);

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.shopping_basket_rounded, size: 64, color: AppTheme.textSecondary),
              SizedBox(height: 12),
              Text('Alışveriş listesi boş!',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ]),
          );
        }

        final categories = categoriesAsync.value?.map((c) => c.name).toList() ?? [];
        final categorized = <String, List<ShoppingItemModel>>{};
        for (final item in items) {
          categorized.putIfAbsent(item.category, () => []).add(item);
        }

        // Sort categories: known first
        final sortedCats = categorized.keys.toList()
          ..sort((a, b) {
            final ai = categories.indexOf(a);
            final bi = categories.indexOf(b);
            if (ai == -1 && bi == -1) return a.compareTo(b);
            if (ai == -1) return 1;
            if (bi == -1) return -1;
            return ai.compareTo(bi);
          });

        return ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            for (final cat in sortedCats) ...[
              _CategoryHeader(cat, categorized[cat]!.length),
              ...categorized[cat]!.map((item) => _ShoppingItemTile(
                    item: item,
                    userId: userId,
                  )),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String name;
  final int count;
  const _CategoryHeader(this.name, this.count);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(children: [
        const Icon(Icons.label_rounded, size: 14, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text('$name ($count)',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTheme.primary)),
        const Expanded(child: Divider(indent: 8)),
      ]),
    );
  }
}

class _ShoppingItemTile extends ConsumerWidget {
  final ShoppingItemModel item;
  final String userId;

  const _ShoppingItemTile({required this.item, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urgencyColor = switch (item.urgency) {
      'High' => AppTheme.error,
      'Medium' => AppTheme.warning,
      _ => AppTheme.textSecondary,
    };

    return Card(
      child: ListTile(
        leading: item.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(item.imageUrl!,
                    width: 44, height: 44, fit: BoxFit.cover))
            : Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shopping_bag_rounded,
                    color: AppTheme.primary, size: 22),
              ),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (item.description != null)
            Text(item.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: urgencyColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(item.urgency,
                  style: TextStyle(
                      fontSize: 10,
                      color: urgencyColor,
                      fontWeight: FontWeight.w600)),
            ),
            if (item.expectedPrice != null) ...[
              const SizedBox(width: 6),
              Text('~${AppConstants.formatAmount(item.expectedPrice!)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ]),
        ]),
        trailing: IconButton(
          icon: const Icon(Icons.check_circle_outline_rounded, size: 28),
          color: AppTheme.primary,
          onPressed: () async {
            await ref.read(shoppingServiceProvider).markBought(item.id, userId);
          },
        ),
      ),
    );
  }
}

class _ArchiveView extends ConsumerWidget {
  const _ArchiveView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(archivedShoppingItemsProvider);

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text('Arşiv boş.',
                style: TextStyle(color: AppTheme.textSecondary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle_rounded, color: AppTheme.success),
                title: Text(item.title,
                    style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: AppTheme.textSecondary)),
                subtitle: item.boughtAt != null
                    ? Text('Satın alındı: ${AppConstants.formatDate(item.boughtAt!)}',
                        style: const TextStyle(fontSize: 11))
                    : null,
                trailing: Text(item.category,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }
}

class _AddItemSheet extends ConsumerStatefulWidget {
  final String userId;
  const _AddItemSheet({required this.userId});

  @override
  ConsumerState<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<_AddItemSheet> {
  final _form = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String _urgency = 'Low';
  String? _category;
  DateTime? _deadline;
  Uint8List? _imageBytes;
  String? _imageFileName;
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() { _imageBytes = bytes; _imageFileName = picked.name; });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final item = ShoppingItemModel(
        id: '',
        title: _titleCtrl.text.trim(),
        category: _category ?? 'Diğer',
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        urgency: _urgency,
        deadline: _deadline,
        expectedPrice: double.tryParse(_priceCtrl.text.replaceAll(',', '.')),
        addedBy: widget.userId,
      );
      await ref.read(shoppingServiceProvider).addItem(
        item,
        imageBytes: _imageBytes,
        fileName: _imageFileName,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCategoryPicker(BuildContext context, List categories) {
    final options = [...categories.map((c) => c.name as String), 'Yeni Kategori'];
    int selectedIndex = _category != null
        ? options.indexOf(_category!)
        : 0;
    if (selectedIndex < 0) selectedIndex = 0;
    final controller = FixedExtentScrollController(initialItem: selectedIndex);
    final newCatCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final isNewCat = selectedIndex == options.length - 1;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('İptal'),
                  ),
                  const Text('Kategori Seç',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () async {
                      if (isNewCat) {
                        final name = newCatCtrl.text.trim();
                        if (name.isNotEmpty) {
                          await ref.read(shoppingServiceProvider)
                              .addCategory(name, widget.userId);
                          setState(() => _category = name);
                        }
                      } else {
                        setState(() => _category = options[selectedIndex]);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Tamam',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: CupertinoPicker(
                scrollController: controller,
                itemExtent: 44,
                onSelectedItemChanged: (i) => setS(() => selectedIndex = i),
                children: options.map((o) => Center(
                  child: Text(
                    o,
                    style: TextStyle(
                      fontSize: 18,
                      color: o == 'Yeni Kategori'
                          ? AppTheme.primary
                          : Colors.black87,
                      fontWeight: o == 'Yeni Kategori'
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                )).toList(),
              ),
            ),
            if (isNewCat)
              Padding(
                padding: EdgeInsets.only(
                  left: 24, right: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: TextField(
                  controller: newCatCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Kategori adı'),
                ),
              )
            else
              const SizedBox(height: 24),
          ]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(shoppingCategoriesProvider);
    final categories = categoriesAsync.value ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24, right: 24, top: 16,
      ),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Ürün Ekle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Ürün adı *'),
              validator: (v) => v == null || v.isEmpty ? 'Gerekli' : null,
            ),
            const SizedBox(height: 12),

            // Category picker row
            InkWell(
              onTap: () => _showCategoryPicker(context, categories),
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Kategori (opsiyonel)'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _category ?? 'Seç...',
                      style: TextStyle(
                        color: _category != null ? Colors.black87 : AppTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    const Icon(Icons.expand_more_rounded, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Açıklama'),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Tahmini fiyat', prefixText: '€ '),
              )),
            ]),
            const SizedBox(height: 12),

            // Urgency
            Row(children: [
              const Text('Aciliyet: ',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              ...['Low', 'Medium', 'High'].map((u) {
                final selected = _urgency == u;
                final chipColor = switch (u) {
                  'Medium' => Colors.amber,
                  'High' => AppTheme.error,
                  _ => AppTheme.textSecondary,
                };
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      switch (u) {
                        'Low' => 'Düşük',
                        'Medium' => 'Orta',
                        _ => 'Yüksek',
                      },
                      style: TextStyle(
                        color: selected ? Colors.white : chipColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: selected,
                    selectedColor: chipColor,
                    onSelected: (_) => setState(() => _urgency = u),
                  ),
                );
              }),
            ]),
            const SizedBox(height: 12),

            // Image
            if (_imageBytes != null)
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_imageBytes!, height: 80, fit: BoxFit.cover,
                      width: double.infinity),
                ),
                Positioned(right: 4, top: 4,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _imageBytes = null; _imageFileName = null;
                    }),
                    child: const CircleAvatar(radius: 12,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close_rounded, size: 14, color: Colors.white)),
                  )),
              ])
            else
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_rounded),
                label: const Text('Fotoğraf ekle'),
              ),
            const SizedBox(height: 16),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    : const Text('Listeye Ekle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryManagerSheet extends ConsumerStatefulWidget {
  final String userId;
  const _CategoryManagerSheet({required this.userId});

  @override
  ConsumerState<_CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends ConsumerState<_CategoryManagerSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(shoppingCategoriesProvider);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Kategoriler',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(labelText: 'Yeni kategori'),
          )),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () async {
              if (_ctrl.text.trim().isNotEmpty) {
                await ref.read(shoppingServiceProvider)
                    .addCategory(_ctrl.text.trim(), widget.userId);
                _ctrl.clear();
              }
            },
            child: const Text('Ekle'),
          ),
        ]),
        const SizedBox(height: 16),
        categoriesAsync.when(
          data: (cats) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cats.map((c) => Chip(
              label: Text(c.name),
              onDeleted: () async {
                await ref.read(shoppingServiceProvider).deleteCategory(c.id);
              },
            )).toList(),
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('Yüklenemedi'),
        ),
      ]),
    );
  }
}
