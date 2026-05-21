import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings_model.dart';
import '../models/user_model.dart';
import '../models/drive_link_model.dart';
import '../services/settings_service.dart';
import '../services/drive_service.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) => SettingsService());
final driveServiceProvider = Provider<DriveService>((ref) => DriveService());

final appSettingsProvider = StreamProvider<AppSettingsModel>((ref) {
  return ref.watch(settingsServiceProvider).watchSettings();
});

final allUsersProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(settingsServiceProvider).watchUsers();
});

final driveLinksProvider = StreamProvider<List<DriveLinkModel>>((ref) {
  return ref.watch(driveServiceProvider).watchLinks();
});
