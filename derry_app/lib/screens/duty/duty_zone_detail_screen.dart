import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/duty_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/duty_provider.dart';
import '../../providers/settings_provider.dart';

class DutyZoneDetailScreen extends ConsumerStatefulWidget {
  final String zoneId;

  const DutyZoneDetailScreen({super.key, required this.zoneId});

  @override
  ConsumerState<DutyZoneDetailScreen> createState() =>
      _DutyZoneDetailScreenState();
}

class _DutyZoneDetailScreenState
    extends ConsumerState<DutyZoneDetailScreen> {
  final String weekLabel = AppConstants.currentWeekLabel();

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(dutyZonesProvider);
    final assignmentsAsync = ref.watch(currentWeekAssignmentsProvider);
    final usersAsync = ref.watch(allUsersProvider);
    final isHM = ref.watch(isHousemasterProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    final zones = zonesAsync.asData?.value ?? [];
    final zone = zones.cast<DutyZoneModel?>().firstWhere(
          (z) => z?.id == widget.zoneId,
          orElse: () => null,
        );

    if (zone == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nöbet Bölgesi')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final assignments = assignmentsAsync.asData?.value ?? [];
    final assignment = _findAssignment(assignments, zone.id);
    final users = usersAsync.asData?.value ?? [];

    final assignedUser = assignment?.assignedUserId != null
        ? users.firstWhere(
            (u) => u.id == assignment!.assignedUserId,
            orElse: () =>
                UserModel(id: '', name: 'Bilinmiyor', role: 'member', isHousemaster: false, createdAt: DateTime.now()),
          )
        : null;

    final isAssigned = assignment?.assignedUserId == currentUserId;
    final canCheckTasks = isAssigned || isHM;
    final isCompleted = assignment?.isCompleted ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(zone.name),
        actions: [
          if (isHM)
            PopupMenuButton<String>(
              onSelected: (v) => _onMenuSelected(v, zone, context),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'rename', child: Text('Bölgeyi Yeniden Adlandır')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Bölgeyi Sil',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Assignment info card
          SliverToBoxAdapter(
            child: _AssignmentCard(
              assignedUser: assignedUser,
              weekLabel: weekLabel,
              isCompleted: isCompleted,
            ),
          ),

          // Mini-tasks header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Text('Görevler',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(
                    '${assignment?.completedMiniTaskIds.length ?? 0}/${zone.miniTasks.length} tamamlandı',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // Mini-tasks list
          if (zone.miniTasks.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Henüz görev yok.\nAşağıdan ekleyebilirsin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final task = zone.miniTasks[i];
                  final isDone =
                      assignment?.isMiniTaskCompleted(task.id) ?? false;
                  return _MiniTaskTile(
                    task: task,
                    isDone: isDone,
                    canToggle: canCheckTasks && !isCompleted,
                    canDelete: isHM,
                    onToggle: (val) => _toggleTask(task.id, val, zone.id),
                    onDelete: () => _deleteTask(task.id, zone.id),
                  );
                },
                childCount: zone.miniTasks.length,
              ),
            ),

          // Add task button (available to everyone)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: OutlinedButton.icon(
                onPressed: () => _showAddTaskDialog(context, zone.id),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Görev Ekle'),
              ),
            ),
          ),

          // Complete / uncomplete button
          if (canCheckTasks && zone.miniTasks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: isCompleted
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                        ),
                        onPressed: () =>
                            _setZoneComplete(zone.id, false),
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: const Text('Tamamlamayı Geri Al'),
                      )
                    : ElevatedButton.icon(
                        onPressed: () =>
                            _setZoneComplete(zone.id, true),
                        icon: const Icon(Icons.check_circle_rounded,
                            size: 18),
                        label: const Text('Nöbeti Tamamla'),
                      ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  DutyAssignmentModel? _findAssignment(
      List<DutyAssignmentModel> list, String zoneId) {
    try {
      return list.firstWhere((a) => a.zoneId == zoneId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggleTask(
      String taskId, bool completed, String zoneId) async {
    await ref.read(dutyServiceProvider).toggleMiniTask(
          weekLabel: weekLabel,
          zoneId: zoneId,
          taskId: taskId,
          completed: completed,
        );
  }

  Future<void> _setZoneComplete(String zoneId, bool value) async {
    await ref.read(dutyServiceProvider).markZoneComplete(
          weekLabel: weekLabel,
          zoneId: zoneId,
          isCompleted: value,
        );
    if (mounted && value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nöbet tamamlandı!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteTask(String taskId, String zoneId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Görevi Sil'),
        content: const Text('Bu görevi silmek istediğine emin misin?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(dutyServiceProvider).deleteMiniTask(zoneId, taskId);
    }
  }

  void _showAddTaskDialog(BuildContext context, String zoneId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Görev'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'Görev adı', hintText: 'Örn: Yerleri sil'),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) async {
            if (ctrl.text.trim().isEmpty) return;
            await ref
                .read(dutyServiceProvider)
                .addMiniTask(zoneId, ctrl.text.trim());
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await ref
                  .read(dutyServiceProvider)
                  .addMiniTask(zoneId, ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  Future<void> _onMenuSelected(
      String value, DutyZoneModel zone, BuildContext context) async {
    if (value == 'rename') {
      final ctrl = TextEditingController(text: zone.name);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bölgeyi Yeniden Adlandır'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Bölge Adı'),
            autofocus: true,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Kaydet')),
          ],
        ),
      );
      if (confirmed == true && ctrl.text.trim().isNotEmpty) {
        await ref
            .read(dutyServiceProvider)
            .updateZoneName(zone.id, ctrl.text.trim());
      }
    } else if (value == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bölgeyi Sil'),
          content: Text('"${zone.name}" bölgesini silmek istediğine emin misin?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        await ref.read(dutyServiceProvider).deleteZone(zone.id);
        if (context.mounted) Navigator.pop(context);
      }
    }
  }
}

// ── Assignment info card ──────────────────────────────────────────────────

class _AssignmentCard extends StatelessWidget {
  final UserModel? assignedUser;
  final String weekLabel;
  final bool isCompleted;

  const _AssignmentCard({
    required this.assignedUser,
    required this.weekLabel,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppTheme.success.withOpacity(0.07)
            : AppTheme.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? AppTheme.success.withOpacity(0.3)
              : AppTheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isCompleted
                ? AppTheme.success.withOpacity(0.15)
                : AppTheme.primary.withOpacity(0.15),
            child: Icon(
              isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.person_rounded,
              color: isCompleted ? AppTheme.success : AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$weekLabel Nöbetçisi',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  assignedUser?.name ?? 'Henüz atanmadı',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: assignedUser != null
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isCompleted)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Tamamlandı',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Mini-task tile ────────────────────────────────────────────────────────

class _MiniTaskTile extends StatelessWidget {
  final DutyMiniTask task;
  final bool isDone;
  final bool canToggle;
  final bool canDelete;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _MiniTaskTile({
    required this.task,
    required this.isDone,
    required this.canToggle,
    required this.canDelete,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Checkbox(
        value: isDone,
        onChanged: canToggle ? (v) => onToggle(v ?? false) : null,
        activeColor: AppTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          fontSize: 15,
          decoration: isDone ? TextDecoration.lineThrough : null,
          color: isDone ? AppTheme.textSecondary : AppTheme.textPrimary,
        ),
      ),
      trailing: canDelete
          ? IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppTheme.textSecondary),
              onPressed: onDelete,
            )
          : null,
    );
  }
}
