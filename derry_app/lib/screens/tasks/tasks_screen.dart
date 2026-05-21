import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/task_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/task_model.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
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
    if (mounted) {
      setState(() {
        _userId = prefs.getString(AppConstants.prefUserId) ?? '';
        _isHM = prefs.getBool(AppConstants.prefIsHousemaster) ?? false;
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weekLabel = AppConstants.currentWeekLabel();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Görevler'),
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        bottom: _isHM
            ? TabBar(
                controller: _tabs,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: const [
                  Tab(text: 'Görevlerim'),
                  Tab(text: 'Tüm Üyeler'),
                ],
              )
            : null,
      ),
      floatingActionButton: _isHM
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/tasks/new'),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Görev'),
            )
          : null,
      body: _isHM
          ? TabBarView(
              controller: _tabs,
              children: [
                _MyTasksView(userId: _userId, weekLabel: weekLabel),
                _AllMembersMatrixView(weekLabel: weekLabel),
              ],
            )
          : _MyTasksView(userId: _userId, weekLabel: weekLabel),
    );
  }
}

class _MyTasksView extends ConsumerWidget {
  final String userId;
  final String weekLabel;

  const _MyTasksView({required this.userId, required this.weekLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(userTasksProvider(userId));
    final completionsAsync = ref.watch(todayCompletionsProvider(userId));

    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.task_alt_rounded, size: 64, color: AppTheme.textSecondary),
              SizedBox(height: 16),
              Text('Sana atanan görev yok.',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ]),
          );
        }
        final completedIds = completionsAsync.valueOrNull
            ?.map((c) => c.taskId).toSet() ?? {};

        // Group by type
        final recurring = tasks.where((t) => t.type == AppConstants.taskRecurring).toList();
        final oneTime = tasks.where((t) => t.type == AppConstants.taskOneTime).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (recurring.isNotEmpty) ...[
              _SectionHeader('Tekrarlayan Görevler (${recurring.length})'),
              ...recurring.map((t) => _TaskCard(
                task: t,
                isDone: completedIds.contains(t.id),
                userId: userId,
                weekLabel: weekLabel,
              )),
            ],
            if (oneTime.isNotEmpty) ...[
              _SectionHeader('Tek Seferlik Görevler (${oneTime.length})'),
              ...oneTime.map((t) => _TaskCard(
                task: t,
                isDone: completedIds.contains(t.id),
                userId: userId,
                weekLabel: weekLabel,
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

class _AllMembersMatrixView extends ConsumerWidget {
  final String weekLabel;
  const _AllMembersMatrixView({required this.weekLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasksAsync = ref.watch(allTasksProvider);
    final weekCompAsync = ref.watch(weekCompletionsProvider(weekLabel));

    return allTasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return const Center(child: Text('Henüz görev yok.'));
        }

        // Collect all assignee IDs
        final allUsers = tasks
            .expand((t) => t.assignedTo)
            .toSet()
            .toList();

        final completions = weekCompAsync.valueOrNull ?? [];
        final completedSet = {
          for (final c in completions) '${c.taskId}_${c.userId}': true
        };

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(AppTheme.secondary.withOpacity(0.3)),
              columns: [
                const DataColumn(label: Text('Görev', style: TextStyle(fontWeight: FontWeight.bold))),
                ...allUsers.map((u) => DataColumn(
                    label: Text(u.substring(0, 6),
                        style: const TextStyle(fontSize: 11)))),
              ],
              rows: tasks.map((task) {
                return DataRow(cells: [
                  DataCell(
                    SizedBox(
                      width: 160,
                      child: Text(task.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                  ...allUsers.map((uid) {
                    if (!task.assignedTo.contains(uid)) {
                      return const DataCell(Text('—',
                          style: TextStyle(color: AppTheme.textSecondary)));
                    }
                    final done = completedSet['${task.id}_$uid'] ?? false;
                    return DataCell(
                      Icon(
                        done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: done ? AppTheme.success : AppTheme.textSecondary,
                        size: 20,
                      ),
                    );
                  }),
                ]);
              }).toList(),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final TaskModel task;
  final bool isDone;
  final String userId;
  final String weekLabel;

  const _TaskCard({
    required this.task,
    required this.isDone,
    required this.userId,
    required this.weekLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHM = ref.watch(isHousemasterProvider).valueOrNull ?? false;

    return Card(
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? AppTheme.success : Colors.transparent,
              border: Border.all(
                color: isDone ? AppTheme.success : const Color(0xFF9CA3AF),
                width: 2,
              ),
            ),
            child: isDone
                ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description != null)
              Text(task.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            if (task.deadline != null)
              Text(
                'Son: ${AppConstants.formatDate(task.deadline!)}',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.warning),
              ),
          ],
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          _typeChip(task),
          if (isHM) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18),
              onSelected: (action) async {
                if (action == 'edit') {
                  context.push('/tasks/${task.id}/edit');
                } else if (action == 'delete') {
                  await ref.read(taskServiceProvider).deleteTask(task.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                PopupMenuItem(
                    value: 'delete',
                    child: Text('Sil', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ]),
      ),
    );
  }

  Widget _typeChip(TaskModel task) {
    String label;
    Color color;
    if (task.type == AppConstants.taskRecurring) {
      label = switch (task.recurrence.type) {
        AppConstants.recDaily => 'Günlük',
        AppConstants.recWeekly => 'Haftalık',
        AppConstants.recCustom => 'Özel',
        _ => 'Tekrar',
      };
      color = AppTheme.primary;
    } else {
      label = 'Tek Sefer';
      color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary)),
    );
  }
}
