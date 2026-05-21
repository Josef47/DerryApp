import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../providers/settings_provider.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  final String? taskId;
  const TaskFormScreen({super.key, this.taskId});

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _form = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _type = AppConstants.taskOneTime;
  String _recType = AppConstants.recNone;
  List<int> _selectedDays = [];
  int _interval = 1;
  DateTime? _deadline;
  List<String> _assignedTo = [];
  bool _reminderEnabled = true;
  bool _loading = false;
  TaskModel? _existingTask;
  String _createdBy = '';

  static const _dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  void initState() {
    super.initState();
    _loadUser();
    if (widget.taskId != null) _loadTask();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _createdBy = prefs.getString(AppConstants.prefUserId) ?? '');
  }

  Future<void> _loadTask() async {
    final task = await ref.read(taskServiceProvider).getTask(widget.taskId!);
    if (task != null && mounted) {
      setState(() {
        _existingTask = task;
        _titleCtrl.text = task.title;
        _descCtrl.text = task.description ?? '';
        _type = task.type;
        _recType = task.recurrence.type;
        _selectedDays = List.from(task.recurrence.daysOfWeek);
        _interval = task.recurrence.interval;
        _deadline = task.deadline;
        _assignedTo = List.from(task.assignedTo);
        _reminderEnabled = task.reminderEnabled;
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final recurrence = RecurrenceModel(
        type: _type == AppConstants.taskRecurring ? _recType : AppConstants.recNone,
        daysOfWeek: _selectedDays,
        interval: _interval,
        nextDeadline: _deadline,
      );
      final task = TaskModel(
        id: _existingTask?.id ?? '',
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        type: _type,
        assignedTo: _assignedTo,
        recurrence: recurrence,
        deadline: _deadline,
        reminderEnabled: _reminderEnabled,
        createdBy: _createdBy,
        createdAt: _existingTask?.createdAt ?? DateTime.now(),
      );

      if (_existingTask != null) {
        await ref.read(taskServiceProvider).updateTask(task);
      } else {
        await ref.read(taskServiceProvider).createTask(task);
      }
      if (mounted) context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final isEdit = _existingTask != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Görevi Düzenle' : 'Yeni Görev'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Görev Adı *'),
              validator: (v) => v == null || v.isEmpty ? 'Gerekli alan' : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Task type
            const Text('Görev Tipi',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _TypeButton(
                label: 'Tekrarlayan',
                icon: Icons.repeat_rounded,
                selected: _type == AppConstants.taskRecurring,
                onTap: () => setState(() {
                  _type = AppConstants.taskRecurring;
                  _recType = AppConstants.recDaily;
                }),
              )),
              const SizedBox(width: 12),
              Expanded(child: _TypeButton(
                label: 'Tek Seferlik',
                icon: Icons.looks_one_rounded,
                selected: _type == AppConstants.taskOneTime,
                onTap: () => setState(() {
                  _type = AppConstants.taskOneTime;
                  _recType = AppConstants.recNone;
                }),
              )),
            ]),
            const SizedBox(height: 16),

            // Recurrence settings
            if (_type == AppConstants.taskRecurring) ...[
              const Text('Tekrar Sıklığı',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: AppConstants.recDaily, label: Text('Günlük')),
                  ButtonSegment(value: AppConstants.recWeekly, label: Text('Haftalık')),
                  ButtonSegment(value: AppConstants.recCustom, label: Text('Özel')),
                ],
                selected: {_recType},
                onSelectionChanged: (s) => setState(() => _recType = s.first),
              ),
              const SizedBox(height: 12),

              if (_recType == AppConstants.recCustom) ...[
                const Text('Günler',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(7, (i) {
                    final day = i + 1; // 1=Mon
                    final selected = _selectedDays.contains(day);
                    return FilterChip(
                      label: Text(_dayNames[i]),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selectedDays.add(day);
                        } else {
                          _selectedDays.remove(day);
                        }
                      }),
                    );
                  }),
                ),
                const SizedBox(height: 8),
              ],

              if (_recType == AppConstants.recWeekly) ...[
                Row(children: [
                  const Text('Her'),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue: _interval.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (v) => _interval = int.tryParse(v) ?? 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('haftada bir'),
                ]),
                const SizedBox(height: 8),
              ],
            ],

            // Deadline
            const Text('Son Tarih',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _deadline ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 12),
                  Text(
                    _deadline != null
                        ? AppConstants.formatDate(_deadline!)
                        : 'Tarih seç (isteğe bağlı)',
                    style: TextStyle(
                      color: _deadline != null
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (_deadline != null)
                    GestureDetector(
                      onTap: () => setState(() => _deadline = null),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: AppTheme.textSecondary),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Assigned to
            const Text('Kişiler',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            usersAsync.when(
              data: (users) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: users.map((u) {
                  final selected = _assignedTo.contains(u.id);
                  return FilterChip(
                    label: Text(u.name),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _assignedTo.add(u.id);
                      } else {
                        _assignedTo.remove(u.id);
                      }
                    }),
                  );
                }).toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Kullanıcılar yüklenemedi'),
            ),
            const SizedBox(height: 16),

            // Reminder
            SwitchListTile(
              title: const Text('Hatırlatma Bildirimi',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Tamamlanmadıysa bildirim gönder'),
              value: _reminderEnabled,
              onChanged: (v) => setState(() => _reminderEnabled = v),
              contentPadding: EdgeInsets.zero,
              activeColor: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primary : const Color(0xFFD1D5DB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: selected ? Colors.white : AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              )),
        ]),
      ),
    );
  }
}
