import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _userId = '';
  String? _newKey;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userId = prefs.getString(AppConstants.prefUserId) ?? '');
  }

  void _showCreateKeyDialog() {
    final nameCtrl = TextEditingController();
    bool isHM = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Yeni Üye Ekle'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Üye adı *'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Housemaster'),
              value: isHM,
              onChanged: (v) => setS(() => isHM = v),
              activeColor: AppTheme.primary,
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final key = await ref.read(authServiceProvider).createInviteKey(
                  name: nameCtrl.text.trim(),
                  isHousemaster: isHM,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() => _newKey = key);
                _showKeyDialog(key, nameCtrl.text.trim());
              },
              child: const Text('Anahtar Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  void _showKeyDialog(String key, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.key_rounded, color: AppTheme.primary),
          SizedBox(width: 8),
          Text('Davet Anahtarı'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$name için davet anahtarı:',
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
            ),
            child: Row(children: [
              Expanded(
                child: Text(key,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        letterSpacing: 2)),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: AppTheme.primary),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: key));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kopyalandı!')));
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),
          const Text(
            'Bu anahtarı üyeyle paylaşın. Anahtar sadece bir kez kullanılabilir.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Yönetimi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateKeyDialog,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Üye Ekle'),
      ),
      body: usersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(
              child: Text('Henüz üye yok.',
                  style: TextStyle(color: AppTheme.textSecondary)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, i) {
              final user = users[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: user.isHousemaster
                        ? AppTheme.primary
                        : AppTheme.secondary,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: user.isHousemaster ? Colors.white : AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(user.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (user.isHousemaster ? AppTheme.primary : Colors.grey)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user.isHousemaster ? 'Housemaster' : 'Üye',
                        style: TextStyle(
                          fontSize: 11,
                          color: user.isHousemaster ? AppTheme.primary : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ]),
                  trailing: user.id != _userId
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (action) async {
                            if (action == 'delete') {
                              final confirm = await _confirmDelete(context, user.name);
                              if (confirm == true) {
                                await ref.read(settingsServiceProvider).deleteUser(user.id);
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Kullanıcıyı Sil',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        )
                      : const Chip(
                          label: Text('Sen', style: TextStyle(fontSize: 11)),
                        ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String name) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kullanıcıyı Sil'),
          content: Text('$name adlı kullanıcıyı silmek istediğinizden emin misiniz?'),
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
}
