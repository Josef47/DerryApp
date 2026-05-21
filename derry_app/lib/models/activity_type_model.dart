import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityTypeModel {
  final String id;
  final String name;
  final String unit;
  final bool active;
  final String createdBy;

  const ActivityTypeModel({
    required this.id,
    required this.name,
    required this.unit,
    this.active = true,
    required this.createdBy,
  });

  factory ActivityTypeModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ActivityTypeModel(
      id: doc.id,
      name: d['name'] ?? '',
      unit: d['unit'] ?? '',
      active: d['active'] ?? true,
      createdBy: d['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'unit': unit,
        'active': active,
        'createdBy': createdBy,
      };
}
