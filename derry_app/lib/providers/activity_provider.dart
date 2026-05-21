import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_type_model.dart';
import '../models/activity_log_model.dart';
import '../services/activity_service.dart';

final activityServiceProvider = Provider<ActivityService>((ref) => ActivityService());

final activeTypesProvider = StreamProvider<List<ActivityTypeModel>>((ref) {
  return ref.watch(activityServiceProvider).watchActiveTypes();
});

final allTypesProvider = StreamProvider<List<ActivityTypeModel>>((ref) {
  return ref.watch(activityServiceProvider).watchAllTypes();
});

final userActivityLogsProvider =
    StreamProvider.family<List<ActivityLogModel>, String>((ref, userId) {
  return ref.watch(activityServiceProvider).watchUserLogs(userId);
});

final weekActivityLogsProvider =
    StreamProvider.family<List<ActivityLogModel>, String>((ref, weekLabel) {
  return ref.watch(activityServiceProvider).watchWeekLogs(weekLabel);
});
