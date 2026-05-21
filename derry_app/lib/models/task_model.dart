import 'package:cloud_firestore/cloud_firestore.dart';

class RecurrenceModel {
  final String type; // none | daily | weekly | custom
  final List<int> daysOfWeek; // 1=Mon..7=Sun
  final int interval;
  final DateTime? nextDeadline;
  final DateTime? endDate;

  const RecurrenceModel({
    required this.type,
    this.daysOfWeek = const [],
    this.interval = 1,
    this.nextDeadline,
    this.endDate,
  });

  factory RecurrenceModel.fromMap(Map<String, dynamic> m) => RecurrenceModel(
        type: m['type'] ?? 'none',
        daysOfWeek: List<int>.from(m['daysOfWeek'] ?? []),
        interval: m['interval'] ?? 1,
        nextDeadline:
            (m['nextDeadline'] as Timestamp?)?.toDate(),
        endDate: (m['endDate'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'type': type,
        'daysOfWeek': daysOfWeek,
        'interval': interval,
        if (nextDeadline != null)
          'nextDeadline': Timestamp.fromDate(nextDeadline!),
        if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      };
}

class TaskModel {
  final String id;
  final String title;
  final String? description;
  final String type; // recurring | one-time
  final List<String> assignedTo;
  final RecurrenceModel recurrence;
  final DateTime? deadline;
  final bool reminderEnabled;
  final String createdBy;
  final DateTime createdAt;
  final bool archived;

  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.assignedTo,
    required this.recurrence,
    this.deadline,
    this.reminderEnabled = true,
    required this.createdBy,
    required this.createdAt,
    this.archived = false,
  });

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'],
      type: d['type'] ?? 'one-time',
      assignedTo: List<String>.from(d['assignedTo'] ?? []),
      recurrence: RecurrenceModel.fromMap(
          d['recurrence'] as Map<String, dynamic>? ?? {}),
      deadline: (d['deadline'] as Timestamp?)?.toDate(),
      reminderEnabled: d['reminderEnabled'] ?? true,
      createdBy: d['createdBy'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      archived: d['archived'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        if (description != null) 'description': description,
        'type': type,
        'assignedTo': assignedTo,
        'recurrence': recurrence.toMap(),
        if (deadline != null) 'deadline': Timestamp.fromDate(deadline!),
        'reminderEnabled': reminderEnabled,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'archived': archived,
      };
}

class CompletionModel {
  final String id;
  final String taskId;
  final String userId;
  final DateTime completedAt;
  final String weekLabel;

  const CompletionModel({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.completedAt,
    required this.weekLabel,
  });

  factory CompletionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CompletionModel(
      id: doc.id,
      taskId: d['taskId'] ?? '',
      userId: d['userId'] ?? '',
      completedAt:
          (d['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      weekLabel: d['weekLabel'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'taskId': taskId,
        'userId': userId,
        'completedAt': Timestamp.fromDate(completedAt),
        'weekLabel': weekLabel,
      };
}
