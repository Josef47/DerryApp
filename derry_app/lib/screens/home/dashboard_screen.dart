import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/task_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/task_model.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _userId = '';
  String _userName = '';
  bool _isHM = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userId = prefs.getString(AppConstants.prefUserId) ?? '';
        _userName = prefs.getString(AppConstants.prefUserName) ?? '';
        _isHM = prefs.getBool(AppConstants.prefIsHousemaster) ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekLabel = AppConstants.currentWeekLabel();
    final userTasksAsync = ref.watch(userTasksProvider(_userId));
    final todayCompAsync = ref.watch(todayCompletionsProvider(_userId));
    final balanceAsync = ref.watch(balanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Merhaba, $_userName 👋'),
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userTasksProvider(_userId));
          ref.invalidate(balanceProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Week label
            Row(children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(weekLabel,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ]),
            const SizedBox(height: 16),

            // Stats row
            Row(children: [
              Expanded(child: _StatCard(
                label: 'Bugünkü Görev',
                icon: Icons.checklist_rounded,
                color: AppTheme.primary,
                content: userTasksAsync.when(
                  data: (tasks) {
                    final todayTasks = tasks.where((t) => _isDueToday(t)).toList();
                    final done = todayCompAsync.value
                        ?.map((c) => c.taskId).toSet() ?? {};
                    final pending = todayTasks.where((t) => !done.contains(t.id)).length;
                    return Text('$pending bekliyor',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold));
                  },
                  loading: () => const CircularProgressIndicator(strokeWidth: 2),
                  error: (_, __) => const Text('—'),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                label: 'Ev Bakiyesi',
                icon: Icons.account_balance_wallet_rounded,
                color: Colors.teal,
                content: balanceAsync.when(
                  data: (b) => Text(
                    b != null ? AppConstants.formatAmount(b.currentBalance) : '€0.00',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: (b?.currentBalance ?? 0) >= 0
                          ? AppTheme.success
                          : AppTheme.error,
                    ),
                  ),
                  loading: () => const CircularProgressIndicator(strokeWidth: 2),
                  error: (_, __) => const Text('—'),
                ),
              )),
            ]),
            const SizedBox(height: 20),

            // Today's tasks
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Bugünkü Görevler',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              TextButton(
                onPressed: () => context.go('/tasks'),
                child: const Text('Tümünü gör'),
              ),
            ]),

            userTasksAsync.when(
              data: (tasks) {
                final todayTasks = tasks.where((t) => _isDueToday(t)).toList();
                if (todayTasks.isEmpty) {
                  return _EmptyCard(
                    icon: Icons.celebration_rounded,
                    message: 'Bugün için görev yok! 🎉',
                  );
                }
                final completedIds = todayCompAsync.value
                    ?.map((c) => c.taskId).toSet() ?? {};
                return Column(
                  children: todayTasks.map((t) => _TaskTile(
                    task: t,
                    isDone: completedIds.contains(t.id),
                    userId: _userId,
                    weekLabel: weekLabel,
                  )).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Hata: $e'),
            ),

            const SizedBox(height: 20),

            // Quick actions
            const Text('Hızlı İşlemler',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickAction(
                  icon: Icons.add_shopping_cart_rounded,
                  label: 'Alışveriş',
                  onTap: () => context.go('/shopping'),
                ),
                _QuickAction(
                  icon: Icons.add_card_rounded,
                  label: 'Harcama Ekle',
                  onTap: () => context.go('/finance/new'),
                ),
                _QuickAction(
                  icon: Icons.bar_chart_rounded,
                  label: 'Aktivite Logla',
                  onTap: () => context.go('/activities'),
                ),
                if (_isHM)
                  _QuickAction(
                    icon: Icons.add_task_rounded,
                    label: 'Görev Oluştur',
                    onTap: () => context.go('/tasks/new'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isDueToday(TaskModel task) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (task.type == AppConstants.taskRecurring) {
      final rec = task.recurrence;
      if (rec.type == AppConstants.recDaily) return true;
      if (rec.type == AppConstants.recWeekly) {
        final nd = rec.nextDeadline;
        if (nd == null) return false;
        return DateTime(nd.year, nd.month, nd.day).isAtSameMomentAs(today);
      }
      if (rec.type == AppConstants.recCustom) {
        return rec.daysOfWeek.contains(now.weekday);
      }
    }
    if (task.deadline != null) {
      final dl = task.deadline!;
      return DateTime(dl.year, dl.month, dl.day)
          .isAtSameMomentAs(today);
    }
    return false;
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Widget content;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ]),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final TaskModel task;
  final bool isDone;
  final String userId;
  final String weekLabel;

  const _TaskTile({
    required this.task,
    required this.isDone,
    required this.userId,
    required this.weekLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: GestureDetector(
          onTap: () async {
            final svc = ref.read(taskServiceProvider);
            if (isDone) {
              await svc.uncompleteTask(task.id, userId);
            } else {
              await svc.completeTask(task.id, userId, weekLabel);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? AppTheme.success : Colors.transparent,
              border: Border.all(
                color: isDone ? AppTheme.success : AppTheme.textSecondary,
                width: 2,
              ),
            ),
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: isDone ? AppTheme.textSecondary : AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: task.description != null
            ? Text(task.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12))
            : null,
        trailing: _RecurrenceChip(task.recurrence.type),
      ),
    );
  }
}

class _RecurrenceChip extends StatelessWidget {
  final String type;
  const _RecurrenceChip(this.type);

  @override
  Widget build(BuildContext context) {
    if (type == AppConstants.recNone) return const SizedBox.shrink();
    final label = switch (type) {
      AppConstants.recDaily => 'Günlük',
      AppConstants.recWeekly => 'Haftalık',
      AppConstants.recCustom => 'Özel',
      _ => '',
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: (MediaQuery.of(context).size.width - 56) / 2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ]),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(children: [
        Icon(icon, size: 40, color: AppTheme.textSecondary),
        const SizedBox(height: 8),
        Text(message,
            style: const TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center),
      ]),
    );
  }
}
