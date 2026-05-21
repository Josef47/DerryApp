import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';

final taskServiceProvider = Provider<TaskService>((ref) => TaskService());

final allTasksProvider = StreamProvider<List<TaskModel>>((ref) {
  return ref.watch(taskServiceProvider).watchAllTasks();
});

final userTasksProvider =
    StreamProvider.family<List<TaskModel>, String>((ref, userId) {
  return ref.watch(taskServiceProvider).watchUserTasks(userId);
});

final todayCompletionsProvider =
    StreamProvider.family<List<CompletionModel>, String>((ref, userId) {
  return ref.watch(taskServiceProvider).watchTodayCompletions(userId);
});

final weekCompletionsProvider =
    StreamProvider.family<List<CompletionModel>, String>((ref, weekLabel) {
  return ref.watch(taskServiceProvider).watchWeekCompletions(weekLabel);
});
