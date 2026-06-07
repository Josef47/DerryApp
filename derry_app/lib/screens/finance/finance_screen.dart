import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/finance_entry_model.dart';
import '../../providers/finance_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      _userId = prefs.getString(AppConstants.prefUserId) ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(balanceProvider);
    final entriesAsync = ref.watch(financeEntriesProvider);
    final isHM = ref.watch(isHousemasterProvider);
    final isTreasurer = ref.watch(isTreasurerProvider);
    final canManage = isHM || isTreasurer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finans'),
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Bakiyeyi Güncelle',
              onPressed: () => _showUpdateBalanceDialog(context),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (canManage) ...[
            FloatingActionButton.extended(
              heroTag: 'addFunds',
              onPressed: () => _showAddFundsDialog(context),
              backgroundColor: AppTheme.success,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Fon Ekle'),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.extended(
            heroTag: 'addExpense',
            onPressed: () => context.push('/finance/new'),
            icon: const Icon(Icons.remove_circle_outline_rounded),
            label: const Text('Harcama Ekle'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance card
          balanceAsync.when(
            data: (balance) => _BalanceCard(
              balance: balance?.currentBalance ?? 0,
              lastUpdatedBy: balance?.lastUpdatedBy,
              lastUpdatedAt: balance?.lastUpdatedAt,
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Entries list
          Expanded(
            child: entriesAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.receipt_long_rounded, size: 64, color: AppTheme.textSecondary),
                      SizedBox(height: 12),
                      Text('Henüz harcama kaydı yok.',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ]),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: entries.length,
                  itemBuilder: (context, i) => _EntryTile(
                    entry: entries[i],
                    isHM: isHM,
                    userId: _userId,
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFundsDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fon Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Miktar (€)',
                prefixText: '€ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Açıklama'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
              if (amount == null || amount <= 0) return;
              final desc = descCtrl.text.trim().isEmpty ? 'Fon eklendi' : descCtrl.text.trim();
              await ref.read(financeServiceProvider).addFunds(
                userId: _userId,
                amount: amount,
                description: desc,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _showUpdateBalanceDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bakiyeyi Güncelle'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Yeni Bakiye (€)',
            prefixText: '€ ',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (amount == null) return;
              await ref.read(financeServiceProvider).updateBalance(amount, _userId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;
  final String? lastUpdatedBy;
  final DateTime? lastUpdatedAt;

  const _BalanceCard({
    required this.balance,
    this.lastUpdatedBy,
    this.lastUpdatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = balance >= 0;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [const Color(0xFF2D6A4F), const Color(0xFF52B788)]
              : [const Color(0xFFD62828), const Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isPositive ? AppTheme.primary : AppTheme.error)
                .withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.account_balance_wallet_rounded,
                color: Colors.white70, size: 16),
            SizedBox(width: 6),
            Text('Ev Bakiyesi',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Text(
            AppConstants.formatAmount(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (lastUpdatedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Son güncelleme: ${AppConstants.formatDateTime(lastUpdatedAt!)}',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  final FinanceEntryModel entry;
  final bool isHM;
  final String userId;

  const _EntryTile({required this.entry, required this.isHM, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final userName = usersAsync.value
        ?.firstWhere((u) => u.id == entry.userId,
            orElse: () => throw Exception())
        .name ?? entry.userId.substring(0, 6);

    final isIncome = entry.isIncome;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncome
              ? AppTheme.success.withOpacity(0.2)
              : AppTheme.secondary.withOpacity(0.4),
          child: Icon(
            isIncome ? Icons.add_circle_outline_rounded : Icons.receipt_rounded,
            color: isIncome ? AppTheme.success : AppTheme.primary,
            size: 20,
          ),
        ),
        title: Text(entry.description, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          '$userName • ${AppConstants.formatDateTime(entry.createdAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            isIncome
                ? '+ ${AppConstants.formatAmount(entry.amount)}'
                : '− ${AppConstants.formatAmount(entry.amount)}',
            style: TextStyle(
              color: isIncome ? AppTheme.success : AppTheme.error,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          if (isHM) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18),
              onSelected: (action) async {
                if (action == 'delete') {
                  final confirm = await _confirmDelete(context);
                  if (confirm == true) {
                    await ref.read(financeServiceProvider)
                        .deleteEntry(entry.id, userId);
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Sil', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ]),
        onTap: entry.receiptImageUrl != null
            ? () => _showReceipt(context, entry.receiptImageUrl!)
            : null,
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kaydı Sil'),
          content: const Text('Bu harcamayı silmek istediğinizden emin misiniz?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil'),
            ),
          ],
        ),
      );

  void _showReceipt(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AppBar(
            title: const Text('Fiş'),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          Image.network(url, fit: BoxFit.contain),
        ]),
      ),
    );
  }
}
