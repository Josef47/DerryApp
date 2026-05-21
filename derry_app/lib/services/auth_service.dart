import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/user_model.dart';

class AuthService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<UserModel?> loginWithKey(String key) async {
    final trimmed = key.trim().toUpperCase();
    final snap = await _db
        .collection(AppConstants.colOneTimeKeys)
        .where('key', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) throw Exception('Geçersiz davet anahtarı.');
    final keyDoc = snap.docs.first;
    final keyData = keyDoc.data();
    if (keyData['used'] == true) throw Exception('Bu anahtar zaten kullanıldı.');

    // Anonymous sign-in
    await _auth.signInAnonymously();

    // FCM token
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (_) {}

    final userId = keyData['userId'] as String;

    // Upsert user doc
    final userRef = _db.collection(AppConstants.colUsers).doc(userId);
    final userSnap = await userRef.get();
    if (!userSnap.exists) {
      await userRef.set({
        'name': keyData['name'] ?? 'Member',
        'role': keyData['role'] ?? AppConstants.roleMember,
        'isHousemaster': keyData['isHousemaster'] ?? false,
        'fcmToken': fcmToken,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await userRef.update({'fcmToken': fcmToken});
    }

    // Mark key as used
    await keyDoc.reference.update({'used': true, 'usedAt': FieldValue.serverTimestamp()});

    final updatedSnap = await userRef.get();
    final user = UserModel.fromFirestore(updatedSnap);

    // Persist session
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefUserId, user.id);
    await prefs.setString(AppConstants.prefUserName, user.name);
    await prefs.setBool(AppConstants.prefIsHousemaster, user.isHousemaster);

    return user;
  }

  Future<UserModel?> getSessionUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(AppConstants.prefUserId);
    if (userId == null || userId.isEmpty) return null;
    try {
      final doc = await _db.collection(AppConstants.colUsers).doc(userId).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefUserId);
    await prefs.remove(AppConstants.prefUserName);
    await prefs.remove(AppConstants.prefIsHousemaster);
  }

  // Housemaster creates a new invite key
  Future<String> createInviteKey({
    required String name,
    required bool isHousemaster,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final creatorId = prefs.getString(AppConstants.prefUserId) ?? '';

    // Generate unique user ID
    final userRef = _db.collection(AppConstants.colUsers).doc();
    final userId = userRef.id;

    // Generate key: XX-XXXX-XXXX
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String randomKey() {
      final buf = StringBuffer();
      for (var i = 0; i < 8; i++) {
        if (i == 4) buf.write('-');
        buf.write(chars[(DateTime.now().microsecondsSinceEpoch + i * 31) % chars.length]);
      }
      return 'HM-${buf.toString()}';
    }

    final key = randomKey();
    await _db.collection(AppConstants.colOneTimeKeys).doc(key).set({
      'key': key,
      'userId': userId,
      'name': name,
      'role': isHousemaster ? AppConstants.roleHousemaster : AppConstants.roleMember,
      'isHousemaster': isHousemaster,
      'used': false,
      'createdBy': creatorId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return key;
  }
}
