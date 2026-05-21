import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/activity_type_model.dart';
import '../models/activity_log_model.dart';

class ActivityService {
  final _db = FirebaseFirestore.instance;

  Stream<List<ActivityTypeModel>> watchActiveTypes() => _db
      .collection(AppConstants.colActivityTypes)
      .where('active', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(ActivityTypeModel.fromFirestore).toList());

  Stream<List<ActivityTypeModel>> watchAllTypes() => _db
      .collection(AppConstants.colActivityTypes)
      .snapshots()
      .map((s) => s.docs.map(ActivityTypeModel.fromFirestore).toList());

  Stream<List<ActivityLogModel>> watchUserLogs(String userId) => _db
      .collection(AppConstants.colActivityLogs)
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ActivityLogModel.fromFirestore).toList());

  Stream<List<ActivityLogModel>> watchWeekLogs(String weekLabel) => _db
      .collection(AppConstants.colActivityLogs)
      .where('weekLabel', isEqualTo: weekLabel)
      .snapshots()
      .map((s) => s.docs.map(ActivityLogModel.fromFirestore).toList());

  Future<void> addLog(ActivityLogModel log) async {
    await _db.collection(AppConstants.colActivityLogs).add(log.toFirestore());
  }

  Future<void> createActivityType(ActivityTypeModel type) async {
    await _db.collection(AppConstants.colActivityTypes).add(type.toFirestore());
  }

  Future<void> updateActivityType(ActivityTypeModel type) async {
    await _db
        .collection(AppConstants.colActivityTypes)
        .doc(type.id)
        .update(type.toFirestore());
  }

  Future<void> deleteActivityType(String typeId) async {
    await _db
        .collection(AppConstants.colActivityTypes)
        .doc(typeId)
        .update({'active': false});
  }
}
