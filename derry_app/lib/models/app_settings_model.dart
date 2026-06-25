import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettingsModel {
  final String reminderTime; // "08:00"
  final String timezone;
  final String houseName;
  // 1=Pzt, 2=Sal, 3=Çar (default), 4=Per, 5=Cum, 6=Cmt, 7=Paz
  final int dutyDayOfWeek;

  const AppSettingsModel({
    this.reminderTime = '08:00',
    this.timezone = 'Europe/Amsterdam',
    this.houseName = 'Our House',
    this.dutyDayOfWeek = 3,
  });

  factory AppSettingsModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppSettingsModel(
      reminderTime: d['reminderTime'] ?? '08:00',
      timezone: d['timezone'] ?? 'Europe/Amsterdam',
      houseName: d['houseName'] ?? 'Our House',
      dutyDayOfWeek: d['dutyDayOfWeek'] as int? ?? 3,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'reminderTime': reminderTime,
        'timezone': timezone,
        'houseName': houseName,
        'dutyDayOfWeek': dutyDayOfWeek,
      };

  AppSettingsModel copyWith({
    String? reminderTime,
    String? timezone,
    String? houseName,
    int? dutyDayOfWeek,
  }) =>
      AppSettingsModel(
        reminderTime: reminderTime ?? this.reminderTime,
        timezone: timezone ?? this.timezone,
        houseName: houseName ?? this.houseName,
        dutyDayOfWeek: dutyDayOfWeek ?? this.dutyDayOfWeek,
      );
}
