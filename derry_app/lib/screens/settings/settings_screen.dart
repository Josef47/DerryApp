import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/app_settings_model.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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
    final settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
      ),
      body: settingsAsync.when(
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // House info
            _SectionCard(
              title: 'Ev Bilgileri',
              icon: Icons.home_rounded,
              child: Column(children: [
                _EditableTile(
                  label: 'Ev Adı',
                  value: settings.houseName,
                  onSave: (v) async {
                    final updated = AppSettingsModel(
                      houseName: v,
                      reminderTime: settings.reminderTime,
                      timezone: settings.timezone,
                    );
                    await ref.read(settingsServiceProvider).updateSettings(updated);
                  },
                ),
                _EditableTile(
                  label: 'Saat Dilimi',
                  value: settings.timezone,
                  onSave: (v) async {
                    final updated = AppSettingsModel(
                      houseName: settings.houseName,
                      reminderTime: settings.reminderTime,
                      timezone: v,
                    );
                    await ref.read(settingsServiceProvider).updateSettings(updated);
                  },
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Notifications
            _SectionCard(
              title: 'Bildirimler',
              icon: Icons.notifications_rounded,
              child: _EditableTile(
                label: 'Hatırlatma Saati',
                value: settings.reminderTime,
                hint: 'ÖR: 08:00',
                onSave: (v) async {
                  final updated = AppSettingsModel(
                    houseName: settings.houseName,
                    reminderTime: v,
                    timezone: settings.timezone,
                  );
                  await ref.read(settingsServiceProvider).updateSettings(updated);
                },
              ),
            ),
            const SizedBox(height: 16),

            // User management
            _SectionCard(
              title: 'Kullanıcı Yönetimi',
              icon: Icons.people_rounded,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.manage_accounts_rounded, color: AppTheme.primary),
                title: const Text('Üyeleri Yönet'),
                subtitle: const Text('Davet anahtarı oluştur, üyeleri gör'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () => context.push('/settings/users'),
              ),
            ),
            const SizedBox(height: 32),

            // Logout
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                ),
                onPressed: () async {
                  await ref.read(authServiceProvider).logout();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Çıkış Yap'),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const Divider(height: 20),
        child,
      ]),
    );
  }
}

class _EditableTile extends StatefulWidget {
  final String label;
  final String value;
  final String? hint;
  final Future<void> Function(String) onSave;

  const _EditableTile({
    required this.label,
    required this.value,
    this.hint,
    required this.onSave,
  });

  @override
  State<_EditableTile> createState() => _EditableTileState();
}

class _EditableTileState extends State<_EditableTile> {
  bool _editing = false;
  late TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(widget.label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        subtitle: Text(
          widget.value.isEmpty ? '—' : widget.value,
          style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.primary),
          onPressed: () => setState(() => _editing = true),
        ),
      );
    }

    return Row(children: [
      Expanded(child: TextField(
        controller: _ctrl,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
        ),
        autofocus: true,
      )),
      const SizedBox(width: 8),
      if (_saving)
        const SizedBox(width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2))
      else ...[
        IconButton(
          icon: const Icon(Icons.check_rounded, color: AppTheme.success),
          onPressed: () async {
            setState(() => _saving = true);
            await widget.onSave(_ctrl.text.trim());
            if (mounted) setState(() { _editing = false; _saving = false; });
          },
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
          onPressed: () => setState(() {
            _editing = false;
            _ctrl.text = widget.value;
          }),
        ),
      ],
    ]);
  }
}
