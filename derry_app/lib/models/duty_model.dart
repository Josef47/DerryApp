import 'package:cloud_firestore/cloud_firestore.dart';

class DutyMiniTask {
  final String id;
  final String title;
  final int order;

  const DutyMiniTask({
    required this.id,
    required this.title,
    required this.order,
  });

  factory DutyMiniTask.fromMap(Map<String, dynamic> m) => DutyMiniTask(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        order: m['order'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'order': order};
}

class DutyZoneModel {
  final String id;
  final String name;
  final String iconName;
  final int order;
  final List<DutyMiniTask> miniTasks;
  final DateTime createdAt;

  const DutyZoneModel({
    required this.id,
    required this.name,
    required this.iconName,
    required this.order,
    required this.miniTasks,
    required this.createdAt,
  });

  factory DutyZoneModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final tasks = (d['miniTasks'] as List<dynamic>? ?? [])
        .map((t) => DutyMiniTask.fromMap(t as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return DutyZoneModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      iconName: d['iconName'] as String? ?? 'cleaning',
      order: d['order'] as int? ?? 0,
      miniTasks: tasks,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'iconName': iconName,
        'order': order,
        'miniTasks': miniTasks.map((t) => t.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  DutyZoneModel copyWith({
    String? name,
    String? iconName,
    int? order,
    List<DutyMiniTask>? miniTasks,
  }) =>
      DutyZoneModel(
        id: id,
        name: name ?? this.name,
        iconName: iconName ?? this.iconName,
        order: order ?? this.order,
        miniTasks: miniTasks ?? this.miniTasks,
        createdAt: createdAt,
      );
}

class DutyAssignmentModel {
  // Document ID format: {weekLabel}_{zoneId}
  final String id;
  final String weekLabel;
  final String zoneId;
  final String? assignedUserId;
  final List<String> completedMiniTaskIds;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DutyAssignmentModel({
    required this.id,
    required this.weekLabel,
    required this.zoneId,
    this.assignedUserId,
    required this.completedMiniTaskIds,
    required this.isCompleted,
    required this.createdAt,
    this.updatedAt,
  });

  factory DutyAssignmentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DutyAssignmentModel(
      id: doc.id,
      weekLabel: d['weekLabel'] as String? ?? '',
      zoneId: d['zoneId'] as String? ?? '',
      assignedUserId: d['assignedUserId'] as String?,
      completedMiniTaskIds:
          List<String>.from(d['completedMiniTaskIds'] as List? ?? []),
      isCompleted: d['isCompleted'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'weekLabel': weekLabel,
        'zoneId': zoneId,
        'assignedUserId': assignedUserId,
        'completedMiniTaskIds': completedMiniTaskIds,
        'isCompleted': isCompleted,
        'createdAt': Timestamp.fromDate(createdAt),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };

  bool isMiniTaskCompleted(String taskId) =>
      completedMiniTaskIds.contains(taskId);
}
