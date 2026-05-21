import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/app_settings_model.dart';
import '../models/user_model.dart';

class SettingsService {
  final _db = FirebaseFirestore.instance;

  Stream<AppSettingsModel> watchSettings() => _db
      .collection(AppConstants.colSettings)
      .doc(AppConstants.docSettings)
      .snapshots()
      .map((s) => s.exists
          ? AppSettingsModel.fromFirestore(s)
          : const AppSettingsModel());

  Future<void> updateSettings(AppSettingsModel settings) async {
    await _db
        .collection(AppConstants.colSettings)
        .doc(AppConstants.docSettings)
        .set(settings.toFirestore());
  }

  Stream<List<UserModel>> watchUsers() => _db
      .collection(AppConstants.colUsers)
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(UserModel.fromFirestore).toList());

  Future<void> deleteUser(String userId) async {
    await _db.collection(AppConstants.colUsers).doc(userId).delete();
  }
}
