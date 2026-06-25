import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/duty_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/duty_provider.dart';
import '../../providers/settings_provider.dart';

class DutyScreen extends ConsumerStatefulWidget {
  const DutyScreen({super.key});

  @override
  ConsumerState<DutyScreen> createState() => _DutyScreenState();
}

class _DutyScreenState extends ConsumerState<DutyScreen> {
  final String weekLabel = AppConstants.currentWeekLabel();

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(dutyZonesProvider);
    final assignmentsAsync = ref.watch(currentWeekAssignmentsProvider);
    final usersAsync = ref.watch(allUsersProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    final isHM = ref.watch(isHousemasterProvider);

    final dutyDayOfWeek = settingsAsync.asData?.value?.dutyDayOfWeek ?? 3;
    final isToday = DateTime.now().weekday == dutyDayOfWeek;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nöbet'),
            Text(
              weekLabel,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white70),
            ),
          ],
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          if (isHM)
            IconButton(
              icon: const Icon(Icons.assignment_ind_rounded),
              tooltip: 'Atamaları Yönet',
              onPressed: () => _showAssignmentSheet(
                context,
                zonesAsync.asData?.value ?? [],
                usersAsync.asData?.value ?? [],
                assignmentsAsync.asData?.value ?? [],
              ),
            ),
        ],
      ),
      body: zonesAsync.when(
        data: (zones) {
          final assignments = assignmentsAsync.asData?.value ?? [];
          final users = usersAsync.asData?.value ?? [];

          return CustomScrollView(
            slivers: [
              if (isToday)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.primary.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.notifications_active_rounded,
                            color: AppTheme.primary, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bugün nöbet günü! Görevlerini tamamla.',
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (zones.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cleaning_services_rounded,
                            size: 64, color: AppTheme.textSecondary),
                        const SizedBox(height: 16),
                        const Text('Henüz nöbet bölgesi yok.',
                            style:
                                TextStyle(color: AppTheme.textSecondary)),
                        if (isHM) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showAddZoneDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Bölge Ekle'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i == zones.length) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: OutlinedButton.icon(
                            onPressed: () => _showAddZoneDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Yeni Bölge Ekle'),
                          ),
                        );
                      }
                      final zone = zones[i];
                      final assignment = _findAssignment(assignments, zone.id);
                      final assignedUser = assignment?.assignedUserId != null
                          ? users.firstWhere(
                              (u) => u.id == assignment!.assignedUserId,
                              orElse: () => _unknownUser(),
                            )
                          : null;
                      return _ZoneCard(
                        zone: zone,
                        assignment: assignment,
                        assignedUser: assignedUser,
                        onTap: () =>
                            context.push('/duty/${zone.id}'),
                      );
                    },
                    childCount: zones.length + (isHM ? 1 : 0),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  DutyAssignmentModel? _findAssignment(
      List<DutyAssignmentModel> assignments, String zoneId) {
    try {
      return assignments.firstWhere((a) => a.zoneId == zoneId);
    } catch (_) {
      return null;
    }
  }

  UserModel _unknownUser() => UserModel(
        id: '',
        name: 'Bilinmiyor',
        role: 'member',
        isHousemaster: false,
        createdAt: DateTime.now(),
      );

  void _showAddZoneDialog(BuildContext context) {
    final ctrl = TextEditingController();
    String selectedIcon = 'cleaning';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Yeni Nöbet Bölgesi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(labelText: 'Bölge Adı'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              const Text('İkon Seç',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _zoneIcons.entries.map((e) {
                  final selected = selectedIcon == e.key;
                  return GestureDetector(
                    onTap: () => setSt(() => selectedIcon = e.key),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary.withOpacity(0.15)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(e.value,
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                          size: 24),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                await ref.read(dutyServiceProvider).addZone(
                      name: ctrl.text.trim(),
                      iconName: selectedIcon,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignmentSheet(
    BuildContext context,
    List<DutyZoneModel> zones,
    List<UserModel> users,
    List<DutyAssignmentModel> assignments,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AssignmentSheet(
        zones: zones,
        users: users,
        assignments: assignments,
        weekLabel: weekLabel,
      ),
    );
  }
}

// ── Zone card ──────────────────────────────────────────────────────────────

class _ZoneCard extends StatelessWidget {
  final DutyZoneModel zone;
  final DutyAssignmentModel? assignment;
  final UserModel? assignedUser;
  final VoidCallback onTap;

  const _ZoneCard({
    required this.zone,
    required this.assignment,
    required this.assignedUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completed = assignment?.isCompleted ?? false;
    final totalTasks = zone.miniTasks.length;
    final doneTasks = assignment?.completedMiniTaskIds.length ?? 0;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: completed
                      ? AppTheme.success.withOpacity(0.1)
                      : AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _zoneIcons[zone.iconName] ??
                      Icons.cleaning_services_rounded,
                  color: completed ? AppTheme.success : AppTheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            zone.name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (completed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    size: 13, color: AppTheme.success),
                                SizedBox(width: 4),
                                Text('Tamam',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.success,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_rounded,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          assignedUser?.name ?? 'Atanmadı',
                          style: TextStyle(
                            fontSize: 13,
                            color: assignedUser != null
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (totalTasks > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: totalTasks > 0
                                    ? doneTasks / totalTasks
                                    : 0,
                                backgroundColor:
                                    AppTheme.divider,
                                color: completed
                                    ? AppTheme.success
                                    : AppTheme.primaryLight,
                                minHeight: 5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$doneTasks/$totalTasks',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ] else
                      const SizedBox(height: 2),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Assignment bottom sheet (admin) ───────────────────────────────────────

class _AssignmentSheet extends ConsumerStatefulWidget {
  final List<DutyZoneModel> zones;
  final List<UserModel> users;
  final List<DutyAssignmentModel> assignments;
  final String weekLabel;

  const _AssignmentSheet({
    required this.zones,
    required this.users,
    required this.assignments,
    required this.weekLabel,
  });

  @override
  ConsumerState<_AssignmentSheet> createState() => _AssignmentSheetState();
}

class _AssignmentSheetState extends ConsumerState<_AssignmentSheet> {
  late Map<String, String?> _selections; // zoneId -> userId
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selections = {
      for (final z in widget.zones)
        z.id: widget.assignments
            .firstWhere((a) => a.zoneId == z.id,
                orElse: () => DutyAssignmentModel(
                      id: '',
                      weekLabel: widget.weekLabel,
                      zoneId: z.id,
                      completedMiniTaskIds: [],
                      isCompleted: false,
                      createdAt: DateTime.now(),
                    ))
            .assignedUserId,
    };
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('Nöbet Atamaları',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(widget.weekLabel,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 20),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final zone in widget.zones)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          _zoneIcons[zone.iconName] ??
                              Icons.cleaning_services_rounded,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(zone.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String?>(
                          value: _selections[zone.id],
                          hint: const Text('Atanmadı',
                              style: TextStyle(fontSize: 13)),
                          underline: const SizedBox(),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('— Atanmadı —',
                                  style: TextStyle(fontSize: 13)),
                            ),
                            ...widget.users.map((u) => DropdownMenuItem(
                                  value: u.id,
                                  child: Text(u.name,
                                      style: const TextStyle(fontSize: 13)),
                                )),
                          ],
                          onChanged: (v) =>
                              setState(() => _selections[zone.id] = v),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveAll,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Kaydet'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    final service = ref.read(dutyServiceProvider);
    for (final entry in _selections.entries) {
      await service.setAssignment(
        weekLabel: widget.weekLabel,
        zoneId: entry.key,
        userId: entry.value,
      );
    }
    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }
}

// ── Icon map ───────────────────────────────────────────────────────────────

const Map<String, IconData> _zoneIcons = {
  'kitchen': Icons.kitchen_rounded,
  'bathroom': Icons.bathtub_rounded,
  'living': Icons.weekend_rounded,
  'stairs': Icons.stairs_rounded,
  'cleaning': Icons.cleaning_services_rounded,
  'bedroom': Icons.bed_rounded,
  'garden': Icons.grass_rounded,
  'garage': Icons.garage_rounded,
};
