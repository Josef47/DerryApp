import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/loyalty_card_model.dart';
import '../../providers/shopping_provider.dart';

class LoyaltyCardsScreen extends ConsumerStatefulWidget {
  const LoyaltyCardsScreen({super.key});

  @override
  ConsumerState<LoyaltyCardsScreen> createState() => _LoyaltyCardsScreenState();
}

class _LoyaltyCardsScreenState extends ConsumerState<LoyaltyCardsScreen> {
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userId = prefs.getString(AppConstants.prefUserId) ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(loyaltyCardsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sadakat Kartları'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCardDialog(context),
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('Kart Ekle'),
      ),
      body: cardsAsync.when(
        data: (cards) {
          if (cards.isEmpty) {
            return const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.credit_card_off_rounded, size: 64, color: AppTheme.textSecondary),
                SizedBox(height: 12),
                Text('Henüz sadakat kartı eklenmedi.',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ]),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: cards.length,
            itemBuilder: (context, i) => _CardTile(
              card: cards[i],
              onTap: () => _showCardFullscreen(context, cards[i]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  void _showAddCardDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddCardSheet(userId: _userId),
    );
  }

  void _showCardFullscreen(BuildContext context, LoyaltyCardModel card) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(card.storeName),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (card.cardImageUrl != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(card.cardImageUrl!),
                  ),
                ),
              if (card.barcodeValue != null) ...[
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(children: [
                    Text(
                      card.barcodeValue!,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    if (card.barcodeType != null) ...[
                      const SizedBox(height: 4),
                      Text(card.barcodeType!,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _CardTile extends ConsumerWidget {
  final LoyaltyCardModel card;
  final VoidCallback onTap;

  const _CardTile({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF2D6A4F), Color(0xFF52B788)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(children: [
          if (card.cardImageUrl != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(card.cardImageUrl!,
                    fit: BoxFit.cover,
                    color: Colors.black26,
                    colorBlendMode: BlendMode.darken),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.credit_card_rounded, color: Colors.white70, size: 20),
                Text(card.storeName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
          ),
          Positioned(
            right: 4, top: 4,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 18),
              onSelected: (v) async {
                if (v == 'delete') {
                  await ref.read(shoppingServiceProvider).deleteLoyaltyCard(card.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete',
                    child: Text('Sil', style: TextStyle(color: Colors.red))),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _AddCardSheet extends ConsumerStatefulWidget {
  final String userId;
  const _AddCardSheet({required this.userId});

  @override
  ConsumerState<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends ConsumerState<_AddCardSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _storeCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  bool _scanning = false;
  bool _loading = false;
  Uint8List? _imageBytes;
  String? _imageFileName;
  String? _scannedType;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _storeCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() { _imageBytes = bytes; _imageFileName = picked.name; });
    }
  }

  Future<void> _save() async {
    if (_storeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mağaza adı girin.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final card = LoyaltyCardModel(
        id: '',
        storeName: _storeCtrl.text.trim(),
        barcodeValue: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        barcodeType: _scannedType,
        addedBy: widget.userId,
      );
      await ref.read(shoppingServiceProvider).addLoyaltyCard(
        card,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24, right: 24, top: 16,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Kart Ekle',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        TextField(
          controller: _storeCtrl,
          decoration: const InputDecoration(labelText: 'Mağaza Adı *'),
        ),
        const SizedBox(height: 16),

        TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Fotoğraf'),
            Tab(text: 'Barkod Tara'),
          ],
        ),
        SizedBox(
          height: 220,
          child: TabBarView(
            controller: _tabs,
            children: [
              // Photo tab
              Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (_imageBytes != null)
                  Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_imageBytes!, height: 120, fit: BoxFit.cover),
                    ),
                    Positioned(right: 4, top: 4,
                      child: GestureDetector(
                        onTap: () => setState(() { _imageBytes = null; _imageFileName = null; }),
                        child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54,
                            child: Icon(Icons.close_rounded, size: 14, color: Colors.white)),
                      )),
                  ])
                else
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Galeriden Seç'),
                  ),
              ])),

              // Scanner tab
              _scanning
                  ? Stack(children: [
                      MobileScanner(
                        onDetect: (capture) {
                          final barcode = capture.barcodes.first;
                          if (barcode.rawValue != null) {
                            setState(() {
                              _barcodeCtrl.text = barcode.rawValue!;
                              _scannedType = barcode.format.name;
                              _scanning = false;
                            });
                          }
                        },
                      ),
                      Positioned(
                        bottom: 8, left: 0, right: 0,
                        child: Center(child: OutlinedButton(
                          style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                          onPressed: () => setState(() => _scanning = false),
                          child: const Text('İptal'),
                        )),
                      ),
                    ])
                  : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (_barcodeCtrl.text.isNotEmpty)
                        Text('✓ ${_barcodeCtrl.text}',
                            style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _scanning = true),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: Text(_barcodeCtrl.text.isEmpty ? 'Barkod Tara' : 'Yeniden Tara'),
                      ),
                      const SizedBox(height: 8),
                      const Text('veya manuel girin:',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _barcodeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Barkod değeri',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ])),
            ],
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                : const Text('Kartı Kaydet'),
          ),
        ),
      ]),
    );
  }
}
