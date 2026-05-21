import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogModel {
  final String id;
  final String userId;
  final String activityTypeId;
  final double value;
  final String weekLabel;
  final String? note;
  final bool syncedToDrive;
  final DateTime createdAt;

  const ActivityLogModel({
    required this.id,
    required this.userId,
    required this.activityTypeId,
    required this.value,
    required this.weekLabel,
    this.note,
    this.syncedToDrive = false,
    required this.createdAt,
  });

  factory ActivityLogModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ActivityLogModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      activityTypeId: d['activityTypeId'] ?? '',
      value: (d['value'] ?? 0).toDouble(),
      weekLabel: d['weekLabel'] ?? '',
      note: d['note'],
      syncedToDrive: d['syncedToDrive'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'activityTypeId': activityTypeId,
        'value': value,
        'weekLabel': weekLabel,
        if (note != null) 'note': note,
        'syncedToDrive': syncedToDrive,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
