import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/task_model.dart';

class TaskService {
  final _db = FirebaseFirestore.instance;

  Stream<List<TaskModel>> watchAllTasks() => _db
      .collection(AppConstants.colTasks)
      .where('archived', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.map(TaskModel.fromFirestore).toList());

  Stream<List<TaskModel>> watchUserTasks(String userId) => _db
      .collection(AppConstants.colTasks)
      .where('assignedTo', arrayContains: userId)
      .where('archived', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.map(TaskModel.fromFirestore).toList());

  Stream<List<CompletionModel>> watchTodayCompletions(String userId) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    return _db
        .collection(AppConstants.colCompletions)
        .where('userId', isEqualTo: userId)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('completedAt', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((s) => s.docs.map(CompletionModel.fromFirestore).toList());
  }

  Stream<List<CompletionModel>> watchWeekCompletions(String weekLabel) => _db
      .collection(AppConstants.colCompletions)
      .where('weekLabel', isEqualTo: weekLabel)
      .snapshots()
      .map((s) => s.docs.map(CompletionModel.fromFirestore).toList());

  Future<void> createTask(TaskModel task) async {
    await _db.collection(AppConstants.colTasks).add(task.toFirestore());
  }

  Future<void> updateTask(TaskModel task) async {
    await _db
        .collection(AppConstants.colTasks)
        .doc(task.id)
        .update(task.toFirestore());
  }

  Future<void> deleteTask(String taskId) async {
    await _db
        .collection(AppConstants.colTasks)
        .doc(taskId)
        .update({'archived': true});
  }

  Future<void> completeTask(String taskId, String userId, String weekLabel) async {
    // Write completion
    await _db.collection(AppConstants.colCompletions).add({
      'taskId': taskId,
      'userId': userId,
      'completedAt': FieldValue.serverTimestamp(),
      'weekLabel': weekLabel,
    });

    // Advance nextDeadline for recurring tasks
    final taskDoc = await _db.collection(AppConstants.colTasks).doc(taskId).get();
    if (!taskDoc.exists) return;
    final task = TaskModel.fromFirestore(taskDoc);
    if (task.type == AppConstants.taskRecurring) {
      final nextDeadline = _nextOccurrence(task);
      if (nextDeadline != null) {
        await taskDoc.reference.update({
          'recurrence.nextDeadline': Timestamp.fromDate(nextDeadline),
        });
      }
    }
  }

  Future<void> uncompleteTask(String taskId, String userId) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    final snaps = await _db
        .collection(AppConstants.colCompletions)
        .where('taskId', isEqualTo: taskId)
        .where('userId', isEqualTo: userId)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('completedAt', isLessThan: Timestamp.fromDate(end))
        .get();
    for (final doc in snaps.docs) {
      await doc.reference.delete();
    }
  }

  DateTime? _nextOccurrence(TaskModel task) {
    final now = DateTime.now();
    final rec = task.recurrence;
    switch (rec.type) {
      case AppConstants.recDaily:
        return now.add(const Duration(days: 1));
      case AppConstants.recWeekly:
        return now.add(Duration(days: 7 * rec.interval));
      case AppConstants.recCustom:
        if (rec.daysOfWeek.isEmpty) return null;
        // Find next matching weekday
        for (var i = 1; i <= 7; i++) {
          final candidate = now.add(Duration(days: i));
          if (rec.daysOfWeek.contains(candidate.weekday)) return candidate;
        }
        return null;
      default:
        return null;
    }
  }

  Future<TaskModel?> getTask(String taskId) async {
    final doc = await _db.collection(AppConstants.colTasks).doc(taskId).get();
    if (!doc.exists) return null;
    return TaskModel.fromFirestore(doc);
  }
}
