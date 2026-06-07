import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettingsModel {
  final String reminderTime; // "08:00"
  final String timezone;
  final String houseName;
  const AppSettingsModel({
    this.reminderTime = '08:00',
    this.timezone = 'Europe/Amsterdam',
    this.houseName = 'Our House',
  });

  factory AppSettingsModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppSettingsModel(
      reminderTime: d['reminderTime'] ?? '08:00',
      timezone: d['timezone'] ?? 'Europe/Amsterdam',
      houseName: d['houseName'] ?? 'Our House',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'reminderTime': reminderTime,
        'timezone': timezone,
        'houseName': houseName,
      };
}
