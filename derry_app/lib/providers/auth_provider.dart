import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../core/constants.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Current logged-in user (loaded from SharedPrefs + Firestore)
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  return ref.read(authServiceProvider).getSessionUser();
});

// Simple sync check from SharedPrefs
final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final uid = prefs.getString(AppConstants.prefUserId);
  return uid != null && uid.isNotEmpty;
});

final isHousemasterProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(AppConstants.prefIsHousemaster) ?? false;
});

final currentUserIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(AppConstants.prefUserId) ?? '';
});
