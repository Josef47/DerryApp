import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/activity_log_model.dart';
import '../../models/activity_type_model.dart';
import '../../providers/activity_provider.dart';
import '../../providers/settings_provider.dart';

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _userId = '';
  bool _isHM = false;
  String _selectedWeek = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _selectedWeek = AppConstants.currentWeekLabel();
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
        title: const Text('Aktiviteler'),
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        actions: [
          if (_isHM)
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: 'Aktivite Türlerini Yönet',
              onPressed: () => _showTypeManager(context),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Bu Hafta'),
            Tab(text: 'Geçmiş'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogDialog(context),
        icon: const Icon(Icons.add_chart_rounded),
        label: const Text('Log Ekle'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ThisWeekView(userId: _userId, weekLabel: _selectedWeek),
          _HistoryView(userId: _userId),
        ],
      ),
    );
  }

  void _showLogDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LogActivitySheet(userId: _userId),
    );
  }

  void _showTypeManager(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ActivityTypeManagerSheet(userId: _userId),
    );
  }
}

class _ThisWeekView extends ConsumerWidget {
  final String userId;
  final String weekLabel;

  const _ThisWeekView({required this.userId, required this.weekLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(weekActivityLogsProvider(weekLabel));
    final typesAsync = ref.watch(allTypesProvider);
    final usersAsync = ref.watch(allUsersProvider);

    return logsAsync.when(
      data: (logs) {
        final types = typesAsync.valueOrNull ?? [];
        final users = usersAsync.valueOrNull ?? [];

        if (logs.isEmpty) {
          return const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bar_chart_rounded, size: 64, color: AppTheme.textSecondary),
              SizedBox(height: 12),
              Text('Bu hafta için henüz aktivite logu yok.',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ]),
          );
        }

        // Group by user
        final byUser = <String, List<ActivityLogModel>>{};
        for (final log in logs) {
          byUser.putIfAbsent(log.userId, () => []).add(log);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(weekLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: AppTheme.primary)),
              ]),
            ),
            const SizedBox(height: 16),

            ...byUser.entries.map((entry) {
              final user = users.where((u) => u.id == entry.key).firstOrNull;
              return _UserActivityCard(
                userName: user?.name ?? entry.key.substring(0, 6),
                logs: entry.value,
                types: types,
                isMe: entry.key == userId,
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }
}

class _UserActivityCard extends StatelessWidget {
  final String userName;
  final List<ActivityLogModel> logs;
  final List<ActivityTypeModel> types;
  final bool isMe;

  const _UserActivityCard({
    required this.userName,
    required this.logs,
    required this.types,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary,
              child: Text(userName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Text(isMe ? '$userName (Sen)' : userName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          ...logs.map((log) {
            final type = types.where((t) => t.id == log.activityTypeId).firstOrNull;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Icon(Icons.fiber_manual_record_rounded, size: 8, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(type?.name ?? 'Aktivite',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                Text(
                  '${log.value.toStringAsFixed(0)} ${type?.unit ?? ''}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
                if (log.syncedToDrive) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.cloud_done_rounded, size: 14, color: Colors.teal),
                ],
              ]),
            );
          }),
        ]),
      ),
    );
  }
}

class _HistoryView extends ConsumerWidget {
  final String userId;
  const _HistoryView({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(userActivityLogsProvider(userId));
    final typesAsync = ref.watch(allTypesProvider);

    return logsAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(
              child: Text('Henüz aktivite logu yok.',
                  style: TextStyle(color: AppTheme.textSecondary)));
        }
        final types = typesAsync.valueOrNull ?? [];

        // Group by week
        final byWeek = <String, List<ActivityLogModel>>{};
        for (final log in logs) {
          byWeek.putIfAbsent(log.weekLabel, () => []).add(log);
        }
        final weeks = byWeek.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: weeks.map((week) {
            final weekLogs = byWeek[week]!;
            return ExpansionTile(
              title: Text(week,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              children: weekLogs.map((log) {
                final type = types.where((t) => t.id == log.activityTypeId).firstOrNull;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.arrow_right_rounded, color: AppTheme.primary),
                  title: Text(type?.name ?? 'Aktivite'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${log.value.toStringAsFixed(0)} ${type?.unit ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (log.syncedToDrive) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.cloud_done_rounded, size: 14, color: Colors.teal),
                    ],
                  ]),
                  subtitle: log.note != null
                      ? Text(log.note!, style: const TextStyle(fontSize: 11))
                      : null,
                );
              }).toList(),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }
}

class _LogActivitySheet extends ConsumerStatefulWidget {
  final String userId;
  const _LogActivitySheet({required this.userId});

  @override
  ConsumerState<_LogActivitySheet> createState() => _LogActivitySheetState();
}

class _LogActivitySheetState extends ConsumerState<_LogActivitySheet> {
  final _valueCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _selectedTypeId;
  bool _loading = false;

  @override
  void dispose() {
    _valueCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktivite türü seçin.')));
      return;
    }
    final value = double.tryParse(_valueCtrl.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçerli bir değer girin.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final log = ActivityLogModel(
        id: '',
        userId: widget.userId,
        activityTypeId: _selectedTypeId!,
        value: value,
        weekLabel: AppConstants.currentWeekLabel(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      await ref.read(activityServiceProvider).addLog(log);
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
    final typesAsync = ref.watch(activeTypesProvider);
    final types = typesAsync.valueOrNull ?? [];

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
        const Text('Aktivite Logla',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        DropdownButtonFormField<String>(
          value: _selectedTypeId,
          decoration: const InputDecoration(labelText: 'Aktivite türü *'),
          items: types.map((t) => DropdownMenuItem(
            value: t.id,
            child: Text('${t.name} (${t.unit})'),
          )).toList(),
          onChanged: (v) => setState(() => _selectedTypeId = v),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _valueCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Değer *'),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _noteCtrl,
          decoration: const InputDecoration(labelText: 'Not (isteğe bağlı, örn. kitap adı)'),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                : const Text('Kaydet'),
          ),
        ),
      ]),
    );
  }
}

class _ActivityTypeManagerSheet extends ConsumerStatefulWidget {
  final String userId;
  const _ActivityTypeManagerSheet({required this.userId});

  @override
  ConsumerState<_ActivityTypeManagerSheet> createState() =>
      _ActivityTypeManagerSheetState();
}

class _ActivityTypeManagerSheetState
    extends ConsumerState<_ActivityTypeManagerSheet> {
  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(allTypesProvider);
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
        const Text('Aktivite Türleri',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Tür adı'),
          )),
          const SizedBox(width: 8),
          SizedBox(width: 90, child: TextField(
            controller: _unitCtrl,
            decoration: const InputDecoration(labelText: 'Birim'),
          )),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              if (_nameCtrl.text.trim().isNotEmpty && _unitCtrl.text.trim().isNotEmpty) {
                final type = ActivityTypeModel(
                  id: '',
                  name: _nameCtrl.text.trim(),
                  unit: _unitCtrl.text.trim(),
                  active: true,
                  createdBy: widget.userId,
                );
                await ref.read(activityServiceProvider).createActivityType(type);
                _nameCtrl.clear();
                _unitCtrl.clear();
              }
            },
            child: const Text('Ekle'),
          ),
        ]),
        const SizedBox(height: 16),
        typesAsync.when(
          data: (types) => SizedBox(
            height: 200,
            child: ListView(
              children: types.map((t) => ListTile(
                dense: true,
                leading: Icon(
                  t.active ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: t.active ? AppTheme.success : AppTheme.textSecondary,
                  size: 18,
                ),
                title: Text(t.name),
                subtitle: Text(t.unit),
                trailing: IconButton(
                  icon: Icon(
                    t.active ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 18,
                  ),
                  onPressed: () async {
                    final updated = ActivityTypeModel(
                      id: t.id, name: t.name, unit: t.unit,
                      active: !t.active, createdBy: t.createdBy,
                    );
                    await ref.read(activityServiceProvider).updateActivityType(updated);
                  },
                ),
              )).toList(),
            ),
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('Yüklenemedi'),
        ),
      ]),
    );
  }
}
