import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/duty_model.dart';

const _uuid = Uuid();

class DutyService {
  final _db = FirebaseFirestore.instance;

  // ── Zones ──────────────────────────────────────────────────────────────

  Stream<List<DutyZoneModel>> watchZones() => _db
      .collection(AppConstants.colDutyZones)
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map(DutyZoneModel.fromFirestore).toList());

  Future<void> addZone({
    required String name,
    required String iconName,
    int? order,
  }) async {
    final snap = await _db.collection(AppConstants.colDutyZones).get();
    await _db.collection(AppConstants.colDutyZones).add({
      'name': name,
      'iconName': iconName,
      'order': order ?? snap.docs.length,
      'miniTasks': <Map<String, dynamic>>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateZoneName(String zoneId, String name) async {
    await _db
        .collection(AppConstants.colDutyZones)
        .doc(zoneId)
        .update({'name': name});
  }

  Future<void> deleteZone(String zoneId) async {
    await _db.collection(AppConstants.colDutyZones).doc(zoneId).delete();
  }

  Future<void> addMiniTask(String zoneId, String title) async {
    final zoneDoc =
        await _db.collection(AppConstants.colDutyZones).doc(zoneId).get();
    final currentTasks =
        (zoneDoc.data()?['miniTasks'] as List<dynamic>? ?? []);
    final newTask = {
      'id': _uuid.v4(),
      'title': title,
      'order': currentTasks.length,
    };
    await _db.collection(AppConstants.colDutyZones).doc(zoneId).update({
      'miniTasks': FieldValue.arrayUnion([newTask]),
    });
  }

  Future<void> deleteMiniTask(String zoneId, String taskId) async {
    final zoneDoc =
        await _db.collection(AppConstants.colDutyZones).doc(zoneId).get();
    final tasks = (zoneDoc.data()?['miniTasks'] as List<dynamic>? ?? [])
        .where((t) => (t as Map)['id'] != taskId)
        .toList();
    await _db
        .collection(AppConstants.colDutyZones)
        .doc(zoneId)
        .update({'miniTasks': tasks});
  }

  // ── Assignments ────────────────────────────────────────────────────────

  String _assignmentId(String weekLabel, String zoneId) =>
      '${weekLabel}_$zoneId';

  Stream<List<DutyAssignmentModel>> watchAssignmentsForWeek(
          String weekLabel) =>
      _db
          .collection(AppConstants.colDutyAssignments)
          .where('weekLabel', isEqualTo: weekLabel)
          .snapshots()
          .map((s) => s.docs.map(DutyAssignmentModel.fromFirestore).toList());

  Future<DutyAssignmentModel?> getAssignment(
      String weekLabel, String zoneId) async {
    final doc = await _db
        .collection(AppConstants.colDutyAssignments)
        .doc(_assignmentId(weekLabel, zoneId))
        .get();
    if (!doc.exists) return null;
    return DutyAssignmentModel.fromFirestore(doc);
  }

  Future<void> setAssignment({
    required String weekLabel,
    required String zoneId,
    required String? userId,
  }) async {
    final docId = _assignmentId(weekLabel, zoneId);
    await _db
        .collection(AppConstants.colDutyAssignments)
        .doc(docId)
        .set({
      'weekLabel': weekLabel,
      'zoneId': zoneId,
      'assignedUserId': userId,
      'completedMiniTaskIds': <String>[],
      'isCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // When reassigning, reset completion state
    if (userId != null) {
      await _db
          .collection(AppConstants.colDutyAssignments)
          .doc(docId)
          .update({
        'completedMiniTaskIds': <String>[],
        'isCompleted': false,
        'assignedUserId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> toggleMiniTask({
    required String weekLabel,
    required String zoneId,
    required String taskId,
    required bool completed,
  }) async {
    final docId = _assignmentId(weekLabel, zoneId);
    final ref = _db.collection(AppConstants.colDutyAssignments).doc(docId);

    // Ensure document exists before toggling
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'weekLabel': weekLabel,
        'zoneId': zoneId,
        'assignedUserId': null,
        'completedMiniTaskIds': <String>[],
        'isCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    if (completed) {
      await ref.update({
        'completedMiniTaskIds': FieldValue.arrayUnion([taskId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update({
        'completedMiniTaskIds': FieldValue.arrayRemove([taskId]),
        'isCompleted': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> markZoneComplete({
    required String weekLabel,
    required String zoneId,
    required bool isCompleted,
  }) async {
    final docId = _assignmentId(weekLabel, zoneId);
    await _db
        .collection(AppConstants.colDutyAssignments)
        .doc(docId)
        .update({
      'isCompleted': isCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
