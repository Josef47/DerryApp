import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String role;
  final bool isHousemaster;
  final String? fcmToken;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.role,
    required this.isHousemaster,
    this.fcmToken,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: d['name'] ?? '',
      role: d['role'] ?? 'member',
      isHousemaster: d['isHousemaster'] ?? false,
      fcmToken: d['fcmToken'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'role': role,
        'isHousemaster': isHousemaster,
        if (fcmToken != null) 'fcmToken': fcmToken,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
