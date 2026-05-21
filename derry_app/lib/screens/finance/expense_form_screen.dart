import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/finance_provider.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _form = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;
  String _userId = '';
  Uint8List? _receiptBytes;
  String? _receiptFileName;

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
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _receiptBytes = bytes;
        _receiptFileName = picked.name;
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir tutar girin.')));
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(financeServiceProvider).addExpense(
        userId: _userId,
        amount: amount,
        description: _descCtrl.text.trim(),
        receiptBytes: _receiptBytes,
        receiptFileName: _receiptFileName,
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Harcama Ekle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Amount
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Tutar',
                prefixText: '€ ',
                prefixStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Tutar gerekli';
                if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Geçerli tutar girin';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Açıklama *'),
              validator: (v) => v == null || v.isEmpty ? 'Açıklama gerekli' : null,
            ),
            const SizedBox(height: 24),

            // Receipt photo
            const Text('Fiş Fotoğrafı',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickReceipt,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _receiptBytes != null
                        ? AppTheme.primary
                        : const Color(0xFFD1D5DB),
                    width: _receiptBytes != null ? 2 : 1,
                  ),
                ),
                child: _receiptBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(children: [
                          Image.memory(_receiptBytes!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover),
                          Positioned(
                            right: 8, top: 8,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _receiptBytes = null;
                                _receiptFileName = null;
                              }),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.black54,
                                child: const Icon(Icons.close_rounded,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ]),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded,
                              size: 36, color: AppTheme.textSecondary),
                          SizedBox(height: 8),
                          Text('Fiş fotoğrafı ekle (isteğe bağlı)',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    : const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
