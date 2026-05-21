import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettingsModel {
  final String reminderTime; // "08:00"
  final String timezone;
  final String houseName;
  final String? driveSheetId;
  final String? googleRefreshToken;

  const AppSettingsModel({
    this.reminderTime = '08:00',
    this.timezone = 'Europe/Amsterdam',
    this.houseName = 'Our House',
    this.driveSheetId,
    this.googleRefreshToken,
  });

  factory AppSettingsModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppSettingsModel(
      reminderTime: d['reminderTime'] ?? '08:00',
      timezone: d['timezone'] ?? 'Europe/Amsterdam',
      houseName: d['houseName'] ?? 'Our House',
      driveSheetId: d['driveSheetId'],
      googleRefreshToken: d['googleRefreshToken'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'reminderTime': reminderTime,
        'timezone': timezone,
        'houseName': houseName,
        if (driveSheetId != null) 'driveSheetId': driveSheetId,
        if (googleRefreshToken != null)
          'googleRefreshToken': googleRefreshToken,
      };
}
